--!Type(UI)

--!Bind
local root : UILuaView = nil

--!Bind
local close_button : VisualElement = nil
--!Bind
local question_input: VisualElement = nil
--!Bind
local answer_input_one: VisualElement = nil
--!Bind
local answer_input_two: VisualElement = nil
--!Bind
local answer_input_three: VisualElement = nil
--!Bind
local answer_input_four: VisualElement = nil

--!Bind
local answer_a: Label = nil
--!Bind
local answer_b: Label = nil
--!Bind
local answer_c: Label = nil
--!Bind
local answer_d: Label = nil

--!Bind
local submit_button: VisualElement = nil

local uiManager = require("UiManager")
local gameManager = require("GameManager")

local Buttons = {
    answer_a,
    answer_b,
    answer_c,
    answer_d
}

local selectedID = 0

local QuestionInput = UITextField.new()
QuestionInput:AddToClassList("title")
QuestionInput:SetPlaceholderText("Enter you Question Here")
question_input:Add(QuestionInput)

local Answer_Input_One = UITextField.new()
Answer_Input_One:AddToClassList("title")
Answer_Input_One:SetPlaceholderText("Enter Answer A Here")
answer_input_one:Add(Answer_Input_One)

local Answer_Input_Two = UITextField.new()
Answer_Input_Two:AddToClassList("title")
Answer_Input_Two:SetPlaceholderText("Enter Answer B Here")
answer_input_two:Add(Answer_Input_Two)

local Answer_Input_Three = UITextField.new()
Answer_Input_Three:AddToClassList("title")
Answer_Input_Three:SetPlaceholderText("Enter Answer C Here")
answer_input_three:Add(Answer_Input_Three)

local Answer_Input_Four = UITextField.new()
Answer_Input_Four:AddToClassList("title")
Answer_Input_Four:SetPlaceholderText("Enter Answer D Here")
answer_input_four:Add(Answer_Input_Four)

for i, button in ipairs(Buttons) do
    button:RegisterPressCallback(function()
        for each, button in ipairs(Buttons) do
            button:RemoveFromClassList("selected")
        end
        button:AddToClassList("selected")
        selectedID = i
    end)
end

submit_button:RegisterPressCallback(function()
    local _questionData = {
        question = QuestionInput.text,
        answers = {
            Answer_Input_One.text,
            Answer_Input_Two.text,
            Answer_Input_Three.text,
            Answer_Input_Four.text
        },
        correctAnswer = selectedID
    }
    gameManager.SubmitQuestion(_questionData)
end)

close_button:RegisterPressCallback(function()
    uiManager.setDefaultUI()
end)