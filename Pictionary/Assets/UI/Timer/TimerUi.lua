--!Type(UI)

--!Bind
local timer_label : Label = nil

local playerTracker = require("PlayerTracker")

function self:Start()
    playerTracker.gameTime.Changed:Connect(function(value)
        timer_label.text = value
    end)
end
