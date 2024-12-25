--!Type(ClientAndServer)

--!SerializeField
local Airplane: GameObject = nil
--!SerializeField
local CameraObject: GameObject = nil

local myAnchor = nil
local airplaneAnimator = nil

local camScript = nil

function self:ClientStart()
    myAnchor = self.gameObject:GetComponent(Anchor)
    airplaneAnimator = Airplane:GetComponent(Animator)
    camScript = CameraObject:GetComponent(RTSCamera)

    myAnchor.Entered:Connect(function(anchor, player)
        airplaneAnimator:SetTrigger("Fly")

        if player ~= client.localPlayer then
            return
        end

        CameraObject.transform.parent = Airplane.transform
        camScript.enabled = false
    end)

    myAnchor.Exited:Connect(function(anchor, player)
        if player ~= client.localPlayer then
            return
        end
        CameraObject.transform.parent = nil
        camScript.enabled = true
    end)
end
