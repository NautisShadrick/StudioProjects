--!Type(UI)

--!SerializeField
local icon : Texture = nil

--!Bind
local health_bar : VisualElement = nil
--!Bind
local heart_icon : Image = nil

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

function SyncToRemainingTime(timeRemaining, totalDuration)
    local currentProgress = (timeRemaining / totalDuration) * 100
    health_bar.style.width = StyleLength.new(Length.Percent(currentProgress))
    if healthBarTween then
        healthBarTween:stop()
        healthBarTween = nil
    end
    healthBarTween = Tween:new(
        currentProgress,
        0,
        timeRemaining,
        false,
        false,
        TweenModule.Easing.linear,
        function(value)
            health_bar.style.width = StyleLength.new(Length.Percent(value))
        end,
        function()
            health_bar.style.width = StyleLength.new(Length.Percent(0))
        end
    )
    healthBarTween:start()
end

function SetIcon(newIcon)
    icon = newIcon
    heart_icon.image = icon
end

function self:Awake()
    heart_icon.image = icon
    print(typeof(TweenModule))
    print(typeof(Tween))
    self.gameObject:SetActive(false)
end

