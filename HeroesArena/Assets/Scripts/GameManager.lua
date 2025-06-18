--!Type(Module)

--!SerializeField
local playerPlaces : {Transform} = {}
--!SerializeField
local bossAttackPlace : Transform = nil

--!SerializeField
local joinTime : number = 30
--!SerializeField
local turnTime : number = 15


gameTime = NumberValue.new("GameTime", 0)
gameState = NumberValue.new("GameState", 1)
-- 1 = lobby/canjoin, 2 = starting/canjoin, 3 = playing
playerQueue = TableValue.new("PlayerQueue", {})
-- Player Turn Order
local bossTurnCounter = NumberValue.new("BossTurnCounter", 3)
-- How many turns left until the boss attacks

local currentTurn = NumberValue.new("CurrentTurn", 0)
-- Time left on the current turn

local playerJoinRequest = Event.new("playerJoinRequest")
local playerJoinResponse = Event.new("playerJoinResponse")

local playerActionRequest = Event.new("playerActionRequest")
local playerActionResponse = Event.new("playerActionResponse")

local bossActionEvent = Event.new("bossActionEvent")
local bossHealth = NumberValue.new("BossHealth", 700)

local ReEnableEvent = Event.new("RE_ENABLE")
local moveRequest = Event.new("MOVE_REQUEST")
local moveEvent = Event.new("MOVE_EVENT")

local characterController = require("PlayerCharacterController")
local playerTracker = require("PlayerTracker")


------------ Utility Functions ------------
function GetPlace(queue, player)
    queue = queue or playerQueue.value
    player = player or client.localPlayer
    for i, person in ipairs(queue) do
        if person == player then
            return i
        end
    end
    return 0
end

function MovePlayer(posTransform, posRot)
    moveRequest:FireServer(posTransform.position, posRot)
end
-------------- CLIENT -------------


function HandleGameStateChange(newState)
    if newState == 1 then
        -- Lobby state, can join
        print("Game is in lobby state, players can join.")
    elseif newState == 2 then
        -- Starting state, can join but game is about to start
        print("Game is starting soon, players can still join.")
    elseif newState == 3 then
        -- Playing state, no more joins allowed
        print("Game is now playing, no more players can join.")
    end
end

function PlayerJoinedHandler()
    playerTracker.TeleportPlayer(Vector3.new(0, 0, 0)) -- Teleport the player to a default position
    Timer.After(0.5, function()
        WalkToMyPlace()
    end)
end

function WalkToMyPlace()
    local _myPlace = GetPlace(playerQueue.value, client.localPlayer)
    print("My place in queue: " .. tostring(_myPlace))
    local _pos = playerPlaces[_myPlace]
    if _pos == nil then
        print("No position found for player in queue.", client.localPlayer.name)
        return
    end
    MovePlayer(_pos)
end

function HandleTurnChange(newTurn)
    print("Turn changedrom to " .. tostring(newTurn))
    print("Current Turn: " .. tostring(currentTurn.value))
    print("My place in queue: " .. tostring(GetPlace(playerQueue.value, client.localPlayer)))

    local _ismyTurn = newTurn == GetPlace(playerQueue.value, client.localPlayer)
    if _ismyTurn then
        print("It's my turn!")
        --MovePlayer(bossAttackPlace, bossAttackPlace.rotation)
        --Timer.After(3, function()
        --    WalkToMyPlace()
        --end)
    end
end

function self:ClientStart()
    gameState.Changed:Connect(HandleGameStateChange)

    playerJoinResponse:Connect(PlayerJoinedHandler)

    currentTurn.Changed:Connect(HandleTurnChange)

    moveEvent:Connect(function(player, pos, rot)
        player.character:MoveTo(pos, 1, function()
            if not rot then
                local _place = GetPlace(playerQueue.value, player)
                if _place == nil or playerPlaces[_place] == nil then return end
                player.character.transform.rotation = playerPlaces[_place].rotation
            else
                player.character.transform.rotation = rot
            end
        end)
    end)

    ReEnableEvent:Connect(function(targetPlayer)
        print(targetPlayer.name .. " is re-enabled")
        characterController.options.enabled = true
    end)

    client.PlayerDisconnected:Connect(function(player)
        -- User Disconnected, handle cleanup, walk everyone to their places
        WalkToMyPlace()
    end)
end

function JoinGameClient()
    playerJoinRequest:FireServer()
end


-------------- SERVER -------------

function HandlePlayerJoined(player)
    if player == nil then
        print("Player is nil in HandlePlayerJoined")
        return
    end

    -- Check if the game is in a state that allows joining
    if gameState.value == 3 then
        -- Game is already playing, no more joins allowed
        print("Game is already playing, cannot join.")
        return
    end

    -- Reference the player queue, add the player to it, and then update the queue
    local _tempQueue = playerQueue.value
    table.insert(_tempQueue, player)
    playerQueue.value = _tempQueue

    -- If this is the first player, set the game state to starting
    if #_tempQueue == 1 then
        StartJoinRound()
    end

    playerJoinResponse:FireClient(player)

end

function StartGame()
    if gameState.value == 2 then
        -- If still in starting state after 15 seconds, move to playing state
        gameState.value = 3
        print("Join round ended, game state set to playing.")
        currentTurn.value = 1 -- Start with the first player in the queue
        StartTurnForNextPlayer()
    end
end

function StartJoinRound()
    gameState.value = 2
    print("First player joined, game state set to starting.")
    gameTime.value = joinTime
    --Start the Join Round timer
    Timer.After(joinTime, function()
        StartGame()
    end)
    
end

function StartTurnForNextPlayer()
    local turn = currentTurn.value
    print("Starting turn for player: " .. playerQueue.value[turn].name)
    print("Player Health: " .. playerTracker.GetPlayerHealth(playerQueue.value[turn]))
    print("Boss Health: " .. bossHealth.value)

    gameTime.value = turnTime

    Timer.After(turnTime, function()
        -- End the turn after 15 seconds
        -- Start the next player's turn
        currentTurn.value = (currentTurn.value % #playerQueue.value) + 1
        StartTurnForNextPlayer()
    end)
end

function self:ServerStart()

    Timer.Every(1, function()
        if gameTime.value > 0 then gameTime.value = gameTime.value - 1 end
    end)

    playerJoinRequest:Connect(HandlePlayerJoined)

    moveRequest:Connect(function(player, pos, rot)
        player.character.transform.position = pos
        player.character.transform.rotation = rot or player.character.transform.rotation
        moveEvent:FireAllClients(player, pos, rot)
    end)

    server.PlayerDisconnected:Connect(function(player)
        -- User Disconnected, handle cleanup, walk everyone to their places
        local _tempQueue = playerQueue.value
        for i, p in ipairs(_tempQueue) do
            if p == player then
                table.remove(_tempQueue, i)
                break
            end
        end
        playerQueue.value = _tempQueue

        -- If the queue is empty, reset the game state to lobby
        if #_tempQueue == 0 then
            gameState.value = 1
            print("All players left, game state reset to lobby.")
        end
    end)
end