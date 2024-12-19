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
            isReady = BoolValue.new("isReady" .. player.user.id, true),
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

        local myIndicator = character.gameObject.transform:GetChild(1).gameObject

        playerinfo.isReady.Changed:Connect(function()
            print("Player " .. player.name .. " is ready: " .. tostring(playerinfo.isReady.Value))
            myIndicator:SetActive(not playerinfo.isReady.value)
        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------
function self:ServerAwake()
    TrackPlayers(server)
end
