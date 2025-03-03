--!Type(Module)

--!SerializeField
local TimerUIObj : GameObject = nil
--!SerializeField
local SelectionUIObj : GameObject = nil
--!SerializeField
local resultsUIObj : GameObject = nil
--!SerializeField
local cinematicOverlayObj : GameObject = nil
--!SerializeField
local leaderboardUIObj : GameObject = nil
--!SerializeField
local hudButtonsUIObj : GameObject = nil

--!SerializeField
local mainCamera : Camera = nil
--!SerializeField
local cutSceneCamera : Camera = nil

timerUI = nil
selectionUI = nil
resultsUI = nil
cinematicOverlay = nil
leaderboardUI = nil
hudButtonsUI = nil

local gameManager = require("GameStateManager")

function self:ClientStart()
    timerUI = TimerUIObj:GetComponent(TimerUI)
    selectionUI = SelectionUIObj:GetComponent(SelectionUI)
    resultsUI = resultsUIObj:GetComponent(ResultsUI)
    cinematicOverlay = cinematicOverlayObj:GetComponent(CinemaOverlays)
    leaderboardUI = leaderboardUIObj:GetComponent(LeaderboardUI)
    hudButtonsUI = hudButtonsUIObj:GetComponent(HudButtons)
    ToggleSelectionUI(false)
    HideLeaderboard()

    gameManager.playerMatchedEvent:Connect(function(match)
        resultsUI.Match()
    end)

    gameManager.playerMismatchedEvent:Connect(function(match)
        resultsUI.Split()
    end)

    mainCamera.gameObject:SetActive(false)
    cutSceneCamera.gameObject:SetActive(true)


    TimerUIObj:SetActive(false)
    Timer.After(4.5, function()
        cinematicOverlay.FadeOut()
        Timer.After(.5, function()
            TimerUIObj:SetActive(true)
            cutSceneCamera.gameObject:SetActive(false)
            mainCamera.gameObject:SetActive(true)
            cutSceneCamera.transform.parent.gameObject:SetActive(false)
        end)
        Timer.After(1, function()
            cinematicOverlayObj:SetActive(false)
        end)
    end)

end

function ToggleDefaultHUD(state)
    hudButtonsUIObj:SetActive(state)
    TimerUIObj:SetActive(state)
end

function ToggleSelectionUI(state)
    SelectionUIObj:SetActive(state)
end

function HideLeaderboard()
    leaderboardUIObj:SetActive(false)
    ToggleDefaultHUD(true)
end

function ShowLeaderboard()
    leaderboardUIObj:SetActive(true)
    leaderboardUI.UpdateLeaderboard()
    ToggleDefaultHUD(false)
end