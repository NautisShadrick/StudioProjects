--!Type(Module)

--!SerializeField
local CreateQuestionOBJ: GameObject = nil
--!SerializeField
local AnswersOBJ: GameObject = nil
--!SerializeField
local hudButtonsOBJ: GameObject = nil
--!SerializeField
local resultsOBJ: GameObject = nil

createQuestionUI = nil
questionUI = nil
hudButtons = nil
resultsUI = nil

local uis = {
    CreateQuestionOBJ,
    AnswersOBJ,
    hudButtonsOBJ
}

function self:ClientStart()
    createQuestionUI = CreateQuestionOBJ:GetComponent(CreateQuestionUI)
    questionUI = AnswersOBJ:GetComponent(FourButtonMenu)
    hudButtons = hudButtonsOBJ:GetComponent(HudButtons)
    resultsUI = resultsOBJ:GetComponent(ResultsUI)
end

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
    hudButtonsOBJ:SetActive(true)
end

function SetQuestionData(questionData)
    questionUI.UpdateButtons(questionData.answers)
    questionUI.SetQuestionText(questionData.question)
end