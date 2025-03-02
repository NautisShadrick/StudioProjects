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

function self:Start()
    SetHand(gameManager.GameState.value)
    gameManager.GameState.Changed:Connect(function(state)
        SetHand(state)
    end)
end