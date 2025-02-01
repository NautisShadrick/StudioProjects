--!Type(Module)

local GetDefaultMonsterDataRequest = Event.new("GetDefaultMonsterDataRequest")

players = {}
local playercount = 0

local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            monsterCollection = TableValue.new("MonsterCollection"..player.user.id, {}),
            currentMosnterIndex = NumberValue.new("CurrentMonsterIndex"..player.user.id, 1)
        }

        player.CharacterChanged:Connect(function(player, character) 
            local playerinfo = players[player]
            if (character == nil) then
                return
            end 

            if characterCallback then
                characterCallback(playerinfo)
            end
        end)
    end)

    game.PlayerDisconnected:Connect(function(player)
        playercount = playercount - 1
        players[player] = nil
    end)
end
------------- CLIENT -------------

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        GetDefaultMonsterDataRequest:FireServer()
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

function GetPlayerMonsterData()
    return players[client.localPlayer].monsterCollection.value[players[client.localPlayer].currentMosnterIndex.value]
end

function GetPlayerMonsterCollection()
    return players[client.localPlayer].monsterCollection.value
end

------------- SERVER -------------

function SavePlayerMonstersToStorage(player: Player)
    local _monsterCollection = players[player].monsterCollection.value
    Storage.SetPlayerValue(player, "monster_colletion", _monsterCollection)
end

function GetPlayerMonstersFromStorage(player: Player)
    Storage.GetPlayerValue(player, "monster_colletion", function(monsterCollection)
        if monsterCollection == nil then 
            return
        end
        players[player].monsterCollection.value = monsterCollection
    end)
end

function SetHealthInCollection(player: Player, hp: number)

    local _tempCollection = players[player].monsterCollection.value
    local _tempMonsterData = _tempCollection[players[player].currentMosnterIndex.value]

    _tempMonsterData.currentHealth = hp
    _tempCollection[players[player].currentMosnterIndex.value] = _tempMonsterData

    players[player].monsterCollection.value = _tempCollection

    print("Health from PlayerTracker Reference ", players[player].monsterCollection.value[players[player].currentMosnterIndex.value].currentHealth)
end

function self:ServerAwake()
    TrackPlayers(server)

    GetDefaultMonsterDataRequest:Connect(function(player)
        print("setting monster data for: ", player.name)
        GetPlayerMonstersFromStorage(player)
    end)
end
