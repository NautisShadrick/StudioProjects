--!Type(UI)

--!Bind
local timer_icon : VisualElement = nil
--!Bind
local timer_arm_icon : VisualElement = nil
--!Bind
local timer_label : Label = nil

local gameManager = require("GameStateManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local handRotationTween = nil

local timerTween = nil

function SetTitle(title)
    timer_label.text = title
end

function SetHand(state)
    if state == 1 then

        if handRotationTween then
            handRotationTween:stop()
            handRotationTween = nil
        end

        handRotationTween = Tween:new(
            -40,
             40,
            .5,
            false,
            false,
            TweenModule.Easing.bounce,
            function(value)
                timer_arm_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value)))
            end,
            function()
            end
        )
        handRotationTween:start()
    else

        if handRotationTween then
            handRotationTween:stop()
            handRotationTween = nil
        end

        handRotationTween = Tween:new(
             40,
            -40,
            .5,
            false,
            false,
            TweenModule.Easing.bounce,
            function(value)
                timer_arm_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value)))
            end,
            function()
            end
        )
        handRotationTween:start()
    end
end

function StartTimerWithDuration(duration)

    if timerTween then
        timerTween:stop()
        timerTween = nil
    end
    -- Implementation for starting the timer with a specific duration
    timerTween = Tween:new(
        duration,
        0,
        duration,
        false,
        false,
        TweenModule.Easing.linear,
        function(value)
            -- set timer label text to be mm:ss format
            local minutes = math.floor(value / 60)
            local seconds = math.floor(value % 60)
            timer_label.text = string.format("%02d:%02d", minutes, seconds)
        end,
        function()
            -- Timer completed
        end
    )
    timerTween:start()
end

function self:Start()
end