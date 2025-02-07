--!Type(Module)

--!SerializeField
local TimerObj : GameObject = nil
--!SerializeField
local MidScoreObj : GameObject = nil
--!SerializeField
local ResultsObj : GameObject = nil

timerUI = nil
midScoreUI = nil
resultsUI = nil

local left = 0
local right = 0

local danceGameManager = require("DanceGameManager")

function self:ClientAwake()
    timerUI = TimerObj:GetComponent(TimerUI)
    midScoreUI = MidScoreObj:GetComponent(MidScoreUI)
    resultsUI = ResultsObj:GetComponent(ResultsUI)

    SetScores({left = 0, right = 0})
    SetTitle("Intermission")

    danceGameManager.gameState.Changed:Connect(function(state)
        if state == 1 then
            SetTitle("Intermission")
            timerUI.ToggleClockAnim(false)
            -- Tally Scores
            TallyScores()
        elseif state == 2 then
            SetScores({left = 0, right = 0})
            SetTitle("Dance Off")
            timerUI.ToggleClockAnim(true)
        end
        StartTimer(danceGameManager.roundDurations[state])
    end)

    Timer.After(1, function()
        StartTimer(danceGameManager.roundTime.value)
    end)
end

function AnnounceWinner()
    --Announce winning team
    if left > right then
        resultsUI.ShowPopup("Red Team Wins!")
    elseif right > left then
        resultsUI.ShowPopup("Blue Team Wins!")
    else
        resultsUI.ShowPopup("It's a tie!")
    end
end

function StartTimer(duration)
    timerUI.StartTimer(duration)
    print(danceGameManager.roundTime.value)
end

function SetScores(scores)
    left = scores.left
    right = scores.right
    midScoreUI.SetScores(scores)
end

function SetTitle(title)
    timerUI.SetTitle(title)
end

function TallyScores()
    midScoreUI.TallyScores()
end