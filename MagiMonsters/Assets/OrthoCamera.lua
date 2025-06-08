--!Type(Client)

--!SerializeField
local _Camera : Camera = nil

--!SerializeField
local _MinX : number = -50
--!SerializeField
local _MaxX : number = 50
--!SerializeField
local _MinZ : number = -50
--!SerializeField
local _MaxZ : number = 50

--!SerializeField
local _MoveSpeed : number = 1
--!SerializeField
local _ZoomSpeed : number = 1
--!SerializeField
local _Zoom : number = 10
--!SerializeField
local _ZoomMin : number = 5
--!SerializeField
local _ZoomMax : number = 20

-- Enhanced camera smoothing parameters
local smoothTime : number = Input.isMouseInput and 0.05 or 0.15  -- Faster for mouse, smoother for touch
local currentVelocity : Vector3 = Vector3.zero  -- For SmoothDamp
local zoomVelocity : number = 0  -- For zoom smoothing
local targetZoom : number = _Zoom  -- Target zoom level
local zoomSmoothTime : number = Input.isMouseInput and 0.03 or 0.1  -- Faster zoom for mouse

local defaultZoom : number = _Zoom

local resetTime : number = 0
local resetLerpDuration : number = 1.2

local inertiaVelocity : Vector3 = Vector3.zero
local inertiaMagnitude : number = 0
local inertiaMultiplier : number = Input.isMouseInput and 1.5 or 2.5  -- Less inertia for mouse
local closeMaxInitialInertia : number = Input.isMouseInput and 35 or 45  -- Adjusted for platform
local farMaxInitialIntertia : number = Input.isMouseInput and 150 or 180  -- Adjusted for platform
local inertiaDampeningFactor : number = Input.isMouseInput and 0.93 or 0.95  -- Faster stop for mouse

local wasPanning : boolean = false
local panTargetStart : Vector3 = Vector3.zero

local initialZoomOfPinch : number = _Zoom
local wasPinching : boolean = false
local lastPinchScreenPosition : Vector3 = Vector3.zero

local target : Vector3 = Vector3.zero
local smoothedTarget : Vector3 = Vector3.zero  -- For smooth camera following
local worldUpPlane = Plane.new(Vector3.up, Vector3.zero)

local CameraMoveStateEnum = {
  None = 0,
  ManualControl = 1,
  Resetting = 2,
}

local cameraMoveState = CameraMoveStateEnum.None

local InertiaMinVelocity : number = 0.5  -- Prevents infinite slow drag at the end
local InertiaStepDuration : number = 1 / 60  -- Each inertia step normalized to 60fps

local lastPanVelocity : Vector3 = Vector3.zero
local lastPanTime : number = 0

function self:Start()
    if not _Camera then
        _Camera = self.gameObject:GetComponent(Camera)
    end

    _Camera.orthographic = true
    _Camera.orthographicSize = _Zoom

    local initialRotation = Quaternion.Euler(24.049, 45, 0)
    _Camera.transform.rotation = initialRotation

    target = Vector3.zero
    _Camera.transform.position = target + CalculateRelativePosition()
end

function ScreenPositionToWorldPoint(camera: Camera, screenPosition: Vector3): Vector3
  local ray = camera:ScreenPointToRay(screenPosition)
  local success, distance = worldUpPlane:Raycast(ray)

  if not success then
    print("Camera raycast failed. Is the camera not angled down?")
    return Vector3.zero
  end

  return ray:GetPoint(distance)
end

function ClampTargetToBounds(pos)
  pos.x = math.clamp(pos.x, _MinX, _MaxX)
  pos.z = math.clamp(pos.z, _MinZ, _MaxZ)
  return pos
end

function PanWorldPositionToScreenPosition(worldPosition: Vector3, screenPosition: Vector3)
  -- Calculate drag delta in screen space
  local targetPlane = Plane.new(Vector3.up, worldPosition)
  local ray = _Camera:ScreenPointToRay(screenPosition)
  local success, distance = targetPlane:Raycast(ray)
  
  if success then
    local dragWorldDelta = -(ray:GetPoint(distance) - worldPosition)
    -- Project drag delta onto camera's local axes
    local camRight = _Camera.transform.right
    local camUp = _Camera.transform.up
    -- Only use X (right) and Y (up) components in camera space
    local deltaRight = camRight * Vector3.Dot(dragWorldDelta, camRight)
    local deltaUp = camUp * Vector3.Dot(dragWorldDelta, camUp)
    local dragAdjustment = deltaRight + deltaUp
    target = ClampTargetToBounds(target + dragAdjustment)
  end
end

function PanCamera(evt)
  if not wasPanning then
    panTargetStart = ScreenPositionToWorldPoint(_Camera, evt.position)
  end

  PanWorldPositionToScreenPosition(panTargetStart, evt.position)

  -- Track velocity for all pan gestures
  local currentTime = Time.time
  if currentTime > lastPanTime then
    local worldPos = ScreenPositionToWorldPoint(_Camera, evt.position)
    lastPanVelocity = (worldPos - panTargetStart) / (currentTime - lastPanTime)
  end
  lastPanTime = currentTime
end

function ZoomIn()
  _Zoom = Mathf.Clamp(_Zoom - 1, _ZoomMin, _ZoomMax)
  targetZoom = _Zoom  -- Keep targetZoom in sync for touch handling
end

function ZoomOut()
  _Zoom = Mathf.Clamp(_Zoom + 1, _ZoomMin, _ZoomMax)
  targetZoom = _Zoom  -- Keep targetZoom in sync for touch handling
end

function ResetZoomScale()
  initialZoomOfPinch = _Zoom
end

function CalculateRelativePosition()
  local rotation = Quaternion.Euler(24.049, 45, 0)
  local distanceFromTarget = 30
  return rotation * Vector3.back * distanceFromTarget
end


function PostZoomMoveTowardsScreenPoint(screenPosition)
  local rayBefore = _Camera:ScreenPointToRay(screenPosition)
  local successBefore, distBefore = worldUpPlane:Raycast(rayBefore)
  if not successBefore then return end
  local worldBefore = rayBefore:GetPoint(distBefore)

  -- Apply zoom change (already done before this function is called)
  UpdatePosition()

  local rayAfter = _Camera:ScreenPointToRay(screenPosition)
  local successAfter, distAfter = worldUpPlane:Raycast(rayAfter)
  if not successAfter then return end
  local worldAfter = rayAfter:GetPoint(distAfter)

  local worldDelta = worldBefore - worldAfter
  target = ClampTargetToBounds(target + worldDelta)
end


function PinchRotateAndZoomCamera(evt)
  if not wasPinching then
    lastPinchScreenPosition = evt.position
    ResetZoomScale()
  end

  if evt.scale > 0 then
    -- Calculate new zoom directly from pinch scale
    local newZoom = initialZoomOfPinch + (initialZoomOfPinch / evt.scale - initialZoomOfPinch)
    targetZoom = Mathf.Clamp(newZoom, _ZoomMin, _ZoomMax)
    _Zoom = targetZoom  -- Direct zoom update for touch

    -- Store the world position before zoom
    local pinchStartWorldPosition = ScreenPositionToWorldPoint(_Camera, lastPinchScreenPosition)
    
    -- Update camera position for new zoom
    _Camera.orthographicSize = _Zoom
    
    -- Adjust position to maintain pinch point
    PanWorldPositionToScreenPosition(pinchStartWorldPosition, evt.position)
    lastPinchScreenPosition = evt.position
  end
end

function ResetPinchDrag()
  lastPinchScreenPosition = Vector3.zero
  wasPanning = false
  wasPinching = false
end

function ResetInertia()
  inertiaVelocity = Vector3.zero
  inertiaMagnitude = 0
end

function IsCameraActive()
  return self.isActiveAndEnabled
end

function ApplyInertia(worldVelocity: Vector3)
  -- No inertia, movement stops immediately
  inertiaVelocity = Vector3.zero
  inertiaMagnitude = 0
  currentVelocity = Vector3.zero
end

local MaxSwipeVelocity = 400
function CalculateWorldVelocity(evt)
  -- Use event velocity for consistency
  local velocity = evt.velocity
  velocity.x = Mathf.Clamp(velocity.x, -MaxSwipeVelocity, MaxSwipeVelocity)
  velocity.y = Mathf.Clamp(velocity.y, -MaxSwipeVelocity, MaxSwipeVelocity)

  local screenStart = evt.position
  local screenEnd = evt.position + velocity

  local worldStart = ScreenPositionToWorldPoint(_Camera, screenStart)
  local worldEnd = ScreenPositionToWorldPoint(_Camera, screenEnd)

  -- Calculate world space velocity
  local result = -(worldEnd - worldStart)
  
  -- Scale velocity based on input type for consistent feel
  local velocityScale = Input.isMouseInput and 1.2 or 1.0  -- Slightly higher for mouse to match feel
  result = result * velocityScale
  
  return result
end

function UpdateInertia()
  -- No inertia updates needed
end

function UpdatePosition()
  target = ClampTargetToBounds(target)
  
  -- Direct position updates, no smoothing
  smoothedTarget = target
  
  _Camera.orthographicSize = _Zoom
  _Camera.transform.rotation = Quaternion.Euler(24.049, 45, 0)
  _Camera.transform.position = target + CalculateRelativePosition()
end

Input.PinchOrDragBegan:Connect(function(evt)
  if not IsCameraActive() then return end

  cameraMoveState = CameraMoveStateEnum.ManualControl
  ResetPinchDrag()
  ResetZoomScale()
  ResetInertia()
end)

Input.PinchOrDragChanged:Connect(function(evt)
  if not IsCameraActive() then return end
  cameraMoveState = CameraMoveStateEnum.ManualControl

  if Input.isMouseInput then
    PanCamera(evt)
  else
    if evt.isPinching then
      PinchRotateAndZoomCamera(evt)
    else
      PanCamera(evt)
    end
  end

  wasPinching = evt.isPinching
  wasPanning = not evt.isPinching
end)

Input.PinchOrDragEnded:Connect(function(evt)
  if not IsCameraActive() then return end

  cameraMoveState = CameraMoveStateEnum.None

  -- Apply inertia for all pan gestures (both touch and mouse)
  local worldVelocity = CalculateWorldVelocity(evt)
  if worldVelocity.magnitude > 0.01 then
    ApplyInertia(worldVelocity)
  end
end)

Input.MouseWheel:Connect(function(evt)
  if not IsCameraActive() then return end

  -- Store initial world point under cursor
  local worldPointBeforeZoom = ScreenPositionToWorldPoint(_Camera, evt.position)

  if evt.delta.y < 0.0 then
    ZoomIn()
  else
    ZoomOut()
  end

  -- Update camera for new zoom
  _Camera.orthographicSize = _Zoom

  -- Adjust position to maintain cursor point
  local worldPointAfterZoom = ScreenPositionToWorldPoint(_Camera, evt.position)
  local adjustment = worldPointBeforeZoom - worldPointAfterZoom
  target = ClampTargetToBounds(target + adjustment)
  smoothedTarget = target  -- Update smoothed target to prevent conflict with pan transitions
end)

function self:Update()
  if not IsCameraActive() then return end

  if cameraMoveState == CameraMoveStateEnum.Resetting then
    local lerp = (Time.time - resetTime) / resetLerpDuration
    local position = client.localPlayer.character.gameObject.transform.position
    target = ClampTargetToBounds(Vector3.Lerp(target, position, lerp))
    _Zoom = Mathf.Lerp(_Zoom, defaultZoom, lerp)

    if (lerp >= 1) then
      cameraMoveState = CameraMoveStateEnum.None
    end
  end

  if cameraMoveState == CameraMoveStateEnum.ManualControl then
    UpdateInertia()
  end

  UpdatePosition()
end
