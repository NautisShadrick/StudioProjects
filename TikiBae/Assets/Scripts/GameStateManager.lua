--!Type(Module)

--!SerializeField
local boatPrefab : GameObject = nil
--!SerializeField
local stateDuration : number = 15

local GetpairsResponse = Event.new("GetpairsResponse")
makeChoiceRequest = Event.new("makeChoiceRequest")

--[[
0 -> Island, Group Mingling
1 -> Paired Boat Rides
--]]
local GameState = NumberValue.new("gameState", 0)
local pairInfo = TableValue.new("pairInfo", {})
local currentTimeRemaining = NumberValue.new("currentTimeRemaining", 0)

uiManager = require("UIManager")
playerTracker = require("PlayerTracker")
characterController = require("PlayerCharacterController")

local mainCamera = nil
local camScript = nil

local myCurrentPair = nil

local boatTable = {}

---- CLIENT ----

function AddToBoats(player_pairs, soloPlayer)
    for i, pair in ipairs(player_pairs) do
        local player1 = pair[1]
        local player2 = pair[2]
        local boatObj = GameObject.Instantiate(boatPrefab)
        table.insert(boatTable, boatObj)
        boatObj.transform.position = Vector3.new(-7.5, 0, 0)

        if soloPlayer ~= client.localPlayer then characterController.options.enabled = false end

        player1.character.gameObject:GetComponent(NavMeshAgent).enabled = false
        player2.character.gameObject:GetComponent(NavMeshAgent).enabled = false

        player1.character.gameObject.transform.parent = boatObj.transform
        player2.character.gameObject.transform.parent = boatObj.transform

        player1.character.gameObject.transform.localPosition = Vector3.new(0, 0, 0)
        player2.character.gameObject.transform.localPosition = Vector3.new(0, 0, 0)

        print(player1.character.gameObject.transform.localPosition.x, player1.character.gameObject.transform.localPosition.y, player1.character.gameObject.transform.localPosition.z)

        if player1 == client.localPlayer then
            myCurrentPair = player2
        elseif player2 == client.localPlayer then
            myCurrentPair = player1
        end

    end
end

function RemoveFromBoats()
    for player, playerInfo in playerTracker.players do
        local char = player.character
        char.gameObject.transform.parent = nil
        char.gameObject:GetComponent(NavMeshAgent).enabled = true
    end
    characterController.options.enabled = true
    playerTracker.TeleportLocalPlayerRequest(Vector3.new(math.random(-2,2),0,math.random(-2,2)))
    myCurrentPair = nil

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
    GameState.Changed:Connect(SyncToState)

    Chat.TextMessageReceivedHandler:Connect(function(channelInfo, player, message)
        info = channelInfo
        local canSeeMessage = (player == myCurrentPair or player == client.localPlayer) or GameState.value == 0
        local messageToDisplay = canSeeMessage and message or "..."
        Chat:DisplayTextMessage(channelInfo, player, messageToDisplay)
    end)

    currentTimeRemaining.Changed:Connect(function(timeRemaining)
        uiManager.timerUI.SetTitle(tostring(timeRemaining))

        if myCurrentPair then
            if timeRemaining == 10 then
                -- Display Choice UI
                uiManager.ToggleSelectionUI(true)
            end
        end

    end)

    mainCamera = Camera.main
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

    local player_pairs, solo_player = playerTracker.SeperatePlayersIntoRandomPairs()
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
    for player, choice in choicesByPlayer do
        local pairMate = playerPairMatesByPlayer[player]
        if choicesByPlayer[pairMate] == choice and choice == 1 then
            choiceMatches[player] = pairMate
        end
    end

    for player, mate in choiceMatches do
        print(player.name, "and", mate.name, "matched!")
    end

    -- Clear Pair Mates
    playerPairMatesByPlayer = {}
end