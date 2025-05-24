--!Type(Module)

--!SerializeField
local battleGround: GameObject = nil
--!SerializeField
local playerPoint: Transform = nil
--!SerializeField
local enemyPoint: Transform = nil

--!SerializeField
local playerCreature: GameObject = nil
--!SerializeField
local enemyCreature: GameObject = nil

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local battleData = require("BattleData")
local uiManager = require("UIManager")
local gameManager = require("GameManager")

local playerCreatureScript
local enemyCreatureScript

local currentEnemyCreatureID = ""

function GetPlayerCreature()
    return playerCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)
end
function GetEnemyCreature()
    return enemyCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)
end

function InitializeBattleGrounds(playerCreatureID: string, enemyCreatureID: string, customName)
    enemyCreatureID = enemyCreatureID or currentEnemyCreatureID
    currentEnemyCreatureID = enemyCreatureID

    battleGround:SetActive(true)

    local _playerSprite = monsterLibrary.GetDefaultMonsterData(playerCreatureID).monsterSprite
    local _enemySprite = monsterLibrary.GetDefaultMonsterData(enemyCreatureID).monsterSprite

    local _playerMonsterMaterial = playerCreature:GetComponent(Renderer).material
    local _enemyMonsterMaterial = enemyCreature:GetComponent(Renderer).material

    _playerMonsterMaterial.mainTexture = _playerSprite
    _enemyMonsterMaterial.mainTexture = _enemySprite

    playerCreatureScript.setBool("dead", false)
    enemyCreatureScript.setBool("dead", false)

end

function EndBattleGrounds()
    battleGround:SetActive(false)
end

function self:ClientStart()

    playerCreatureScript = playerCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)
    enemyCreatureScript = enemyCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)

    uiManager.ActionEvent:Connect(function(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, actionName, enemyCreature)

        if turn == gameManager.myTurnIndexClient then -- Was Enemy Action
            enemyCreatureScript.playTrigger("attack")
            Timer.After(.5, function() playerCreatureScript.playTrigger("hurt") end)
        else -- Was Player Action
            playerCreatureScript.playTrigger("attack")
            Timer.After(.5, function() enemyCreatureScript.playTrigger("hurt") end)
        end

        if enemyCreature then
            InitializeBattleGrounds(playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value].speciesName, enemyCreature.speciesName, enemyCreature.name)
        else
            InitializeBattleGrounds(playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value].speciesName, currentEnemyCreatureID)
        end

        
    end)
end