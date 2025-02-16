--!Type(Module)

StartEggRequest = Event.new("StartEggRequest")
UpdateEggStatsEvent = Event.new("UpdateEggStatsEvent")

local playerTracker = require("PlayerTracker")


------------ Client ------------

function self:ClientStart()
end


------------ Server ------------

local playerHatcheryTimers = {}


function UpdateStats(player, hatcherySlot)
    local playerinfo = playerTracker.players[player]
    local currentTime = os.time()
    local startTime = hatcherySlot.startTime
    local totalDuration = hatcherySlot.totalDuration
    local timeSinceStart = currentTime - startTime

    local _timeRemaining = math.max(0, totalDuration - timeSinceStart)
    local _timeRemainingString = string.format("%02d:%02d", math.floor(_timeRemaining / 60), _timeRemaining % 60)
    UpdateEggStatsEvent:FireClient(player, _timeRemaining, totalDuration)
end

function InitializeHatchery(player)
    print("Initializing Hatchery")
    local _hatcheryData = playerTracker.players[player].hatcheryData.value
    if #_hatcheryData > 0 then
        print("Starting Hatchery Timer")
        -- Update hatch Timer and Information
        for i, _hatcherySlot in ipairs(_hatcheryData) do
            UpdateStats(player, _hatcherySlot)
        end
        if playerHatcheryTimers[player] then
            playerHatcheryTimers[player]:Stop()
            playerHatcheryTimers[player] = nil
        end
        playerHatcheryTimers[player] = Timer.Every(10, function()
            print("Updating Hatchery Timer")
            -- Update hatch Timer and Information
            for i, _hatcherySlot in ipairs(_hatcheryData) do
                UpdateStats(player, _hatcherySlot)
            end
        end)
    end
end

function SaveHatcheryDataToStorage(player: Player)
    print("Saving Hatchery Data")
    local _hatcheryData = playerTracker.players[player].hatcheryData.value
    Storage.SetPlayerValue(player, "hatchery_data", _hatcheryData, function()
        print("Hatchery Data Saved")
        InitializeHatchery(player)
    end)
end

function GetHatcheryDataFromStorage(player: Player)
    Storage.GetPlayerValue(player, "hatchery_data", function(hatcheryData)
        if hatcheryData == nil then 
            hatcheryData = {
            }
        end
        playerTracker.players[player].hatcheryData.value = hatcheryData
        InitializeHatchery(player)
    end)
end

function StartEgg(player)
    print("Starting Egg")
    local _playerEggCollection = playerTracker.players[player].eggCollection.value
    if #_playerEggCollection > 0 then
        print("Starting Egg Hatch Process")
        local _eggData = _playerEggCollection[1]
        local _HatcherySlotData = {monster = _eggData.monster, startTime = os.time(), totalDuration = _eggData.totalDuration}

        local _hatcheryData = {}
        table.insert(_hatcheryData, _HatcherySlotData)
        playerTracker.players[player].hatcheryData.value = _hatcheryData
        SaveHatcheryDataToStorage(player)
    end
end

function self:ServerStart()
    StartEggRequest:Connect(StartEgg)

    server.PlayerConnected:Connect(function(player)
        player.CharacterChanged:Connect(function(player, character)
            GetHatcheryDataFromStorage(player)
        end)
    end)

    server.PlayerDisconnected:Connect(function(player)
        if playerHatcheryTimers[player] then
            playerHatcheryTimers[player]:Stop()
            playerHatcheryTimers[player] = nil
        end
    end)
end