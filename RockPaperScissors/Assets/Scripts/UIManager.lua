--!Type(Module)

--!SerializeField
local mainHUDOBJ: GameObject = nil

local mainHudUI = nil

function self:ClientStart()
    mainHudUI = mainHUDOBJ.gameObject:GetComponent(mainHUD)
end

function ShowOptions()
    print("Showing options")
    mainHudUI.SetState("options")
end