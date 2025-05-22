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

local monsterName = ""
local monsterSprite = nil

local canTap = false
local state = 0
local slotID = 0

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local uiManager = require("UIManager")

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
local monsterIdleTween = Tween:new(
    -20,
    -40,
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

local eggPopInTween = Tween:new(
    0.01,
    1,
    0.75,
    false,
    false,
    Easing.easeOutBack,
    function(value)
        egg_sprite.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        egg_sprite.style.scale = StyleScale.new(Vector2.new(1, 1))
    end
)


function GetMonsterInSlot(slotId)
    local playerinfo = playerTracker.players[client.localPlayer]
    local _hatcheryData = playerinfo.hatcheryData.value
    for i, _hatcherySlot in ipairs(_hatcheryData) do
        if _hatcherySlot.slotId == slotId then
            return _hatcherySlot.monster
        end
    end
    return nil
end

function InitializeHatchingUI(slotId)

    slotID = slotId
    
    local _monster = GetMonsterInSlot(slotId)
    if _monster == nil then
        print("No monster in slot")
        uiManager.CloseHatchEggUI()
        return
    end

    local monsterData : MonsterBase = monsterLibrary.monsters[_monster]
    if monsterData == nil then
        print("No monster data")
        uiManager.CloseHatchEggUI()
        return
    end

    eggSprite = monsterLibrary.eggSprites[monsterData.GetElement()]
    if eggSprite == nil then
        print("No egg sprite")
        uiManager.CloseHatchEggUI()
        return
    end

    monsterSprite = monsterData.GetSprite()
    monsterName = monsterData.GetName()

    local elementBG = uiManager.GetBG(monsterData.GetElement())
    click_off.style.backgroundImage = elementBG


    hatch_egg_text.text = "Hatch Your Egg!"
    egg_sprite.image = eggSprite

    cracks_sprite.style.display = DisplayStyle.Flex
    egg_sprite.style.display = DisplayStyle.Flex

    egg_particle.image = particleTex
    glowRotateTween:start()
    click_off.style.opacity = 0
    egg_particle.style.opacity = 0

    cracks_sprite.image = cracks[0]


    egg_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(-500)))
    glow_sprite.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    hatch_egg_text.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    continue_text.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))

    continue_text.text = ""

    bgFadeInTween:start()
    Timer.After(0.25, function()
        Timer.After(.2, function() glowPopInTween:start() end)
        eggFallInTween:start()
    end)

end

function self:Start()
    uiManager.CloseHatchEggUI()
end

egg_container:RegisterPressCallback(function()
    if canTap then
        state = state + 1
        if state == 1 then
            crackFadeInTween:start()
        end
        if state < 3 then
            tapParticle:Play()
            eggShakeTween:start()
            cracks_sprite.image = cracks[state+1]
        else
            cracks_sprite.style.display = DisplayStyle.None
            hatchParticle:Play(true)

            hatch_egg_text.text = monsterName .. "!"
            egg_sprite.image = monsterSprite
            eggPopInTween:start()
            continue_text.text = "Tap to continue..."
            eggIdleTween:stop()
            monsterIdleTween:start()
        end
        if state >= 4 then
            state = 0
            canTap = false
            eggShakeTween:stop()
            eggIdleTween:stop()
            textPopInTween:stop()
            uiManager.CloseHatchEggUI()
            uiManager.OpenNameMonsterUI(slotID)
        end
    end
end)
