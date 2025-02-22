--!Type(Module)

local TeleportRequest = Event.new("TeleportRequest")
local TeleportResponse = Event.new("TeleportResponse")

--local uiManager = require("UIManager")
players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player
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
    end

    TrackPlayers(client, OnCharacterInstantiate)

    TeleportResponse:Connect(function(player, destination)
        local character = player.character
        if character then
            character:Teleport(destination)
        end
    end)
end

function TeleportLocalPlayerRequest(destination)
    TeleportRequest:FireServer(destination)
end

------------- SERVER -------------

function SeperatePlayersIntoRandomPairs()
    local playerList = {}
    for player, playerinfo in pairs(players) do
        table.insert(playerList, player)
    end

    local playerCount = #playerList
    local playerPairs = {}
    for i = 1, playerCount, 2 do
        local player1 = playerList[i]
        local player2 = playerList[i + 1]
        local pair = {player1, player2}
        
        if #pair ~= 1 then
            table.insert(playerPairs, pair)
        else
            soloPlayer = pair[1]
        end
    end

    return playerPairs, soloPlayer
end

function self:ServerAwake()
    TrackPlayers(server)

    TeleportRequest:Connect(TeleportPlayerServer)

    Timer.After(2,function()
        local playerPairs, soloPlayer = SeperatePlayersIntoRandomPairs()
        for i, pair in ipairs(playerPairs) do
            local player1 = pair[1]
            local player2 = pair[2]
            print("Pair", i, player1.name, player2.name)
        end
        if soloPlayer then print("Solo", soloPlayer.name) end
    end)
    
end

function TeleportPlayerServer(player, destination)
    local character = player.character
    if character then
        character.transform.position = destination
        TeleportResponse:FireAllClients(player, destination)
    end
end
