--!Type(ClientAndServer)

--!SerializeField
local Seats : {Anchor} = {}

local addtoListReq = Event.new("AddToListRequest")
local removeFromListReq = Event.new("RemoveFromListRequest")
myPlayers = TableValue.new("My Players", {})

function GetPlayercount()
    local count = 0
    for _, _ in pairs(myPlayers.value) do
        count = count + 1
    end
    return count
end

function self:ClientStart()

    -- Register Entered Events for all seats
    for _, seat in ipairs(Seats) do
        seat.Entered:Connect(function(anchor, character)
            print("Player entered seat at table: " .. character.player.name .. " at anchor " .. tostring(client.localPlayer.name))
            local player = character.player
            if player == client.localPlayer then
                print("Requesting to be added to table list")
                addtoListReq:FireServer()
            end
        end)
        seat.Exited:Connect(function(anchor, character)
            -- When a player leaves the table remove them from the list
            local player = character.player
            if player == client.localPlayer then
                removeFromListReq:FireServer()
            end
        end)
    end

    -- only display the chat messages of the players at the table to the players at the table
    Chat.TextMessageReceivedHandler:Connect(function(channel, player, message, originalMessage)

        -- if the sender is at the table only display the message if the local player is also at the table
        if not myPlayers.value[client.localPlayer.user.id] and myPlayers.value[player.user.id] then
            Chat:DisplayTextMessage(channel, player, "***", originalMessage)
            return
        end
        Chat:DisplayTextMessage(channel, player, message, originalMessage)
    end)
end

function self:ServerStart()
    addtoListReq:Connect(function(player)
        print("Adding player to table list: " .. player.name)
        local myplayersTable = myPlayers.value
        myplayersTable[player.user.id] = player

        myPlayers.value = myplayersTable
    end)

    removeFromListReq:Connect(function(player)
        local myplayersTable = myPlayers.value
        myplayersTable[player.user.id] = nil

        myPlayers.value = myplayersTable
    end)

    server.PlayerDisconnected:Connect(function(player)
        local myplayersTable = myPlayers.value
        myplayersTable[player.user.id] = nil

        myPlayers.value = myplayersTable
    end)
end