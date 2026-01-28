--!Type(UI)

--!SerializeField
local arrowSprites : {Sprite} = {}

--!Bind
local Button_Left : VisualElement = nil
--!Bind
local Button_Down : VisualElement = nil
--!Bind
local Button_Up : VisualElement = nil
--!Bind
local Button_Right : VisualElement = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

local upDistance = -(Screen.height/1.5)

local buttonDirections = {
    [0] = Button_Left,
    [1] = Button_Down,
    [2] = Button_Up,
    [3] = Button_Right,
}

function FadOutArrow(arrowElement)
    local fadeOutTween = Tween:new(
        1,
        1.75,
        0.2,
        false,
        false,
        Easing.Linear,
        function(value, t)
            local opacity = (t - 1) * -1
            arrowElement.style.scale = Scale.new(Vector2.new(value, value))
            arrowElement.style.opacity = opacity
        end,
        function()
            arrowElement:RemoveFromHierarchy()
        end
    )
    fadeOutTween:start()
end

function CreateArrow(direction)
    if direction == -1 then return end
    --print("Creating arrow in direction: "..direction)
    local arrowElement = VisualElement.new()
    arrowElement:AddToClassList("arrow-element")

    arrowElement.style.backgroundImage = arrowSprites[direction+1].texture

    if buttonDirections[direction] then
        buttonDirections[direction]:Add(arrowElement)
    end

    local popInTween = Tween:new(
        0.002,
        1,
        0.2,
        false,
        false,
        Easing.OutBack,
        function(value)
            arrowElement.style.scale = Scale.new(Vector2.new(value, value))
        end,
        function()
            -- After pop-in complete, start moving up
        end
    )
    popInTween:start()

    local elementTween = Tween:new(
        upDistance,
        0,
        2,
        false,
        false,
        Easing.Linear,
        function(value)
            arrowElement.style.translate = StyleTranslate.new(Translate.new(Length.new(0),Length.new(value)))
        end,
        function()
            FadOutArrow(arrowElement)
        end
    )
    elementTween:start()
end

-- Expose buttons for external callback registration
Buttons = buttonDirections