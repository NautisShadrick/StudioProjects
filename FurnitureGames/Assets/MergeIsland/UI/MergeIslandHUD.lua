--!Type(UI)

-- MergeIslandHUD -- the full-screen Merge Island board.
--
-- The grid is built ONCE and then repainted from MergeIslandManager's local mirror, which is
-- itself only ever written from a server snapshot. So the view has no game state of its own:
-- every repaint is the authoritative board.
--
-- Drag uses DragGesture, not raw pointer events. The Studio API does not expose pointer
-- capture, so a PointerMove-based drag would be lost the moment the pointer left the source
-- cell. Pickup identifies the grabbed cell from a per-cell PointerDownEvent (reliable, uses
-- the event target) and only the DROP target is resolved from coordinates.
--
-- Illegal drops never touch the network: the same rule function the server will run is checked
-- locally first, so a refused drag snaps back instantly. The server still re-validates
-- everything it is asked to do.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("Item art, ONE SPRITE PER TIER, ordered bottom of the ladder to top. Index 1 = tier 1. Any tier left empty falls back to its placeholder colour and tier number, so a partly-filled list is fine while you are still making art.")
--!SerializeField
local tierSprites : {Sprite} = {}

--------------------------------
------  USS CLASS NAMES   ------
--------------------------------
local BoardRowClass = "board-row"
local CellClass = "cell"
local CellHiddenClass = "cell-hidden"
local CellGhostClass = "cell-ghost"
local CellOpenClass = "cell-open"
local CellDropTargetClass = "cell-drop-target"
local CellItemClass = "cell-item"
local CellItemVisibleClass = "cell-item-visible"
local CellItemGhostClass = "cell-item-ghost"
local CellItemLiftedClass = "cell-item-lifted"
local CellTierClass = "cell-tier"
local FlyingItemClass = "flying-item"
local GeneratorButtonDisabledClass = "generator-button-disabled"
local WorldTopButtonClass = "world-top-button"
local WorldTopGlyphClass = "world-top-glyph"

--------------------------------
---- UXML ELEMENT BINDINGS -----
--------------------------------
--!Bind
local _hudRoot : VisualElement = nil
--!Bind
local _infoButton : VisualElement = nil
--!Bind
local _closeButton : VisualElement = nil
--!Bind
local _boardGrid : VisualElement = nil
--!Bind
local _loadingLabel : Label = nil
--!Bind
local _energyLabel : Label = nil
--!Bind
local _generatorButton : VisualElement = nil
--!Bind
local _hintLabel : Label = nil
--!Bind
local _toastLabel : Label = nil
--!Bind
local _flightLayer : VisualElement = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Must match .cell-item / .flying-item in the USS so a dropped item lands flush.
local ITEM_SIZE = 32
-- How far the finger must travel before a drag starts rather than reading as a tap.
local DRAG_MIN_DISTANCE = 6
-- The lifted item is drawn slightly larger so it reads as picked up.
local LIFT_SCALE = 1.2

local SNAP_BACK_SECONDS = 0.18
local POP_SECONDS = 0.26
local POP_FROM_SCALE = 0.55
local BREAK_SECONDS = 0.3
local BREAK_FROM_SCALE = 0.4
-- Toast: fades in while sliding up, holds, then fades out.
local TOAST_RISE_PX = 24
local TOAST_IN_SECONDS = 0.22
local TOAST_HOLD_SECONDS = 1.2
local TOAST_OUT_SECONDS = 0.35

local WORLD_TOP_BUTTON_INDEX = 0

-- Prints each gesture point alongside the grid's worldBound, to confirm the drag coordinate
-- space on a new build. See gesturePoint below.
local DEBUG_DRAG = false

local DEFAULT_HINT = "Drag an item onto a matching item to merge it"
-- Rejection reasons -> player-facing copy. Reasons the player cannot act on (an out-of-sync
-- move, a drag of nothing) are deliberately absent and fall through to the default hint.
local REJECT_MESSAGES = {
    no_energy = "Out of energy!",
    board_full = "Board is full!",
    mismatch = "Those tiers don't match",
    max_tier = "That's already the highest tier",
    locked = "That tile is still locked",
}

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local manager = require("MergeIslandManager")
local config = require("MergeIslandConfig")
local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- cellElements[index] = { root, item, tier, itemClass }
-- itemClass remembers which item-<type>-<tier> class is currently applied, so a repaint can
-- remove exactly that one instead of clearing the whole class list.
local cellElements: {any} = {}

-- The cell whose PointerDownEvent fired most recently, and which a starting drag will lift.
-- This is how a drag knows what was grabbed without depending on gesture coordinates.
--
-- It is cleared on the grid's own trickle-down handler (which runs BEFORE any cell's) and
-- consumed when a drag begins. Both matter: without them, a press that lands on the grid but
-- not on a cell would start a drag using whatever cell was pressed last, lifting the wrong
-- item.
local pressedIndex: number | nil = nil

-- Live drag, or nil. { fromIndex, element, hoverIndex, x, y, originX, originY }
-- x/y track the lifted element's current position so a snap-back never has to read a
-- StyleLength back out of the element.
local dragState: any = nil

-- Set when a legal drop is sent, so the merge pop plays on the authoritative repaint rather
-- than optimistically before it.
local pendingPopIndex: number | nil = nil

-- Keeps the source cell's item hidden between committing a move and the snapshot that confirms
-- it. Without this the item flickers back into its old cell for one network round trip.
local committedFromIndex: number | nil = nil

-- Bumped on every toast; a deferred fade-out only runs if its toast is still the newest one, so
-- a superseded toast cannot hide the one that replaced it.
local toastGeneration: number = 0
local toastTween = nil
local isOpen: boolean = false
local worldTopButton: VisualElement = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- Convert a gesture event into a panel-space point.
--
-- IF DROPS LAND ON THE WRONG CELL, THIS IS THE FUNCTION TO FIX. The docs do not state whether
-- gesture `position` is panel space (what worldBound uses) or raw screen space, and the two
-- differ by the panel scale and possibly a flipped Y. Every hit-test goes through here, so a
-- correction is one place. Set DEBUG_DRAG to print the gesture point next to the grid's
-- worldBound and the answer is immediately obvious.
local function gesturePoint(evt): Vector2
    local _point = Vector2.new(evt.position.x, evt.position.y)
    if DEBUG_DRAG then
        local _grid = _boardGrid.worldBound
        print("[MergeIslandHUD] gesture=(" .. tostring(_point.x) .. "," .. tostring(_point.y)
            .. ") screen=(" .. tostring(evt.screenPosition.x) .. "," .. tostring(evt.screenPosition.y)
            .. ") gridWorld=(" .. tostring(_grid.x) .. "," .. tostring(_grid.y)
            .. " " .. tostring(_grid.width) .. "x" .. tostring(_grid.height) .. ")")
    end
    return _point
end

-- Which cell is under a panel-space point, or nil. WorldToLocal handles the panel scale for
-- us, which is why this does not need the manual scale-factor math the Drop Four board uses.
local function cellIndexAt(point: Vector2): number | nil
    -- Cheap rejection first, so a drag outside the board does not test 49 cells per move.
    local _gridLocal = _boardGrid:WorldToLocal(point)
    if not _boardGrid:ContainsPoint(_gridLocal) then
        return nil
    end
    for i = 1, config.CELL_COUNT do
        local _ui = cellElements[i]
        if _ui then
            if _ui.root:ContainsPoint(_ui.root:WorldToLocal(point)) then
                return i
            end
        end
    end
    return nil
end

local function applyToast(opacity: number, risePx: number)
    _toastLabel.style.opacity = StyleFloat.new(opacity)
    _toastLabel.style.translate = StyleTranslate.new(
        Translate.new(Length.new(0), Length.new(risePx)))
end

-- Pop a transient message above the generator: fade in while sliding up from below, hold, then
-- fade out. Re-triggering restarts it, and the generation guard stops a superseded toast's
-- deferred fade-out from hiding the newer one.
local function showToast(text: string)
    toastGeneration = toastGeneration + 1
    local _generation = toastGeneration
    if toastTween then
        toastTween:stop()
        toastTween = nil
    end

    _toastLabel.text = text
    _toastLabel.style.display = DisplayStyle.Flex
    applyToast(0, TOAST_RISE_PX)

    toastTween = Tween:new(
        0, 1, TOAST_IN_SECONDS, false, false, Easing.easeOutQuad,
        function(value) applyToast(value, TOAST_RISE_PX * (1 - value)) end,
        function()
            applyToast(1, 0)
            Timer.After(TOAST_HOLD_SECONDS, function()
                if _generation ~= toastGeneration then
                    return
                end
                toastTween = Tween:new(
                    1, 0, TOAST_OUT_SECONDS, false, false, Easing.easeInQuad,
                    function(value) applyToast(value, 0) end,
                    function()
                        if _generation ~= toastGeneration then
                            return
                        end
                        applyToast(0, TOAST_RISE_PX)
                        _toastLabel.style.display = DisplayStyle.None
                        toastTween = nil
                    end
                )
                toastTween:start()
            end)
        end
    )
    toastTween:start()
end

-- The assigned sprite's texture for a tier, or nil when that tier has no art yet. Sprites are
-- assigned in the inspector, so a half-filled list is normal during production -- every caller
-- has to cope with nil rather than assume art exists.
local function tierTexture(tier: number?)
    -- `tier or 0` keeps the index a plain number for the type checker; index 0 never exists, so
    -- a nil tier falls through to the no-art path just the same.
    local _sprite = tierSprites[tier or 0]
    if not _sprite then
        return nil
    end
    return _sprite.texture
end

-- Paint one cell's item element for an item (or a ghost's silhouette). Passing nil tier hides
-- it. Art comes from tierSprites when available; the USS colour class and the tier number are
-- the fallback, and the number is dropped once real art is in so it does not sit on top of it.
local function hideItemVisual(ui)
    ui.item:RemoveFromClassList(CellItemVisibleClass)
    ui.item.style.backgroundImage = nil
    ui.tier.text = ""
end

local function applyItemVisual(ui, tier: number?, isGhost: boolean)
    if ui.itemClass then
        ui.item:RemoveFromClassList(ui.itemClass)
        ui.itemClass = nil
    end
    ui.item:RemoveFromClassList(CellItemGhostClass)

    if tier == nil then
        hideItemVisual(ui)
        return
    end
    local _info = config.TierInfo(tier)
    if not _info then
        hideItemVisual(ui)
        return
    end

    local _texture = tierTexture(tier)
    if _texture then
        ui.item.style.backgroundImage = _texture
        ui.tier.text = ""
    else
        ui.item.style.backgroundImage = nil
        ui.itemClass = _info.class
        ui.item:AddToClassList(_info.class)
        ui.tier.text = tostring(tier)
    end

    ui.item:AddToClassList(CellItemVisibleClass)
    if isGhost then
        ui.item:AddToClassList(CellItemGhostClass)
    end
end

local function renderCell(index: number)
    local _ui = cellElements[index]
    if not _ui then
        return
    end
    local _cell = config.CellAt(manager.GetCells(), index)

    _ui.root:RemoveFromClassList(CellHiddenClass)
    _ui.root:RemoveFromClassList(CellGhostClass)
    _ui.root:RemoveFromClassList(CellOpenClass)

    if _cell.state == config.STATE_GHOST then
        _ui.root:AddToClassList(CellGhostClass)
        applyItemVisual(_ui, _cell.tier, true)
    elseif _cell.state == config.STATE_OPEN then
        _ui.root:AddToClassList(CellOpenClass)
        applyItemVisual(_ui, _cell.tier, false)
    else
        _ui.root:AddToClassList(CellHiddenClass)
        applyItemVisual(_ui, nil, false)
    end

    -- A cell whose item is lifted (or whose move is committed but unconfirmed) keeps its layout
    -- but hides the item, so the grid never reflows mid-drag -- a reflow would move every
    -- worldBound the drop test reads.
    if (dragState and dragState.fromIndex == index) or committedFromIndex == index then
        _ui.item:AddToClassList(CellItemLiftedClass)
    else
        _ui.item:RemoveFromClassList(CellItemLiftedClass)
    end
end

local function scaleElement(element: VisualElement, value: number)
    element.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
end

-- Overshoot-and-settle pop, used for a spawn and for a completed merge.
local function popCell(index: number)
    local _ui = cellElements[index]
    if not _ui then
        return
    end
    local _tween = Tween:new(
        POP_FROM_SCALE, 1, POP_SECONDS, false, false, Easing.easeOutBack,
        function(value) scaleElement(_ui.item, value) end,
        function() scaleElement(_ui.item, 1) end
    )
    _tween:start()
end

-- Cells that just broke open grow in from small, so the board visibly expands.
local function playBreak(indices: {number})
    for _, index in ipairs(indices) do
        local _ui = cellElements[index]
        if _ui then
            local _tween = Tween:new(
                BREAK_FROM_SCALE, 1, BREAK_SECONDS, false, false, Easing.easeOutBack,
                function(value) scaleElement(_ui.root, value) end,
                function() scaleElement(_ui.root, 1) end
            )
            _tween:start()
        end
    end
end

local function refreshGenerator()
    if manager.CanSpawn() then
        _generatorButton:RemoveFromClassList(GeneratorButtonDisabledClass)
    else
        _generatorButton:AddToClassList(GeneratorButtonDisabledClass)
    end
end

local function renderBoard()
    if not manager.IsLoaded() then
        _loadingLabel.style.display = DisplayStyle.Flex
        return
    end
    _loadingLabel.style.display = DisplayStyle.None

    -- This snapshot IS the confirmation a committed move was waiting for, so the hold is
    -- released before painting -- the new board already shows the item in its new cell.
    committedFromIndex = nil

    for i = 1, config.CELL_COUNT do
        renderCell(i)
    end
    _energyLabel.text = tostring(manager.GetEnergy())
    refreshGenerator()

    -- The merge/unlock pop is played here, on the authoritative repaint, so the animation can
    -- never show a result the server did not actually grant.
    if pendingPopIndex then
        popCell(pendingPopIndex)
        pendingPopIndex = nil
    end
end

local function clearHover()
    if dragState and dragState.hoverIndex then
        local _ui = cellElements[dragState.hoverIndex]
        if _ui then
            _ui.root:RemoveFromClassList(CellDropTargetClass)
        end
        dragState.hoverIndex = nil
    end
end

-- Move the lifted element so it is centred on a panel-space point. Layout left/top, never
-- percent translate -- percent translate is not reflected in worldBound.
local function moveFlying(point: Vector2)
    local _local = _flightLayer:WorldToLocal(point)
    dragState.x = _local.x - ITEM_SIZE / 2
    dragState.y = _local.y - ITEM_SIZE / 2
    dragState.element.style.left = Length.new(dragState.x)
    dragState.element.style.top = Length.new(dragState.y)
end

-- Tear the drag down. `unhideSource` is false when a move has been committed to the server:
-- the source item stays hidden until the confirming snapshot, so it does not flicker back.
local function teardownDrag(unhideSource: boolean)
    if not dragState then
        return
    end
    clearHover()
    local _from = dragState.fromIndex
    dragState.element:RemoveFromHierarchy()
    dragState = nil
    if not unhideSource then
        return
    end
    local _ui = cellElements[_from]
    if _ui then
        _ui.item:RemoveFromClassList(CellItemLiftedClass)
    end
end

-- Tween the lifted item back to its origin cell, then tear the drag down. Used for every
-- illegal drop, which costs no network traffic at all.
local function snapBack()
    if not dragState then
        return
    end
    clearHover()
    local _element = dragState.element
    local _startX = dragState.x
    local _startY = dragState.y
    local _endX = dragState.originX
    local _endY = dragState.originY
    local _from = dragState.fromIndex

    -- Detach state now so a new drag can start even while this tween is still running.
    dragState = nil

    local _tween = Tween:new(
        0, 1, SNAP_BACK_SECONDS, false, false, Easing.easeOutQuad,
        function(value)
            _element.style.left = Length.new(Mathf.Lerp(_startX, _endX, value))
            _element.style.top = Length.new(Mathf.Lerp(_startY, _endY, value))
        end,
        function()
            _element:RemoveFromHierarchy()
            local _ui = cellElements[_from]
            if _ui then
                _ui.item:RemoveFromClassList(CellItemLiftedClass)
            end
        end
    )
    _tween:start()
end

local function beginDrag(index: number, point: Vector2)
    local _cells = manager.GetCells()
    if not config.HasItem(_cells, index) then
        return
    end
    local _cell = config.CellAt(_cells, index)
    local _info = config.TierInfo(_cell.tier)
    if not _info then
        return
    end

    local _sourceUi = cellElements[index]
    local _sourceWorld = _sourceUi.item.worldBound
    -- Not laid out yet (HUD hidden, or first frame): a drag would have nowhere to snap back to.
    if _sourceWorld.width <= 0 then
        return
    end
    local _originLocal = _flightLayer:WorldToLocal(Vector2.new(_sourceWorld.center.x, _sourceWorld.center.y))

    local _element = VisualElement.new()
    _element:AddToClassList(FlyingItemClass)
    _element.pickingMode = PickingMode.Ignore
    local _tierLabel = Label.new()
    _tierLabel:AddToClassList(CellTierClass)
    _tierLabel.pickingMode = PickingMode.Ignore
    -- Same art rule as a cell: the tier's sprite if it has one, otherwise the placeholder
    -- colour class plus its tier number.
    local _texture = tierTexture(_cell.tier)
    if _texture then
        _element.style.backgroundImage = _texture
    else
        _element:AddToClassList(_info.class)
        _tierLabel.text = tostring(_cell.tier)
    end
    _element:Add(_tierLabel)
    _flightLayer:Add(_element)
    _element:BringToFront()
    scaleElement(_element, LIFT_SCALE)

    dragState = {
        fromIndex = index,
        element = _element,
        hoverIndex = nil,
        originX = _originLocal.x - ITEM_SIZE / 2,
        originY = _originLocal.y - ITEM_SIZE / 2,
    }

    _sourceUi.item:AddToClassList(CellItemLiftedClass)
    moveFlying(point)
    Sounds.HapticsLight:Play()
end

local function buildGrid()
    _boardGrid:Clear()
    cellElements = {}

    for _row = 1, config.ROWS do
        local _rowElement = VisualElement.new()
        _rowElement:AddToClassList(BoardRowClass)
        _rowElement.pickingMode = PickingMode.Ignore
        _boardGrid:Add(_rowElement)

        for _col = 1, config.COLS do
            local _index = config.CellIndex(_row, _col)

            local _cellElement = VisualElement.new()
            _cellElement:AddToClassList(CellClass)
            -- Dynamically created elements are not reliably tappable unless pickingMode is set
            -- explicitly in Lua, even with a USS rule.
            _cellElement.pickingMode = PickingMode.Position
            _rowElement:Add(_cellElement)

            local _itemElement = VisualElement.new()
            _itemElement:AddToClassList(CellItemClass)
            _itemElement.pickingMode = PickingMode.Ignore
            _cellElement:Add(_itemElement)

            local _tierLabel = Label.new()
            _tierLabel:AddToClassList(CellTierClass)
            _tierLabel.pickingMode = PickingMode.Ignore
            _itemElement:Add(_tierLabel)

            cellElements[_index] = {
                root = _cellElement,
                item = _itemElement,
                tier = _tierLabel,
                itemClass = nil,
            }

            -- Pickup identity comes from the event target, not from coordinates, so grabbing
            -- the right item never depends on the gesture coordinate space.
            _cellElement:RegisterCallback(PointerDownEvent, function()
                pressedIndex = _index
            end)
        end
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function Show()
    if isOpen then
        return
    end
    isOpen = true
    _hudRoot.style.display = DisplayStyle.Flex
    -- Full-screen HUD: the world controls underneath would be unreachable anyway, and leaving
    -- them up lets a drag double as a camera pan.
    UI:HideWorldControls()
    renderBoard()
end

function Hide()
    if not isOpen then
        return
    end
    isOpen = false
    -- A drag in flight must not survive the HUD closing, or the flying element would be
    -- orphaned in a hidden layer.
    teardownDrag(true)
    -- Likewise a toast: bump the generation so any deferred fade-out is abandoned, and reset it
    -- so the next open does not flash a stale message mid-animation.
    toastGeneration = toastGeneration + 1
    if toastTween then
        toastTween:stop()
        toastTween = nil
    end
    _toastLabel.style.display = DisplayStyle.None
    applyToast(0, TOAST_RISE_PX)
    _hudRoot.style.display = DisplayStyle.None
    UI:ShowWorldControls()
end

function Toggle()
    if isOpen then
        Hide()
    else
        Show()
    end
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    -- A partly-filled sprite list is fine (those tiers fall back to placeholders), but MORE
    -- sprites than rungs means someone expected a tier that the ladder does not have, and the
    -- extras would silently never render.
    if #tierSprites > config.MAX_TIER then
        print("[MergeIslandHUD] tierSprites has " .. tostring(#tierSprites) .. " entries but the"
            .. " ladder only has " .. tostring(config.MAX_TIER) .. " tiers; the extras are"
            .. " ignored. Add rows to ITEM_TIERS in MergeIslandConfig to use them.")
    end

    buildGrid()

    -- Start closed; the world-top button is the way in.
    isOpen = false
    _hudRoot.style.display = DisplayStyle.None
    _hintLabel.text = DEFAULT_HINT

    _closeButton:RegisterPressCallback(function() Hide() end)
    _infoButton:RegisterPressCallback(function()
        showToast("Merge two matching items, or drop one on its faded twin to unlock the board")
    end)

    _generatorButton:RegisterPressCallback(function()
        if not manager.CanSpawn() then
            -- Refused locally: no spawn, no intent sent, just a toast saying why. The server
            -- would reject it too, but there is no reason to make the player wait for that.
            if manager.GetEnergy() < config.SPAWN_COST then
                showToast(REJECT_MESSAGES.no_energy)
            else
                showToast(REJECT_MESSAGES.board_full)
            end
            return
        end
        Sounds.HapticsLight:Play()
        manager.RequestSpawn()
    end)

    -- Clear the pending pickup on the way DOWN the hierarchy, so a cell's own handler (which
    -- runs later, on the way back up) is the only thing that can set it. A press that misses
    -- every cell therefore leaves it nil instead of leaving the previous cell armed.
    _boardGrid:RegisterCallback(PointerDownEvent, function()
        pressedIndex = nil
    end, TrickleDown.TrickleDown)

    -- Drag lives on the grid container, so the gesture keeps reporting after the finger leaves
    -- the cell it started on.
    _boardGrid:RegisterGesture(DragGesture.new(DRAG_MIN_DISTANCE))

    _boardGrid:RegisterCallback(DragGestureBegan, function(evt)
        if not isOpen or not manager.IsLoaded() then
            return
        end
        -- A drag already in flight (or a press that never landed on a cell) is not a pickup.
        if dragState or not pressedIndex then
            return
        end
        -- Consume it, so one press can only ever start one drag.
        local _index = pressedIndex
        pressedIndex = nil
        beginDrag(_index, gesturePoint(evt))
    end)

    _boardGrid:RegisterCallback(DragGestureChanged, function(evt)
        if not dragState then
            return
        end
        local _point = gesturePoint(evt)
        moveFlying(_point)

        local _over = cellIndexAt(_point)
        if _over == dragState.hoverIndex then
            return
        end
        clearHover()
        -- Highlight only a drop that would actually be legal, using the same rules the server
        -- will apply.
        if _over and manager.CanDrop(dragState.fromIndex, _over) then
            local _ui = cellElements[_over]
            if _ui then
                _ui.root:AddToClassList(CellDropTargetClass)
                dragState.hoverIndex = _over
            end
        end
    end)

    _boardGrid:RegisterCallback(DragGestureEnded, function(evt)
        if not dragState then
            return
        end
        -- A cancelled gesture (interrupted by the system, another pointer, etc.) is not a drop.
        if evt.cancelled then
            snapBack()
            return
        end
        local _from = dragState.fromIndex
        local _over = cellIndexAt(gesturePoint(evt))

        if not _over or not manager.CanDrop(_from, _over) then
            -- Illegal: resolved entirely locally, no network traffic.
            snapBack()
            return
        end

        local _result = manager.ResolveLocalDrop(_from, _over)
        -- A move is just a relocation; only a merge or an unlock earns a pop.
        if _result.kind ~= config.KIND_MOVE then
            pendingPopIndex = _over
        end
        -- Hold the source cell empty until the server's snapshot lands, so the item does not
        -- reappear at its old position for the round trip.
        committedFromIndex = _from
        teardownDrag(false)
        manager.RequestMove(_from, _over)
    end)

    manager.OnBoardChanged(function()
        renderBoard()
    end)

    manager.OnSpawned(function(index)
        popCell(index)
    end)

    manager.OnUnlocked(function(index, openedIndices)
        playBreak(openedIndices)
        Sounds.HapticsLight:Play()
    end)

    manager.OnRejected(function(reason)
        local _message = REJECT_MESSAGES[reason]
        if _message then
            showToast(_message)
        end
        refreshGenerator()
    end)

    -- Entry point. Building the button here keeps Merge Island drop-in: nothing else in the
    -- scene needs to know it exists.
    worldTopButton = VisualElement.new()
    worldTopButton:AddToClassList(WorldTopButtonClass)
    worldTopButton.pickingMode = PickingMode.Position
    local _glyph = Label.new()
    _glyph:AddToClassList(WorldTopGlyphClass)
    _glyph.text = "M"
    _glyph.pickingMode = PickingMode.Ignore
    worldTopButton:Add(_glyph)
    worldTopButton:RegisterPressCallback(function() Toggle() end)
    UI:AddWorldTopButton(worldTopButton, WORLD_TOP_BUTTON_INDEX)

    renderBoard()
end
