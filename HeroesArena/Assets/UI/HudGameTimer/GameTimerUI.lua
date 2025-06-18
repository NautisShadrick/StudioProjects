--!Type(UI)

--!Bind
local game_time_label : Label = nil

local gameManger = require("GameManager")

function self:Start()

    game_time_label.text = tostring(gameManger.gameTime.value)
    gameManger.gameTime.Changed:Connect(function(newTime)
        if newTime < 0 then
            game_time_label.text = "00"
        else
            game_time_label.text = tostring(newTime)
        end
    end)
end