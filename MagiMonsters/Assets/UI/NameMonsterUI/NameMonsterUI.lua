--!Type(UI)

--!Bind
local _root : UILuaView = nil

--!Bind
local close_button : VisualElement = nil
--!Bind
local header : Label = nil
--!Bind
local question_input: VisualElement = nil
--!Bind
local submit_button: VisualElement = nil

local uiManager = require("UIManager")
local gameManager = require("GameManager")
local hatcheryController = require("HatcheryController")

local hatchingSlotId = 0


local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local QuestionInput = nil

submit_button:RegisterPressCallback(function()
    local monsterName = QuestionInput.text
    hatcheryController.HatchMonsterRequest:FireServer(hatchingSlotId, monsterName)
    self.gameObject:SetActive(false)
end)

close_button:RegisterPressCallback(function()
    self.gameObject:SetActive(false)
end)

local contentPopInTween = Tween:new(
    .01,
    1,
    0.2,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        question_input.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
        submit_button.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
    end
)

local titlePopInTween = Tween:new(
    .01,
    1,
    0.2,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        header.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
        contentPopInTween:start()
        question_input:EnableInClassList("hidden", false)
        submit_button:EnableInClassList("hidden", false)
    end
)

local popInTween = Tween:new(
    .01,
    1,
    0.4,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        _root.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
        titlePopInTween:start()
        header:EnableInClassList("hidden", false)
    end
)

function InitializeUI(slotId)

    hatchingSlotId = slotId

    question_input:Clear()
    QuestionInput = UITextField.new()
    QuestionInput:AddToClassList("title")
    QuestionInput:SetPlaceholderText("monster name")
    question_input:Add(QuestionInput)

    header:EnableInClassList("hidden", true)
    question_input:EnableInClassList("hidden", true)
    submit_button:EnableInClassList("hidden", true)
    popInTween:start()

end

function self:Start()
    self.gameObject:SetActive(false)
end


--[[
TODO : Make sure the name of the monster defaults to the special name if the player exits the ui or otherwise closes the app
--]]