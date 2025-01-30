--!Type(UI)

--!Bind
local four_button_menu: UILuaView = nil
--!Bind
local buttons_root: VisualElement = nil
--!Bind
local question_text: Label = nil
--!Bind
local timer_bar_fill : VisualElement = nil
--!Bind
local timer_icon : VisualElement = nil
--!Bind
local timer_arm_icon : VisualElement = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local timerBarShrinkTween = Tween:new(
    1,
    0,
    30,
    false,
    false,
    TweenModule.Easing.linear,
    function(value)
        timer_bar_fill.style.width = StyleLength.new(Length.Percent(value*100))
    end,
    function()
        timer_bar_fill.style.width = StyleLength.new(Length.Percent(0))
    end
)

local clockIconRotateBackandForthTween = Tween:new(
    -10,
    10,
    .25,
    true,
    true,
    TweenModule.Easing.easeInOutQuad,
    function(value)
        timer_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(value)))
    end,
    function()
    end
)

local rotateClockArmTween = Tween:new(
    0,
    360,
    .5,
    true,
    false,
    TweenModule.Easing.linear,
    function(value)
        timer_arm_icon.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(value)))
    end,
    function()
    end
)

clockIconRotateBackandForthTween:start()
rotateClockArmTween:start()

local gameManager = require("GameManager")

local currentButtons = {}

function GuessInput(id)
    gameManager.SelectAnswer(id)
    for i, button in ipairs(currentButtons) do
        button:RemoveFromClassList("selected")
    end
    currentButtons[id]:AddToClassList("selected")
end

function CreateButton(text, index: number)
    local _button = VisualElement.new()
    _button:AddToClassList("button-base")

    local _indexlabel = Label.new()
    _indexlabel:AddToClassList("button-index")
    _indexlabel.text = index == 1 and "A" or index == 2 and "B" or index == 3 and "C" or index == 4 and "D" or "NA"

    local _title = Label.new()
    _title:AddToClassList("button-title")
    _title.text = text or "Button"

    _button:Add(_indexlabel)
    _button:Add(_title)

    buttons_root:Add(_button)


    _button:RegisterPressCallback(function()
        GuessInput(index)
    end)

    table.insert(currentButtons, _button)
end

function UpdateButtons(buttons)
    buttons_root:Clear()
    currentButtons = {}
    for i, button in ipairs(buttons) do
        CreateButton(button, i)
    end

    timerBarShrinkTween:stop()
    timerBarShrinkTween:start()
end

function SetQuestionText(text)
    question_text.text = text
end

Menu_One =
{
    {"guess1"},
    {"guess2"},
    {"guess3"},
    {"guess4"}
}

UpdateButtons(Menu_One)
