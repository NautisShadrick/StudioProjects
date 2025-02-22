--!Type(Module)

--!SerializeField
local TimerUIObj : GameObject = nil

timerUI = nil


function self:ClientStart()
    timerUI = TimerUIObj:GetComponent(TimerUI)
    print(typeof(timerUI))
end