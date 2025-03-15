--!Type(Module)

StartEggRequest = Event.new("StartEggRequest")
UpdateEggStatsEvent = Event.new("UpdateEggStatsEvent")
HatchMonsterRequest = Event.new("HatchMonsterRequest")
SlotHatchedEvent = Event.new("SlotHatchedEvent")

local playerTracker = require("PlayerTracker")
local playerInventoryManager = require("PlayerInventoryManager")


------------ Client ------------

function self:ClientStart()
end


------------ Server ------------

local playerHatcheryTimers = {}


function UpdateStats(player, hatcherySlot)
    print("Updating Stats")
    local playerinfo = playerTracker.players[player]
    local currentTime = os.time()
    local startTime = hatcherySlot.startTime
    local totalDuration = hatcherySlot.totalDuration
    local timeSinceStart = currentTime - startTime

    local _timeRemaining = math.max(0, totalDuration - timeSinceStart)
    local _timeRemainingString = string.format("%02d:%02d", math.floor(_timeRemaining / 60), _timeRemaining % 60)
    UpdateEggStatsEvent:FireClient(player, _timeRemaining, totalDuration, hatcherySlot.slotId)
end

function InitializeHatchery(player)
    print("Initializing Hatchery")

    if #playerTracker.players[player].hatcheryData.value > 0 then
        -- Update hatch Timer and Information
        for i, _hatcherySlot in ipairs(playerTracker.players[player].hatcheryData.value) do
            UpdateStats(player, _hatcherySlot)
        end
        if playerHatcheryTimers[player] then
            playerHatcheryTimers[player]:Stop()
            playerHatcheryTimers[player] = nil
        end
        print("Starting Hatchery Timer")
        playerHatcheryTimers[player] = Timer.Every(10, function()

            print("Updating Hatchery Timer")
            -- Update hatch Timer and Information
            local hasActiveSlot = false
            for i, _hatcherySlot in ipairs(playerTracker.players[player].hatcheryData.value) do
                UpdateStats(player, _hatcherySlot)
                if math.max(0, _hatcherySlot.totalDuration - (os.time() - _hatcherySlot.startTime)) > 0 then
                    hasActiveSlot = true
                end
            end

            if not hasActiveSlot then
                print("Stopping Hatchery Timer")
                playerHatcheryTimers[player]:Stop()
                playerHatcheryTimers[player] = nil
            end
        end)
    end
end

function SaveHatcheryDataToStorage(player: Player, cb)
    print("Saving Hatchery Data")
    local _hatcheryData = playerTracker.players[player].hatcheryData.value
    Storage.SetPlayerValue(player, "hatchery_data", _hatcheryData, function()
        print("Hatchery Data Saved")
        if #_hatcheryData > 0 then InitializeHatchery(player) end
        cb()
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

function StartEgg(player, slotId, eggId)
    local _playerEggCollection = playerTracker.players[player].eggCollection.value
    if #_playerEggCollection > 0 then
        print("Starting Egg Hatch Process")

        -- Fetch Egg Data
        local i = eggId or 1
        local _eggData = _playerEggCollection[i]
        -- Create hatchery Slot Data
        local _HatcherySlotData = {monster = _eggData.monster, startTime = os.time(), totalDuration = _eggData.totalDuration, slotId = slotId}

        -- Add Hatchery Slot Data to Player Hatchery Data
        local _hatcheryData = playerTracker.players[player].hatcheryData.value
        table.insert(_hatcheryData, _HatcherySlotData)
        playerTracker.players[player].hatcheryData.value = _hatcheryData

        SaveHatcheryDataToStorage(player, function()
            -- Remove Egg from Eggdata and Save to Storage
            table.remove(_playerEggCollection, i)
            playerTracker.players[player].eggCollection.value = _playerEggCollection
            playerInventoryManager.SaveEggCollectionToStorage(player)
        end)
    end
end

function HatchMonster(player, slotId, monsterName)
    local playerinfo = playerTracker.players[player]
    local _hatcheryData = playerinfo.hatcheryData.value

    for i, _hatcherySlot in ipairs(_hatcheryData) do
        if _hatcherySlot.slotId == slotId then
            if _hatcherySlot.totalDuration <= os.time() - _hatcherySlot.startTime then
                -- Hatch Monster
                print("Hatching Monster")
                table.remove(_hatcheryData, i)
                playerinfo.hatcheryData.value = _hatcheryData
                SaveHatcheryDataToStorage(player, function()
                    -- Add Monster to Player Inventory
                    playerInventoryManager.GivePlayerMonster(player, _hatcherySlot.monster, monsterName)
                    SlotHatchedEvent:FireClient(player, slotId)
                end)
            else
                -- Egg is not ready yet, somehow hacked this event
                print(player.name .. " tried to hatch an egg that is not ready yet")
            end
        end
    end
end

function self:ServerStart()
    StartEggRequest:Connect(StartEgg)
    HatchMonsterRequest:Connect(HatchMonster)

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