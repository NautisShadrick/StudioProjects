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
local acceptUI : AcceptInviteUI = nil

--!SerializeField
local mainCamera : Camera = nil
--!SerializeField
local cutSceneCamera : Camera = nil

matchAnimationCompleteEvent = Event.new("MatchAnimationCompleteEvent")

timerUI = nil
selectionUI = nil
resultsUI = nil
cinematicOverlay = nil
leaderboardUI = nil
hudButtonsUI = nil

local audioManager = require("AudioManager")
local gameManager = require("GameStateManager")
local playerTracker = require("PlayerTracker")

function self:ClientStart()
    timerUI = TimerUIObj:GetComponent(TimerUI)
    selectionUI = SelectionUIObj:GetComponent(SelectionUI)
    resultsUI = resultsUIObj:GetComponent(ResultsUI)
    cinematicOverlay = cinematicOverlayObj:GetComponent(CinemaOverlays)
    leaderboardUI = leaderboardUIObj:GetComponent(LeaderboardUI)
    hudButtonsUI = hudButtonsUIObj:GetComponent(HudButtons)
    ToggleSelectionUI(false)
    HideLeaderboard()
    ToggleDefaultHUD(false)

    gameManager.playerMatchedEvent:Connect(function(match)
        resultsUI.Match()
        audioManager.PlaySound("match")
    end)

    gameManager.playerMismatchedEvent:Connect(function(match)
        resultsUI.Split()
        audioManager.PlaySound("pass")
    end)

    playerTracker.inviteEvent:Connect(function(senderPlayer)
        local senderName = senderPlayer.name
        acceptUI.ShowInvite(senderName, function()
            playerTracker.acceptInviteRequest:FireServer(senderPlayer)
        end)
    end)

    mainCamera.gameObject:SetActive(false)
    cutSceneCamera.gameObject:SetActive(true)
    TimerUIObj:SetActive(false)

    Timer.After(4.5, function()
        cinematicOverlay.FadeOut()
        Timer.After(.5, function()
            cutSceneCamera.gameObject:SetActive(false)
            mainCamera.gameObject:SetActive(true)
            cutSceneCamera.transform.parent.gameObject:SetActive(false)
            hudButtonsUIObj:SetActive(true)
        end)
        Timer.After(1, function()
            cinematicOverlayObj:SetActive(false)
        end)
    end)

end

function PlayTimer(duration)
    timerUI.StartTimerWithDuration(duration)
end

function ToggleTimerUI(state)
    TimerUIObj:SetActive(state)
end

function ToggleDefaultHUD(state)
    hudButtonsUIObj:SetActive(state)
    --TimerUIObj:SetActive(state)
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
    audioManager.PlaySound("rustle")
end