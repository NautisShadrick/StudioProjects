--!Type(UI)

--!Bind
local letter_box : VisualElement = nil
--!Bind
local letter_top : VisualElement = nil
--!Bind
local letter_bottom : VisualElement = nil
--!Bind
local fade : VisualElement = nil
--!Bind
local player_name_title : Label = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local FadeTween = Tween:new(
    -1,
    1,
    1,
    false,
    false,
    TweenModule.Easing.linear,
    function(value)
        -- opacity is 0 to 1 to 0
        local opacity = 1-math.abs(value)
        print("opacity", opacity)
        fade.style.opacity = StyleFloat.new(opacity)
    end,
    function()
        fade.style.opacity = StyleFloat.new(0)
    end
)

local removeLetterBoxesTween = Tween:new(
    1,
    1.5,
    .5,
    false,
    false,
    TweenModule.Easing.linear,
    function(value)
        letter_box.style.scale = StyleScale.new(Scale.new((Vector2.new(1, value))))
    end,
    function()
    end
)

local addLetterBoxesTween = Tween:new(
    1.5,
    1,
    .5,
    false,
    false,
    TweenModule.Easing.linear,
    function(value)
        letter_box.style.scale = StyleScale.new(Scale.new((Vector2.new(1, value))))
    end,
    function()
    end
)

local slideNameInTween = Tween:new(
    250,
    0,
    1,
    false,
    false,
    TweenModule.Easing.easeOutQuad,
    function(value, t)
        player_name_title.style.opacity = StyleFloat.new(t)
        player_name_title.style.translate =  StyleTranslate.new(Translate.new(Length.new(value),  Length.new(0)))
    end,
    function()
        player_name_title.style.translate =  StyleTranslate.new(Translate.new(Length.new(0),  Length.new(0)))
    end
)

local slideNameOutTween = Tween:new(
    0,
    250,
    1,
    false,
    false,
    TweenModule.Easing.easeOutQuad,
    function(value, t)
        player_name_title.style.opacity = StyleFloat.new(1-t)
        player_name_title.style.translate =  StyleTranslate.new(Translate.new(Length.new(value),  Length.new(0)))
    end,
    function()
        player_name_title.style.translate =  StyleTranslate.new(Translate.new(Length.new(0),  Length.new(0)))
    end
)

function FadeOut()
    print("FadeOut")
    FadeTween:start()
    removeLetterBoxesTween:start()
    slideNameOutTween:start()
end

function self:Awake()

    player_name_title.text = "Welcome to Tiki Bae"

    fade.style.opacity = StyleFloat.new(0)
    addLetterBoxesTween:start()
    slideNameInTween:start()
end