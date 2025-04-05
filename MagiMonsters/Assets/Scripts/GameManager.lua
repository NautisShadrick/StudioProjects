--!Type(Module)

--!SerializeField
local LootTables : {DropLootTable} = {}

local StartBattleRequest = Event.new("StartBattleRequest")
local DoActionRequest = Event.new("DoActionRequest")

local SwapMonsterRequest = Event.new("SwapMonsterRequest")

local SearchRequest = Event.new("SearchRequest")
local SearchResponse = Event.new("SearchResponse")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local battleModule = require("BattleData")

local uiManager = require("UIManager")

local lootTableMap = {
    ["forest_1"] = 1
}

-----------------------
--    CLIENT SIDE    --
-----------------------

function SwapMonster(monsterIndex: number)
    if uiManager.currentBattleTurn ~= 0 then
        print("Not your turn")
        return
    end
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

function StartNewBattle(enemy: string)
    StartBattleRequest:FireServer(enemy)
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

end

-----------------------
--    SERVER SIDE    --
-----------------------

function self:ServerAwake()

    local playerBattles = {}
    local searchesByPlayer = {}

    StartBattleRequest:Connect(function(player, enemy)
        playerBattles[player] = nil
        playerBattles[player] = battleModule.Battle:new(player, playerTracker.players[player].monsterCollection.value[playerTracker.players[player].currentMosnterIndex.value], monsterLibrary.GetDefaultMonsterData(enemy))
    end)

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

        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end
        playerBattles[player]:SwapMonster()
    end)

    SearchRequest:Connect(function(player, objectType, duration)
        
        if searchesByPlayer[player] then
            print("Player is already searching")
            return
        end
        searchesByPlayer[player] = true
        Timer.After(duration, function()

            local _lootTableObject = LootTables[lootTableMap[objectType]]

            local _lootTable = _lootTableObject.GenerateLoot(10)
        
            for i, loot in ipairs(_lootTable) do
                print("Loot ID: " .. loot.id .. ", Amount: " .. loot.amount)
            end

            searchesByPlayer[player] = nil
            SearchResponse:FireClient(player, _lootTable)
        end)

    end)

    server.PlayerDisconnected:Connect(function(player)
        playerBattles[player] = nil
        searchesByPlayer[player] = nil
    end)
end