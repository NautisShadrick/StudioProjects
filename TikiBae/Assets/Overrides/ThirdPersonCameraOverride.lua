--!Type(Client)

--!SerializeField
local cameraPivotHeight : number = 2.5 -- The height of the point over the player the camera will pivot around
--!SerializeField
local initalDistanceFromPivot : number = 7.5

--!SerializeField
local minDistanceFromPivot : number = 3
--!SerializeField
local maxDistanceFromPivot : number = 25

--!SerializeField
local cameraOffset : Vector3 = Vector3.new(0.75, 0.5, 0) -- an offset that is applied to the camera after its position from the pivot point is calculated

-- Rotation limits

--!SerializeField
local EnableMaxPitch : boolean = true -- Enable the maximum pitch
--!SerializeField
local EnableMaxYaw : boolean = false -- Enable the maximum yaw

--!SerializeField
local initialPitch : number = 10
--!SerializeField
local minPitch : number = -5 -- The minimum pitch of the camera (looking down)
--!SerializeField
local maxPitch : number = 30 -- The maximum pitch of the camera (looking up)
--!SerializeField
local minYaw : number = -360 -- For full 360 rotation, set to -360 (left/right movement)
--!SerializeField
local maxYaw : number = 360 -- For full 360 rotation, set to 360 (left/right movement)

--!SerializeField
local touchRotationSensitivity : number = 0.4 -- The sensitivity of the rotation
--!SerializeField
local mouseRotationSensitivity : number = 0.4 -- The sensitivity of the rotation using a mouse

--!SerializeField
local rotationSmoothing : number = 1 -- The smoothing of the rotation

--!SerializeField
local touchZoomSensitivity : number = 5 -- sensitivity for touch based zoom

--!SerializeField
local FOV : number = 60 -- The field of view of the camera

local camera = self.gameObject:GetComponent(Camera)
if camera == nil then
    error("ThirdPersonCamera.lua requires a Camera component on the same GameObject")
end

local zoom = initalDistanceFromPivot

local rotationSensitivity = 0
local yaw : number = 0 -- The yaw of the camera
local pitch : number = 0 -- The pitch of the camera

local currentRotationVelocity : Vector2 = Vector2.zero

local lastDirection : Vector2 = Vector2.zero -- The last direction of the camera (for rotation)
local isPinching : boolean = false
local previousPinchDistance = 1 -- the previous distance value between two touches during a pinch gesture

function self:Start()
    ResetCamera()
end

function self:ResetCamera()
    -- Adjust sensitivity for mobile devices
    if Input.isMouseInput then
        rotationSensitivity = mouseRotationSensitivity
    else 
        rotationSensitivity = touchRotationSensitivity
    end

    zoom = initalDistanceFromPivot
    yaw = 0
    pitch = initialPitch

    currentRotationVelocity = Vector2.zero
    isPinching = false
    previousPinchDistance = 1
    lastDirection = Vector2.zero

    camera.fieldOfView = FOV

    if client.localPlayer.character then
        local characterTransform = client.localPlayer.character.gameObject.transform
        yaw = characterTransform.eulerAngles.y
        UpdatePosition()
    end
end

Input.MouseWheel:Connect(function(evt)
    if not self:IsActive() then
        return
    end

    if evt.delta.y < 0.0 then
        zoom = Mathf.Clamp(zoom - 1, minDistanceFromPivot, maxDistanceFromPivot)
    else
        zoom = Mathf.Clamp(zoom + 1, minDistanceFromPivot, maxDistanceFromPivot)
    end
end)

Input.PinchOrDragBegan:Connect(function(event)
    if not self:IsActive() then
        return
    end

    isPinching = event.isPinching
    previousPinchDistance = event.distance
    lastDirection = Vector2.zero
end)

-- When the pinch or drag changes
Input.PinchOrDragChanged:Connect(function(event)
    if not self:IsActive() then
        return
    end

    if isPinching then
        local zoomDelta = (1 - event.distance / previousPinchDistance) * touchZoomSensitivity
        zoom = Mathf.Clamp(zoom + zoomDelta, minDistanceFromPivot, maxDistanceFromPivot)

        previousPinchDistance = event.distance
    else
        local delta = event.deltaPosition
        local deltaX = delta.x
        local deltaY = delta.y

        local deltaAngleX = -deltaY * rotationSensitivity  -- Invert for natural movement
        local deltaAngleY = deltaX * rotationSensitivity

        Rotate(Vector2.new(deltaAngleY, 0))
        Rotate(Vector2.new(0, deltaAngleX))
    end
end)

Input.PinchOrDragEnded:Connect(function(event)
    if not self:IsActive() then
        return
    end

    isPinching = false
    previousPinchDistance = 1
    lastDirection = Vector2.zero
end)

function Rotate(rotate)
    -- Apply sensitivity
    rotate = rotate * rotationSensitivity

    -- Smooth the rotation
    currentRotationVelocity = Vector2.Lerp(currentRotationVelocity, rotate, rotationSmoothing)
    
    -- Adjust the pitch rotation (up/down movement)
    if EnableMaxPitch then
        pitch = math.clamp(pitch + currentRotationVelocity.y, minPitch, maxPitch)
    else
        pitch = pitch + currentRotationVelocity.y
    end
    
    -- Adjust the yaw rotation (left/right movement)
    if EnableMaxYaw then
        yaw = math.clamp(yaw + currentRotationVelocity.x, minYaw, maxYaw)
    else
        yaw = yaw + currentRotationVelocity.x
    end
end

function self:IsActive()
    return camera ~= nil and camera.isActiveAndEnabled and self.isActiveAndEnabled
end

function UpdatePosition()
    local playerPosition = client.localPlayer.character.gameObject.transform.position
    local cameraPivotPosition = playerPosition + cameraPivotHeight * Vector3.up

    local rotation = Quaternion.Euler(pitch, yaw, 0)

    camera.transform.position = cameraPivotPosition + zoom * (rotation * Vector3.back) + (rotation * cameraOffset)
    camera.transform.rotation = rotation
    --cameraOffset
    
end

function self:LateUpdate()
    if not self:IsActive() then
        return
    end

    UpdatePosition()
end

function UpdateOffsets(offset)
    cameraOffset = offset
end