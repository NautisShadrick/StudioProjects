--!Type(UI)


local npcColor: Color = Color.new(157, 56, 187)
local npcName: string = "NPC"
local messageTexts: {DialoguePage} = {}

--!Bind
local message_container: VisualElement = nil
--!Bind
local title_container: VisualElement = nil
--!Bind
local responses_container : VisualElement = nil
--!Bind
local title: Label = nil
--!Bind
local message: VisualElement = nil
--!Bind
local indicator: VisualElement = nil

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local currentPage = 1

local currentTimers = {}

local indicatorBobTween = Tween:new(
    -1,
    1,
    0.5,
    true,
    true,
    TweenModule.Easing.easeInOutQuad,
    function(value)
        indicator.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
    end,
    function()
    end
)
indicatorBobTween:start()

local titlePopInTween = Tween:new(
    .01,
    1,
    0.2,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        title_container.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
    end
)

local popInTween = Tween:new(
    .01,
    1,
    0.2,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        message_container.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
    end,
    function()
        titlePopInTween:start()
    end
)

function ApplySpecialAnimation(character : Label, characterIndex: number, specialAnimationID : number)
    local isEven = characterIndex % 2 == 0
    if specialAnimationID == 1 then
        local _characterWaveTween = Tween:new(
            -4,
            1,
            0.5,
            true,
            true,
            TweenModule.Easing.easeOutBack,
            function(value)
                character.style.translate = StyleTranslate.new(Translate.new(Length.new(0),Length.new(value)))
            end,
            function() 
            end
        )
        _characterWaveTween:start()
    elseif specialAnimationID == 2 then
        local _characterWaveTween = Tween:new(
            -2,
            3,
            0.5,
            true,
            true,
            TweenModule.Easing.easeInOutQuad,
            function(value)
                character.style.translate = StyleTranslate.new(Translate.new(Length.new(0),Length.new(value)))
            end,
            function() 
            end
        )
        _characterWaveTween:start()
    end
end

function CreateResponseButton(response, index, newChunks)
    local _newResponse = VisualElement.new()
    _newResponse:AddToClassList("response-button")

    local _newResponseLabel = Label.new()
    _newResponseLabel:AddToClassList("response-label")
    _newResponseLabel.text = response

    _newResponse:Add(_newResponseLabel)
    responses_container:Add(_newResponse)

    _newResponse:RegisterPressCallback(function()
        SkipTimers()
        currentPage = 1
        local ourChunk = newChunks[index]
        messageTexts = ourChunk.GetPages()
        ConvertMessageToLabels(messageTexts[currentPage])
    end)
end

function ConvertMessageToLabels(messagePage : DialoguePage) -- This is the funciton that populates each page of the dialogue
    message:Clear()
    responses_container:Clear()
    local charCount = 0

    for each, textBlock in pairs(messagePage.GetMessages()) do
        local charCountInCurrentBlock = 0

        local textBlockMessage, specialAnimationID, textColor = textBlock.GetMessageData()

        for char in textBlockMessage:gmatch(".") do
            charCount = charCount + 1
            local _newCharacter = Label.new()
            _newCharacter:AddToClassList("message-character")
            _newCharacter.text = char
            _newCharacter.style.color = StyleColor.new(textColor)
    
            local newTimer = Timer.After(charCount * 0.05, function()
                message:Add(_newCharacter)
    
                local _newCharacterIn = Tween:new(
                    0,
                    1,
                    0.2,
                    false,
                    false,
                    TweenModule.Easing.easeOutBack,
                    function(value)
                        _newCharacter.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
                    end,
                    function()
                        _newCharacter.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
                    end
                )
                _newCharacterIn:start()
                ApplySpecialAnimation(_newCharacter, charCountInCurrentBlock + 1, specialAnimationID)
                charCountInCurrentBlock = charCountInCurrentBlock + 1
            end)
            table.insert(currentTimers, newTimer)

        end

    end

    local pageResponses = messagePage.GetResponses()
    local newChunks = messagePage.GetNewChunks()
    print(#newChunks)
    for i, response in pageResponses do CreateResponseButton(response, i, newChunks) end
end

function InitializeDialogue(_npcColor : Color, _npcName : string, _messageTexts : {DialoguePage})
    message:Clear()
    npcColor = _npcColor
    npcName = _npcName
    messageTexts = _messageTexts

    currentPage = 1
    title_container.style.backgroundColor = StyleColor.new(npcColor)
    title.text = npcName

    title_container.style.scale = StyleScale.new(Scale.new(Vector2.new(0, 0)))
    popInTween:start()

    ConvertMessageToLabels(messageTexts[currentPage])
end

function SkipTimers()
    for each, timer in pairs(currentTimers) do
        timer:Stop()
        timer = nil
    end
    currentTimers = {}
end

function CloseDialogue()
    SkipTimers()
    message:Clear()
    self.gameObject:SetActive(false)
end

message_container:RegisterPressCallback(function()
    SkipTimers()
    currentPage = currentPage + 1
    if currentPage > #messageTexts then
        CloseDialogue()
        return
    end
    ConvertMessageToLabels(messageTexts[currentPage])
end)


function self:Start()
    self.gameObject:SetActive(false)
end
