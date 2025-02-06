--!Type(Module)

--!SerializeField
local TimerObj : GameObject = nil
--!SerializeField
local MidScoreObj : GameObject = nil

local timerUI = nil
local midScoreUI = nil

local danceGameManager = require("DanceGameManager")

function self:ClientAwake()
    timerUI = TimerObj:GetComponent(TimerUI)
    midScoreUI = MidScoreObj:GetComponent(MidScoreUI)

    SetScores({left = 0, right = 0})
    SetTitle("Intermission")

    danceGameManager.gameState.Changed:Connect(function(state)
        if state == 1 then
            SetTitle("Intermission")
            timerUI.ToggleClockAnim(false)
        elseif state == 2 then
            SetTitle("Dance Off")
            timerUI.ToggleClockAnim(true)
        end
        StartTimer(danceGameManager.roundDurations[state])
    end)
end

function StartTimer(duration)
    timerUI.StartTimer(duration)
end

function SetScores(scores)
    midScoreUI.SetScores(scores)
end

function SetTitle(title)
    timerUI.SetTitle(title)
end