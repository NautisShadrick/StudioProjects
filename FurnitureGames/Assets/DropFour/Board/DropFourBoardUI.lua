--!Type(UI)

-- DropFourBoardUI -- the 7x6 board view, shown to everyone holding a seat while a game is
-- running. Players get live column taps; spectators get the same board read-only with a
-- banner, so waiting in the queue is not dead time.
--
-- The board is rendered from the replicated `board` value, which means a spectator or a
-- mid-game joiner is correct with no bespoke sync. DiscDroppedEvent is the animation
-- trigger only: the cell it targets is held back from the value-driven render until the
-- flying disc lands, so a disc never pops into place before its own animation.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("The DropFourManager on the parent GameObject. It is a ClientAndServer script, not a Module, so it must be referenced here rather than required.")
--!SerializeField
local manager : DropFourManager = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Must match .flying-disc / .board-disc in the USS so the disc lands flush.
local FLYING_DISC_SIZE = 42
local STATE_PLAYING = "PLAYING"

-- Drop flight. Held deliberately short: the board is small, and a long fall makes a
-- 7-column game feel sluggish.
local DROP_SECONDS = 0.42

-- Playable-column hint float. Same parameters as the playable-card float in Color Splash,
-- so "you can interact with this" reads identically across both games.
local FLOAT_SECONDS = 1.6
local FLOAT_DISTANCE = 10

-- Winning-line pulse.
local WIN_PULSE_SECONDS = 0.5
local WIN_PULSE_MIN = 1.0
local WIN_PULSE_MAX = 1.18

-- Window slide, matching the lobby / HUD / launcher views.
local SLIDE_SECONDS = 0.35
local SLIDE_OFFSCREEN_PCT = 100

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local tableRegistry = require("DropFourRegistry")
local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--------------------------------
------     UI BINDINGS    ------
--------------------------------
--!Bind
local _boardRow : VisualElement = nil
--!Bind
local _boardGrid : VisualElement = nil
--!Bind
local _capRow : VisualElement = nil
--!Bind
local _flightLayer : VisualElement = nil
--!Bind
local _spectatorBanner : Label = nil
--!Bind
local _minimizeButton : VisualElement = nil
--!Bind
local _quitButton : Label = nil

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- discs[row][col] -> the VisualElement whose class carries the cell's mark.
local discs: {{VisualElement}} = {}
-- caps[col] -> the floating drop-hint disc above that column.
local caps: {VisualElement} = {}
-- Columns currently playable by the local player, keyed by column number.
local readyColumns: {[number]: boolean} = {}
-- Flat cell indices whose disc is mid-flight, so renderBoard leaves them empty until the
-- flight lands. Without this the replicated board would paint the disc instantly and the
-- animation would play on top of an already-filled slot.
local pendingCells: {[number]: boolean} = {}
local winCells: {any} = {}
local slideTween = nil
local floatTween = nil
local winTween = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- Localized string lookup; falls through to English until a loc database is assigned.
local function L(key: string, fallback: string): string
    local _s: any = _G.Strings
    return tostring((_s and _s[key]) or fallback)
end

local function slideApply(pct: number)
    if _boardRow then
        _boardRow.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.Percent(pct)))
    end
end

local function playSlide(fromPct: number, toPct: number, easing)
    if slideTween then
        slideTween:stop()
    end
    slideApply(fromPct)
    slideTween = Tween:new(
        fromPct, toPct, SLIDE_SECONDS, false, false, easing,
        function(value) slideApply(value) end,
        function() slideApply(toPct) end
    )
    slideTween:start()
end

-- Paint one disc element for a mark (0 = empty).
local function applyMark(disc: VisualElement, mark: number)
    disc:RemoveFromClassList("board-disc-1")
    disc:RemoveFromClassList("board-disc-2")
    if mark == 1 then
        disc:AddToClassList("board-disc-1")
    elseif mark == 2 then
        disc:AddToClassList("board-disc-2")
    end
end

-- Ask the server to drop in this column. Locally gated so an illegal tap is not even sent;
-- the server re-validates regardless.
local function requestDrop(col: number)
    if not manager.GetPlayersTurn(client.localPlayer) then
        return
    end
    if not readyColumns[col] then
        return
    end
    Sounds.HapticsLight:Play()
    manager.NotifyActivity()
    manager.DropRequest:FireServer(col)
end

local function buildGrid()
    _boardGrid:Clear()
    _capRow:Clear()
    discs = {}
    caps = {}

    for _row = 1, manager.ROWS do
        discs[_row] = {}
    end

    for _col = 1, manager.COLS do
        local _cap = VisualElement.new()
        _cap:AddToClassList("col-cap")
        _cap.pickingMode = PickingMode.Ignore
        local _capDisc = VisualElement.new()
        _capDisc:AddToClassList("col-cap-disc")
        _capDisc.pickingMode = PickingMode.Ignore
        _cap:Add(_capDisc)
        _capRow:Add(_cap)
        caps[_col] = _capDisc

        local _column = VisualElement.new()
        _column:AddToClassList("board-col")
        -- Dynamically created elements are not reliably tappable unless pickingMode is set
        -- explicitly in Lua, even with a USS rule.
        _column.pickingMode = PickingMode.Position
        _column:RegisterPressCallback(function() requestDrop(_col) end)
        _boardGrid:Add(_column)

        -- Row 1 is the top row, so building rows in order fills the column top-down and
        -- discs land at the highest row number.
        for _row = 1, manager.ROWS do
            local _cell = VisualElement.new()
            _cell:AddToClassList("board-cell")
            _cell.pickingMode = PickingMode.Ignore
            local _disc = VisualElement.new()
            _disc:AddToClassList("board-disc")
            _disc.pickingMode = PickingMode.Ignore
            _cell:Add(_disc)
            _column:Add(_cell)
            discs[_row][_col] = _disc
        end
    end
end

local function clearWinHighlight()
    if winTween then
        winTween:stop()
        winTween = nil
    end
    for _, cell in ipairs(winCells) do
        local _disc = discs[cell.row] and discs[cell.row][cell.col]
        if _disc then
            _disc:RemoveFromClassList("board-disc-win")
            _disc.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
        end
    end
    winCells = {}
end

-- Repaint every cell from the replicated board, skipping any cell whose disc is still in
-- flight.
local function renderBoard(board)
    if not board then
        return
    end
    for _row = 1, manager.ROWS do
        for _col = 1, manager.COLS do
            local _disc = discs[_row] and discs[_row][_col]
            if _disc then
                local _index = manager.CellIndex(_row, _col)
                if pendingCells[_index] then
                    applyMark(_disc, 0)
                else
                    applyMark(_disc, manager.CellAt(board, _row, _col))
                end
            end
        end
    end
end

-- Recompute which columns the local player may drop into, and show a hint disc in their own
-- color above each. Spectators and off-turn players get none.
local function refreshReady()
    readyColumns = {}
    local _mark = manager.GetLocalPlayerMark()
    local _myTurn = _mark ~= nil and manager.GetPlayersTurn(client.localPlayer)

    for _col = 1, manager.COLS do
        local _capDisc = caps[_col]
        local _playable = _myTurn and manager.GetLandingRow(_col) ~= nil
        readyColumns[_col] = _playable or nil
        if _capDisc then
            if _playable then
                _capDisc:RemoveFromClassList("board-disc-1")
                _capDisc:RemoveFromClassList("board-disc-2")
                _capDisc:AddToClassList(_mark == 2 and "board-disc-2" or "board-disc-1")
                _capDisc.style.display = DisplayStyle.Flex
            else
                _capDisc.style.display = DisplayStyle.None
                _capDisc.style.top = Length.new(0)
            end
        end
    end

    -- Spectator banner: holding a seat but not in the running game.
    if _mark == nil and manager.TableState.value == STATE_PLAYING then
        _spectatorBanner.text = L("drop_four_spectating", "Watching -- you're in the next game")
        _spectatorBanner.style.display = DisplayStyle.Flex
    else
        _spectatorBanner.style.display = DisplayStyle.None
    end
end

-- Fly a disc from the column's cap down into its landing cell, then hand the cell back to
-- the value-driven render. Coordinates are converted from world space into the flight
-- layer's local (scaled) units, the same conversion the Color Splash card flight uses.
local function animateDrop(col: number, row: number, mark: number)
    local _index = manager.CellIndex(row, col)
    local _disc = discs[row] and discs[row][col]
    local _cap = caps[col]

    -- Any bail-out below must still paint the cell, or the disc would go missing entirely.
    local function paintNow()
        pendingCells[_index] = nil
        if _disc then
            applyMark(_disc, mark)
        end
    end

    if not _disc or not _cap then
        paintNow()
        return
    end

    local _parentWorld = _flightLayer.worldBound
    local _cellWorld = _disc.worldBound
    local _capWorld = _cap.worldBound
    -- Window hidden or not laid out yet: skip the flourish, keep the state correct.
    if _parentWorld.width <= 0 or _cellWorld.width <= 0 then
        paintNow()
        return
    end

    local _parentLocalWidth = nil
    pcall(function() _parentLocalWidth = _flightLayer.layout.width end)
    if not _parentLocalWidth or _parentLocalWidth <= 0 then
        paintNow()
        return
    end
    local _scaleFactor = _parentWorld.width / _parentLocalWidth
    if _scaleFactor <= 0 then
        _scaleFactor = 1
    end

    local _endX = (_cellWorld.center.x - _parentWorld.x) / _scaleFactor - FLYING_DISC_SIZE / 2
    local _endY = (_cellWorld.center.y - _parentWorld.y) / _scaleFactor - FLYING_DISC_SIZE / 2
    local _startY = (_capWorld.center.y - _parentWorld.y) / _scaleFactor - FLYING_DISC_SIZE / 2

    -- Hold the target cell empty for the duration of the flight.
    pendingCells[_index] = true
    applyMark(_disc, 0)

    local _flying = VisualElement.new()
    _flying:AddToClassList("flying-disc")
    _flying:AddToClassList(mark == 2 and "board-disc-2" or "board-disc-1")
    _flying.pickingMode = PickingMode.Ignore
    _flying.style.left = Length.new(_endX)
    _flying.style.top = Length.new(_startY)
    _flightLayer:Add(_flying)
    _flying:BringToFront()

    -- bounce easing gives the disc a physical settle as it hits the stack.
    local _dropTween = Tween:new(
        0, 1, DROP_SECONDS, false, false, Easing.bounce,
        function(value)
            _flying.style.top = Length.new(Mathf.Lerp(_startY, _endY, value))
        end,
        function()
            _flying:RemoveFromHierarchy()
            paintNow()
            refreshReady()
        end
    )
    _dropTween:start()
end

local function showWinLine(cells)
    clearWinHighlight()
    if not cells then
        return
    end
    winCells = cells
    for _, cell in ipairs(winCells) do
        local _disc = discs[cell.row] and discs[cell.row][cell.col]
        if _disc then
            _disc:AddToClassList("board-disc-win")
        end
    end
    winTween = Tween:new(
        WIN_PULSE_MIN, WIN_PULSE_MAX, WIN_PULSE_SECONDS, true, true, Easing.easeInOutQuad,
        function(value)
            for _, cell in ipairs(winCells) do
                local _disc = discs[cell.row] and discs[cell.row][cell.col]
                if _disc then
                    _disc.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
                end
            end
        end
    )
    winTween:start()
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function SlideIn()
    playSlide(SLIDE_OFFSCREEN_PCT, 0, Easing.easeOutQuad)
end

function SlideOut()
    playSlide(0, SLIDE_OFFSCREEN_PCT, Easing.easeInQuad)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    if manager == nil then
        error("DropFourBoardUI: manager SerializeField is not assigned")
    end

    buildGrid()
    renderBoard(manager.Board.value)
    refreshReady()

    _minimizeButton:RegisterPressCallback(function() tableRegistry.Minimize() end)
    -- Quitting mid-game forfeits the match, so it routes through the launcher's confirm.
    _quitButton:RegisterPressCallback(function() tableRegistry.RequestQuit() end)

    manager.ConnectViewValue("board", function(newBoard)
        renderBoard(newBoard)
        refreshReady()
    end)

    manager.ConnectViewValue("currentTurnIndex", function()
        refreshReady()
    end)

    manager.ConnectViewValue("currentPlayers", function()
        refreshReady()
    end)

    manager.ConnectViewValue("tableState", function()
        refreshReady()
    end)

    manager.DiscDroppedEvent:Connect(function(col, row, mark)
        animateDrop(col, row, mark)
    end)

    -- A fresh game clears any leftover win highlight and repaints the empty board.
    manager.GameStartedEvent:Connect(function()
        clearWinHighlight()
        pendingCells = {}
        renderBoard(manager.Board.value)
        refreshReady()
    end)

    manager.YourTurnEvent:Connect(function()
        refreshReady()
    end)

    manager.GameWonEvent:Connect(function(winner, cells)
        showWinLine(cells)
        refreshReady()
    end)

    manager.GameDrawnEvent:Connect(function()
        refreshReady()
    end)

    -- Playable columns float their hint disc gently. Drives style.top rather than translate
    -- so it composes with layout instead of disturbing the worldBound the drop math reads.
    floatTween = Tween:new(
        0, 1, FLOAT_SECONDS, true, true, Easing.easeInOutQuad,
        function(value)
            local _offset = -FLOAT_DISTANCE * value
            for _col = 1, manager.COLS do
                local _capDisc = caps[_col]
                if _capDisc then
                    if readyColumns[_col] then
                        _capDisc.style.top = Length.new(_offset)
                    else
                        _capDisc.style.top = Length.new(0)
                    end
                end
            end
        end
    )
    floatTween:start()
end

function self:OnEnable()
    SlideIn()
end
