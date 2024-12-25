--!Type(UI)

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

--!Bind
local result_label: Label = nil

local popInTween = Tween:new(
    0.01,
    1,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        result_label.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value))))
    end,
    function()
        result_label.style.scale = StyleScale.new(Scale.new((Vector2.new(1, 1))))
    end
)

local shrinkOutTween = Tween:new(
    1,
    0.01,
    0.5,
    false,
    false,
    TweenModule.Easing.easeInBack,
    function(value)
        result_label.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value))))
    end,
    function()
        result_label:EnableInClassList("hidden", true)
    end
)

function ShowResults(results)

    if results == "win" then
        result_label.text = "You Win!"
    elseif results == "lose" then
        result_label.text = "You Lose!"
    else
        result_label.text = "Draw!"
    end

    result_label:EnableInClassList("hidden", false)
    popInTween:start()
    Timer.After(1, function()
        shrinkOutTween:start()
    end)
end

function self:Awake()
    result_label:EnableInClassList("hidden", true)
end

