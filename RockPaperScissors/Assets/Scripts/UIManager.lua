--!Type(Module)

--!SerializeField
local mainHUDOBJ: GameObject = nil
--!SerializeField
local resultsOBJ: GameObject = nil

local mainHudUI = nil
local resultsUI = nil

local gameManager = require("GameManager")

function self:ClientStart()
    mainHudUI = mainHUDOBJ.gameObject:GetComponent(mainHUD)
    resultsUI = resultsOBJ.gameObject:GetComponent(ResultsUI)
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

function ShowResults(results)
    resultsUI.ShowResults(results)
end