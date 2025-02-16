--!Type(Module)



function self:ServerStart()
    scene.PlayerJoined:Connect(function(scene, player)
        Timer.After(1, function() server.MovePlayerToScene(player, server.LoadSceneAdditive(1)) end)
    end)
end