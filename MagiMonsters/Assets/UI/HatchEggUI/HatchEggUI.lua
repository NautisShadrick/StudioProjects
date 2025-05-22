--!Type(UI)

--!SerializeField
local fallInAnimationCurve : AnimationCurve = nil
--!SerializeField
local eggShakeAnimationCurve : AnimationCurve = nil

--!SerializeField
local cracks : {Texture} = {}
--!SerializeField
local particleTex : Texture = nil

--!SerializeField
local idleParticle: ParticleSystem = nil
--!SerializeField
local tapParticle: ParticleSystem = nil
--!SerializeField
local hatchParticle: ParticleSystem = nil

--!Bind
local click_off: VisualElement = nil

--!Bind
local reward_container: VisualElement = nil
--!Bind
local glow_sprite : VisualElement = nil
--!Bind
local egg_container: VisualElement = nil
--!Bind
local egg_particle: Image = nil
--!Bind
local egg_sprite : Image = nil
--!Bind
local cracks_sprite : Image = nil

--!Bind
local hatch_egg_text : Label = nil
--!Bind
local continue_text : Label = nil

local canTap = false
local state = 0

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

local glowRotateTween = Tween:new(
    0,
    360,
    10,
    true,
    false,
    Easing.Linear,
    function(value)
        glow_sprite.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value)))
    end,
    function()
    end
)

local bgFadeInTween = Tween:new(
    0,
    1,
    0.25,
    false,
    false,
    Easing.easeInOutCubic,
    function(value)
        click_off.style.opacity = value
    end,
    function()
        click_off.style.opacity = 1
    end
)

local glowPopInTween = Tween:new(
    0.01,
    1,
    0.5,
    false,
    false,
    Easing.easeOutBack,
    function(value)
        glow_sprite.style.scale = StyleScale.new(Vector2.new(value, value))
        egg_particle.style.opacity = value
    end,
    function()
        glow_sprite.style.scale = StyleScale.new(Vector2.new(1, 1))
        egg_particle.style.opacity = 1
    end
)

local textPopInTween = Tween:new(
    0.01,
    1,
    0.5,
    false,
    false,
    Easing.easeOutBack,
    function(value)
        hatch_egg_text.style.scale = StyleScale.new(Vector2.new(value, value))
        continue_text.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        hatch_egg_text.style.scale = StyleScale.new(Vector2.new(1, 1))
        continue_text.style.scale = StyleScale.new(Vector2.new(1, 1))
    end
)

local eggIdleTween = Tween:new(
    0,
    20,
    3,
    true,
    true,
    Easing.easeInOutQuad,
    function(value)
        egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
    end,
    function()
        egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(0)))
    end
)

local eggShakeTween = Tween:new(
    -8,
    8,
    .5,
    false,
    false,
    function(t) return eggShakeAnimationCurve:Evaluate(t) end,
    function(value)
        egg_container.style.rotate = StyleRotate.new(Rotate.new(Angle.new(value)))
    end,
    function()
        egg_container.style.rotate = StyleRotate.new(Rotate.new(Angle.new(0)))
    end
)

local eggFallInTween = Tween:new(
    -500,
    0,
    .85,
    false,
    false,
    function(t) return fallInAnimationCurve:Evaluate(t) end,
    function(value)
        egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
    end,
    function()
        eggIdleTween:start()
        egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(0)))
        canTap = true
        textPopInTween:start()
    end
)


local crackIdleTween = Tween:new(
    1,
    1.25,
    1,
    true,
    true,
    Easing.easeInOutQuad,
    function(value)
        cracks_sprite.style.opacity = value
    end,
    function()
    end
)
local crackFadeInTween = Tween:new(
    0,
    1,
    0.3,
    false,
    false,
    Easing.easeOutBack,
    function(value)
        cracks_sprite.style.opacity = value
    end,
    function()
        cracks_sprite.style.opacity = 1
        crackIdleTween:start()
    end
)

function InitializeHatchingUI()
end

function self:Start()
    egg_particle.image = particleTex
    glowRotateTween:start()
    click_off.style.opacity = 0
    egg_particle.style.opacity = 0
    egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(-500)))
    glow_sprite.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    hatch_egg_text.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    continue_text.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))

    continue_text.text = ""

    Timer.After(1, function()
        bgFadeInTween:start()
        Timer.After(0.25, function()
            Timer.After(.2, function() glowPopInTween:start() end)
            eggFallInTween:start()
        end)
    end)
end

egg_container:RegisterPressCallback(function()
    if canTap then
        tapParticle:Play()
        eggShakeTween:start()
        state = state + 1
        if state == 1 then
            crackFadeInTween:start()
        end

        if state < 3 then
            cracks_sprite.image = cracks[state]
        else
            print("egg hatched")
        end
    end
end)