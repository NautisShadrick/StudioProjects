--!Type(Module)

local moveRequest = Event.new("MOVE_REQUEST")
local moveEvent = Event.new("MOVE_EVENT")

local playerQueue = TableValue.new("PLAYER_QUEUE", {})
skipRequest = Event.new("SKIP_REQUEST")

UpdateWalletEvent = Event.new("UPDATE_WALLET")
UpdatePlaceEvent = Event.new("UPDATE_PLACE")

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
                if value.personName == player.name then
                    table.remove(_tempQueue, key)
                    playerQueue.value = _tempQueue
                end
            end
        end

    end)
end

------------ Swapping Positions in Queue ------------
function SkipXPlaces(queue, personName, x)
    for i = 1, x do
        for key, value in ipairs(queue) do
            if value.personName == personName then
                if key == 1 then
                    return
                end
                queue[key], queue[key - 1] = queue[key - 1], queue[key]
            end
        end
    end
end

------------ Utility Functions ------------
function GetPlace(queue, playerName, cb)
    for i, person in ipairs(queue) do
        if person.personName == playerName then
            cb(i)
            return
        end
    end
end

function PrintQueueNames(table)
    for key, value in ipairs(table) do
        print(tostring(key), tostring(value.personName))
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

    --[[
    PrintQueueNames(_hardCodedQueue)
    SkipXPlaces(_hardCodedQueue, "Jack", 5)
    PrintQueueNames(_hardCodedQueue)
    --]]

    HandleQueueChange(playerQueue.value)
    playerQueue.Changed:Connect(HandleQueueChange)

    moveEvent:Connect(function(player, pos)
        player.character:MoveTo(pos, 1)
    end)

end

function MovePlayer(player, place)
    local _char = player.character
    moveRequest:FireServer(place)
end

function HandleQueueChange(queue, oldQueue)
    print("Queue has changed!")
    if client.localPlayer.name == "NautisShadrick" then
        PrintQueueNames(queue)
    end

    GetPlace(queue, client.localPlayer.name, function(place)
        UpdatePlaceEvent:Fire(client.localPlayer, place)
    end)
    MoveToPlace(queue)
end

function MoveToPlace(queue)
    print("TEST")
    local _playerPlace = 0
    for key, value in ipairs(queue) do
        print(value.personName .. client.localPlayer.name)
        if value.personName == client.localPlayer.name then
            _playerPlace = key
            print(_playerPlace)
            MovePlayer(client.localPlayer, Vector3.new(_playerPlace * 1.5,0,0))
            --characterController.LocalMoveTo(client.localPlayer.character, Vector3.new(_playerPlace * 1.5,0,0), 1, 0)
        end
    end
end

------------- SERVER -------------

function self:ServerAwake()

    function ServerCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        -- Add the player to the queue
        local _tempQueue = playerQueue.value
        table.insert(_tempQueue, {personName = player.name})
        playerQueue.value = _tempQueue

        IncomeTimersByPlayer[player] = Timer.Every(1, function()
            IncrementMoney(player)
        end)
    end

    TrackPlayers(server, ServerCharacterInstantiate)

    skipRequest:Connect(function(player)
        local _tempQueue = playerQueue.value
        SkipXPlaces(_tempQueue, player.name, 1)
        playerQueue.value = _tempQueue
    end)

    moveRequest:Connect(function(player, pos)
        player.character.transform.position = pos
        moveEvent:FireAllClients(player, pos)
    end)
end

function IncrementMoney(player)
    local playerinfo = players[player]
    playerinfo.wallet.value = playerinfo.wallet.value + playerinfo.incomeRate.value
end