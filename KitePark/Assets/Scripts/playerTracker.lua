--!Type(Module)

--!SerializeField
local kitePrefabs : {GameObject} = {}
--!SerializeField
local duckKitePrefab : GameObject = nil
--!SerializeField
local dragonKitePrefab : GameObject = nil
--!SerializeField
local buildKitePrefab : GameObject = nil

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
setMyBuildRequest = Event.new("SetMyBuildRequest")

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
            myBuild = TableValue.new("MyBuild_" .. player.user.id, {}),
            myKite = nil,
            myKiteConstructor = nil,
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
        local _playerInfo = players[player]
        if _playerInfo and _playerInfo.myKite then
            GameObject.Destroy(_playerInfo.myKite.gameObject)
        end
        players[player] = nil
    end)
end

------------- CLIENT -------------

function UpdateKite(player, newKite, oldKite)
    playerinfo = players[player]
    local character = player.character

    if playerinfo.myKite then
        GameObject.Destroy(playerinfo.myKite.gameObject)
        playerinfo.myKite = nil
    end

    if playerinfo.myKiteConstructor then
        playerinfo.myKiteConstructor = nil
    end

    if not buildKitePrefab then
        print("BuildKite prefab not assigned!")
        return
    end

    local kiteInstance = GameObject.Instantiate(buildKitePrefab)
    kiteInstance.name = "Kite_" .. player.name

    playerinfo.myKite = kiteInstance:GetComponent(KiteController)
    if playerinfo.myKite then
        playerinfo.myKite.SetPlayer(player)
    end

    playerinfo.myKiteConstructor = kiteInstance:GetComponent(KiteConstructor)
    if playerinfo.myKiteConstructor then
        playerinfo.myKiteConstructor.SetPlayer(player)
    end

    print("Spawned BuildKite for " .. player.name)
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
        playerInfo.playerKite.value = 1
    end)

    ChangeLengthRequest:Connect(function(player, newLength)
        local _playerInfo = players[player]
        if _playerInfo and _playerInfo.lineLength then
            local _clampedLength = math.max(MIN_LINE_LENGTH, math.min(MAX_LINE_LENGTH, newLength))
            _playerInfo.lineLength.value = _clampedLength
        end
    end)

    setMyBuildRequest:Connect(function(player, buildData)
        local _playerInfo = players[player]
        if _playerInfo and _playerInfo.myBuild then
            _playerInfo.myBuild.value = buildData
            print("Updated build for " .. player.name .. " with " .. #buildData .. " parts")
        end
    end)
end

function SetScore(player, score)
	players[player].playerScore.value = score
end
