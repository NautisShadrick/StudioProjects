--!Type(UI)

local christmasTreeManager = require("ChristmasTreeController")
local Tweenlocal TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--!Bind
local Tree_Card_Container : VisualElement = nil
--!Bind
local placementElement : VisualElement = nil
--!Bind
local confirm_button : Label = nil
--!Bind
local place_title : Label = nil

-- Local variables for UI dragging
local isDragging = false

local currentPOS = Vector2.new(0,0)
local placed = false

buff_ID = ""

local titleTween = Tween:new(
    0,
    -2,
    1,
    true,
    true,
    Easing.easeInOutQuad,
    function(v, t)
        -- Scale from 0.9 to 1.1 and back
        local scale = Mathf.Lerp(0.9, 1.1, t)
        place_title.style.scale = StyleScale.new(Vector2.new(scale, scale))
        place_title.style.rotate = StyleRotate.new(Rotate.new(Angle.new(v)))
    end,
    nil
)

local OpenCardTween = Tween:new(
    0,
    1,
    0.5,
    false,
    false,
    Easing.easeOutBack,
    function(v)
        Tree_Card_Container.style.scale = StyleScale.new(Vector2.new(v, v))
        Tree_Card_Container.style.opacity = StyleFloat.new(v)
    end,
    function()
        Tree_Card_Container.style.scale = StyleScale.new(Vector2.new(1, 1))
        Tree_Card_Container.style.opacity = StyleFloat.new(1)
    end
)

-- Function to update the 3D object position based on UI element position
local function UpdateObjectPose(_ornamentItem)
    -- Get current position and dimensions for calculating center
    local currentLeft = _ornamentItem.style.left.value.value or 0
    local currentTop = _ornamentItem.style.top.value.value or 0
    
    local parent = _ornamentItem.parent
    local parentWidth = parent.layout.width
    local parentHeight = parent.layout.height
    local elementWidth = _ornamentItem.layout.width
    local elementHeight = _ornamentItem.layout.height
    
    -- Calculate center position of the element
    local centerX = currentLeft + (elementWidth / 2)
    local centerY = currentTop + (elementHeight / 2)
    
    -- Normalize to 0-1 range with (0,0) at bottom-left and (1,1) at top-right
    -- Note: UI coordinates have (0,0) at top-left, so we need to flip Y
    local normalizedX = centerX / parentWidth
    local normalizedY = 1.0 - (centerY / parentHeight)
    
    -- Print the normalized center position
    currentPOS = Vector2.new(normalizedX, normalizedY)
end

function CreateItem(buffType)

    placed = false
    confirm_button:EnableInClassList("locked", true)

    local _ornamentItem = VisualElement.new()
    _ornamentItem.name = "_OrnamentItem"
    _ornamentItem:AddToClassList("ornament_sticker")
    _ornamentItem.style.backgroundImage = christmasTreeManager.buffIconmap[buffType]
    

    local stickerPulseTween = Tween:new(
        1.8,
        2,
        0.5,
        true,
        true,
        Easing.easeInOutQuad,
        function(scale)
            _ornamentItem.style.scale = StyleScale.new(Vector2.new(scale, scale))
        end,
        nil
    )
    stickerPulseTween:start()

    placementElement:Add(_ornamentItem)
    
    -- Position the item in the center of the placement element
    local parent = placementElement
    local parentWidth = parent.layout.width
    local parentHeight = parent.layout.height
    
    -- Assume element size (should match your CSS)
    local assumedElementWidth = 32
    local assumedElementHeight = 32
    
    -- Calculate center position
    local centerX = (parentWidth / 2) - (assumedElementWidth / 2)
    local centerY = (parentHeight / 2) - (assumedElementHeight / 2)
    
    -- Set initial position at center
    _ornamentItem.style.position = Position.Absolute
    _ornamentItem.style.left = centerX
    _ornamentItem.style.top = centerY
    
    -- Handle the drag start from the button
    _ornamentItem:RegisterGesture(DragGesture.new())
    _ornamentItem:RegisterCallback(DragGestureBegan, function(evt)
        -- Ensure drag starts from the button
        if evt.target == _ornamentItem then
            -- Set isDragging flag to true
            isDragging = true
            
            -- Make sure the element is positioned absolutely for dragging
            _ornamentItem.style.position = Position.Absolute
            
            -- Optional: Add visual feedback for drag start (e.g., change opacity)
            _ornamentItem.style.opacity = StyleFloat.new(0.8)
            _ornamentItem.style.scale = StyleScale.new(Vector2.new(1.2, 1.2))
            stickerPulseTween:stop()
        end
    end)

    -- Handle the object movement as the drag continues
    _ornamentItem:RegisterCallback(DragGestureChanged, function(evt)
        if isDragging then
            -- Use deltaPosition to get the change in position since last frame
            local currentLeft = _ornamentItem.style.left.value.value or 0
            local currentTop = _ornamentItem.style.top.value.value or 0
            
            -- Calculate new position based on delta movement
            local newX = currentLeft + evt.deltaPosition.x
            local newY = currentTop + evt.deltaPosition.y
            
            -- Get parent container and element dimensions for boundary checking
            local parent = _ornamentItem.parent
            local parentWidth = parent.layout.width
            local parentHeight = parent.layout.height
            local elementWidth = _ornamentItem.layout.width
            local elementHeight = _ornamentItem.layout.height
            
            -- Constrain the position within parent bounds
            newX = math.max(0, math.min(newX, parentWidth - elementWidth))
            newY = math.max(0, math.min(newY, parentHeight - elementHeight))
            
            -- Update the UI element's position
            _ornamentItem.style.left = newX
            _ornamentItem.style.top = newY
            _ornamentItem.style.position = Position.Absolute
        end
    end)

    -- Handle the end of the drag
    _ornamentItem:RegisterCallback(DragGestureEnded, function(evt)
        if isDragging then
            -- Update the 3D object position
            UpdateObjectPose(_ornamentItem)
            
            -- Reset dragging state
            isDragging = false
            
            -- Optional: Reset visual feedback
            _ornamentItem.style.opacity = StyleFloat.new(1.0)
            _ornamentItem.style.scale = StyleScale.new(Vector2.new(1, 1))

            placed = true
            confirm_button:EnableInClassList("locked", false)
            
            -- You can add logic here to snap to specific positions or validate the drop location
            -- For now, the element stays where it was dropped
        end
    end)
end

function CreateNonDraggableItem(x, y, buffType)
    print("Creating non-draggable ornament at normalized position: x=" .. x .. ", y=" .. y)
    local _ornamentItem = VisualElement.new()
    _ornamentItem.name = "_OrnamentItemStatic"
    _ornamentItem:AddToClassList("ornament_sticker")
    _ornamentItem.pickingMode = PickingMode.Ignore  -- Ignore input events
    _ornamentItem.style.backgroundImage = christmasTreeManager.buffIconmap[buffType]
    
    -- Position the element based on normalized coordinates
    local parent = placementElement
    local parentWidth = parent.layout.width
    local parentHeight = parent.layout.height
    
    -- Convert normalized coordinates back to UI coordinates
    -- Note: Y coordinate needs to be flipped since UI has (0,0) at top-left
    -- The saved coordinates represent the CENTER position, so we need to offset by half the element size
    local centerX = x * parentWidth
    local centerY = (1.0 - y) * parentHeight
    
    -- We'll use a default element size assumption since layout might not be ready immediately
    -- This should match the actual sticker size from CSS
    local assumedElementWidth =  32  -- Adjust this to match your actual sticker size
    local assumedElementHeight = 32 -- Adjust this to match your actual sticker size
    
    -- Calculate top-left position from center position
    local uiX = centerX - (assumedElementWidth / 2)
    local uiY = centerY - (assumedElementHeight / 2)
    
    -- Set absolute positioning
    _ornamentItem.style.position = Position.Absolute
    _ornamentItem.style.left = uiX
    _ornamentItem.style.top = uiY
    
    -- Add to parent
    placementElement:Add(_ornamentItem)
    
    -- Make it non-draggable by not registering drag gestures
    -- You could add different styling to distinguish from draggable items
    _ornamentItem.style.opacity = StyleFloat.new(0.5)  -- Slightly transparent to show it's static
    local popInTween = Tween:new(
        0.1,
        1,
        0.2,
        false,
        false,
        Easing.easeOutBack,
        function(v)
            _ornamentItem.style.scale = StyleScale.new(Vector2.new(v, v))
        end,
        function()
            -- Completion callback (optional)
        end
    )
    popInTween:start()
end

function CreateStatics(ornamentsList)
    -- Clear existing static items only (not all items)
    local childCount = placementElement.childCount
    for i = childCount - 1, 0, -1 do
        local child = placementElement:ElementAt(i)
        if child.name == "_OrnamentItemStatic" then
            placementElement:RemoveAt(i)
        end
    end
    
    for i, ornament in ipairs(ornamentsList) do
        Timer.After(0.025*i, function()
            CreateNonDraggableItem(ornament.x, ornament.y, ornament.ornamentType)
        end)
    end
end

function InitializeBook(id)
    Tree_Card_Container.style.scale = StyleScale.new(Vector2.new(.01, .01))
    Tree_Card_Container.style.opacity = StyleFloat.new(0)
    titleTween:start()
    OpenCardTween:start()
    buff_ID = id
end

confirm_button:RegisterPressCallback(function()
    if not placed then
        return
    end

    local CloseCardTween = Tween:new(
        1,
        0,
        0.3,
        false,
        false,
        Easing.easeInBack,
        function(v)
            Tree_Card_Container.style.scale = StyleScale.new(Vector2.new(v, v))
        end,
        function()
            Tree_Card_Container.style.scale = StyleScale.new(Vector2.new(0.1, 0.1))
            titleTween:stop()
            christmasTreeManager.placeOrnamentRequest:FireServer(currentPOS.x, currentPOS.y, client.localPlayer.user.id, buff_ID)
            placementElement:Clear()
            self.transform.gameObject:SetActive(false)
        end
    )
    CloseCardTween:start()
end)