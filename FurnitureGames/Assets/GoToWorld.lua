--!Type(ClientAndServer)

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------

function self:ClientStart()
    Chat.TextMessageReceivedHandler:Connect(function(channel, player, message)
        if player.isLocal and message:sub(1, 3) == "/go" then
            local _worldId, _instanceId = message:match("^/go%s+(%S+)%s+(%S+)")
            if _worldId and _instanceId then
                UI:ExecuteDeepLink("https://high.rs/world?id=" .. _worldId .. "&instance=" .. _instanceId)
                print("https://high.rs/world?id=" .. _worldId .. "&instance=" .. _instanceId)
            end
        else
            Chat:DisplayTextMessage(channel, player, message)
        end
    end)
end
