--!Type(UI)

--!Bind
local queue_container: VisualElement = nil

local gameManager = require("GameManager")
local uiManager = require("UiManager")

function AddQuestionToQueue(question: string, index: number)

    local question_container = VisualElement.new()
    question_container:AddToClassList("question")

    local question_label = Label.new()
    question_label:AddToClassList("question-text")

    -- Extract the first 27 characters of the question
    local reduced_question = string.sub(question, 1, 24)
    if string.len(question) > 27 then
        reduced_question = reduced_question .. "..."
    end
    question_label.text = reduced_question

    local delete_button = VisualElement.new()
    delete_button:AddToClassList("delete-button")

    delete_button:RegisterPressCallback(function()
        -- Remove the Button from the queue
        gameManager.RemoveQuestionFromQueue(index)
    end)

    question_container:Add(question_label)
    question_container:Add(delete_button)

    queue_container:Add(question_container)
    return question_container
end

function UpdateQueue(newQueue)
    queue_container:Clear()
    currentQueue = {}
    for i, question in ipairs(newQueue) do
        local newQuestion = AddQuestionToQueue(question.question, i)
    end
end

function self:ClientStart()
    UpdateQueue(gameManager.questionsQueueTable.value)
    gameManager.questionsQueueTable.Changed:Connect(function(newQueue)
        UpdateQueue(newQueue)
    end)
    if uiManager.isHost == false then self.gameObject:SetActive(false) end
end