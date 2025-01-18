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

function InitializeBattleGrounds(playerCreatureID: string, enemyCreatureID: string)

    print(playerCreatureID, enemyCreatureID)

    local _playerSprite = monsterLibrary.GetDefaultMonsterData(playerCreatureID).monsterSprite
    local _enemySprite = monsterLibrary.GetDefaultMonsterData(enemyCreatureID).monsterSprite

    local _playerMonsterMaterial = playerCreature:GetComponent(Renderer).material
    local _enemyMonsterMaterial = enemyCreature:GetComponent(Renderer).material

    _playerMonsterMaterial.mainTexture = _playerSprite
    _enemyMonsterMaterial.mainTexture = _enemySprite
end