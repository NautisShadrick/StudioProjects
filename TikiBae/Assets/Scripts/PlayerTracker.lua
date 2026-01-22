--!Type(Module)

local TeleportRequest = Event.new("TeleportRequest")
local TeleportResponse = Event.new("TeleportResponse")

teleportToAnchorRequest = Event.new("teleportToAnchorRequest")
teleportToAnchorResponse = Event.new("teleportToAnchorResponse")

inviteRequest = Event.new("inviteRequest")
inviteEvent = Event.new("inviteEvent")
acceptInviteRequest = Event.new("acceptInviteRequest")

local gameStateManager = require("GameStateManager")

--local uiManager = require("UIManager")
players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    game.PlayerConnected:Connect(function(player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            matches = TableValue.new("matches"..player.user.id, {}, player),
            lastInviteID = StringValue.new("lastInviteID"..player.user.id, "", player),
            currentPartnerID = StringValue.new("currentPartnerID"..player.user.id, "", player),
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

        if game == server then
            Storage.GetPlayerValue(player, "matches", function(matches)
                print("Loaded matches for", player.name)
                playersMatches = matches or {}
                players[player].matches.value = playersMatches
            end)
        end
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

    teleportToAnchorResponse:Connect(function(player, anchor)
        local character = player.character
        if not character then
            print("No character to teleport for player:", player.name)
            return
        end
        if not anchor then
            print("No anchor provided for teleportation for player:", player.name)
            return
        end
        if character and anchor then
            character:TeleportToAnchor(anchor)
        end
    end)
end

function TeleportLocalPlayerRequest(destination)
    TeleportRequest:FireServer(destination)
end

function TeleportToAnchorRequest(anchor)
    print(typeof(anchor))
    teleportToAnchorRequest:FireServer(anchor.gameObject)
end

------------- SERVER -------------

-- Fisher-Yates shuffle algorithm
function ShuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

function self:ServerAwake()
    TrackPlayers(server)

    TeleportRequest:Connect(TeleportPlayerServer)
    teleportToAnchorRequest:Connect(function(player, anchor)
        print(typeof(player), typeof(anchor))
        teleportToAnchorResponse:FireAllClients(player, anchor)
    end)


    inviteRequest:Connect(function(player, recipientPlayer)
        local inviteID = recipientPlayer.user.id
        players[player].lastInviteID.value = inviteID
        inviteEvent:FireClient(recipientPlayer, player)
    end)


    acceptInviteRequest:Connect(function(player, senderPlayer)
        print(player.name .. " accepted invite from " .. senderPlayer.name)
        gameStateManager.StartBoatRideForPair(player, senderPlayer)
    end)
end

function TeleportPlayerServer(player, destination)
    local character = player.character
    if character then
        character.transform.position = destination
        TeleportResponse:FireAllClients(player, destination)
    end
end
