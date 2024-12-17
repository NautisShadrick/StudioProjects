--!Type(Module)

--!SerializeField
local camerScript: GameObject = nil
--!SerializeField
local LinePlaces: {Transform} = {}

--!Header("Fart")
--!SerializeField
local fartCost: number = 150
--!SerializeField
local fartParticle: GameObject = nil
--!SerializeField
local fartSounds: {AudioShader} = {}

--!Header("FartBomb")
--!SerializeField
local fartBombCost: number = 1000
--!SerializeField
local fartBombParticle: GameObject = nil
--!SerializeField
local fartBombSounds: {AudioShader} = {}

--!Header("ToiletParty")
--!SerializeField
local toiletPartyCost: number = 1000
--!SerializeField
local toiletPartyParticle: GameObject = nil
--!SerializeField
local toiletPartySounds: {AudioShader} = {}

local ReEnableEvent = Event.new("RE_ENABLE")
local ToiletTimer = IntValue.new("SERVER_TIMER", 120)
local baseTime = 120

local moveRequest = Event.new("MOVE_REQUEST")
local moveEvent = Event.new("MOVE_EVENT")

local FartRequest = Event.new("FART_REQUEST")
local FartEvent = Event.new("FART_EVENT")

local FartBombRequest = Event.new("FART_BOMB_REQUEST")
local FartBombEvent = Event.new("FART_BOMB_EVENT")

local PoopHeadRequest = Event.new("POOP_HEAD_REQUEST")
local PoopHeadEvent = Event.new("POOP_HEAD_EVENT")

local ToiletPartyRequest = Event.new("TOILET_PARTY_REQUEST")
local ToiletPartyEvent = Event.new("TOILET_PARTY_EVENT")

local FireAlarmRequest = Event.new("FIRE_ALARM_REQUEST")
local FireAlarmEvent = Event.new("FIRE_ALARM_EVENT")

local playerQueue = TableValue.new("PLAYER_QUEUE", {})
skipRequest = Event.new("SKIP_REQUEST")

UpdateWalletEvent = Event.new("UPDATE_WALLET")
UpdatePlaceEvent = Event.new("UPDATE_PLACE")
EnterParty = Event.new("HIDE_BUTTON")
LeaveParty = Event.new("HIDE_BUTTON")
UpdateTimerEvent = Event.new("UPDATE_TIMER")

--[[
local _hardCodedQueue = 
{
    {personName = "Bill"},
    {personName = "Bob"},
    {personName = "Joe"},
    {personName = "Sally"},
    {personName = "Jill"},
    {personName = "Jack"},
    {personName = "Herbertnininjer"}
}
--]]

local characterController = require("LineSimPlayerController")
local TeleportManager = require("TeleportManager")

--local uiManager = require("UIManager")
players = {}
local playercount = 0
local IncomeTimersByPlayer = {}

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            wallet = IntValue.new("WALLET" .. player.user.id, 0),
            incomeRate = NumberValue.new("INCOME_RATE" .. player.user.id, 1)
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

        --Stop and Destroy the player timer
        if IncomeTimersByPlayer[player] then
            IncomeTimersByPlayer[player]:Stop()
        end
        IncomeTimersByPlayer[player] = nil

        if server then
            local _tempQueue = playerQueue.value
            for key, value in ipairs(_tempQueue) do
                if value == player then
                    table.remove(_tempQueue, key)
                    playerQueue.value = _tempQueue
                end
            end
        end
    end)
end

------------ Swapping Positions in Queue ------------
function SkipXPlaces(queue, player, x)
    for i = 1, x do
        for key, value in ipairs(queue) do
            if value == player then
                if key == 1 then
                    return
                end
                queue[key], queue[key - 1] = queue[key - 1], queue[key]
            end
        end
    end
end

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

function GetSkipCost(player)
    return math.floor(100/GetPlace(playerQueue.value, player))
end

function PrintQueueNames(table)
    for key, value in ipairs(table) do
        print(tostring(key), tostring(value.name))
    end
end

------------- CLIENT -------------

function self:ClientAwake()

    characterController.options.enabled = false

    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.Character

        playerinfo.wallet.Changed:Connect(function(wallet, oldWallet)
            UpdateWalletEvent:Fire(player, wallet)
        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)

    HandleQueueChange(playerQueue.value)
    playerQueue.Changed:Connect(HandleQueueChange)

    moveEvent:Connect(function(player, pos)
        player.character:MoveTo(pos, 1, function()
            local _place = GetPlace(playerQueue.value, player)
            if _place == nil or LinePlaces[_place] == nil then return end
            player.character.transform.rotation = LinePlaces[_place].rotation
        end)
    end)

    ReEnableEvent:Connect(function(targetPlayer)
        print(targetPlayer.name .. " is re-enabled")
        characterController.options.enabled = true
        EnterParty:Fire()
        TeleportManager.TeleortPlayer(client.localPlayer, Vector3.new(12, 6.25, 2), function()
            local _newMoveto = Vector3.new(math.random(-2,2), 0, math.random(-2,2))
            _newMoveto = _newMoveto + client.localPlayer.character.transform.position
            MovePlayer(client.localPlayer, _newMoveto)
        end)

    end)

    ToiletTimer.Changed:Connect(function(timer)
        if GetPlace(playerQueue.value, client.localPlayer) == 1 then
            --SHOW TIMER
            UpdateTimerEvent:Fire(timer)
        end
    end)

    FartEvent:Connect(function(player)
        local _fart = GameObject.Instantiate(fartParticle)
        _fart.transform.position = player.character.transform.position
        _fart.transform.parent = player.character.transform
        Audio:PlayShader(fartSounds[math.random(1, #fartSounds)])
    end)

    FartBombEvent:Connect(function()
        local _fart = GameObject.Instantiate(fartBombParticle)
        _fart.transform.position = Vector3.new(12, 6.25, 2)
        Audio:PlayShader(fartBombSounds[math.random(1, #fartBombSounds)])
    end)

    ToiletPartyEvent:Connect(function()

        characterController.options.enabled = true
        EnterParty:Fire()
        TeleportManager.TeleortPlayer(client.localPlayer, Vector3.new(12, 6.25, 2), function()
            local _newMoveto = Vector3.new(math.random(-2,2), 0, math.random(-2,2))
            _newMoveto = _newMoveto + client.localPlayer.character.transform.position
            MovePlayer(client.localPlayer, _newMoveto)
        end)

        local _particle = GameObject.Instantiate(toiletPartyParticle)
        _particle.transform.position = Vector3.new(12, 6.25, 2)
        for eaach, sound in ipairs(toiletPartySounds) do
            Audio:PlayShader(sound)
        end

    end)

end

function MovePlayer(player, place)
    local _char = player.character
    moveRequest:FireServer(place)
end

function HandleQueueChange(queue, oldQueue)
    local _previousPlace = GetPlace(oldQueue, client.localPlayer)
    local _newPlace = GetPlace(queue, client.localPlayer)

    UpdatePlaceEvent:Fire(client.localPlayer, GetPlace(queue, client.localPlayer.name))

    if _newPlace == 0 then return end
    if characterController.options.enabled == true then
        characterController.options.enabled = false
        LeaveParty:Fire()
    end

    MoveToPlace(queue, oldQueue, _previousPlace, _newPlace)
end

function MoveToPlace(queue, oldQueue, _previousPlace, _newPlace)
    oldQueue = oldQueue or {}

    if _previousPlace ~= _newPlace then
        if _newPlace == 0 then return end
        local _newplace = LinePlaces[_newPlace]
        local _newPos
        if _newplace then
            _newPos = _newplace.position
        else
            _newPos = LinePlaces[#LinePlaces].position
        end
        MovePlayer(client.localPlayer, _newPos)
    end
    

end

function GetMoney()
    return players[client.localPlayer].wallet.value
end

--------------- UI ACTIONS ---------------
function FartBackwards()
    FartRequest:FireServer()
end
function FartBomb()
    FartBombRequest:FireServer()
end
function Poop()
    PoopHeadRequest:FireServer()
end
function Party()
    ToiletPartyRequest:FireServer()
end
function FireAlarm()
    FireAlarmRequest:FireServer()
end

------------- SERVER -------------

function self:ServerAwake()

    function FinishTimer()
        ToiletTimer.value = baseTime
        local _tempQueue = playerQueue.value
        if #_tempQueue > 0 then
            local _tempPlayer = _tempQueue[1]
            table.remove(_tempQueue, 1)
            playerQueue.value = _tempQueue

            --Enable the Player Controller
            ReEnableEvent:FireClient(_tempPlayer, _tempPlayer)
        end
    end

    Timer.Every(1, function()
        ToiletTimer.value = ToiletTimer.value - 1
        --print(ToiletTimer.value)
        if ToiletTimer.value < 1 then
            FinishTimer()
        end
    end)

    function ServerCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        -- Add the player to the queue
        local _tempQueue = playerQueue.value
        table.insert(_tempQueue, player)
        playerQueue.value = _tempQueue

        IncomeTimersByPlayer[player] = Timer.Every(0.1, function()
            IncrementMoney(player)
        end)
    end

    TrackPlayers(server, ServerCharacterInstantiate)

    skipRequest:Connect(function(player)
        -- Check if the player has enough money to skip
        local _playerMoney = players[player].wallet.value
        local _costToSkip = GetSkipCost(player)
        if _playerMoney < _costToSkip then
            return
        end

        --Take The cost from the wallet
        players[player].wallet.value = _playerMoney - _costToSkip

        --Move the player up the queue
        local _tempQueue = playerQueue.value
        SkipXPlaces(_tempQueue, player, 1)
        playerQueue.value = _tempQueue
    end)

    moveRequest:Connect(function(player, pos)
        player.character.transform.position = pos
        moveEvent:FireAllClients(player, pos)
    end)

    ---- Handle Special Action Requests ----

    ---- Send the person behind you all the back in the queue
    FartRequest:Connect(function(player)
        print("Farting")
        local _playerWallet = players[player].wallet.value
        if _playerWallet < fartCost then
            return
        end
        print("had enough money")

        --Take the money
        players[player].wallet.value = _playerWallet - fartCost

        -- Handle the fart
        local _myplace = GetPlace(playerQueue.value, player)
        local _targetPlace = _myplace + 1

        print("Target Place did not exceed the line length")
        local _victim = playerQueue.value[_targetPlace]
        if _victim == nil then
            FartEvent:FireAllClients(player)
            return
        end
        FartEvent:FireAllClients(_victim)
        print("Victim is not nil")
        -- Remove Victim from the Queue and Re add
        local _tempQueue = playerQueue.value
        table.remove(_tempQueue, _targetPlace)
        playerQueue.value = _tempQueue
        _tempQueue = playerQueue.value
        table.insert(_tempQueue, _victim)
        playerQueue.value = _tempQueue
    end)

    ---- Add all the players not in queue to the back of the queue
    FartBombRequest:Connect(function(player)

        local _playerWallet = players[player].wallet.value
        if _playerWallet < fartBombCost then
            return
        end
        players[player].wallet.value = _playerWallet - fartBombCost

        local _tempQueue = playerQueue.value

        for key, value in pairs(players) do
            if typeof(key) == "Player" then
                -- If not in queue, add to the back
                if not IsInLine(key) then
                    print("Adding " .. key.name .. " to the back of the queue")
                    table.insert(_tempQueue, key)
                end

            end
        end

        playerQueue.value = _tempQueue
        FartBombEvent:FireAllClients()

    end)

    -- Remove all players from the queue and teleport them to the party
    ToiletPartyRequest:Connect(function(player)
        local _playerWallet = players[player].wallet.value
        if _playerWallet < toiletPartyCost then
            return
        end
        players[player].wallet.value = _playerWallet - toiletPartyCost

        local _tempQueue = {}
        playerQueue.value = _tempQueue

        ToiletPartyEvent:FireAllClients()
    end)

end

function IsInLine(player) : boolean
    for key, value in ipairs(playerQueue.value) do
        if value == player then
            return true
        end
    end
    return false
end

function IncrementMoney(player)
    if not IsInLine(player) then return end
    local playerinfo = players[player]
    playerinfo.wallet.value = playerinfo.wallet.value + (playerinfo.incomeRate.value * 1)
end