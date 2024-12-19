--!Type(Module)

--!SerializeField
local mainHUDOBJ: GameObject = nil

local mainHudUI = nil

function self:ClientStart()
    mainHudUI = mainHUDOBJ.gameObject:GetComponent(mainHUD)
end

function ShowOptions()
    print("Showing options")
    mainHudUI.SetState(1)
end

function ShowResponse()
    print("Showing response")
    mainHudUI.SetState(2)
end

function DisableOptions()
    print("Disabling options")
    mainHudUI.DisableOptions()
end

function ResetGame()
    print("Resetting game")
    mainHudUI.HideButtons()
end