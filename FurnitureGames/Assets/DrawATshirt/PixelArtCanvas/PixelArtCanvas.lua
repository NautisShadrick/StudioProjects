--!Type(UI)

local CANVAS_SIZE = 32
local COLOR_COUNT = 4

local ColorPickerEntryClass = "color-picker-entry"
local ColorPickerEntrySelectedClass = "color-picker-entry-selected"

--!Bind
local _container: VisualElement = nil
--!Bind
local _canvas: VisualElement = nil
--!Bind
local _colorPicker: VisualElement = nil
--!Bind
local _clearButton: VisualElement = nil
--!Bind
local _resetZoomButton: VisualElement = nil
--!Bind
local _saveButton: VisualElement = nil
--!Bind
local _closeButton: VisualElement = nil

local clothesCanvasModule = require("ClothesCanvasModule")

local COLOR_PALETTE: {Color} = {
    Color.new(0, 0, 0, 1),                       -- 0: Black
    Color.new(1, 1, 1, 1),                       -- 1: White
    Color.new(133/255, 97/255, 255/255, 1),     -- 2: Purple
    Color.new(255/255, 91/255, 149/255, 1),     -- 3: Pink/Red
    Color.new(0.75, 0.75, 0.75, 1),              -- 4: Light Gray
    Color.new(0.25, 0.25, 0.25, 1),              -- 5: Dark Gray
}

local INDEX_CHARS = "0123456789abcdefghijklmnopqrstuv"

local canvasTexture: Texture2D = nil
local pixelData: {number} = {}
local selectedColorIndex: number = 0
local isDrawing: boolean = false
local colorEntries: {VisualElement} = {}

local MIN_ZOOM = 1.0
local MAX_ZOOM = 8.0
local WHEEL_ZOOM_FACTOR = 0.1
local currentZoom: number = 1.0
local panOffsetX: number = 0
local panOffsetY: number = 0
local isPinching: boolean = false
local lastPinchScale: number = 1.0
local isMiddleMousePanning: boolean = false
local lastMousePos: Vector2 = Vector2.new(0, 0)

local function indexToChar(index: number): string
    return string.sub(INDEX_CHARS, index + 1, index + 1)
end

local function charToIndex(char: string): number
    local pos = string.find(INDEX_CHARS, char, 1, true)
    if pos then
        return pos - 1
    end
    return 0
end

local function initializePixelData()
    pixelData = {}
    for i = 1, CANVAS_SIZE * CANVAS_SIZE do
        pixelData[i] = 1
    end
end

local function getPixelIndex(x: number, y: number): number
    return y * CANVAS_SIZE + x + 1
end

local function updateTexture(raw)
    for y = 0, CANVAS_SIZE - 1 do
        for x = 0, CANVAS_SIZE - 1 do
            local idx = getPixelIndex(x, y)
            local colorIdx = pixelData[idx]
            local color = COLOR_PALETTE[colorIdx + 1]
            -- When raw, render white (index 1) as transparent
            if raw and colorIdx == 1 then
                color = Color.new(1, 1, 1, 0)
            end
            canvasTexture:SetPixel(x, y, color)
        end
    end
    if raw then
        print("Returning raw texture", typeof(canvasTexture))
        return canvasTexture
    end
    canvasTexture:Apply()
    _canvas.style.backgroundImage = canvasTexture
end

local function setPixel(x: number, y: number, colorIndex: number)
    if x < 0 or x >= CANVAS_SIZE or y < 0 or y >= CANVAS_SIZE then
        return
    end
    local idx = getPixelIndex(x, y)
    if pixelData[idx] ~= colorIndex then
        pixelData[idx] = colorIndex
        canvasTexture:SetPixel(x, y, COLOR_PALETTE[colorIndex + 1])
        canvasTexture:Apply()
    end
end

local CANVAS_UI_SIZE = 256

local function screenToPixel(localPos: Vector2): (number, number)
    -- localPosition in Unity UI Toolkit is already in element's local coordinate space
    -- The CSS transform (scale/translate) affects visual rendering but localPosition
    -- is reported relative to the untransformed element bounds
    -- Direct mapping from UI coords to texture coords
    local pixelX = math.floor((localPos.x / CANVAS_UI_SIZE) * CANVAS_SIZE)
    local pixelY = math.floor(((CANVAS_UI_SIZE - localPos.y) / CANVAS_UI_SIZE) * CANVAS_SIZE)
    return pixelX, pixelY
end

local function handleDrawAtLocal(localPos: Vector2)
    if isPinching then
        return
    end
    local pixelX, pixelY = screenToPixel(localPos)
    setPixel(pixelX, pixelY, selectedColorIndex)
end

local function applyCanvasTransform()
    _canvas.style.scale = StyleScale.new(Scale.new(Vector2.new(currentZoom, currentZoom)))
    _canvas.style.translate = StyleTranslate.new(Translate.new(Length.new(panOffsetX), Length.new(panOffsetY)))
end

local function resetZoomPan()
    currentZoom = 1.0
    panOffsetX = 0
    panOffsetY = 0
    applyCanvasTransform()
end

local function clampPan()
    local canvasSize = _canvas:GetResolvedStyleSize()
    local maxPan = (canvasSize.x * (currentZoom - 1)) / 2
    panOffsetX = math.max(-maxPan, math.min(maxPan, panOffsetX))
    panOffsetY = math.max(-maxPan, math.min(maxPan, panOffsetY))
end

local function updateColorSelection(newIndex: number)
    if colorEntries[selectedColorIndex + 1] then
        colorEntries[selectedColorIndex + 1]:RemoveFromClassList(ColorPickerEntrySelectedClass)
    end
    selectedColorIndex = newIndex
    if colorEntries[selectedColorIndex + 1] then
        colorEntries[selectedColorIndex + 1]:AddToClassList(ColorPickerEntrySelectedClass)
    end
end

local function createColorPicker()
    _colorPicker:Clear()
    colorEntries = {}

    for i = 0, COLOR_COUNT - 1 do
        local entry = VisualElement.new()
        entry:AddToClassList(ColorPickerEntryClass)
        entry.style.backgroundColor = StyleColor.new(COLOR_PALETTE[i + 1])

        if i == selectedColorIndex then
            entry:AddToClassList(ColorPickerEntrySelectedClass)
        end

        local colorIdx = i
        entry:RegisterPressCallback(function()
            updateColorSelection(colorIdx)
        end)

        _colorPicker:Add(entry)
        colorEntries[i + 1] = entry
    end
end

local function clearCanvas()
    initializePixelData()
    updateTexture(false)
end

function SerializePixelData(): string
    local chars = {}
    for i = 1, #pixelData do
        chars[i] = indexToChar(pixelData[i])
    end
    return table.concat(chars)
end

function DeserializePixelData(data: string, raw)
    raw = raw or false
    if not data or #data ~= CANVAS_SIZE * CANVAS_SIZE then
        return
    end

    for i = 1, #data do
        local char = string.sub(data, i, i)
        pixelData[i] = charToIndex(char)
    end
    return updateTexture(raw)
end

function SetOnSaveCallback(callback: (string) -> ())
    onSaveCallback = callback
end

function SetOnCloseCallback(callback: () -> ())
    onCloseCallback = callback
end

function Show()
    _container:SetDisplay(true)
end

function Hide()
    _container:SetDisplay(false)
end

function LoadFromData(data: string)
    DeserializePixelData(data)
end

function self:Start()
    canvasTexture = Texture2D.new(CANVAS_SIZE, CANVAS_SIZE)

    initializePixelData()
    updateTexture(false)
    createColorPicker()

    _canvas:RegisterCallback(PointerDownEvent, function(evt: PointerDownEvent)
        local localPos = Vector2.new(evt.localPosition.x, evt.localPosition.y)
        if evt.button == 2 then
            isMiddleMousePanning = true
            lastMousePos = Vector2.new(evt.position.x, evt.position.y)
        else
            isDrawing = true
            handleDrawAtLocal(localPos)
        end
    end)

    _canvas:RegisterCallback(PointerMoveEvent, function(evt: PointerMoveEvent)
        local currentPos = Vector2.new(evt.position.x, evt.position.y)
        if isMiddleMousePanning then
            local deltaX = currentPos.x - lastMousePos.x
            local deltaY = currentPos.y - lastMousePos.y
            panOffsetX = panOffsetX + deltaX
            panOffsetY = panOffsetY + deltaY
            clampPan()
            applyCanvasTransform()
            lastMousePos = currentPos
        elseif isDrawing and evt.pressedButtons > 0 then
            local localPos = Vector2.new(evt.localPosition.x, evt.localPosition.y)
            handleDrawAtLocal(localPos)
        end
    end)

    _canvas:RegisterCallback(PointerUpEvent, function(evt: PointerUpEvent)
        if evt.button == 2 then
            isMiddleMousePanning = false
        else
            isDrawing = false
        end
    end)

    _container:RegisterCallback(WheelEvent, function(evt: WheelEvent)
        local zoomDelta = -evt.delta.y * WHEEL_ZOOM_FACTOR
        local newZoom = currentZoom + zoomDelta
        currentZoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, newZoom))
        clampPan()
        applyCanvasTransform()
    end)

    _clearButton:RegisterPressCallback(function()
        clearCanvas()
        resetZoomPan()
    end)

    Input.PinchOrDragBegan:Connect(function(evt: PinchGestureBegan)
        if evt.isPinching then
            isPinching = true
            isDrawing = false
            lastPinchScale = evt.scale
        end
    end)

    Input.PinchOrDragChanged:Connect(function(evt: PinchGestureChanged)
        if evt.isPinching and isPinching then
            local scaleDelta = evt.scale / lastPinchScale
            local newZoom = currentZoom * scaleDelta
            currentZoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, newZoom))
            lastPinchScale = evt.scale

            panOffsetX = panOffsetX + evt.deltaPosition.x
            panOffsetY = panOffsetY + evt.deltaPosition.y
            clampPan()

            applyCanvasTransform()
        end
    end)

    Input.PinchOrDragEnded:Connect(function(evt: PinchGestureEnded)
        isPinching = false
    end)

    _resetZoomButton:RegisterPressCallback(function()
        resetZoomPan()
    end)

    _saveButton:RegisterPressCallback(function()
        local serialized = SerializePixelData()
        print("Saved pixel art data: " .. serialized)
        clothesCanvasModule.createShirtRequest:FireServer(serialized)
    end)

    _closeButton:RegisterPressCallback(function()
        Hide()
    end)
end
