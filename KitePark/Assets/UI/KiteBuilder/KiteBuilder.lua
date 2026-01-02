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
local _partsScrollView: VisualElement = nil
--!Bind
local _trashCan: VisualElement = nil
--!Bind
local _colorPicker: VisualElement = nil
--!Bind
local _colorSwatch1: VisualElement = nil
--!Bind
local _colorSwatch2: VisualElement = nil
--!Bind
local _colorSwatch3: VisualElement = nil
--!Bind
local _colorSwatch4: VisualElement = nil
--!Bind
local _colorSwatch5: VisualElement = nil
--!Bind
local _colorSwatch6: VisualElement = nil
--!Bind
local _colorSwatch7: VisualElement = nil
--!Bind
local _colorSwatch8: VisualElement = nil

local KitePartItemClass = "kite-part-item"
local TrashCanActiveClass = "trash-can-active"
local PlacedKitePartClass = "placed-kite-part"
local LockedClass = "locked"
local ColorPickerVisibleClass = "color-picker-visible"

local COLOR_SWATCHES = {
    "#FFFFFF",
    "#FF6B6B",
    "#4ECDC4",
    "#FFE66D",
    "#95E1D3",
    "#F38181",
    "#AA96DA",
    "#6C5CE7",
}

local isDragging = false
local hasPlacedParts = false
local placedParts: {{instanceID: number, partID: string, x: number, y: number, color: string}} = {}
local nextInstanceID = 1
local selectedPartInstanceID: number = nil
local selectedPartElement: VisualElement = nil

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

local function showColorPicker(partElement: VisualElement, instanceID: number)
    selectedPartElement = partElement
    selectedPartInstanceID = instanceID

    local _left = partElement.style.left.value.value or 0
    local _top = partElement.style.top.value.value or 0

    local _pickerX = _left + 60
    local _pickerY = _top - 20

    local _parentWidth = _placementArea.layout.width
    local _parentHeight = _placementArea.layout.height

    if _pickerX + 140 > _parentWidth then
        _pickerX = _left - 150
    end
    if _pickerY < 0 then
        _pickerY = _top + 60
    end
    if _pickerY + 70 > _parentHeight then
        _pickerY = _parentHeight - 75
    end

    _colorPicker.style.left = _pickerX
    _colorPicker.style.top = _pickerY
    _colorPicker:EnableInClassList(ColorPickerVisibleClass, true)
end

local function hideColorPicker()
    _colorPicker:EnableInClassList(ColorPickerVisibleClass, false)
    selectedPartElement = nil
    selectedPartInstanceID = nil
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

    hideColorPicker()
end

local function setupColorSwatches()
    local _swatches = {_colorSwatch1, _colorSwatch2, _colorSwatch3, _colorSwatch4, _colorSwatch5, _colorSwatch6, _colorSwatch7, _colorSwatch8}

    for i, swatch in ipairs(_swatches) do
        local _hex = COLOR_SWATCHES[i]
        local _color = hexToColor(_hex)
        swatch.style.backgroundColor = StyleColor.new(_color)

        swatch:RegisterPressCallback(function()
            applyColorToPart(_hex)
        end)
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

local function isOverlappingTrashCan(element: VisualElement): boolean
    local _elementRect = element.worldBound
    local _trashRect = _trashCan.worldBound

    local _overlapX = _elementRect.x < _trashRect.x + _trashRect.width and
                      _elementRect.x + _elementRect.width > _trashRect.x
    local _overlapY = _elementRect.y < _trashRect.y + _trashRect.height and
                      _elementRect.y + _elementRect.height > _trashRect.y

    return _overlapX and _overlapY
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

    local _pulseTween = Tween:new(
        1,
        1.1,
        0.5,
        true,
        true,
        Easing.easeInOutQuad,
        function(scale)
            _partElement.style.scale = StyleScale.new(Vector2.new(scale, scale))
        end,
        nil
    )
    _pulseTween:start()

    _partElement:RegisterGesture(DragGesture.new())

    _partElement:RegisterPressCallback(function()
        if not isDragging then
            showColorPicker(_partElement, instanceID)
        end
    end)

    _partElement:RegisterCallback(DragGestureBegan, function(evt)
        if evt.target == _partElement then
            isDragging = true
            hideColorPicker()
            _partElement.style.opacity = StyleFloat.new(0.8)
            _partElement.style.scale = StyleScale.new(Vector2.new(1.2, 1.2))
            _pulseTween:stop()
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

            if isOverlappingTrashCan(_partElement) then
                _trashCan:EnableInClassList(TrashCanActiveClass, true)
            else
                _trashCan:EnableInClassList(TrashCanActiveClass, false)
            end
        end
    end)

    _partElement:RegisterCallback(DragGestureEnded, function(evt)
        if isDragging then
            isDragging = false
            _partElement.style.opacity = StyleFloat.new(1.0)
            _partElement.style.scale = StyleScale.new(Vector2.new(1, 1))
            _trashCan:EnableInClassList(TrashCanActiveClass, false)

            if isOverlappingTrashCan(_partElement) then
                _placementArea:Remove(_partElement)
                for i = #placedParts, 1, -1 do
                    if placedParts[i].instanceID == instanceID then
                        table.remove(placedParts, i)
                        break
                    end
                end
                updateConfirmButtonState()
                _pulseTween:stop()
            else
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
            end
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

    _partOption:RegisterPressCallback(function()
        local _parentWidth = _placementArea.layout.width
        local _parentHeight = _placementArea.layout.height

        local _startX = (_parentWidth / 2) - 25
        local _startY = (_parentHeight / 2) - 25

        local _instanceID = nextInstanceID
        nextInstanceID = nextInstanceID + 1

        local _placedPart = createPlacedPart(_instanceID, _partID, _sprite, _startX, _startY)
        _placementArea:Add(_placedPart)

        local _normX, _normY = getNormalizedPosition(_startX, _startY)
        table.insert(placedParts, {instanceID = _instanceID, partID = _partID, x = _normX, y = _normY, color = "#FFFFFF"})

        updateConfirmButtonState()

        local _popTween = Tween:new(
            0.5,
            1,
            0.2,
            false,
            false,
            Easing.easeOutBack,
            function(v)
                _placedPart.style.scale = StyleScale.new(Vector2.new(v, v))
            end,
            nil
        )
        _popTween:start()
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

local function clearPlacedParts()
    hideColorPicker()
    local _childCount = _placementArea.childCount
    for i = _childCount - 1, 0, -1 do
        local _child = _placementArea:ElementAt(i)
        if _child ~= _trashCan and _child ~= _colorPicker then
            _placementArea:RemoveAt(i)
        end
    end
end

function InitializeBuilder()
    placedParts = {}
    nextInstanceID = 1
    clearPlacedParts()

    _cardContainer.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    _cardContainer.style.opacity = StyleFloat.new(0)

    _confirmButton:EnableInClassList(LockedClass, true)
    hasPlacedParts = false

    initializeTweens()
    titleTween:start()
    openCardTween:start()
end

function GetPlacedParts(): {{instanceID: number, partID: string, x: number, y: number, color: string}}
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

function self:Start()
    populateKiteParts()
    setupColorSwatches()
    _confirmButton:EnableInClassList(LockedClass, true)
    _colorPicker:EnableInClassList(ColorPickerVisibleClass, false)
end
