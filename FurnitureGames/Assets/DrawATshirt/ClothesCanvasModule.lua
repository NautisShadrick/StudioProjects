--!Type(Module)

--!SerializeField
local pixelArtCanvas : PixelArtCanvas = nil

createShirtRequest = Event.new("CreateShirtRequest")

players = {}
local playercount = 0
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            myShirt = StringValue.new("myShirt"..player.user.id, ""),
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
    TrackPlayers(client, function(playerInfo)
        local myShirtQuad = playerInfo.player.character.transform:GetChild(2).transform:GetChild(0).gameObject
        local myShirtMat = myShirtQuad:GetComponent(MeshRenderer).material
        playerInfo.myShirt.Changed:Connect(function(serializedTexture)
            print(serializedTexture)
            print("Updating shirt texture for player: " .. playerInfo.player.name)
            -- Update My shirtDecoreItem
            local texture = pixelArtCanvas.DeserializePixelData(serializedTexture, true)
            print(typeof(texture))
            myShirtMat.mainTexture = texture
        end)
    end)
end

function self:ServerAwake()
    TrackPlayers(server, function(playerInfo)end)
    createShirtRequest:Connect(function(player, shirtData)
        print("Received shirt creation request from player: " .. player.name)
        -- Here you would add the logic to create and assign the shirt to the player
        players[player].myShirt.value = shirtData
    end)
end