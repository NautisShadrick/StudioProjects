--!Type(UI)

--!SerializeField
local boothController : ChatBoothController = nil

--!Bind
local player_count : Label = nil

local playerCount = 0
local playerMax = 4

function setMaxCount(maxCount : number)
    playerMax = maxCount
    playerCount = boothController.GetPlayercount()
    player_count.text = tostring(playerCount) .. " / " .. tostring(playerMax)
end



function self:Start()
    boothController.myPlayers.Changed:Connect(function(players)
        playerCount = boothController.GetPlayercount()
        player_count.text = tostring(playerCount) .. " / " .. tostring(playerMax)
    end)
end