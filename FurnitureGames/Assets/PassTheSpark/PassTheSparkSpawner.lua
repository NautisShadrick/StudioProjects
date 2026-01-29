--!Type(Module)

--!SerializeField
local entityPrefbab : GameObject = nil



stealSparkRequest = Event.new("stealSparkRequest")
playersEmoteEvent = Event.new("playersEmoteEvent")

activeHolderID = StringValue.new("activeHolderID", "")


players = {}
local playercount = 0
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
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
        local playerID = player.user.id
        if game == server then
            -- asign activeHolder to another player if the current holder leaves
            if activeHolderID.value == player.user.id then
                for otherPlayer, info in players do
                    if otherPlayer.user.id ~= playerID then
                        activeHolderID.value = otherPlayer.user.id
                        break
                    end
                end
            end
        end
        playercount = playercount - 1
        players[player] = nil
    end)
end

function GetPlayerByID(id : string)
    print("Getting player by ID: " .. id)
    for player, info in players do
        if player.user.id == id then
            print("Found player: " .. player.name)
            return player
        end
    end
end

function self:ClientAwake()
    TrackPlayers(client, function()end)
end

function self:ServerAwake()
    TrackPlayers(server, function()end)
    local _newEntity = GameObject.Instantiate(entityPrefbab)

    stealSparkRequest:Connect(function(player)
        print("SERVER: Received steal spark request from player: " .. player.name)
        if activeHolderID.value ~= player.user.id then
            activeHolderID.value = player.user.id
        end

    end)

end