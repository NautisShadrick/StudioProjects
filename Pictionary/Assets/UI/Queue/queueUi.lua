--!Type(UI)

--!Bind
local queueLabel : Label = nil

local playerTracker = require("PlayerTracker")

function self:Start()
    queueLabel.text = playerTracker.players[client.localPlayer].turnsLeft.value .. " Turns till you draw."
    playerTracker.players[client.localPlayer].turnsLeft.Changed:Connect(function(value)
        queueLabel.text = value .. " Turns till you draw."
        if value == 0 then
            queueLabel.text = "Drawing..."
        end
    end)
end