--!Type(UI)

--!Bind
local okButton : Label
--!Bind
local close_button : VisualElement
--!Bind
local card_container : VisualElement

--!Bind
local message_header : Label = nil
--!Bind
local title_label : Label = nil
--!Bind
local message_label : Label = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local startmessageModule = require("ServerStartupModule")



-- Tweens
local OpenMessageLogTween = Tween:new(
    0.01,
    1,
    0.3,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, easedT)
        card_container.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Callback when the tween is complete
        card_container.style.scale = StyleScale.new(Vector2.new(1, 1))
    end
)

local CloseMessageLogTween = Tween:new(
    1,
    0.01,
    0.3,
    false,
    false,
    TweenModule.Easing.easeInBack,
    function(value, easedT)
        card_container.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Callback when the tween is complete
        card_container.style.scale = StyleScale.new(Vector2.new(0.01, 0.01))
    end
)

okButton:RegisterPressCallback(function()
    CloseMessageLogTween:start()
    Timer.After(.3, function() self.gameObject:SetActive(false) end)
end)

close_button:RegisterPressCallback(function()
    CloseMessageLogTween:start()
    Timer.After(.3, function() self.gameObject:SetActive(false) end)
end)

function DisplayStartMessage(startMessageData)
    if not startMessageData then
        return
    end

    OpenMessageLogTween:start()
    Timer.After(0.1, function()
        if message_header then
            message_header.text = startMessageData.header or "Welcome"
        end

        if title_label then
            title_label.text = startMessageData.title or "Welcome to the Game!"
        end

        if message_label then
            message_label.text = startMessageData.message or "This is a sample message to welcome players."
        end
    end)
end