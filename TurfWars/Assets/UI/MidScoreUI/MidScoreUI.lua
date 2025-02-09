--!Type(UI)

--!Bind
local root : UILuaView = nil
--!Bind
local score_left_label : Label = nil
--!Bind
local score_right_label : Label = nil

local audioManager = require("AudioManager")
local uiManager = require("UIModule")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

local score_left_label_tween = nil
local score_right_label_tween = nil

local leftScore = 0
local rightScore = 0


local scoreBounceTween = Tween:new(
    1,
    1.2,
    0.15,
    true,
    true,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        --Scale the score labels
        score_right_label.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value))))
        score_left_label.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value))))
        --Rotate them slightly to the right based on t
        score_right_label.style.rotate = StyleRotate.new(Rotate.new(Angle.new(-t*5)))
        score_left_label.style.rotate =   StyleRotate.new(Rotate.new(Angle.new(t*5)))

    end,
    function()
    end
)

function SetScores(scores)
    leftScore = scores.left
    rightScore = scores.right

    score_left_label.text = leftScore
    score_right_label.text = rightScore
end

local tallyTimer = nil

function TallyScores()
    root:AddToClassList("final-mode")
    if tallyTimer then tallyTimer:Stop(); tallyTimer = nil end
    tallyTimer = Timer.Every(.15, function()
        scoreBounceTween:start()

        if leftScore > 0 or rightScore > 0 then
            audioManager.PlaySound(1)
        end

        if leftScore > 0 then
            leftScore = leftScore - 1
            score_left_label.text = leftScore
        end

        if rightScore > 0 then
            rightScore = rightScore - 1
            score_right_label.text = rightScore
        end

        if leftScore == 0 or rightScore == 0 then
            scoreBounceTween:stop()
            tallyTimer:Stop()
            tallyTimer = nil

            score_right_label.style.scale = StyleScale.new(Scale.new((Vector2.new(1, 1))))
            score_left_label.style.scale = StyleScale.new(Scale.new((Vector2.new(1, 1))))
            score_right_label.style.rotate = StyleRotate.new(Rotate.new(Angle.new(0)))
            score_left_label.style.rotate = StyleRotate.new(Rotate.new(Angle.new(0)))
            
            Timer.After(1,function()
                root:RemoveFromClassList("final-mode")
                uiManager.AnnounceWinner()
            end)
        end
    end)
end

