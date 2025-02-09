--!Type(Module)

questionsQueueTable = TableValue.new("QuestionsQueue", {})
whitelist = TableValue.new("whitelist", {})


local selectAnswerRequest = Event.new("SelectAnswerRequest")
local submitQuestionRequest = Event.new("SubmitQuestionRequest")
local removeQuestionRequest = Event.new("RemoveQuestionRequest")

local FetchQuestionsRequest = Event.new("FetchQuestionsRequest")

local setQuestionEvent = Event.new("SetQuestionEvent")
local completeQuestionEvent = Event.new("CompleteQuestionEvent")

local uiManager = require("UiManager")
players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    game.PlayerConnected:Connect(function(player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            currentSelection = NumberValue.new("currentSelection"..player.user.id, 0)
        }

        player.CharacterChanged:Connect(function(player, character) 
            local playerinfo = players[player]
            if (character == nil) then
                return
            end 

            if characterCallback then
                characterCallback(playerinfo)
            end
        end)
    end)

    game.PlayerDisconnected:Connect(function(player)
        playercount = playercount - 1
        players[player] = nil
    end)
end
------------- CLIENT -------------

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character
    end

    TrackPlayers(client, OnCharacterInstantiate)

    setQuestionEvent:Connect(function(questionData)

        if uiManager.isHost then return end

        uiManager.openAnswersUI()
        uiManager.SetQuestionData(questionData)
    end)

    completeQuestionEvent:Connect(function(correctPlayers)
        if uiManager.isHost then return end

        uiManager.setDefaultUI()

        --Check if player is in the correctPlayers table
        local isCorrect = false
        for each, player in ipairs(correctPlayers) do
            if player == client.localPlayer then
                isCorrect = true
            end
        end

        local popupMessage = isCorrect and "Correct!" or "Incorrect!"
        uiManager.resultsUI.ShowPopup(popupMessage)
    end)

end

function SelectAnswer(id)
    selectAnswerRequest:FireServer(id)
end
function SubmitQuestion(questionData : {})
    submitQuestionRequest:FireServer(questionData)
end

function RemoveQuestionFromQueue(index)
    removeQuestionRequest:FireServer(index)
end

function FetchQuestionsReq()
    FetchQuestionsRequest:FireServer()
end

------------- SERVER -------------

local currentQuestionData = {
    question = "",
    answers = {
        "",
        "",
        "",
        ""
    },
    correctAnswer = 1
}

local QuestionTimer = nil
local activeQuestion = false

local FetchedQuestions = {}

function CompleteQuestion()
    if QuestionTimer then
        QuestionTimer:Stop()
        QuestionTimer = nil
    end

    local correctAnswer = currentQuestionData.correctAnswer
    local correctPlayers = {}

    for player, playerinfo in pairs(players) do
        if playerinfo.currentSelection.value == correctAnswer then
            table.insert(correctPlayers, player)
        end
    end

    currentQuestionData = {
        question = "",
        answers = {
            "",
            "",
            "",
            ""
        },
        correctAnswer = 1
    }

    completeQuestionEvent:FireAllClients(correctPlayers)

    if questionsQueueTable.value[1] then
        SetQuestion(questionsQueueTable.value[1])
    else
        activeQuestion = false
    end
end

function SetQuestion(questionData)
    activeQuestion = true
    currentQuestionData = questionData
    setQuestionEvent:FireAllClients(questionData)

    if QuestionTimer then
        QuestionTimer:Stop()
        QuestionTimer = nil
    end
    QuestionTimer = Timer.After(15,CompleteQuestion)

    --Remove from queue
    local tempQueue = questionsQueueTable.value
    table.remove(tempQueue, 1)
    questionsQueueTable.value = tempQueue
end

FetchQuestions = function()
    Storage.GetValue("questions", function(value)
        if value then
            FetchedQuestions = value
        else
            FetchedQuestions = {currentQuestionData}
            Storage.SetValue("questions", FetchedQuestions)
        end
    end)
end

function self:ServerAwake()
    TrackPlayers(server)

    selectAnswerRequest:Connect(function(player, id)
        print(player.name, "SelectAnswer", player, id)
        players[player].currentSelection.value = id
    end)

    submitQuestionRequest:Connect(function(player, questionData)

        -- Make sure the player is whitelisted
        local isWhitelisted = false
        for each, playerName in ipairs(whitelist.value) do
            if playerName == player.name then
                isWhitelisted = true
                break
            end
        end
        if not isWhitelisted then return end


        if not activeQuestion then
            SetQuestion(questionData)
        else
            local tempQueue = questionsQueueTable.value
            table.insert(tempQueue, questionData)
            questionsQueueTable.value = tempQueue
        end

    end)

    removeQuestionRequest:Connect(function(player, index)
        local tempQueue = questionsQueueTable.value
        table.remove(tempQueue, index)
        questionsQueueTable.value = tempQueue
    end)


    FetchQuestionsRequest:Connect(function()
        FetchQuestions()
        -- Add all the Questions to the queue
        for each, questionData in ipairs(FetchedQuestions) do
            local tempQueue = questionsQueueTable.value
            table.insert(tempQueue, questionData)
            questionsQueueTable.value = tempQueue
        end
    end)

    FetchQuestions()
    GetWhiteList()
    
end

function GetWhiteList()
    Storage.GetValue("whitelist", function(value)
        if value then
            whitelist.value = value
        else
            whitelist = {"NautisShadrick"}
            Storage.SetValue("whitelist", whitelist)
        end
    end)
end