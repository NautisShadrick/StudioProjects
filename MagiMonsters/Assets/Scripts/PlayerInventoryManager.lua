--!Type(Module)

local requestFirstMonsterRequest = Event.new("RequestFirstMonsterRequest")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")

------------ Client ------------

function RequestFirstMonster(type)
    requestFirstMonsterRequest:FireServer(type)
end

------------ Server ------------

function SaveEggCollectionToStorage(player: Player)
    local _eggCollection = playerTracker.players[player].eggCollection.value
    Storage.SetPlayerValue(player, "egg_collection", _eggCollection, function()
        print("Egg Collection Saved")
    end)
end

function GivePlayerEgg(player: Player, eggData)
    local _eggCollection = playerTracker.players[player].eggCollection.value
    table.insert(_eggCollection, eggData)
    playerTracker.players[player].eggCollection.value = _eggCollection
    SaveEggCollectionToStorage(player)
end

function GivePlayerMonster(player, monsterName)
    print("Giving Player Monster", player.name, monsterName)
    local playerInfo = playerTracker.players[player]
    local monsterCollection = playerInfo.monsterCollection.value

    local monsterData = monsterLibrary.GetStorageMonsterData(monsterName)

    table.insert(monsterCollection, monsterData)
    playerTracker.players[player].monsterCollection.value = monsterCollection
    playerTracker.SavePlayerMonstersToStorage(player)
end

function self:ServerStart()
    requestFirstMonsterRequest:Connect(function(player, type)
        local playerInfo = playerTracker.players[player]
        local monsterCollection = playerInfo.monsterCollection.value
        local eggCollection = playerInfo.eggCollection.value

        if #monsterCollection > 0 or #eggCollection > 0 then print("Someone trying to reclaim freebies, like a chump") return end

        local _newEggData = {monster = "Zapkit", totalDuration = 60}
        GivePlayerEgg(player, _newEggData)
    end)
end