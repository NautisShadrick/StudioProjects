--!Type(Module)

--local uiManager = require("UIManager")
players = {}
local playercount = 0

playerTeleportRequest = Event.new("playerTeleportRequest")
playerTeleportResponse = Event.new("playerTeleportResponse")

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerHealth = NumberValue.new("playerHealth"..player.user.id, 100),
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

        playerinfo.playerHealth.Changed:Connect(function(playerHealth)
            --- UPDATE MY HEALTH UIS

        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)

    playerTeleportResponse:Connect(function(player, position)
        player.character:Teleport(position)
    end)
end

function TeleportPlayer(position)
    playerTeleportRequest:FireServer(position)
end

function GetPlayerHealth(player)
    local playerinfo = players[player]
    if playerinfo then
        return playerinfo.playerHealth.value
    end
    print("Player not found in GetPlayerHealth: " .. tostring(player.name))
    return nil
end

------------- SERVER -------------

function self:ServerAwake()
    TrackPlayers(server)

    playerTeleportRequest:Connect(function(player,position)
        player.character.transform.position = position -- Teleport to a fixed position for now
        playerTeleportResponse:FireAllClients(player, position)
    end)
end