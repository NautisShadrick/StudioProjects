--!Type(UI)

local uiManager = require("UIManager")
local audioManager = require("AudioManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

--!Bind
local result_label: Label = nil

--!Bind
local hearts_container : VisualElement = nil
--!Bind
local glow : VisualElement = nil
--!Bind
local full_heart : VisualElement = nil
--!Bind
local left_heart : VisualElement = nil
--!Bind
local right_heart : VisualElement = nil

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

local heartsContainerPopInTween = Tween:new(
    0.01,
    1,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        hearts_container.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value)))
        )
    end,
    function()
        hearts_container.style.scale = StyleScale.new(Scale.new((Vector2.new(1, 1))))
    end
)

local heartsContainerShrinkOutTween = Tween:new(
    1,
    0.01,
    0.5,
    false,
    false,
    TweenModule.Easing.easeInBack,
    function(value)
        hearts_container.style.scale = StyleScale.new(Scale.new((Vector2.new(value, value)))
        )
    end,
    function()
        hearts_container:EnableInClassList("hidden", true)
        uiManager.matchAnimationCompleteEvent:Fire()
        audioManager.PlaySound("pop")
    end
)

local SplitAndFallRotationTween = Tween:new(
    0,
    1,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutQuad,
    function(value)
        left_heart.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value * -10)))
        right_heart.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value * 10)))

        left_heart.style.translate =  StyleTranslate.new(Translate.new(Length.new(-value*45),  Length.new(0)))
        right_heart.style.translate = StyleTranslate.new(Translate.new(Length.new(value*45),  Length.new(0)))

        local opac = 1 - value

        left_heart.style.opacity =  StyleFloat.new(opac)
        right_heart.style.opacity = StyleFloat.new(opac)
    end,
    function()
        left_heart.style.rotate = StyleRotate.new(Rotate.new(Angle.new(-10)))
        right_heart.style.rotate = StyleRotate.new(Rotate.new(Angle.new(10)))

        left_heart.style.translate =  StyleTranslate.new(Translate.new(Length.new(-45),  Length.new(0)))
        right_heart.style.translate = StyleTranslate.new(Translate.new(Length.new(45),  Length.new(0)))

        left_heart.style.opacity = StyleFloat.new(0)
        right_heart.style.opacity = StyleFloat.new(0)
    end
)

local MatchBounceTween = Tween:new(
    1,
    1.25,
    .75,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        local scaleX = math.abs(1 - t*2)
        full_heart.style.scale = StyleScale.new(Scale.new(Vector2.new(scaleX*value, value)))
        glow.style.scale = StyleScale.new(Scale.new(Vector2.new(t*1.5, t*1.5)))
    end,
    function()
        full_heart.style.scale = StyleScale.new(Scale.new(Vector2.new(1.25, 1.25)))
        glow.style.scale = StyleScale.new(Scale.new(Vector2.new(1.5, 1.5)))
    end
)

local GlowSpinUpTween = Tween:new(
    0,
    360,
    10,
    true,
    false,
    TweenModule.Easing.linear,
    function(value)
        glow.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value)))
    end,
    function()
    end
)

function ShowPopup(txt)

    result_label.text = txt

    result_label:EnableInClassList("hidden", false)
    popInTween:start()
    Timer.After(2, function()
        shrinkOutTween:start()
    end)
    --audioManager.PlaySound(2)
end

function ShowHeartStart()
    glow:EnableInClassList("hidden", true)
    hearts_container:EnableInClassList("hidden", false)
    full_heart:EnableInClassList("hidden", false)
    left_heart:EnableInClassList("hidden", false)
    right_heart:EnableInClassList("hidden", false)

    heartsContainerPopInTween:start()
end

function Split()
    full_heart:EnableInClassList("hidden",  true)
    SplitAndFallRotationTween:start()  

    ShowPopup("Pass!")

    Timer.After(2, function()
        heartsContainerShrinkOutTween:start()
    end)
end

function Match()
    left_heart:EnableInClassList("hidden",  true)
    right_heart:EnableInClassList("hidden", true)
    glow:EnableInClassList("hidden",false)
    GlowSpinUpTween:start()
    MatchBounceTween:start()

    ShowPopup("Match!")

    Timer.After(2, function()
        heartsContainerShrinkOutTween:start()
    end)
end

function self:Awake()
    hearts_container:EnableInClassList("hidden", true)
    result_label:EnableInClassList("hidden", true)
    glow:EnableInClassList("hidden",        true)
    full_heart:EnableInClassList("hidden",  true)
    left_heart:EnableInClassList("hidden",  true)
    right_heart:EnableInClassList("hidden", true)
end

