--!Type(UI)

--!Bind
local health_bar : VisualElement = nil
--!Bind
local heart_icon : VisualElement = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local healthBarTween = nil
local iconPulseTween = nil

function PlayTimer(duration)
    if healthBarTween then
        healthBarTween:stop()
        healthBarTween = nil
    end

    healthBarTween = Tween:new(
        100,
        0,
        duration,
        false,
        false,
        TweenModule.Easing.linear,
        function(value)
            health_bar.style.width = StyleLength.new(Length.Percent(value))
        end,
        function()
            health_bar.style.width = StyleLength.new(Length.Percent(0))
            self.gameObject:SetActive(false)
        end
    )
    healthBarTween:start()

    if iconPulseTween then
        iconPulseTween:stop()
        iconPulseTween = nil
    end

    iconPulseTween = Tween:new(
        1,
        1.1,
        .5,
        true,
        true,
        TweenModule.Easing.easeOutQuad,
        function(value)
            heart_icon.style.scale = StyleScale.new(Vector2.new(value, value))
        end
    )
    iconPulseTween:start()
end

function self:Awake()
    self.gameObject:SetActive(false)
end

