--!Type(UI)

--!Bind
local join_button : VisualElement = nil
--!Bind
local join_button_hover : Label = nil

local arenaUIManager = require("arenaUIManager")
local gameManager = require("GameManager")

function UpdateButtonState(newQueue)
    join_button_hover.text = #newQueue .. " /7 Players"
    for i, player in ipairs(gameManager.playerQueue.value) do
        if player == client.localPlayer then join_button:EnableInClassList("locked", true) return end
    end
    join_button:EnableInClassList("locked", #newQueue >= 7)
end

function self:Start()
    join_button:RegisterPressCallback(function()
        if #gameManager.playerQueue.value >= 7 then return end
        for i, player in ipairs(gameManager.playerQueue.value) do
            if player == client.localPlayer then return end
        end
        arenaUIManager.JoinRequest()
    end)

    UpdateButtonState(gameManager.playerQueue.value)
    gameManager.playerQueue.Changed:Connect(UpdateButtonState)
end