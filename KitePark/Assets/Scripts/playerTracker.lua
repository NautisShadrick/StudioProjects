--!Type(Module)

--!SerializeField
local kitePrefabs : {GameObject} = {}

--------------------------------
------     CONSTANTS      ------
--------------------------------
local DEFAULT_LINE_LENGTH: number = 10
local MIN_LINE_LENGTH: number = 5
local MAX_LINE_LENGTH: number = 25

--------------------------------
------  NETWORKED EVENTS  ------
--------------------------------
ChangeLengthRequest = Event.new("ChangeLengthRequest")

players = {}
local playercount = 0

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function GetMinLineLength(): number
    return MIN_LINE_LENGTH
end

function GetMaxLineLength(): number
    return MAX_LINE_LENGTH
end

function GetDefaultLineLength(): number
    return DEFAULT_LINE_LENGTH
end

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerKite = NumberValue.new("playerKite" .. player.user.id, 1),
            lineLength = NumberValue.new("LineLength_" .. player.user.id, DEFAULT_LINE_LENGTH),
            myKite = nil,
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

function UpdateKite(player, newKite, oldKite)
    playerinfo = players[player]
    local character = player.character
    -- Update UI or other client-side elements based on player kite change
    if playerinfo.myKite then
        GameObject.Destroy(playerinfo.myKite.gameObject)
        playerinfo.myKite = nil
    end
    local kiteIndex = playerinfo.playerKite.value
    print("Player " .. player.name .. " changed kite to index: " .. kiteIndex)
    -- Spawn NewKite for Player
    print(typeof(kitePrefabs[kiteIndex]))
    if kitePrefabs[kiteIndex] then
        local kiteInstance = GameObject.Instantiate(kitePrefabs[kiteIndex])
        kiteInstance.name = "Kite_" .. player.name
        playerinfo.myKite = kiteInstance:GetComponent(KiteController)
        playerinfo.myKite.SetPlayer(player)
    end
end

function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        UpdateKite(player, playerinfo.playerKite.value, nil)
        playerinfo.playerKite.Changed:Connect(function(newKite, oldKite)
            UpdateKite(player, newKite, oldKite)
        end)

        -- Subscribe to line length changes
        playerinfo.lineLength.Changed:Connect(function(newVal, oldVal)
            print(player.name .. " line length changed to: " .. newVal)
            if playerinfo.myKite then
                playerinfo.myKite.SetLineLength(newVal)
            end
        end)
    end
    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------

function self:ServerAwake()
    TrackPlayers(server, function(playerInfo)
        local player = playerInfo.player
    end)

    ChangeLengthRequest:Connect(function(player, newLength)
        print("Received line length change request from " .. player.name .. " to length: " .. newLength)
        local _playerInfo = players[player]
        if _playerInfo and _playerInfo.lineLength then
            local _clampedLength = math.max(MIN_LINE_LENGTH, math.min(MAX_LINE_LENGTH, newLength))
            _playerInfo.lineLength.value = _clampedLength
        end
    end)
end

function SetScore(player, score)
	players[player].playerScore.value = score
end
