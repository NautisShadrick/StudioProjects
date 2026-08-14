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
    local playerinfo = players[player]
    local character = player.character

    if playerinfo.myKite then
        GameObject.Destroy(playerinfo.myKite.gameObject)
        playerinfo.myKite = nil
    end

    if playerinfo.myKiteConstructor then
        playerinfo.myKiteConstructor = nil
    end

    -- Determine which prefab to use
    local kitePrefab = nil
    local playerName = string.lower(player.name)
    local hasBuild = playerinfo.myBuild.value and next(playerinfo.myBuild.value) ~= nil

    if hasBuild then
        -- Player has a custom build, use buildKitePrefab
        kitePrefab = buildKitePrefab
        print("Using custom build kite for " .. player.name)
    elseif playerName == "nautisshadrick" then
        -- Special dragon kite for nautisshadrick
        kitePrefab = dragonKitePrefab
        print("Using dragon kite for " .. player.name)
    elseif playerName == "sourpatchsid" then
        -- Special duck kite for sourpatchsid
        kitePrefab = duckKitePrefab
        print("Using duck kite for " .. player.name)
    elseif #kitePrefabs > 0 then
        -- spawn the kit per playerKite 
        local playerKite = players[player].playerKite.value
        local index = ((playerKite - 1) % #kitePrefabs) + 1
        kitePrefab = kitePrefabs[index]
        print("Using preset kite " .. index .. " for " .. player.name)
    else
        -- Fallback to buildKitePrefab
        kitePrefab = buildKitePrefab
        print("Fallback to build kite for " .. player.name)
    end

    if not kitePrefab then
        print("No kite prefab available!")
        return
    end

    local kiteInstance = GameObject.Instantiate(kitePrefab)
    kiteInstance.name = "Kite_" .. player.name

    playerinfo.myKite = kiteInstance:GetComponent(KiteController)
    if playerinfo.myKite then
        playerinfo.myKite.SetPlayer(player)
    end

    -- Only set KiteConstructor if using buildKitePrefab
    if hasBuild then
        playerinfo.myKiteConstructor = kiteInstance:GetComponent(KiteConstructor)
        if playerinfo.myKiteConstructor then
            playerinfo.myKiteConstructor.SetPlayer(player)
        end
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
            if playerinfo.myKite then
                playerinfo.myKite.SetLineLength(newVal)
            end
        end)

        -- Subscribe to build changes - switch to custom kite when player designs one
        playerinfo.myBuild.Changed:Connect(function(newBuild, oldBuild)
            if next(newBuild) ~= nil then
                UpdateKite(player, playerinfo.playerKite.value, nil)
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
        -- Pick a random Kite for the player
        if #kitePrefabs > 0 then
            local randomKiteIndex = math.random(1, #kitePrefabs)
            playerInfo.playerKite.value = randomKiteIndex
        end
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
