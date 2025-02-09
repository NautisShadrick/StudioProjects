--!Type(Module)

--!SerializeField
local CreateQuestionOBJ: GameObject = nil
--!SerializeField
local AnswersOBJ: GameObject = nil
--!SerializeField
local hudButtonsOBJ: GameObject = nil
--!SerializeField
local resultsOBJ: GameObject = nil

local gameManager = require("GameManager")

createQuestionUI = nil
questionUI = nil
hudButtons = nil
resultsUI = nil

isHost = false

local uis = {
    CreateQuestionOBJ,
    AnswersOBJ,
    hudButtonsOBJ
}

function openCreateQuestionUI()
    for each, ui in ipairs(uis) do
        ui:SetActive(false)
    end
    CreateQuestionOBJ:SetActive(true)
end

function openAnswersUI()
    for each, ui in ipairs(uis) do
        ui:SetActive(false)
    end
    AnswersOBJ:SetActive(true)
end

function setDefaultUI()
    for each, ui in ipairs(uis) do
        ui:SetActive(false)
    end
    if isHost then hudButtonsOBJ:SetActive(true) end
end

function SetQuestionData(questionData)
    questionUI.UpdateButtons(questionData.answers)
    questionUI.SetQuestionText(questionData.question)
end

function self:ClientStart()
    createQuestionUI = CreateQuestionOBJ:GetComponent(CreateQuestionUI)
    questionUI = AnswersOBJ:GetComponent(FourButtonMenu)
    hudButtons = hudButtonsOBJ:GetComponent(HudButtons)
    resultsUI = resultsOBJ:GetComponent(ResultsUI)

    local _whitelist = gameManager.whitelist.value
    for each, playerName in ipairs(_whitelist) do
        if playerName == client.localPlayer.name then
            isHost = true
            break
        end
    end
    
    setDefaultUI()

end