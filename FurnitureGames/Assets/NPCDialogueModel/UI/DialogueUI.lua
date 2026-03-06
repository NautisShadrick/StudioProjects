 --!Type(UI)

local npcColor: Color = Color.new(157, 56, 187)
local npcName: string = "NPC"
local messageTexts: {DialoguePage} = {}

local startChunk: DialogueChunk = nil
local endChunk: DialogueChunk = nil

--!SerializeField
local npcScene : GameObject = nil
--!SerializeField
local defaultNPCBG : Texture2D = nil


--!Bind
local background_scrim : VisualElement = nil
--!Bind
local NPC_backdrop : Image = nil

--!Bind
local _root : UILuaView = nil
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

--!Bind
local NPC_Image : Image = nil
--!Bind
local info_Image : Image = nil

local dialogueUtils = require("DialogueUtilities")

local playerTracker = require("PlayerTracker")
local uiManager = self

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local currentPage = 1
local currentTimers = {}
local hasResponses = false
local lastNpcImage = nil
local inStoryBeat = false

local defaultOutfit: CharacterOutfit = nil

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
    10,
    0,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutQuad,
    function(value, t)
        title_container.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
        --title_container.style.opacity = t
    end,
    function()
    end
)

local InfoImageSlideUpTween = Tween:new(
    10,
    0,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutQuad,
    function(value, t)
        info_Image.style.translate = StyleTranslate.new(Translate.new(Length.new(168), Length.new(value-154)))
        info_Image.style.opacity = StyleFloat.new(t)
    end,
    function()
    end
)

local popInTween = Tween:new(
    .01,
    1,
    0.2 ,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        message_container.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
        background_scrim.style.opacity = StyleFloat.new(t * 0.6) -- Fade in scrim with pop-in
    end,
    function()
        titlePopInTween:start()
    end
)

local myNPC

function CloseDialogue()
    if inStoryBeat then
        inStoryBeat = false
    end

    SkipTimers()
    message:Clear()
    self.gameObject:SetActive(false)
end

function ApplySpecialAnimation(character : Label, characterIndex: number, specialAnimationID : number)
    local isEven = characterIndex % 2 == 0
    if specialAnimationID == 1 then
        local _characterWaveTween = Tween:new(
            -4,
            1,
            0.15,
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
            0.15,
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

function CreateResponseButton(response, index, newChunks, responseIDs)
    local _newResponse = VisualElement.new()
    _newResponse:AddToClassList("response-button")

    local _newResponseLabel = Label.new()
    _newResponseLabel:AddToClassList("response-label")

    local success, localizedData = Localization.TryGetString(response)
    local text = localizedData:Format()

    _newResponseLabel.text = text

    _newResponse:Add(_newResponseLabel)
    responses_container:Add(_newResponse)

    _newResponse:RegisterPressCallback(function(evt)
        evt:StopPropagation() 
        SkipTimers()
        local responseID = responseIDs[index]
        if responseID == "tutorial" then -- Repeat
            messageTexts = startChunk.GetPages()
            currentPage = 1
            ConvertMessageToLabels(messageTexts[currentPage], currentPage)
        elseif responseID == "exit" then -- End
            uiManager.CloseDialogue()
        else
            messageTexts = endChunk.GetPages()
            uiManager.HandleDialogueChoice(responseID)
            currentPage = currentPage + 1
            ConvertMessageToLabels(messageTexts[currentPage], currentPage)
        end
    end)

    local _newResponseIn = Tween:new(
        0,
        1,
        0.4,
        false,
        false,
        TweenModule.Easing.easeOutBack,
        function(value)
            _newResponse.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
        end,
        function()
            _newResponse.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
        end
    )
    _newResponseIn:start()

end

local pageFinished = false

function ConvertMessageToLabels(messagePage : DialoguePage, currentPage) -- This is the funciton that populates each page of the dialogue
    if currentPage > #messageTexts then
        uiManager.CloseDialogue()
        return
    end

    if not messagePage then
        print("[DialogueUI] messagePage is nil for page " .. tostring(currentPage))
        return
    end

    message:Clear()
    responses_container:Clear()
    SkipTimers() -- Clear any remaining timers from previous page
    pageFinished = false
    local charCount = 0
    local totalChars = 0
    local pageMessages = messagePage.GetMessages()
    print("[DialogueUI] GetMessages() returned " .. tostring(#pageMessages) .. " text blocks on page " .. tostring(currentPage))
    for each, textBlock in pairs(pageMessages) do

        local messageKEY, specialAnimationID, textColor, excludeFromLocalization = textBlock.GetMessageData()
        
        local success, localizedData = Localization.TryGetString(messageKEY)
        local _loc = not excludeFromLocalization and success and localizedData:Format() or ""
        local textBlockMessage = _loc ~= "" and _loc or messageKEY

        -- Check if text contains CJK characters to determine processing method
        if dialogueUtils.containsCJKCharacters(textBlockMessage) then
            -- For CJK text, count individual characters (excluding whitespace)
            local i = 1
            while i <= #textBlockMessage do
                local byte = textBlockMessage:byte(i)
                local charLen = 1
                if byte >= 240 then charLen = 4
                elseif byte >= 224 then charLen = 3
                elseif byte >= 192 then charLen = 2
                end
                local char = textBlockMessage:sub(i, i + charLen - 1)
                i = i + charLen
                
                if char:match("%S") then -- Only count non-whitespace characters
                    totalChars = totalChars + 1
                end
            end
        else
            -- Split by whitespace while preserving Unicode characters for non-CJK text
            for word in textBlockMessage:gmatch("[^%s]+") do
                -- Count UTF-8 characters properly
                local _, charCount = word:gsub("[^\128-\191]", "")
                totalChars = totalChars + charCount
            end
        end
    end

    local revealedChars = 0

    for each, textBlock in pairs(pageMessages) do

        local charCountInCurrentBlock = 0
        local messageKEY, specialAnimationID, textColor, excludeFromLocalization = textBlock.GetMessageData()
        print("[DialogueUI] TextBlock message key: '" .. tostring(messageKEY) .. "' excludeFromLocalization=" .. tostring(excludeFromLocalization))

        local success, localizedData = Localization.TryGetString(messageKEY)
        local _loc = not excludeFromLocalization and success and localizedData:Format() or ""
        local textBlockMessage = _loc ~= "" and _loc or messageKEY
        print("[DialogueUI] textBlockMessage after localization: '" .. tostring(textBlockMessage) .. "' (localization success=" .. tostring(success) .. ")")

        --print(tostring(success), tostring(textBlockMessage))

        -- Check if text contains CJK characters to determine processing method
        if dialogueUtils.containsCJKCharacters(textBlockMessage) then
            -- For CJK text, each character gets its own word container
            local i = 1
            while i <= #textBlockMessage do
                local byte = textBlockMessage:byte(i)
                local charLen = 1
                if byte >= 240 then charLen = 4
                elseif byte >= 224 then charLen = 3
                elseif byte >= 192 then charLen = 2
                end
                local char = textBlockMessage:sub(i, i + charLen - 1)
                i = i + charLen
                
                -- Skip whitespace characters
                if char:match("%S") then
                    charCount = charCount + 1
                    
                    -- Each character gets its own word container
                    local _wordContainer = VisualElement.new()
                    _wordContainer:AddToClassList("word-container")
                    
                    local _newCharacter = Label.new()
                    _newCharacter:AddToClassList("message-character")
                    _newCharacter.text = char
                    _newCharacter.style.color = StyleColor.new(textColor)
            
                    local newTimer = Timer.After(charCount * 0.035, function()
                        _wordContainer:Add(_newCharacter)
            
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
                        revealedChars = revealedChars + 1
                        if revealedChars == totalChars then
                            pageFinished = true -- fully revealed
                        end
                    end)
                    table.insert(currentTimers, newTimer)
                    
                    message:Add(_wordContainer)
                end
            end
        else
            -- Split by whitespace while preserving Unicode characters for non-CJK text
            for word in textBlockMessage:gmatch("[^%s]+") do
                local _wordContainer = VisualElement.new()
                _wordContainer:AddToClassList("word-container")
                
                -- Iterate through UTF-8 characters properly
                local i = 1
                while i <= #word do
                    local byte = word:byte(i)
                    local charLen = 1
                    if byte >= 240 then charLen = 4
                    elseif byte >= 224 then charLen = 3
                    elseif byte >= 192 then charLen = 2
                    end
                    local char = word:sub(i, i + charLen - 1)
                    i = i + charLen

                    charCount = charCount + 1
                    local _newCharacter = Label.new()
                    _newCharacter:AddToClassList("message-character")
                    _newCharacter.text = char
                    _newCharacter.style.color = StyleColor.new(textColor)
            
                    local newTimer = Timer.After(charCount * 0.035, function()
                        _wordContainer:Add(_newCharacter)
            
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
                        revealedChars = revealedChars + 1
                        if revealedChars == totalChars then
                            pageFinished = true -- fully revealed
                        end
                    end)
                    table.insert(currentTimers, newTimer)
                end 
                message:Add(_wordContainer)
            end
        end
    end

    local pageResponses = messagePage.GetResponses()
    local newChunks = messagePage.GetNewChunks()
    local responseIDs = messagePage.GetResponseIDs()

    --play any page audio
    local pageSound = messagePage.GetSound()
    --print(typeof(pageSound))
    if pageSound then
        Audio:PlaySound(pageSound, self.gameObject, 1, 1, false, false)
    end

    local responseCount = #pageResponses
    hasResponses = responseCount > 0
    responses_container.style.height = StyleLength.new(Length.new(responseCount*38))
    for i, response in pageResponses do
        Timer.After(i * .1, function() CreateResponseButton(response, i, newChunks, responseIDs ) end)
    end

    -- Handle NPC visibility and outfit
    if myNPC then
        local showNPC = messagePage.GetShowNPC()
        if showNPC then
            NPC_Image.style.display = DisplayStyle.Flex
            -- Set NPC outfit if provided
            local pageOutfit = messagePage.GetNPCOutfit()
            if pageOutfit then
                myNPC.SetOutfit(myNPC, pageOutfit)
            else
                myNPC.SetOutfit(myNPC, defaultOutfit)
            end
            
            local waitTime = currentPage == 1 and 0.5 or .2
            Timer.After(waitTime, function()
                myNPC:PlayEmote(messagePage.GetNPCEmote())
            end)
        else
            NPC_Image.style.display = DisplayStyle.None
        end
    end

    -- Overrides
    local nameOverride = messagePage.GetNameOverride()
    local bgOverride = messagePage.GetBGOverride()
    local npcImageOverride = messagePage.GetNPCImageOverride()
    if npcImageOverride then
        NPC_Image.image = npcImageOverride
    else
        NPC_Image.image = lastNpcImage
    end

    if nameOverride ~= "" then
        title.text = nameOverride
    else
        title.text = npcName
    end

    if bgOverride then
        NPC_backdrop.style.backgroundImage = bgOverride
    else
        NPC_backdrop.style.backgroundImage = defaultNPCBG
    end


    if messagePage.GetPageImage() then
        InfoImageSlideUpTween:start()
        info_Image.style.backgroundImage = messagePage.GetPageImage()
    else
        info_Image.style.opacity = StyleFloat.new(0)
    end
end

local test = true;

function InitializeDialogue(_npcColor : Color, _npcName : string, _startChunk : DialogueChunk, npcImage : Texture, npcAvatar : Character, outfit: CharacterOutfit)
    SkipTimers() -- Clear any existing timers from previous dialogue
    message:Clear()
    npcColor = _npcColor
    npcName = _npcName
    startChunk = _startChunk
    lastNpcImage = npcImage

    defaultOutfit = outfit

    local chunkToUse = startChunk
    messageTexts = chunkToUse.GetPages()
    print("[DialogueUI] GetPages() returned " .. tostring(#messageTexts) .. " pages")
    
    print(typeof(outfit))
    if outfit then npcAvatar.SetOutfit(npcAvatar, outfit) end

    if npcAvatar and test then 
        dialogueUtils.fixAvatarYscale(npcAvatar)
        test = false
    end

    myNPC = npcAvatar

    currentPage = 1
    --title.style.backgroundColor = StyleColor.new(npcColor)
    --title.style.backgroundColor = Color.white
    title.text = npcName

    --title_container.style.opacity = 0
    popInTween:start()

    NPC_Image.image = lastNpcImage

    ConvertMessageToLabels(messageTexts[currentPage], currentPage)
end

function SkipTimers()
    for each, timer in pairs(currentTimers) do
        timer:Stop()
        timer = nil
    end
    currentTimers = {}
    message:Clear() -- Clear any characters that were already added
end

function FinishTimers()
    -- Stop any running timers
    for _, timer in pairs(currentTimers) do
        timer:Stop()
    end
    currentTimers = {}

    -- Instead of clearing, reveal all remaining text immediately
    message:Clear()

    local messagePage = messageTexts[currentPage]
    if not messagePage then return end

    for _, textBlock in pairs(messagePage.GetMessages()) do

        local messageKEY, specialAnimationID, textColor, excludeFromLocalization = textBlock.GetMessageData()
        local success, localizedData = Localization.TryGetString(messageKEY)

        local textBlockMessage, specialAnimationID, textColor, excludeFromLocalization = textBlock.GetMessageData()
        local _loc2 = not excludeFromLocalization and success and localizedData:Format() or ""
        textBlockMessage = _loc2 ~= "" and _loc2 or messageKEY

        -- Check if text contains CJK characters to determine processing method
        if dialogueUtils.containsCJKCharacters(textBlockMessage) then
            -- For CJK text, each character gets its own word container
            local i = 1
            local charIndex = 0
            while i <= #textBlockMessage do
                local byte = textBlockMessage:byte(i)
                local charLen = 1
                if byte >= 240 then charLen = 4
                elseif byte >= 224 then charLen = 3
                elseif byte >= 192 then charLen = 2
                end
                local char = textBlockMessage:sub(i, i + charLen - 1)
                i = i + charLen
                
                -- Skip whitespace characters
                if char:match("%S") then
                    charIndex = charIndex + 1
                    
                    -- Each character gets its own word container
                    local _wordContainer = VisualElement.new()
                    _wordContainer:AddToClassList("word-container")
                    
                    local _newCharacter = Label.new()
                    _newCharacter:AddToClassList("message-character")
                    _newCharacter.text = char
                    _newCharacter.style.color = StyleColor.new(textColor)

                    _wordContainer:Add(_newCharacter)
                    ApplySpecialAnimation(_newCharacter, charIndex, specialAnimationID)
                    
                    message:Add(_wordContainer)
                end
            end
        else
            -- split into words (keeps spacing like ConvertMessageToLabels) for non-CJK text
            for word in textBlockMessage:gmatch("[^%s]+") do
                local _wordContainer = VisualElement.new()
                _wordContainer:AddToClassList("word-container")

                -- Iterate through UTF-8 characters properly
                local i = 1
                local charIndex = 0
                while i <= #word do
                    local byte = word:byte(i)
                    local charLen = 1
                    if byte >= 240 then charLen = 4
                    elseif byte >= 224 then charLen = 3
                    elseif byte >= 192 then charLen = 2
                    end
                    local c = word:sub(i, i + charLen - 1)
                    charIndex = charIndex + 1
                    i = i + charLen
                    local _newCharacter = Label.new()
                    _newCharacter:AddToClassList("message-character")
                    _newCharacter.text = c
                    _newCharacter.style.color = StyleColor.new(textColor)

                    _wordContainer:Add(_newCharacter)
                    ApplySpecialAnimation(_newCharacter, charIndex, specialAnimationID)
                end

                message:Add(_wordContainer)
            end
        end
    end

    pageFinished = true
end

function CloseDialogue()

    if inStoryBeat then
        inStoryBeat = false
    end

    SkipTimers()
    message:Clear()
    self.gameObject:SetActive(false)
end

message_container:RegisterPressCallback(function()
    
    if not pageFinished then 
        FinishTimers()
    elseif hasResponses then 
        return
    else
        SkipTimers()
        currentPage = currentPage + 1
        if currentPage > #messageTexts then
           uiManager.CloseDialogue()
           return
        end
        ConvertMessageToLabels(messageTexts[currentPage], currentPage)
    end
end, nil, false, false)

_root:RegisterPressCallback(function()
    if not pageFinished then 
        FinishTimers()
    elseif hasResponses then 
        return
    else
        SkipTimers()
        currentPage = currentPage + 1
        if currentPage > #messageTexts then
           uiManager.CloseDialogue()
           return
        end
        ConvertMessageToLabels(messageTexts[currentPage], currentPage)
    end
end, nil, false, false)

function self:Start()
    self.gameObject:SetActive(false)
    mainCamera = GameObject.FindWithTag("MainCamera")
end
