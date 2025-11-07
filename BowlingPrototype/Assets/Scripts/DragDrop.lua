--!Type(Module)

local camera: Camera = nil

local isDragging = false -- flag to check if the object is currently being dragged
local dragOffset = Vector3.zero -- offset between the object's center and the touch position

local draggableObject = nil -- object that can be dragged

if server then
    return
end

local POINTCHECKDELTATIME = 0.1 -- Time interval to check motion points

local MotionPoints = {
    startPoint = Vector3.zero,
    midPoint = Vector3.zero,
    endPoint = Vector3.zero
}


local lastMotionDirection = Vector3.zero
local lastMotionMagnitude = 0

function CalculateMotionVector()
    local motionVector = MotionPoints.endPoint - MotionPoints.startPoint
    lastMotionMagnitude = motionVector.magnitude
    lastMotionDirection = motionVector.normalized

    print("Motion Vector: " .. tostring(motionVector))
    print("Direction: " .. tostring(lastMotionDirection))
    print("Magnitude: " .. tostring(lastMotionMagnitude))
    return motionVector
end

function ApplyMotionToObject(obj: GameObject)
    local rb: Rigidbody = obj:GetComponent(Rigidbody)
    if rb then
        rb.velocity = lastMotionDirection * lastMotionMagnitude * 5 -- Adjust multiplier as needed
        print("Applied Velocity: " .. tostring(rb.velocity))
    end
end

function self:ClientStart()
    camera = Camera.main -- Get the main camera in the scene

    local worldUpPlane = Plane.new(Vector3.up, Vector3.new(0, 0, 0)) -- cached to avoid re-generating every call

    -- Function to convert the screen position to a world point based on the camera's perspective
    function ScreenPositionToWorldPoint(screenPosition, flipY)
        -- Check if Y should be flipped
        if flipY then
            local screenHeight = Screen.height
            screenPosition.y = screenHeight - screenPosition.y -- Flip the Y-coordinate
        end

        -- Convert the corrected screen position to a ray
        local ray = camera:ScreenPointToRay(screenPosition) -- Convert screen position to ray
        local hitInfo: RaycastHit -- Initialize hitInfo to store raycast hit details
        local hitSuccess: boolean -- Boolean to store if the ray hit something

        -- Perform the raycast against colliders in the scene
        hitSuccess, hitInfo = Physics.Raycast(ray)

        if hitSuccess then
            return hitInfo.point, false, hitInfo -- Return the point in world space where the ray hit a collider
        else
            -- Fallback to using a plane at y = 0
            local success, distance = worldUpPlane:Raycast(ray)
            if not success then
                return Vector3.zero, true
            end
        
            return ray:GetPoint(distance), true
        end
    end

    -- Raycast from the screen position to check if an object is touched
    function RaycastFromScreen(screenPosition)
        local ray = camera:ScreenPointToRay(screenPosition) -- Convert screen position to ray
        local hitInfo: RaycastHit -- Initialize hitInfo as a RaycastHit object
        local hitSuccess: boolean -- Initialize hitSuccess as a boolean

        -- Perform raycast, returns true if an object is hit
        hitSuccess, hitInfo = Physics.Raycast(ray)
        
        if hitSuccess then
            return hitInfo.collider.gameObject -- Return the touched object
        end

        return nil -- Return nil if no object is touched
    end

    function OnDragBegan(evt)
        print("Drag Began")
         -- Ensure the script is active
        if not self.gameObject.activeSelf then
            return
        end

        -- Check if the touch is on the draggable object
        local touchedObject = RaycastFromScreen(evt.position)

        if touchedObject and touchedObject.tag == "draggable" then
            draggableObject = touchedObject
            MotionPoints.startPoint = touchedObject.transform.position
            print("Start POINT: ", tostring(MotionPoints.startPoint))

            -- after the time delta, record the mid point
            Timer.After(POINTCHECKDELTATIME, function()
                MotionPoints.midPoint = draggableObject.transform.position
                print("Mid POINT: ", tostring(MotionPoints.midPoint))
            end)

            -- after the time delta, record the end point
            Timer.After(POINTCHECKDELTATIME*2, function()
                MotionPoints.endPoint = draggableObject.transform.position
                print("End POINT: ", tostring(MotionPoints.endPoint))
                OnDragEnded()
            end)

            isDragging = true
            -- Disable the original object's collider during the drag
            draggableObject:GetComponent(SphereCollider).enabled = false
            dragOffset = draggableObject.transform.position - ScreenPositionToWorldPoint(evt.position)
        else
            return
        end
    end

    function OnDrag(evt)
        print("Dragging")
        if isDragging then
            -- Convert the touch position to world position and apply the drag offset
            local touchWorldPos, inVoid = ScreenPositionToWorldPoint(evt.position)
            local newPos = touchWorldPos + dragOffset

            -- Update the original object's position (no snapping)
            draggableObject.transform.position = newPos
        end
    end


    function OnDragEnded(evt)
        print("Drag Ended")
        if draggableObject == nil then
            return
        end
        if isDragging then
            isDragging = false
        end

        -- Enable the original object's collider again
        draggableObject:GetComponent(SphereCollider).enabled = true

        -- Calculate and apply motion vector
        CalculateMotionVector()
        ApplyMotionToObject(draggableObject)

        draggableObject = nil
    end


    -- Handle the drag start when touch is detected on the object
    Input.PinchOrDragBegan:Connect(OnDragBegan)
    -- Handle the dragging behavior while the touch is moving
    Input.PinchOrDragChanged:Connect(OnDrag)
    -- Handle the end of dragging when the touch ends
    Input.PinchOrDragEnded:Connect(OnDragEnded)

end