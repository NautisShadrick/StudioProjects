--!Type(Module)

--!SerializeField
local Emojis : {Texture} = {}

changeEmojiRequest = Event.new("ChangeEmojiRequest")

players = {}
local playercount = 0
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            myEmoji = NumberValue.new("myEmoji" .. player.user.id, 0)
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


function UpdatePlayerEmoji(player)
    local playerEmoji = players[player].myEmoji.value
    local char = player.character
    if (char == nil) then print("No character for player " .. player.name) return end
    local playerEmoteIndicator = char.transform:GetChild(1)
    local emojiTexture = Emojis[playerEmoji]
    if playerEmoji == 0 then
        playerEmoteIndicator.gameObject:SetActive(false)
    else
        playerEmoteIndicator.gameObject:SetActive(true)
        playerEmoteIndicator.gameObject:GetComponent(MeshRenderer).material.mainTexture = emojiTexture
    end
end

function self:ClientAwake(playerinfo)
    TrackPlayers(client, function(playerinfo)
        local player = playerinfo.player

        UpdatePlayerEmoji(player)
        playerinfo.myEmoji.Changed:Connect(function()
            UpdatePlayerEmoji(player)
        end)
    end)
end

function self:ServerAwake()
    TrackPlayers(server, function(playerinfo)
        local player = playerinfo.player
    end)

    changeEmojiRequest:Connect(function(player, newEmojiIndex)
        if players[player] then
            players[player].myEmoji.value = newEmojiIndex
        end
    end)
end