--!Type(UI)

--!SerializeField
local starSprite : Texture = nil
--!SerializeField
local cheerSprite : Texture = nil

--!Bind
local reward_particles : VisualElement = nil

--local auidoManager = require("AudioManager")
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
            --auidoManager.PlaySoundEffect("popSound")
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

function CreatAnimatedStarElements(stars: number, startElement: VisualElement, sprite : Texture, destination : VisualElement)
    sprite = sprite or starSprite

    -- Get the world position of where particles should spawn
    local startWorld = startElement.worldBound.position
    local stableParent = reward_particles.parent

    for i=1, math.min(stars, 50) do
        Timer.After(i * .05, function()
            --auidoManager.PlaySoundEffect("popSound")
            local _starParticle = VisualElement.new()
            Timer.After(1, function()
                _starParticle:RemoveFromHierarchy()
            end)
            _starParticle:AddToClassList("star-particle")
            _starParticle.style.position = Position.Absolute

            -- Add to stable parent and position at spawn point
            stableParent:Add(_starParticle)
            local localPos = stableParent:WorldToLocal(startWorld)
            _starParticle.style.left = Length.new(localPos.x)
            _starParticle.style.top = Length.new(localPos.y)

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
    rewardLabel.style.position = Position.Absolute

    -- Add to stable parent and position at spawn point
    local stableParent = reward_particles.parent
    local startWorld = startElement.worldBound.position
    stableParent:Add(rewardLabel)
    local localPos = stableParent:WorldToLocal(startWorld)
    rewardLabel.style.left = Length.new(localPos.x)
    rewardLabel.style.top = Length.new(localPos.y - 60)
    rewardLabel:BringToFront()

    local AwardShrinkOutTween = Tween:new(
        1,                      -- from
        0.01,                    -- to
        .2,                      -- duration in seconds
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
        .1,                      -- duration in seconds
        false,
        false,
        Easing.bounce,          -- easing function
        function(value)         -- onUpdate callback
            position = value
            rewardLabel.style.scale = StyleScale.new(Scale.new(Vector2.new(position, position)))
        end,
        function()             -- onComplete callback
            rewardLabel.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
            Timer.After(.2, function()
                AwardShrinkOutTween:start()
            end)
        end
    )


    AwardPopInTween:start()
end

function TicketAward(amount, startElement)
    local _sprite = starSprite
    local spawnElement = startElement or reward_particles
    --CreatAnimatedStarElements(amount/10, spawnElement, _sprite, UI.aboveChat:Q("SeasonPassAttractor"))
    local message = "+"..tostring(amount)
    if amount == 0 then
        message = "MISS"
    end
    SpawnRewardLabel(message, spawnElement)
end