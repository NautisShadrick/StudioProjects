--!Type(UI)

--!SerializeField
local starSprite : Texture = nil
--!SerializeField
local testAnchor : GameObject = nil

--!Bind
local reward_particles : VisualElement = nil

local itemLibrary = require("ItemLibrary")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing


function MoveElementToElement(_element, _offset, _destination, _duration)
    if not _element or not _destination then return end

    -- Get the world position of the destination
    local destWorld = _destination.worldBound.position 

    -- Convert world position to local space of _element
    local localPos = _element:WorldToLocal(destWorld) 

    -- Animate using Tween
    local moveTween = Tween:new(
        0,                      -- from
        1,                    -- to
        _duration,                      -- duration in seconds
        false,
        false,
        Easing.easeInQuad,          -- easing function
        function(value)         -- onUpdate callback
            _element.style.translate = StyleTranslate.new(Translate.new(Length.new(_offset.x + localPos.x * value), Length.new(_offset.y + localPos.y * value)))
            _element.style.rotate = StyleRotate.new(Rotate.new(Angle.new(360 * value)))
        end,
        function()             -- onComplete callback
            _element:RemoveFromHierarchy()
            --Audio:PlayShader(popSound)
        end
    )
    moveTween:start()

end

function MoveElementToLocalOffset(_element, _offset, _destination, _duration)
    if not _element or not _offset then return end

    -- Animate using Tween
    local moveTween = Tween:new(
        0,                      -- from
        1,                    -- to
        _duration,                      -- duration in seconds
        false,
        false,
        Easing.easeOutQuad,          -- easing function
        function(value)         -- onUpdate callback
            _element.style.translate = StyleTranslate.new(Translate.new(Length.new(_offset.x * value), Length.new(_offset.y * value)))
            _element.style.rotate = StyleRotate.new(Rotate.new(Angle.new(-360 + (360 * value))))
        end,
        function()             -- onComplete callback
            MoveElementToElement(_element, _offset, _destination, .5)
        end
    )
    moveTween:start()
end

function CreatAnimatedItemElements(Items, startElement: VisualElement, destination : VisualElement)

    reward_particles.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(0)))
    local startWorld = startElement.worldBound.position 
    local localPos = reward_particles:WorldToLocal(startWorld) 
    reward_particles.style.translate = StyleTranslate.new(Translate.new(Length.new(localPos.x), Length.new(localPos.y)))

    for i, item in Items do
        local _itemInfo = itemLibrary.GetItemByID(item.id)

        Timer.After(i * .05, function()
            --auidoManager.playPop()
            local _starParticle = VisualElement.new()
            Timer.After(1, function()
                _starParticle:RemoveFromHierarchy()
            end)
            _starParticle:AddToClassList("star-particle")

            reward_particles:Add(_starParticle)

            local sprite = _itemInfo.GetSprite()
            _starParticle.style.backgroundImage = sprite

            local destinationElement = destination or UI.hud:Q("score_icon")
            --Audio:PlaySound(popSound, self.gameObject, .4, .8, false, false)
            local offset = Vector2.new(math.random(-100, 100), math.random(-100, 100))
            MoveElementToLocalOffset(_starParticle, offset, destinationElement, .5)
            _starParticle:SendToBack()
        end)
    end

end

function SpawnRewardLabel(message, startElement)
    local rewardLabel = Label.new()
    rewardLabel.text = message
    rewardLabel:AddToClassList("reward-label")
    rewardLabel:AddToClassList("default")

    reward_particles:Add(rewardLabel)
    rewardLabel:BringToFront()

    local AwardShrinkOutTween = Tween:new(
        1,                      -- from
        0.01,                    -- to
        .25,                      -- duration in seconds
        false,
        false,
        Easing.easeInQuad,          -- easing function
        function(value)         -- onUpdate callback
            position = value
            rewardLabel.style.scale = StyleScale.new(Scale.new(Vector2.new(position, position)))
        end,
        function()             -- onComplete callback
            rewardLabel:RemoveFromHierarchy()
        end
    )

    local AwardPopInTween = Tween:new(
        0.01,                      -- from
        1,                    -- to
        .5,                      -- duration in seconds
        false,
        false,
        Easing.bounce,          -- easing function
        function(value)         -- onUpdate callback
            position = value
            rewardLabel.style.scale = StyleScale.new(Scale.new(Vector2.new(position, position)))
        end,
        function()             -- onComplete callback
            rewardLabel.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
            Timer.After(.5, function()
                AwardShrinkOutTween:start()
            end)
        end
    )


    AwardPopInTween:start()
end

function CollectItemsAnimation(Items)
    CreatAnimatedItemElements(Items, reward_particles, UI.hud:Q("inv_button"))
end