--!Type(Module)

goHomeRequest = Event.new("GoHomeRequest")
leaveHomeRequest = Event.new("LeaveHomeRequest")

function self:ServerStart()

    goHomeRequest:Connect(function(player)
        print("Moving player to scene 1")
        server.MovePlayerToScene(player, server.LoadSceneAdditive(1))
    end)

    leaveHomeRequest:Connect(function(player)
        server.MovePlayerToScene(player, server.LoadSceneAdditive(0))
    end)

end