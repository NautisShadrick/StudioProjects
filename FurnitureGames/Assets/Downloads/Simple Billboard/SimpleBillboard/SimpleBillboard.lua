--!Type(Client)

--!SerializeField
local billboard : boolean = true
--!SerializeField
local amount : Vector3 = Vector3.one
--!SerializeField
local offset : Vector3 = Vector3.zero
--!SerializeField
local cameraOverride : Camera = nil
--!SerializeField
local useInitialRotation : boolean = false -- Should the original rotation of this gameobject be its default orientation?

local lastRotation : Vector3 = Vector3.zero

function self:LateUpdate()
    local camera = cameraOverride or Camera.main
    local cameraRotation = camera.transform.eulerAngles + offset
    local startRotation = self.transform.eulerAngles

    if useInitialRotation then startRotation = startRotation - lastRotation end

    local newRotation = Vector3.new(
        Mathf.Lerp(startRotation.x, cameraRotation.x, amount.x), 
        Mathf.Lerp(startRotation.y, cameraRotation.y, amount.y), 
        Mathf.Lerp(startRotation.z, cameraRotation.z, amount.z)
    )

    lastRotation = newRotation - self.transform.eulerAngles
    self.transform.eulerAngles = newRotation
end

function SetCamera(newCamera:Camera)
    cameraOverride = newCamera
end