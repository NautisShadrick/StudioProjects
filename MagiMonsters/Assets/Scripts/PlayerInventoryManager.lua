--!Type(Module)

local requestFirstMonsterRequest = Event.new("RequestFirstMonsterRequest")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")

function RequestFirstMonster(type)
    requestFirstMonsterRequest:FireServer(type)
end

function self:ServerStart()
    requestFirstMonsterRequest:Connect(function(player, type)
        local playerInfo = playerTracker.players[player]
        local monsterCollection = playerInfo.monsterCollection.value

        if #monsterCollection > 0 then print("Someone trying to reclaim freebies, like a chump") return end

        local monsterName = "Zapkit"
        local monsterData = monsterLibrary.GetStorageMonsterData(monsterName)

        table.insert(monsterCollection, monsterData)
        playerTracker.players[player].monsterCollection.value = monsterCollection
        playerTracker.SavePlayerMonstersToStorage(player)
    end)
end