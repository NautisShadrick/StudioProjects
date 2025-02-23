--!Type(Module)

--!SerializeField
local TimerUIObj : GameObject = nil
--!SerializeField
local SelectionUIObj : GameObject = nil

timerUI = nil
selectionUI = nil

function self:ClientStart()
    timerUI = TimerUIObj:GetComponent(TimerUI)
    selectionUI = SelectionUIObj:GetComponent(SelectionUI)
    ToggleSelectionUI(false)
end

function ToggleSelectionUI(state)
    SelectionUIObj:SetActive(state)
end