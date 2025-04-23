--!Type(Module)

--local uiManager = require("UIManager")
players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerInventory = TableValue.new("playerInventory"..player.user.id, {}),
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

        playerinfo.playerInventory.Changed:Connect(function(playerInventory)
            if player ~= client.localPlayer then print("Not my inventory that changed") return end

            --- UPDATE MY INVENTORY UIS

        end)

        playerinfo.playerHealth.Changed:Connect(function(playerHealth)
            --- UPDATE MY HEALTH UIS

        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------

function self:ServerAwake()
    TrackPlayers(server)
end