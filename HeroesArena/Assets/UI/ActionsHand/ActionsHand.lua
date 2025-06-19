--!Type(UI)

--!Bind
local hand_container : VisualElement = nil

local hand = {}
local cardAngles = {}
local cardYs = {}
local cardXs = {}
local selectedCard = nil
local previousSelectedCard = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

function CreateCard()
    local _newcard = VisualElement.new()
    _newcard:AddToClassList("card")

    hand_container:Add(_newcard)

    table.insert(hand, _newcard)

    _newcard:RegisterPressCallback(function()
        previousSelectedCard = selectedCard
        selectedCard = _newcard
        selectTween = Tween:new(
            0,
            1,
            0.5,
            false,
            false,
            Easing.easeOutBack,
            function(value)
                if selectedCard then
                    selectedCard.style.rotate = StyleRotate.new(Rotate.new(Angle.new(Mathf.LerpAngle(cardAngles[selectedCard], 0, value))))
                    selectedCard.style.scale = StyleScale.new(Scale.new(Vector2.new(Mathf.Lerp(0.5, 1, value), Mathf.Lerp(0.5, 1, value))))
                    selectedCard.style.translate = StyleTranslate.new(Translate.new(Length.new(Mathf.Lerp(cardXs[selectedCard], 0, value)), Length.new(Mathf.Lerp(-cardYs[selectedCard], -300, value))))
                end
            end,
            function()
                if selectedCard then
                    selectedCard.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(-300)))
                    selectedCard.style.rotate = StyleRotate.new(Rotate.new(Angle.new(0)))
                    selectedCard.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
                end
            end
        )

        deSelectTween = Tween:new(
            0,
            1,
            0.5,
            false,
            false,
            Easing.easeOutBack,
            function(value)
                if previousSelectedCard then
                    previousSelectedCard.style.rotate = StyleRotate.new(Rotate.new(Angle.new(Mathf.LerpAngle(0, cardAngles[previousSelectedCard], value))))
                    previousSelectedCard.style.scale = StyleScale.new(Scale.new(Vector2.new(Mathf.Lerp(1, .5, value), Mathf.Lerp(1, .5, value))))
                    previousSelectedCard.style.translate = StyleTranslate.new(Translate.new(Length.new(Mathf.Lerp(0, cardXs[previousSelectedCard], value)), Length.new(Mathf.Lerp(-300, -cardYs[previousSelectedCard], value))))
                end
            end,
            function()
                if previousSelectedCard then
                    previousSelectedCard.style.translate = StyleTranslate.new(Translate.new(Length.new(cardXs[previousSelectedCard]), Length.new(-cardYs[previousSelectedCard])))
                    previousSelectedCard.style.rotate = StyleRotate.new(Rotate.new(Angle.new(cardAngles[previousSelectedCard])))
                    previousSelectedCard.style.scale = StyleScale.new(Scale.new(Vector2.new(.5, .5)))
                end
            end
        )

        deSelectTween:start()
        selectTween:start()


    end, nil)


    return _newcard
end

function UpdateHand()
    local angle
    local minAngle = -10
    local maxAngle = -minAngle

    local offsetX
    local maxOffsetX = 100
    local minOffsetX = -maxOffsetX

    local offsetY
    local maxOffsetY = 25

    local count = #hand

    for i, card in ipairs(hand) do
        --[[
            Rotate the card at an angle between -30 and 30 degrees
            based on its location in the table, first card is -30 last card is 30, lerping the angles in between.
        ]]

        if card == selectedCard then
            continue
        end

        if count == 1 then
            angle = 0
        else
            local step = (maxAngle - minAngle) / (count - 1)
            angle = minAngle + step * (i - 1)
        end

        -- set the x translation of the card based on its location in the table
        -- the middle card being at 0, the first card being -100 and the last card being 100

        if count == 1 then
            offset = 0
        else
            local stepOffsetX = (maxOffsetX - minOffsetX) / (count - 1)
            offsetX = minOffsetX + stepOffsetX * (i - 1)
        end

        local t = (i - 1) / (count - 1) -- Goes from 0 to 1
        local offsetY = -4 * maxOffsetY * (t - 0.5)^2 + maxOffsetY

        card.style.rotate = StyleRotate.new(Rotate.new(Angle.new(angle)))
        card.style.translate = StyleTranslate.new(Translate.new(Length.new(offsetX), Length.new(-offsetY)))
        card.style.scale = StyleScale.new(Scale.new(Vector2.new(.5, .5)))

        cardAngles[card] = angle
        cardXs[card] = offsetX
        cardYs[card] = offsetY

    end
end

function self:Start()
    for i = 1, 6 do
        CreateCard()
    end
    UpdateHand()
end