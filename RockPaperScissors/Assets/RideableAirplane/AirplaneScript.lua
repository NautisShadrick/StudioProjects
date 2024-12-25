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

    myAnchor.Entered:Connect(function(anchor, character)
        airplaneAnimator:SetTrigger("Fly")

        if character ~= client.localPlayer.character then
            print("Not local player")
            return
        end

        camScript.enabled = false
        CameraObject.transform.parent = Airplane.transform
    end)

    myAnchor.Exited:Connect(function(anchor, character)
        if character ~= client.localPlayer.character then
            return
        end
        camScript.enabled = true
        CameraObject.transform.parent = nil
    end)
end
