--!Type(Module)

local TeleportRequest = Event.new("TELEPORT_REQUEST")
local TeleportResponse = Event.new("TELEPORT_RESPONSE")

function TeleortPlayer(player, destination, cb)
    TeleportRequest:FireServer(player, destination)
    
    TeleportResponse:Connect(function(targetPlayer, destination)
        targetPlayer.character:Teleport(destination)
        cb()
    end)
end

function self:ServerAwake()
    TeleportRequest:Connect(function(player, targetPlayer, destination)
        targetPlayer.character.transform.position = destination
        TeleportResponse:FireAllClients(targetPlayer, destination)
    end)
end