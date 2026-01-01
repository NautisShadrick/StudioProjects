--!Type(Module)

--!SerializeField
local kitePrefabs : {GameObject} = {}

players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerKite = NumberValue.new("playerKite", 1, player),
            myKite = nil,
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

function UpdateKite(player, newKite, oldKite)
    playerinfo = players[player]
    local character = player.character
    -- Update UI or other client-side elements based on player kite change
    if playerinfo.myKite then
        GameObject.Destroy(playerinfo.myKite.gameObject)
        playerinfo.myKite = nil
    end
    local kiteIndex = playerinfo.playerKite.value
    print("Player " .. player.name .. " changed kite to index: " .. kiteIndex)
    -- Spawn NewKite for Player
    print(typeof(kitePrefabs[kiteIndex]))
    if kitePrefabs[kiteIndex] then
        local kiteInstance = GameObject.Instantiate(kitePrefabs[kiteIndex])
        kiteInstance.name = "Kite_" .. player.name
        playerinfo.myKite = kiteInstance:GetComponent(KiteController)
        playerinfo.myKite.SetPlayer(player)
    end
end

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        UpdateKite(player, playerinfo.playerKite.value, nil)
        playerinfo.playerKite.Changed:Connect(function(newKite, oldKite)
            UpdateKite(player, newKite, oldKite)
        end)
    end
    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------

function self:ServerAwake()
    TrackPlayers(server, function(playerInfo)
        local player = playerInfo.player
    end)
end

function SetScore(player, score)
	players[player].playerScore.value = score
end
