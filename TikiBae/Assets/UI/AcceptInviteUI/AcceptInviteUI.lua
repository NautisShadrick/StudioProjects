--!Type(UI)

--!Bind
local _inviteContainer: VisualElement = nil
--!Bind
local _inviteText: Label = nil
--!Bind
local _acceptButton: UIButton = nil

local playerTracker = require("PlayerTracker")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local TIMEOUT_DURATION: number = 5
local TWEEN_DURATION: number = 0.3

local isVisible: boolean = false
local inviteId: number = 0
local slideInTween = nil
local slideOutTween = nil
local onAcceptCallback = nil

local function hideUI()
    if not isVisible then
        return
    end

    isVisible = false

    if slideInTween then
        slideInTween:stop()
        slideInTween = nil
    end

    slideOutTween = Tween:new(
        0,
        150,
        TWEEN_DURATION,
        false,
        false,
        TweenModule.Easing.easeInBack,
        function(value)
            _inviteContainer.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
        end,
        function()
            _inviteContainer.style.display = DisplayStyle.None
        end
    )
    slideOutTween:start()
end

local function showUI()
    if isVisible then
        return
    end

    isVisible = true
    inviteId = inviteId + 1
    local _currentInviteId = inviteId
    _inviteContainer.style.display = DisplayStyle.Flex

    if slideOutTween then
        slideOutTween:stop()
        slideOutTween = nil
    end

    slideInTween = Tween:new(
        150,
        0,
        TWEEN_DURATION,
        false,
        false,
        TweenModule.Easing.easeOutBack,
        function(value)
            _inviteContainer.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
        end,
        function()
        end
    )
    slideInTween:start()

    Timer.After(TIMEOUT_DURATION, function()
        if _currentInviteId == inviteId and isVisible then
            hideUI()
        end
    end)
end

function ShowInvite(inviterName: string, callback)
    if inviterName then
        _inviteText.text = inviterName .. " invited you to a ride"
    else
        _inviteText.text = "Invited you to a ride"
    end
    onAcceptCallback = callback
    showUI()
end

function HideInvite()
    hideUI()
end

function self:Start()
    _inviteContainer.style.display = DisplayStyle.None
    _inviteContainer.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(150)))

    _acceptButton:RegisterPressCallback(function()
        if onAcceptCallback then
            onAcceptCallback()
        end
        hideUI()
    end)
end

