--!Type(Module)

--!SerializeField
local LootTables : {DropLootTable} = {}

local StartBattleEvent = Event.new("StartBattleEvent")
local DoActionRequest = Event.new("DoActionRequest")
local SwapMonsterRequest = Event.new("SwapMonsterRequest")
local UseItemRequest = Event.new("UseItemRequest")
local FleeRequest = Event.new("FleeRequest")

local SearchRequest = Event.new("SearchRequest")
local SearchResponse = Event.new("SearchResponse")
VictoryResponse = Event.new("VictoryResponse")


local playerTracker = require("PlayerTracker")
local itemLibrary = require("ItemLibrary")
local monsterLibrary = require("MonsterLibrary")
local battleModule = require("BattleData")
local playerInventoryManager = require("PlayerInventoryManager")

local uiManager = require("UIManager")

local lootTableMap = {
    ["forest_1"] = 1
}

-----------------------
--    CLIENT SIDE    --
-----------------------

function Flee()
    if uiManager.currentBattleTurn ~= 0 then
        print("Not your turn")
        return
    end
    print("Fleeing")
    FleeRequest:FireServer()
end

function UseItem(itemID: string)
    if uiManager.currentBattleTurn ~= 0 then
        print("Not your turn")
        return
    end
    print("Using item", itemID)
    UseItemRequest:FireServer(itemID)
end

function SwapMonster(monsterIndex: number)
    if uiManager.currentBattleTurn ~= 0 then
        print("Not your turn")
        return
    end
    SwapMonsterRequest:FireServer(monsterIndex)
end

function EquipMonster(monsterIndex: number)
    SwapMonsterRequest:FireServer(monsterIndex)
end

function ClientDoAction(action: string)
    if uiManager.currentBattleTurn ~= 0 then
        print("Not your turn")
        return
    end
    print("Client Do Action", action)
    DoActionRequest:FireServer(action)
end

function StartNewBattleClient(enemy)
    uiManager.InitializeBattle(enemy)
end

function Search(objectType: string, duration: number)
    print("Searching through", objectType)
    SearchRequest:FireServer(objectType, duration)
end

function self:ClientAwake()

    SearchResponse:Connect(function(lootTable)
        uiManager.DisplaySearchLoot(lootTable)
    end)

    StartBattleEvent:Connect(function(enemy)
        StartNewBattleClient(enemy)
    end)

end

-----------------------
--    SERVER SIDE    --
-----------------------

local playerBattles = {}
local searchesByPlayer = {}

function StartBattleServer(player, enemy)
    playerBattles[player] = nil
    playerBattles[player] = battleModule.Battle:new(player, playerTracker.players[player].monsterCollection.value[playerTracker.players[player].currentMosnterIndex.value], monsterLibrary.GetDefaultMonsterData(enemy))
end

function HandleBattleVictory(player, monster)
    print("Battle Victory")
    print(player.name, monster.speciesName)

    -- FOUND LOOT
    local _lootTableObject = monsterLibrary.GetDefaultMonsterData(monster.speciesName).lootTable
    local _lootTable = _lootTableObject.GenerateLoot(math.random(1, 5))

    for i, item in ipairs(_lootTable) do
        local itemData = itemLibrary.GetItemByID(item.id)
        if itemData then
            playerInventoryManager.GivePlayerItem(player, item.id, item.amount)
        end
    end

    VictoryResponse:FireClient(player, _lootTable)

end

function HandleBattleEnd(player)
    playerBattles[player] = nil
end

function self:ServerAwake()

    DoActionRequest:Connect(function(player, action)
        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end

        if playerBattles[player].turn ~= 0 then
            print("Not your turn")
            return
        end

        playerBattles[player]:DoAction(action)
    end)

    SwapMonsterRequest:Connect(function(player, monsterIndex)
        playerTracker.players[player].currentMosnterIndex.value = monsterIndex
        playerTracker.players[player].equippedMonsterType.value = playerTracker.players[player].monsterCollection.value[monsterIndex].speciesName

        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end
        playerBattles[player]:SwapMonster()
    end)

    UseItemRequest:Connect(function(player, itemID)
        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end

        if playerBattles[player].turn ~= 0 then
            print("Not your turn")
            return
        end

        local itemData = itemLibrary.GetConsumableByID(itemID)
        if itemData then
            playerInventoryManager.TakePlayerItem(player, itemID, 1)
            playerBattles[player]:UseItem(itemID)
        else
            print("Item not found")
        end
    end)

    FleeRequest:Connect(function(player)
        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end

        if playerBattles[player].turn ~= 0 then
            print("Not your turn")
            return
        end

        playerBattles[player]:EndBattle(playerBattles[player].enemy)
    end)

    SearchRequest:Connect(function(player, objectType, duration)
        
        if searchesByPlayer[player] then
            print("Player is already searching")
            return
        end
        searchesByPlayer[player] = true
        Timer.After(duration, function()

            local _foundMonster = true --math.random() > 0.7 and true or false
            if _foundMonster then
                local _enemy = "Zapkit"
                -- FOUND A MONSTER
                StartBattleServer(player, _enemy)
                StartBattleEvent:FireClient(player, _enemy)
            else

                -- FOUND LOOT

                local _lootTableObject = LootTables[lootTableMap[objectType]]

                local _lootTable = _lootTableObject.GenerateLoot(math.random(1, 5))
            
                --for i, loot in ipairs(_lootTable) do
                --    print("Loot ID: " .. loot.id .. ", Amount: " .. loot.amount)
                --end
    
                SearchResponse:FireClient(player, _lootTable)
    
                for i, item in ipairs(_lootTable) do
                    local itemData = itemLibrary.GetItemByID(item.id)
                    if itemData then
                        playerInventoryManager.GivePlayerItem(player, item.id, item.amount)
                    end
                end

            end

            searchesByPlayer[player] = nil

        end)

    end)

    server.PlayerDisconnected:Connect(function(player)
        playerBattles[player] = nil
        searchesByPlayer[player] = nil
    end)
end