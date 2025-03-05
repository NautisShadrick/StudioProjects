--!Type(UI)

--!SerializeField
local buttonIcons : {Texture} = nil

--!Bind
local hud_buttons: UILuaView = nil
--!Bind
local left_container: VisualElement = nil
--!Bind
local right_container: VisualElement = nil

local uiManager = require("UIManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local diaryButton = nil

local diaryBounceDown = Tween:new(
    1.2,
    1,
    0.3,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        diaryButton.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))

    end,
    function()
        diaryButton.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))

    end
)

local diaryBounceUp = Tween:new(
    1,
    1.2,
    0.2,
    false,
    false,
    TweenModule.Easing.linear, 
    function(value)
        diaryButton.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
        diaryBounceDown:start()
    end
)

function self:Start()
    
    function CreateHudButton(text: string, iconID: string, side: string, cb)

        local iconID = iconID or 0

        local _buttonContainer = VisualElement.new()
        _buttonContainer:AddToClassList("button-container")
    
        local _buttonIcon = VisualElement.new()
        _buttonIcon:AddToClassList("button-icon")
        _buttonIcon:AddToClassList(iconID)
    
        local _butonLabel = Label.new()
        _butonLabel:AddToClassList("button-label")
    
        _butonLabel.text = text
    
        _buttonContainer:Add(_buttonIcon)
        _buttonContainer:Add(_butonLabel)
    
        if side == "left" then
            left_container:Add(_buttonContainer)
        else
            right_container:Add(_buttonContainer)
        end
    
        _buttonContainer:AddToClassList(side .. "-side")
        _buttonContainer:RegisterPressCallback(cb)
    
        return _buttonContainer
    end

    diaryButton = CreateHudButton("Diary", "diary_icon", "right", function()
        uiManager.ShowLeaderboard()
    end)

    uiManager.matchAnimationCompleteEvent:Connect(function()
        diaryBounceUp:start()
    end)
end