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

local monsterLibrary = require("MonsterLibrary")
local battleData = require("BattleData")

function InitializeBattleGrounds(playerCreatureID: string, enemyCreatureID: string)

    battleGround:SetActive(true)

    local _playerSprite = monsterLibrary.GetDefaultMonsterData(playerCreatureID).monsterSprite
    local _enemySprite = monsterLibrary.GetDefaultMonsterData(enemyCreatureID).monsterSprite

    local _playerMonsterMaterial = playerCreature:GetComponent(Renderer).material
    local _enemyMonsterMaterial = enemyCreature:GetComponent(Renderer).material

    _playerMonsterMaterial.mainTexture = _playerSprite
    _enemyMonsterMaterial.mainTexture = _enemySprite
end

function EndBattleGrounds()
    battleGround:SetActive(false)
end

function self:ClientStart()

    local playerCreatureScript = playerCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)
    local enemyCreatureScript = enemyCreature.transform.parent.gameObject:GetComponent(BattleCreatureScript)

    battleData.ActionEvent:Connect(function(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, actionName)

        if turn == 0 then -- Was Enemy Action
            enemyCreatureScript.playTrigger("attack")
            Timer.After(.5, function() playerCreatureScript.playTrigger("hurt") end)
        else -- Was Player Action
            playerCreatureScript.playTrigger("attack")
            Timer.After(.5, function() enemyCreatureScript.playTrigger("hurt") end)
        end
        
    end)
end