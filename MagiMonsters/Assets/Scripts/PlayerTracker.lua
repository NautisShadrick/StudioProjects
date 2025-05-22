--!Type(Module)

local GetDefaultMonsterDataRequest = Event.new("GetDefaultMonsterDataRequest")

local removeMonsterFromTeamRequest = Event.new("RemoveMonsterFromTeamRequest")
local addMonsterToTeamRequest = Event.new("AddMonsterToTeamRequest")

players = {}
local playercount = 0

local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")

local gameManager = require("GameManager")

local worldMonsterSpawner = require("WorldMonsterSpawner")

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    game.PlayerConnected:Connect(function(player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            currentMonsterTeam = TableValue.new("CurrentMonsterTeam"..player.user.id, {}),
            monsterCollection = TableValue.new("MonsterCollection"..player.user.id, {}),
            currentMosnterIndex = NumberValue.new("CurrentMonsterIndex"..player.user.id, 1),
            hatcheryData = TableValue.new("HatcheryData"..player.user.id, {}),
            eggCollection = TableValue.new("EggCollection"..player.user.id, {}),
            playerInventory = TableValue.new("PlayerInventory"..player.user.id, {}),
            equippedMonsterType = StringValue.new("EquippedMonsterType"..player.user.id, ""),
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

function GetItemAmountFromInv(player, itemID)
    local _playerInv = players[player].playerInventory.value
    for i, item in ipairs(_playerInv) do
        if item.id == itemID then
            return item.amount
        end
    end
    return 0
end

function GetPlayerInventory()
    return players[client.localPlayer].playerInventory.value
end

------------- CLIENT -------------

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        GetDefaultMonsterDataRequest:FireServer()

        playerinfo.equippedMonsterType.Changed:Connect(function(monsterType)
            print("Equipped monster type changed to: ", monsterType, player.name)
            if monsterType ~= "" then
                worldMonsterSpawner.SpawnWorldMonster(player, playerinfo.equippedMonsterType.value)
            end
        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

function GetPlayerMonsterData()
    return players[client.localPlayer].monsterCollection.value[players[client.localPlayer].currentMosnterIndex.value]
end

function GetPlayerMonsterCollection()
    return players[client.localPlayer].monsterCollection.value
end

function GetPlayerTeamMonsters()
    local _currentMonsterTeam = players[client.localPlayer].currentMonsterTeam.value
    local _monsterCollection = players[client.localPlayer].monsterCollection.value
    local _tempCollection = {}

    for i, monsterIndex in ipairs(_currentMonsterTeam) do
        table.insert(_tempCollection, _monsterCollection[monsterIndex])
    end

    return _tempCollection
end

function AddMonsterToTeam(index)
    addMonsterToTeamRequest:FireServer(index)
end

function RemoveMonsterFromTeam(index)
    removeMonsterFromTeamRequest:FireServer(index)
end
------------- SERVER -------------

-- player monster team is a table of indexes to the monster collection e.g {1,2,3,4} monsters [1] [2] [3] [4] in the monster collection

function SavePlayerMonstersToStorage(player: Player)
    local _monsterCollection = players[player].monsterCollection.value
    Storage.SetPlayerValue(player, "monster_colletion", _monsterCollection)
end

function SavePlayerTeamToStorage(player: Player)
    local _currentMonsterTeam = players[player].currentMonsterTeam.value
    Storage.SetPlayerValue(player, "current_Monster_Team", _currentMonsterTeam)
end

function GetPlayerMonstersFromStorage(player: Player)
    Storage.GetPlayerValue(player, "monster_colletion", function(monsterCollection)
        if monsterCollection == nil then 
            return
        end
        players[player].monsterCollection.value = monsterCollection

        Storage.GetPlayerValue(player, "current_Monster_Team", function(currentMonsterTeam)
            if currentMonsterTeam == nil or #currentMonsterTeam < 1 then 
                --if the player has no team, set it to the first 4 monsters in the collection, also account for the case where the player has less than 4 monsters
                currentMonsterTeam = {}
                print(#monsterCollection)
                if #monsterCollection == 0 then return end
                local _tempCollection = monsterCollection
                for i = 1, math.min(4, #_tempCollection) do
                    table.insert(currentMonsterTeam, i)
                end

                players[player].currentMonsterTeam.value = currentMonsterTeam

                -- now save the new team to storage
                SavePlayerTeamToStorage(player)

            end
            players[player].currentMonsterTeam.value = currentMonsterTeam
        end)
    end)

    Storage.GetPlayerValue(player, "egg_collection", function(eggCollection)
        if eggCollection == nil then 
            eggCollection = {}
        end
        players[player].eggCollection.value = eggCollection
    end)
end

function SetHealthInCollection(player: Player, hp: number)

    local _tempCollection = players[player].monsterCollection.value
    local _tempMonsterData = _tempCollection[players[player].currentMosnterIndex.value]

    _tempMonsterData.currentHealth = hp
    _tempCollection[players[player].currentMosnterIndex.value] = _tempMonsterData

    players[player].monsterCollection.value = _tempCollection
end

function AddMonsterToTeamHandler(player, index)
    print("Adding monster to team: ", index)
    local _currentMonsterTeam = players[player].currentMonsterTeam.value
    local _monsterCollection = players[player].monsterCollection.value

    if #_currentMonsterTeam == 4 then print("Team is Full") return end

    for i, monsterIndex in ipairs(_currentMonsterTeam) do
        if monsterIndex == index then
            return
        end
    end

    table.insert(_currentMonsterTeam, index)

    players[player].currentMonsterTeam.value = _currentMonsterTeam

    SavePlayerTeamToStorage(player)

    gameManager.HandleSwap(player, _currentMonsterTeam[1])
end
    
function self:ServerAwake()
    TrackPlayers(server, function(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        playerinfo.currentMonsterTeam.Changed:Connect(function(team)
            if #team < 1 then return end
            if playerinfo.currentMosnterIndex.value == team[1] then return end
            gameManager.HandleSwap(player, team[1])
        end)

    end)

    GetDefaultMonsterDataRequest:Connect(function(player)
        print("setting monster data for: ", player.name)
        GetPlayerMonstersFromStorage(player)
    end)

    removeMonsterFromTeamRequest:Connect(function(player, index)
        print("removing monster from team: ", player.name)
        local _currentMonsterTeam = players[player].currentMonsterTeam.value
        local _monsterCollection = players[player].monsterCollection.value

        if #_currentMonsterTeam <= 1 then print("Team at minimum") return end

        for i, monsterIndex in ipairs(_currentMonsterTeam) do
            if monsterIndex == index then
                table.remove(_currentMonsterTeam, i)
                break
            end
        end

        players[player].currentMonsterTeam.value = _currentMonsterTeam

        SavePlayerTeamToStorage(player)
    end)

    addMonsterToTeamRequest:Connect(AddMonsterToTeamHandler)
end
