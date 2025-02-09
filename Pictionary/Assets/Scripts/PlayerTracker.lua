--!Type(Module)

--local uiManager = require("UIManager")
players = {}
local playercount = 0

playerQueue = TableValue.new("PLAYER_QUEUE", {})
gameTime = NumberValue.new("GAME_TIME", 1)

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            turnsLeft = NumberValue.new("TURNS_LEFT"..player.user.id, 0),
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

        if server then
            local _tempQueue = playerQueue.value
            for key, value in ipairs(_tempQueue) do
                if value == player then
                    table.remove(_tempQueue, key)
                    playerQueue.value = _tempQueue
                end
            end
        end

    end)
end

------------ Utility Functions ------------
function GetPlace(queue, player)
    queue = queue or playerQueue.value
    for i, person in ipairs(queue) do
        if person == player then
            return i
        end
    end
    return 0
end

function PrintQueueNames(table)
    for key, value in ipairs(table) do
        print(tostring(key), tostring(value.name))
    end
end

------------- CLIENT -------------

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------

CurrentPlayer = nil
LastPlayer = nil

-- Get How many turns till specific player
function GetTurnsTillPlayer(player)
    local place = GetPlace(playerQueue.value, player)
    local turns = place
    return turns
end

function UpdateQueue()
    if gameTime.value <= 0 then
        gameTime.value = 10
        if #playerQueue.value > 0 then
            -- Get the next player in the queue and set them as the current player and move them to the back of the queue
            CurrentPlayer = playerQueue.value[1]
            local tempTable = playerQueue.value
            table.remove(tempTable, 1)
            if LastPlayer then
                table.insert(tempTable, LastPlayer)
            end
            playerQueue.value = tempTable
            LastPlayer = CurrentPlayer
        end
    end
    -- Update the turns left for each player
    for key, playerInfo in pairs(players) do
        playerInfo.turnsLeft.value = GetTurnsTillPlayer(playerInfo.player)
        if CurrentPlayer == playerInfo.player then
            playerInfo.turnsLeft.value = 0
        end
    end
end

function self:ServerAwake()
    function ServerCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        -- Add the player to the queue
        local _tempQueue = playerQueue.value
        table.insert(_tempQueue, player)
        playerQueue.value = _tempQueue
        PrintQueueNames(playerQueue.value)
    end

    TrackPlayers(server, ServerCharacterInstantiate)

    UpdateQueue()
    Timer.Every(1, function()
        gameTime.value = gameTime.value - 1
        UpdateQueue()
    end)
end
