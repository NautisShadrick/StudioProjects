--!Type(Module)

local StartBattleRequest = Event.new("StartBattleRequest")
local DoActionRequest = Event.new("DoActionRequest")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local battleModule = require("BattleData")

-----------------------
--    CLIENT SIDE    --
-----------------------

function ClientDoAction(action: string)
    print("Client Do Action", action)
    DoActionRequest:FireServer(action)
end

function self:ClientAwake()
    Timer.After(2, function() StartBattleRequest:FireServer() end)
end

-----------------------
--    SERVER SIDE    --
-----------------------

function self:ServerAwake()

    local playerBattles = {}

    StartBattleRequest:Connect(function(player)
        playerBattles[player] = battleModule.Battle:new(player, playerTracker.players[player].monsterData.value, monsterLibrary.GetDefaultMonsterData("StromCat"))
    end)

    DoActionRequest:Connect(function(player, action)
        if not playerBattles[player] then
            print("Player is not in a battle")
            return
        end
        playerBattles[player]:DoAction(action)
    end)

    server.PlayerDisconnected:Connect(function(player)
        playerBattles[player] = nil
    end)
end