--!Type(UI)

local PipOff = "pip-off"
local PipOn = "pip-selected"

--!Bind
local welcome_popup: UILuaView = nil
--!Bind
local _closeOverlay: VisualElement = nil
--!Bind
local _okButton: Button = nil
--!Bind
local _nextButtonLabel: Label = nil
--!Bind
local _backButton: Button = nil
--!Bind
local _content: VisualElement = nil
--!Bind
local _nextButton: VisualElement = nil
--!Bind
local _image1: VisualElement = nil
--!Bind
local _image2: VisualElement = nil
--!Bind
local _image3: VisualElement = nil
--!Bind
--local _image4: VisualElement = nil
--!Bind
local _desc1: Label = nil
--!Bind
local _desc2: Label = nil
--!Bind
local _desc3: Label = nil
--!Bind
--local _desc4: Label = nil
--!Bind
local _pip1: VisualElement = nil
--!Bind
local _pip2: VisualElement = nil
--!Bind
local _pip3: VisualElement = nil
--!Bind
--local _pip4: VisualElement = nil

local _states = 3
local _currentState = 1
local _closeCallback: () -> () = nil

local uiManager = require("UIManager")

-- Import Tweening module for animations.
local TweenModule = require("TweenModule")	
local Tween = TweenModule.Tween -- Tween class for creating animations.
local Easing = TweenModule.Easing -- Easing functions for animations.

-- Tween the Root UI element scaling in.
local InfoCardPopInTween = Tween:new(
	0.2, -- Starting scale.
	1, -- Ending scale.
	0.35, -- Duration in seconds.
	false, -- Do not loop animation.
	false, -- Do not ping-pong animation.
	Easing.easeOutBack, -- Easing function.
	function(value) -- Update function for tween.
		welcome_popup.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value))) -- Update scale of root UI element.
		--Slide up
		local yPos = (1 - value) * 500
		welcome_popup.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(yPos)))
	end,
	function() -- Completion callback (unused here).
		welcome_popup.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1))) -- Update scale of root UI element.
	end
)

function GetRoot(): VisualElement
	return _content
end

function ShowState(state: number)
	if state == 1 then
		InfoCardPopInTween:start()
	end

	_currentState = state
	_image1:SetDisplay(_currentState == 1)
	_image2:SetDisplay(_currentState == 2)
	_image3:SetDisplay(_currentState == 3)
	--_image4:SetDisplay(_currentState == 4)

	_desc1:SetDisplay(_currentState == 1)
	_desc2:SetDisplay(_currentState == 2)
	_desc3:SetDisplay(_currentState == 3)
	--_desc4:SetDisplay(_currentState == 4)

	_pip1:AddToClassList(_currentState == 1 and PipOn or PipOff)
	_pip2:AddToClassList(_currentState == 2 and PipOn or PipOff)
	_pip3:AddToClassList(_currentState == 3 and PipOn or PipOff)
	--_pip4:AddToClassList(_currentState == 4 and PipOn or PipOff)

	_pip1:RemoveFromClassList(_currentState ~= 1 and PipOn or PipOff)
	_pip2:RemoveFromClassList(_currentState ~= 2 and PipOn or PipOff)
	_pip3:RemoveFromClassList(_currentState ~= 3 and PipOn or PipOff)
	--_pip4:RemoveFromClassList(_currentState ~= 4 and PipOn or PipOff)
	
	if state == 3 then
		_nextButtonLabel.text ="Got It!"
	else
		_nextButtonLabel.text ="Next"
	end

	_backButton:SetDisplay(_currentState > 1)
end

local function OnCloseButton()
	uiManager.CloseInfo()
end

local function OnNext()
	if _currentState == _states then
		OnCloseButton()
	else
		ShowState(_currentState + 1)
	end
end

function Init(closeCallback: () -> ())
	_closeCallback = closeCallback
end

function self.ClientAwake()
	_nextButton:RegisterPressCallback(OnNext)
	_backButton:RegisterPressCallback(function()
		ShowState(_currentState - 1)
	end)

	ShowState(1)
end
