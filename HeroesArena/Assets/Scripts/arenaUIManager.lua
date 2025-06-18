--!Type(Module)

--!SerializeField
local lobbyhudOBJ : GameObject = nil
--!SerializeField
local timerHudOBJ : GameObject = nil
--!SerializeField
local actionsHandOBJ : GameObject = nil

local lobbyHudUI : LobbyHud = nil
local timerHudUI : GameTimerUI = nil
local actionsHandUI : ActionsHand = nil


local gameManager = require("GameManager")

function self:ClientStart()
    lobbyHudUI = lobbyhudOBJ:GetComponent(LobbyHud)
    timerHudUI = timerHudOBJ:GetComponent(GameTimerUI)
    actionsHandUI = actionsHandOBJ:GetComponent(ActionsHand)

    actionsHandOBJ:SetActive(false)
    gameManager.gameState.Changed:Connect(function(newState)
        if newState == 1 then
            lobbyhudOBJ:SetActive(true)
            actionsHandOBJ:SetActive(false)
        elseif newState == 2 then
            actionsHandOBJ:SetActive(false)
        elseif newState == 3 then
            lobbyhudOBJ:SetActive(false)
            actionsHandOBJ:SetActive(true)
        end
    end)
end

function JoinRequest()
    gameManager.JoinGameClient()
end