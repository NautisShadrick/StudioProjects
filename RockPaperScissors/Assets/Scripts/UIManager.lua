--!Type(Module)

--!SerializeField
local mainHUDOBJ: GameObject = nil

local mainHudUI = nil

local gameManager = require("GameManager")

function self:ClientStart()
    mainHudUI = mainHUDOBJ.gameObject:GetComponent(mainHUD)
end

function ShowOptions()
    print("Showing options")
    mainHudUI.SetState(1)
end

local pendingTimer = nil
function ShowResponse()
    print("Showing response")
    mainHudUI.SetState(2)
    if pendingTimer then pendingTimer:Stop() end
    pendingTimer = Timer.After(5, function()
        mainHudUI.HideButtons()
        gameManager.localPlayerIsResponding = false
    end)
end

function DisableOptions()
    print("Disabling options")
    mainHudUI.DisableOptions()
end

function ResetGame()
    print("Resetting game")
    mainHudUI.HideButtons()
end