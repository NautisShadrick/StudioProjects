--!Type(Module)

completeQuestRequest = Event.new("CompleteQuestRequest")


players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerQuestSate = NumberValue.new("PlayerQuestState" .. player.user.id, 0),
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


function OnCharacterInstantiate(playerinfo)
end

function HandleStateChange(player, character)
end

function self:ClientAwake()
    TrackPlayers(client, OnCharacterInstantiate)
end

function completeQuestClient(questId)
    completeQuestRequest:FireServer(questId)
end

function ReadCurrentQuestState()
    local player = client.localPlayer
    local playerInfo = players[player]
    if not playerInfo then print("Player info not found for local player") return 0 end
    print("Player: ", player.name, " Current Quest State: ", playerInfo.playerQuestSate.value)
end

------------- SERVER ------------- 
function self:ServerAwake()
    TrackPlayers(server, function(playerInfo)
        local player = playerInfo.player
        FetchQuestState(player)
    end)

    completeQuestRequest:Connect(function(player, questId)
        local playerInfo = players[player]
        if not playerInfo then print("Player info not found for player: " .. tostring(player)) return end
        playerInfo.playerQuestSate.value = questId
    end)
end

function StoreQuestState(player)
    Storage.SetPlayerValue(player, "QuestState", players[player].playerQuestSate.value)
end
function FetchQuestState(player)
    print("Fetching quest state for player: " .. tostring(player))
    print(typeof(players[player]))
    Storage.GetPlayerValue(player, "QuestState", function(value)
        if value then
            print("Fetched quest state for player: " .. tostring(player) .. " Value: " .. tostring(value))
            players[player].playerQuestSate.value = value
        elseif not value then
            print("No quest state found for player: " .. tostring(player) .. ", initializing to 0")
            players[player].playerQuestSate.value = 5
            StoreQuestState(player)
        end
    end)
end