--!Type(UI)

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing
local playerTracker = require("playerTracker")
local KitePartsManager = require("KitePartsManager")

--!Bind
local _cardContainer: VisualElement = nil
--!Bind
local _placementArea: VisualElement = nil
--!Bind
local _confirmButton: Label = nil
--!Bind
local _title: Label = nil
--!Bind
local _partsScrollView: UIScrollView = nil
--!Bind
local _colorPicker: VisualElement = nil
--!Bind
local _transformToolbar: VisualElement = nil
--!Bind
local _rotateCCW: Label = nil
--!Bind
local _flipButton: Label = nil
--!Bind
local _rotateCW: Label = nil
--!Bind
local _scaleUp: Label = nil
--!Bind
local _scaleDown: Label = nil
--!Bind
local _duplicateButton: Label = nil
--!Bind
local _deleteButton: Label = nil

local KitePartItemClass = "kite-part-item"
local PlacedKitePartClass = "placed-kite-part"
local LockedClass = "locked"

local COLOR_SWATCHES = {
    "#FF6F61",
    "#FFB74D",
    "#FFF176",
    "#81C784",
    "#4DB6AC",
    "#64B5F6",
    "#9575CD",
    "#F48FB1",
}

local DEFAULT_COLOR = COLOR_SWATCHES[1]
local selectedColor = DEFAULT_COLOR
local partOptionElements: {VisualElement} = {}

local isDragging = false
local hasPlacedParts = false
local placedParts: {{instanceID: number, partID: string, x: number, y: number, color: string, rotation: number, flip: number, scale: number}} = {}
local nextInstanceID = 1
local selectedPartInstanceID: number = nil
local selectedPartElement: VisualElement = nil

local ROTATION_INCREMENT = 15
local SCALE_INCREMENT = 0.1
local MIN_SCALE = 0.6
local MAX_SCALE = 4.0

local titleTween = nil
local openCardTween = nil

local function initializeTweens()
    titleTween = Tween:new(
        0,
        -2,
        1,
        true,
        true,
        Easing.easeInOutQuad,
        function(v, t)
            local _scale = Mathf.Lerp(0.95, 1.05, t)
            _title.style.scale = StyleScale.new(Vector2.new(_scale, _scale))
            _title.style.rotate = StyleRotate.new(Rotate.new(Angle.new(v)))
        end,
        nil
    )

    openCardTween = Tween:new(
        0,
        1,
        0.5,
        false,
        false,
        Easing.easeOutBack,
        function(v)
            _cardContainer.style.scale = StyleScale.new(Vector2.new(v, v))
            _cardContainer.style.opacity = StyleFloat.new(v)
        end,
        function()
            _cardContainer.style.scale = StyleScale.new(Vector2.new(1, 1))
            _cardContainer.style.opacity = StyleFloat.new(1)
        end
    )
end

local function hexToColor(hex: string): Color
    local _hex = hex:gsub("#", "")
    local _r = tonumber(_hex:sub(1, 2), 16) / 255
    local _g = tonumber(_hex:sub(3, 4), 16) / 255
    local _b = tonumber(_hex:sub(5, 6), 16) / 255
    return Color.new(_r, _g, _b, 1)
end

local function selectPart(partElement: VisualElement, instanceID: number)
    selectedPartElement = partElement
    selectedPartInstanceID = instanceID
end

local function deselectPart()
    selectedPartElement = nil
    selectedPartInstanceID = nil
end

local function applyTransformToPart(partElement: VisualElement, rotation: number, flip: number, scale: number)
    local _scale = scale or 1
    local _scaleX = flip * _scale
    local _scaleY = _scale
    partElement.style.scale = StyleScale.new(Vector2.new(_scaleX, _scaleY))
    partElement.style.rotate = StyleRotate.new(Rotate.new(Angle.new(rotation)))
end

local function rotatePart(direction: number)
    if not selectedPartElement or not selectedPartInstanceID then
        return
    end

    for i, part in ipairs(placedParts) do
        if part.instanceID == selectedPartInstanceID then
            part.rotation = (part.rotation or 0) + (direction * ROTATION_INCREMENT)
            applyTransformToPart(selectedPartElement, part.rotation, part.flip or 1, part.scale or 1)
            break
        end
    end
end

local function flipPart()
    if not selectedPartElement or not selectedPartInstanceID then
        return
    end

    for i, part in ipairs(placedParts) do
        if part.instanceID == selectedPartInstanceID then
            part.flip = (part.flip or 1) * -1
            applyTransformToPart(selectedPartElement, part.rotation or 0, part.flip, part.scale or 1)
            break
        end
    end
end

local function scalePart(direction: number)
    if not selectedPartElement or not selectedPartInstanceID then
        return
    end

    for i, part in ipairs(placedParts) do
        if part.instanceID == selectedPartInstanceID then
            local _newScale = (part.scale or 1) + (direction * SCALE_INCREMENT)
            _newScale = math.max(MIN_SCALE, math.min(MAX_SCALE, _newScale))
            part.scale = _newScale
            applyTransformToPart(selectedPartElement, part.rotation or 0, part.flip or 1, part.scale)
            break
        end
    end
end

local function applyColorToPart(hex: string)
    if not selectedPartElement or not selectedPartInstanceID then
        return
    end

    local _color = hexToColor(hex)
    selectedPartElement.style.unityBackgroundImageTintColor = StyleColor.new(_color)

    for i, part in ipairs(placedParts) do
        if part.instanceID == selectedPartInstanceID then
            part.color = hex
            break
        end
    end
end

local function updatePartOptionTints(hex: string)
    local _tint = hexToColor(hex)
    for _, partOption in ipairs(partOptionElements) do
        partOption.style.unityBackgroundImageTintColor = StyleColor.new(_tint)
    end
end

local function setupColorSwatches()
    for i, hex in ipairs(COLOR_SWATCHES) do
        local _swatch = VisualElement.new()
        _swatch.name = "_colorSwatch" .. i
        _swatch:AddToClassList("color-swatch")

        local _color = hexToColor(hex)
        _swatch.style.backgroundColor = StyleColor.new(_color)

        _swatch:RegisterPressCallback(function()
            applyColorToPart(hex)
            selectedColor = hex
            updatePartOptionTints(hex)
        end)

        _colorPicker:Add(_swatch)
    end
end

local function updateConfirmButtonState()
    if #placedParts > 0 then
        hasPlacedParts = true
        _confirmButton:EnableInClassList(LockedClass, false)
    else
        hasPlacedParts = false
        _confirmButton:EnableInClassList(LockedClass, true)
    end
end

local PART_SIZE = 50

local function getNormalizedPosition(left: number, top: number): (number, number)
    local _parentWidth = _placementArea.layout.width
    local _parentHeight = _placementArea.layout.height

    if _parentWidth <= 0 or _parentHeight <= 0 then
        return 0.5, 0.5
    end

    local _centerX = left + (PART_SIZE / 2)
    local _centerY = top + (PART_SIZE / 2)

    local _normalizedX = _centerX / _parentWidth
    local _normalizedY = 1.0 - (_centerY / _parentHeight)

    return _normalizedX, _normalizedY
end

local function createPlacedPart(instanceID: number, partID: string, sprite: Sprite, startX: number, startY: number): VisualElement
    local _partElement = VisualElement.new()
    _partElement.name = "_PlacedPart_" .. instanceID
    _partElement:AddToClassList(PlacedKitePartClass)

    _partElement.style.position = Position.Absolute
    _partElement.style.left = startX
    _partElement.style.top = startY
    if sprite then
        _partElement.style.backgroundImage = sprite.texture
    else
        _partElement.style.backgroundColor = StyleColor.new(Color.new(1, 0, 0, 1))
    end

    _partElement:RegisterGesture(DragGesture.new())

    _partElement:RegisterPressCallback(function()
        if not isDragging then
            selectPart(_partElement, instanceID)
        end
    end, nil, nil, false)

    _partElement:RegisterCallback(DragGestureBegan, function(evt)
        if evt.target == _partElement then
            isDragging = true
            deselectPart()
        end
    end)

    _partElement:RegisterCallback(DragGestureChanged, function(evt)
        if isDragging then
            local _currentLeft = _partElement.style.left.value.value or 0
            local _currentTop = _partElement.style.top.value.value or 0

            local _newX = _currentLeft + evt.deltaPosition.x
            local _newY = _currentTop + evt.deltaPosition.y

            local _parent = _partElement.parent
            local _parentWidth = _parent.layout.width
            local _parentHeight = _parent.layout.height
            local _elementWidth = _partElement.layout.width
            local _elementHeight = _partElement.layout.height

            _newX = math.max(0, math.min(_newX, _parentWidth - _elementWidth))
            _newY = math.max(0, math.min(_newY, _parentHeight - _elementHeight))

            _partElement.style.left = _newX
            _partElement.style.top = _newY
        end
    end)

    _partElement:RegisterCallback(DragGestureEnded, function(evt)
        if isDragging then
            isDragging = false

            local _currentLeft = _partElement.style.left.value.value or 0
            local _currentTop = _partElement.style.top.value.value or 0
            local _normX, _normY = getNormalizedPosition(_currentLeft, _currentTop)

            for i, part in ipairs(placedParts) do
                if part.instanceID == instanceID then
                    part.x = _normX
                    part.y = _normY
                    break
                end
            end

            selectPart(_partElement, instanceID)
        end
    end)

    return _partElement
end

local function createKitePartOption(kitePart: KitePart)
    local _partID = kitePart.GetPartId()
    local _sprite = kitePart.GetSprite()

    local _partOption = VisualElement.new()
    _partOption.name = "_PartOption_" .. _partID
    _partOption:AddToClassList(KitePartItemClass)

    if _sprite then
        _partOption.style.backgroundImage = _sprite.texture
    else
        _partOption.style.backgroundColor = StyleColor.new(Color.new(1, 0, 0, 1))
    end

    -- Apply selected color tint to part button
    local _tint = hexToColor(selectedColor)
    _partOption.style.unityBackgroundImageTintColor = StyleColor.new(_tint)

    -- Store reference for later tint updates
    table.insert(partOptionElements, _partOption)

    _partOption:RegisterPressCallback(function()
        local _parentWidth = _placementArea.layout.width
        local _parentHeight = _placementArea.layout.height

        local _startX = (_parentWidth / 2) - 25
        local _startY = (_parentHeight / 2) - 25

        local _instanceID = nextInstanceID
        nextInstanceID = nextInstanceID + 1

        local _placedPart = createPlacedPart(_instanceID, _partID, _sprite, _startX, _startY)
        _placementArea:Add(_placedPart)

        -- Apply selected color tint to spawned part
        local _spawnTint = hexToColor(selectedColor)
        _placedPart.style.unityBackgroundImageTintColor = StyleColor.new(_spawnTint)

        local _normX, _normY = getNormalizedPosition(_startX, _startY)
        table.insert(placedParts, {instanceID = _instanceID, partID = _partID, x = _normX, y = _normY, color = selectedColor, rotation = 0, flip = 1, scale = 1})

        selectPart(_placedPart, _instanceID)
        updateConfirmButtonState()
    end)

    return _partOption
end

local function populateKiteParts()
    local _kiteParts = KitePartsManager.GetKiteParts()

    for _, kitePart in ipairs(_kiteParts) do
        local _partOption = createKitePartOption(kitePart)
        _partsScrollView:Add(_partOption)
    end
end

local function duplicatePart()
    if not selectedPartInstanceID then
        return
    end

    local _sourcePart = nil
    for _, part in ipairs(placedParts) do
        if part.instanceID == selectedPartInstanceID then
            _sourcePart = part
            break
        end
    end

    if not _sourcePart then
        return
    end

    local _sprite = nil
    local _kiteParts = KitePartsManager.GetKiteParts()
    for _, kitePart in ipairs(_kiteParts) do
        if kitePart.GetPartId() == _sourcePart.partID then
            _sprite = kitePart.GetSprite()
            break
        end
    end

    local _parentWidth = _placementArea.layout.width
    local _parentHeight = _placementArea.layout.height
    local _startX = (_parentWidth / 2) - 25
    local _startY = (_parentHeight / 2) - 25

    local _instanceID = nextInstanceID
    nextInstanceID = nextInstanceID + 1

    local _placedPart = createPlacedPart(_instanceID, _sourcePart.partID, _sprite, _startX, _startY)
    _placementArea:Add(_placedPart)

    local _normX, _normY = getNormalizedPosition(_startX, _startY)
    table.insert(placedParts, {
        instanceID = _instanceID,
        partID = _sourcePart.partID,
        x = _normX,
        y = _normY,
        color = _sourcePart.color,
        rotation = _sourcePart.rotation,
        flip = _sourcePart.flip,
        scale = _sourcePart.scale
    })

    local _color = hexToColor(_sourcePart.color)
    _placedPart.style.unityBackgroundImageTintColor = StyleColor.new(_color)
    applyTransformToPart(_placedPart, _sourcePart.rotation, _sourcePart.flip, _sourcePart.scale)

    selectPart(_placedPart, _instanceID)
    updateConfirmButtonState()
end

local function deletePart()
    if not selectedPartElement or not selectedPartInstanceID then
        return
    end

    _placementArea:Remove(selectedPartElement)

    for i = #placedParts, 1, -1 do
        if placedParts[i].instanceID == selectedPartInstanceID then
            table.remove(placedParts, i)
            break
        end
    end

    deselectPart()
    updateConfirmButtonState()
end

local function clearPlacedParts()
    deselectPart()
    _placementArea:Clear()
end

local function getSpriteByPartId(partID: string): Sprite
    local _kiteParts = KitePartsManager.GetKiteParts()
    for _, kitePart in ipairs(_kiteParts) do
        if kitePart.GetPartId() == partID then
            return kitePart.GetSprite()
        end
    end
    return nil
end

local function loadExistingBuild()
    local _localPlayer = client.localPlayer
    if not _localPlayer then
        return
    end

    local _playerInfo = playerTracker.players[_localPlayer]
    if not _playerInfo or not _playerInfo.myBuild then
        return
    end

    local _buildData = _playerInfo.myBuild.value
    if not _buildData or #_buildData == 0 then
        return
    end

    local _parentWidth = _placementArea.layout.width
    local _parentHeight = _placementArea.layout.height

    for _, partData in ipairs(_buildData) do
        local _partID = partData.partID
        local _x = partData.x
        local _y = partData.y
        local _colorHex = partData.color or DEFAULT_COLOR
        local _rotation = partData.rotation or 0
        local _flip = partData.flip or 1
        local _scale = partData.scale or 1

        local _sprite = getSpriteByPartId(_partID)

        -- Convert normalized position back to pixel position
        local _pixelX = (_x * _parentWidth) - (PART_SIZE / 2)
        local _pixelY = ((1.0 - _y) * _parentHeight) - (PART_SIZE / 2)

        local _instanceID = nextInstanceID
        nextInstanceID = nextInstanceID + 1

        local _placedPart = createPlacedPart(_instanceID, _partID, _sprite, _pixelX, _pixelY)
        _placementArea:Add(_placedPart)

        -- Apply color tint
        local _tint = hexToColor(_colorHex)
        _placedPart.style.unityBackgroundImageTintColor = StyleColor.new(_tint)

        -- Apply transforms
        applyTransformToPart(_placedPart, _rotation, _flip, _scale)

        table.insert(placedParts, {
            instanceID = _instanceID,
            partID = _partID,
            x = _x,
            y = _y,
            color = _colorHex,
            rotation = _rotation,
            flip = _flip,
            scale = _scale
        })
    end

    updateConfirmButtonState()
end

function InitializeBuilder()
    placedParts = {}
    nextInstanceID = 1
    selectedColor = DEFAULT_COLOR
    clearPlacedParts()

    _cardContainer.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    _cardContainer.style.opacity = StyleFloat.new(0)

    _confirmButton:EnableInClassList(LockedClass, true)
    hasPlacedParts = false

    initializeTweens()
    titleTween:start()
    openCardTween:start()

    -- Load existing build after a short delay to ensure layout is ready
    Timer.After(0.1, function()
        loadExistingBuild()
    end)
end

function GetPlacedParts(): {{instanceID: number, partID: string, x: number, y: number, color: string, rotation: number, flip: number, scale: number}}
    return placedParts
end

function CloseBuilder()
    local _closeTween = Tween:new(
        1,
        0,
        0.3,
        false,
        false,
        Easing.easeInBack,
        function(v)
            _cardContainer.style.scale = StyleScale.new(Vector2.new(v, v))
        end,
        function()
            _cardContainer.style.scale = StyleScale.new(Vector2.new(0.1, 0.1))
            if titleTween then
                titleTween:stop()
            end
            clearPlacedParts()
            self.transform.gameObject:SetActive(false)
        end
    )
    _closeTween:start()
end

_confirmButton:RegisterPressCallback(function()
    if not hasPlacedParts then
        return
    end

    print("Kite built with " .. #placedParts .. " parts!")
    for i, part in ipairs(placedParts) do
        print("  Part " .. i .. ": " .. part.partID .. " at (" .. part.x .. ", " .. part.y .. ")")
    end

    playerTracker.setMyBuildRequest:FireServer(placedParts)
    CloseBuilder()
end)

local function setupTransformToolbar()
    _rotateCCW:RegisterPressCallback(function()
        rotatePart(-1)
    end)

    _rotateCW:RegisterPressCallback(function()
        rotatePart(1)
    end)

    _flipButton:RegisterPressCallback(function()
        flipPart()
    end)

    _scaleUp:RegisterPressCallback(function()
        scalePart(1)
    end)

    _scaleDown:RegisterPressCallback(function()
        scalePart(-1)
    end)

    _duplicateButton:RegisterPressCallback(function()
        duplicatePart()
    end)

    _deleteButton:RegisterPressCallback(function()
        deletePart()
    end)
end

function self:Start()
    populateKiteParts()
    setupColorSwatches()
    setupTransformToolbar()
    _confirmButton:EnableInClassList(LockedClass, true)
end
