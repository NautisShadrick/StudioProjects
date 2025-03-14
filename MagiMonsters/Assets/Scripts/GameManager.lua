--!Type(Module)

local StartBattleRequest = Event.new("StartBattleRequest")
local DoActionRequest = Event.new("DoActionRequest")

local SwapMonsterRequest = Event.new("SwapMonsterRequest")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local battleModule = require("BattleData")

local uiManager = require("UIManager")

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

function Search(objectType: string)
    print("Searching through", objectType)
    StartNewBattle("Zapkit")
end

function self:ClientAwake()
end

-----------------------
--    SERVER SIDE    --
-----------------------

function self:ServerAwake()

    local playerBattles = {}

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

    server.PlayerDisconnected:Connect(function(player)
        playerBattles[player] = nil
    end)
end