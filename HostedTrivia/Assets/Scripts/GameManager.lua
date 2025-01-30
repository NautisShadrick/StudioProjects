--!Type(Module)

local selectAnswerRequest = Event.new("SelectAnswerRequest")
local submitQuestionRequest = Event.new("SubmitQuestionRequest")

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
        uiManager.openAnswersUI()
        uiManager.SetQuestionData(questionData)
    end)

    completeQuestionEvent:Connect(function(correctPlayers)
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
end

function self:ServerAwake()
    TrackPlayers(server)

    selectAnswerRequest:Connect(function(player, id)
        print(player.name, "SelectAnswer", player, id)
        players[player].currentSelection.value = id
    end)

    submitQuestionRequest:Connect(function(player, questionData)
        currentQuestionData = questionData
        setQuestionEvent:FireAllClients(questionData)

        if QuestionTimer then
            QuestionTimer:Stop()
            QuestionTimer = nil
        end

        QuestionTimer = Timer.After(30, function()
            CompleteQuestion()
        end)

    end)
end
