--!Type(Module)

local TeleportRequest = Event.new("TELEPORT_REQUEST")
local TeleportResponse = Event.new("TELEPORT_RESPONSE")

function TeleortPlayer(player, destination, cb)
    TeleportRequest:FireServer(player, destination)
    
    TeleportResponse:Connect(function(targetPlayer, destination)
        print("Teleporting player")
        targetPlayer.character:Teleport(destination)
        cb()
    end)
end

function self:ClientAwake()
    TeleportResponse:Connect(function(targetPlayer, destination)
        if targetPlayer == client.localPlayer then return end
        print("Teleporting player")
        targetPlayer.character:Teleport(destination)
    end)
end

function self:ServerAwake()
    TeleportRequest:Connect(function(player, targetPlayer, destination)
        targetPlayer.character.transform.position = destination
        TeleportResponse:FireAllClients(targetPlayer, destination)
    end)
end