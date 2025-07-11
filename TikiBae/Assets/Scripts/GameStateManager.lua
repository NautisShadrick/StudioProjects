--!Type(Module)

--!SerializeField
local boatPrefab : GameObject = nil
--!SerializeField
local stateDuration : number = 60
--!SerializeField
local mainCamera : Camera = nil

local GetpairsResponse = Event.new("GetpairsResponse")
makeChoiceRequest = Event.new("makeChoiceRequest")

playerMatchedEvent = Event.new("playerMatchedEvent")
playerMismatchedEvent = Event.new("playerMismatchedEvent")

--[[
0 -> Island, Group Mingling
1 -> Paired Boat Rides
--]]
GameState = NumberValue.new("gameState", 0)
local pairInfo = TableValue.new("pairInfo", {})
local currentTimeRemaining = NumberValue.new("currentTimeRemaining", 0)

uiManager = require("UIManager")
playerTracker = require("PlayerTracker")
characterController = require("PlayerCharacterController")
local camScript = nil

local myCurrentPair = nil

local boatTable = {}

--- Utility Functions ---

-- Function to convert seconds to min:seconds 00:00
function SecondsToMinSec(seconds)
    local min = math.floor(seconds / 60)
    local sec = seconds % 60
    return string.format("%02d:%02d", min, sec)
end

---- CLIENT ----

function AddToBoats(player_pairs, soloPlayer)
    for i, pair in ipairs(player_pairs) do

        -- Get players
        local player1 = pair[1]
        local player2 = pair[2]

        -- Create Boat
        local boatObj = GameObject.Instantiate(boatPrefab)
        table.insert(boatTable, boatObj)
        boatObj.transform.position = Vector3.new(-7.5, 0, 0)

        -- Get Boat Controller and Points
        local boatController = boatObj:GetComponent(BoatController)
        local pointA, pointB = boatController.GetPoints()

        -- Disable character controllers for players in boats
        if player1 == client.localPlayer or player2 == client.localPlayer then 
            characterController.options.enabled = false 
        end

        -- Disable NavMeshAgent first
        player1.character.gameObject:GetComponent(NavMeshAgent).enabled = false
        player2.character.gameObject:GetComponent(NavMeshAgent).enabled = false

        -- Set Players to Boat parent first
        player1.character.gameObject.transform.parent = pointA
        player2.character.gameObject.transform.parent = pointB

        -- Set Player local Positions after parenting
        player1.character.gameObject.transform.localPosition = Vector3.new(0, 0, 0)
        player2.character.gameObject.transform.localPosition = Vector3.new(0, 0, 0)

        -- Set Player Rotations
        player1.character.gameObject.transform.localRotation = Quaternion.Euler(0, 0, 0)
        player2.character.gameObject.transform.localRotation = Quaternion.Euler(0, 0, 0)

        --Offset the camera
        camScript.UpdateOffsets(Vector3.new(0, -1, 0))

        --Lower the chat bubbles
        player1.character.transform:GetChild(0).transform.localPosition = Vector3.new(0, 2, 0)
        player2.character.transform:GetChild(0).transform.localPosition = Vector3.new(0, 2, 0)

        if player1 == client.localPlayer then
            myCurrentPair = player2
        elseif player2 == client.localPlayer then
            myCurrentPair = player1
        end

        player1.character:PlayEmote("sit-idle-cute", true)
        player2.character:PlayEmote("sit-idle-cute", true)

    end
end

function RemoveFromBoats()
    for player, playerInfo in playerTracker.players do
        local char = player.character
        char.gameObject.transform.parent = nil
        char.gameObject:GetComponent(NavMeshAgent).enabled = true
        char.transform:GetChild(0).transform.localPosition = Vector3.new(0, 3.25, 0)
    end
    characterController.options.enabled = true
    playerTracker.TeleportLocalPlayerRequest(Vector3.new(math.random(-2,2),0,math.random(-2,2)))
    myCurrentPair = nil
    camScript.UpdateOffsets(Vector3.new(0, 0, 0))


    for i, boat in ipairs(boatTable) do
        GameObject.Destroy(boat)
    end
end

function SyncToState(newState)
    print("GameState", newState)
    if newState == 1 then
        local pairInfo = pairInfo.value
        AddToBoats(pairInfo.player_pairs, pairInfo.solo_player)
    elseif newState == 0 then
        RemoveFromBoats()
        uiManager.ToggleSelectionUI(false)
    end
end

function self:ClientStart()

    camScript = mainCamera.gameObject:GetComponent(ThirdPersonCameraOverride)

    GameState.Changed:Connect(SyncToState)

    Chat.TextMessageReceivedHandler:Connect(function(channelInfo, player, message)
        info = channelInfo
        local canSeeMessage = (player == myCurrentPair or player == client.localPlayer) or GameState.value == 0
        local messageToDisplay = canSeeMessage and message or "..."
        Chat:DisplayTextMessage(channelInfo, player, messageToDisplay)
    end)

    currentTimeRemaining.Changed:Connect(function(timeRemaining)
        uiManager.timerUI.SetTitle(SecondsToMinSec(timeRemaining))

        if myCurrentPair then
            if timeRemaining == 5 then
                -- Display Choice UI
                uiManager.ToggleSelectionUI(true)
            end
        end

    end)

    if GameState.value == 1 then    
        SyncToState(1)
    end
end



---- SERVER ----

local serverStateTimer = nil

local playerPairMatesByPlayer = {}
local choicesByPlayer = {}

function self:ServerAwake()
    currentTimeRemaining.value = stateDuration
    serverStateTimer = Timer.Every(stateDuration,
    function()
        if GameState.value == 0 then
            StartBoatRide()
        else
            EndBoatRide()
        end
    end)

    Timer.Every(1, function()
        currentTimeRemaining.value = currentTimeRemaining.value - 1
        if currentTimeRemaining.value <= 0 then currentTimeRemaining.value = 0 end
    end)

    makeChoiceRequest:Connect(function(player, choice)
        choicesByPlayer[player] = choice
    end)

    server.PlayerDisconnected:Connect(function(player)
        playerPairMatesByPlayer[player] = nil
        choicesByPlayer[player] = nil

    end)
end

function StartBoatRide()

    playerPairMatesByPlayer = {}
    choicesByPlayer = {}

    local player_pairs, solo_player = playerTracker.SeparatePlayersIntoRandomPairs()
    local newPairInfo = {
        player_pairs = player_pairs,
        solo_player = solo_player
    }
    pairInfo.value = newPairInfo
    GameState.value = 1
    currentTimeRemaining.value = stateDuration

    -- Set Each players pair mate
    for i, pair in ipairs(player_pairs) do
        playerPairMatesByPlayer[pair[1]] = pair[2]
        playerPairMatesByPlayer[pair[2]] = pair[1]
    end
end

function EndBoatRide()
    local newPairInfo = {
        player_pairs = {},
        solo_player = nil
    }
    pairInfo.value = newPairInfo
    GameState.value = 0
    currentTimeRemaining.value = stateDuration

    -- Get Choice Matches
    local choiceMatches = {}
    local choiceMismatches = {}
    for player, choice in choicesByPlayer do
        local pairMate = playerPairMatesByPlayer[player]
        if choicesByPlayer[pairMate] == choice and choice == 1 then
            choiceMatches[player] = pairMate
        else
            choiceMismatches[player] = pairMate
        end
    end

    for player, mate in choiceMatches do
        print(player.name, "and", mate.name, "matched!")
        playerMatchedEvent:FireClient(player, mate)

        local playersMatches = playerTracker.players[player].matches.value

        local matchCount = 0
        if playersMatches[mate.user.id] then
            matchCount = playersMatches[mate.user.id][2] or 0
        end
        playersMatches[mate.user.id] = {mate.name, matchCount + 1}

        playerTracker.players[player].matches.value = playersMatches

        Storage.SetPlayerValue(player, "matches", playersMatches)

    end

    for player, mate in choiceMismatches do
        --print(player.name, "and", mate.name, "did not match!")
        playerMismatchedEvent:FireClient(player, mate)
    end

    -- Clear Pair Mates
    playerPairMatesByPlayer = {}
end