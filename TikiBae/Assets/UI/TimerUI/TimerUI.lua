--!Type(UI)

--!Bind
local timer_icon : VisualElement = nil
--!Bind
local timer_arm_icon : VisualElement = nil
--!Bind
local timer_label : Label = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local timerBarShrinkTween = nil

local clockIconRotateBackandForthTween = Tween:new(
    -10,
    10,
    .25,
    true,
    true,
    TweenModule.Easing.easeInOutQuad,
    function(value)
        timer_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(value)))
    end,
    function()
    end
)

local rotateClockArmTween = Tween:new(
    0,
    360,
    .5,
    true,
    false,
    TweenModule.Easing.linear,
    function(value)
        timer_arm_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(value)))
    end,
    function()
    end
)

clockIconRotateBackandForthTween:start()
rotateClockArmTween:start()

function SetTitle(title)
    timer_label.text = title
end

function ToggleClockAnim(state)
    if state then
        clockIconRotateBackandForthTween:start()
        rotateClockArmTween:start()
    else
        clockIconRotateBackandForthTween:stop()
        rotateClockArmTween:stop()
        timer_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(0)))
        timer_arm_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(0)))
    end
end