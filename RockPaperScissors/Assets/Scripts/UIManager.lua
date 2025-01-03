--!Type(Module)

--!SerializeField
local mainHUDOBJ: GameObject = nil
--!SerializeField
local resultsOBJ: GameObject = nil
--!SerializeField
local leaderboardOBJ: GameObject = nil
--!SerializeField
local hudButtonsOBJ: GameObject = nil
--!SerializeField
local welcomObj: GameObject = nil
--!SerializeField
local eventTimerObj: GameObject = nil

local mainHudUI = nil
local resultsUI = nil
local leaderboardUI = nil
local hudButtonsUI = nil
local welcomeUI = nil

local gameManager = require("GameManager")
local leaderboardManager = require("LeaderboardManager")

function self:ClientStart()
    mainHudUI = mainHUDOBJ.gameObject:GetComponent(mainHUD)
    resultsUI = resultsOBJ.gameObject:GetComponent(ResultsUI)
    leaderboardUI = leaderboardOBJ.gameObject:GetComponent(LeaderboardUI)
    hudButtonsUI = hudButtonsOBJ.gameObject:GetComponent(HudButtons)
    welcomeUI = welcomObj.gameObject:GetComponent(UIWelcomePopup)

    leaderboardOBJ:SetActive(false)
    eventTimerObj:SetActive(false)
end

function ShowInfo()
    eventTimerObj:SetActive(false)
    welcomObj:SetActive(true)
    welcomeUI.ShowState(1)
end

function CloseInfo()
    welcomObj:SetActive(false)
    eventTimerObj:SetActive(true)
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

function ShowLeaderboard()
    eventTimerObj:SetActive(false)
    hudButtonsOBJ:SetActive(false)
    leaderboardOBJ:SetActive(true)
    UpdateLeaderboard()
    UpdateLocalPlayer()
end

function HideLeaderboard()
    eventTimerObj:SetActive(true)
    leaderboardOBJ:SetActive(false)
    hudButtonsOBJ:SetActive(true)
end


-------- Leaderboard Functions --------
function UpdateLocalPlayer()
    leaderboardManager.RequestLocalEntry(function(entry)
        leaderboardUI.UpdateLocalPlayer(entry.rank, entry.name, entry.score)
    end)
end

function UpdateLeaderboard()
    leaderboardManager.RequestEntries(function(entries)
        leaderboardUI.UpdateLeaderboard(entries)
    end)
end