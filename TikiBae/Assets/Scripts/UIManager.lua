--!Type(Module)

--!SerializeField
local TimerUIObj : GameObject = nil
--!SerializeField
local SelectionUIObj : GameObject = nil
--!SerializeField
local resultsUIObj : GameObject = nil

timerUI = nil
selectionUI = nil
resultsUI = nil

local gameManager = require("GameStateManager")

function self:ClientStart()
    timerUI = TimerUIObj:GetComponent(TimerUI)
    selectionUI = SelectionUIObj:GetComponent(SelectionUI)
    resultsUI = resultsUIObj:GetComponent(ResultsUI)
    ToggleSelectionUI(false)

    gameManager.playerMatchedEvent:Connect(function(match)
        resultsUI.Match()
    end)

    gameManager.playerMismatchedEvent:Connect(function(match)
        resultsUI.Split()
    end)

end

function ToggleSelectionUI(state)
    SelectionUIObj:SetActive(state)
end