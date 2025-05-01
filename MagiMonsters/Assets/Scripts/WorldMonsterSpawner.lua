--!Type(Module)

--!SerializeField
local worldMonsterPrefab : GameObject = nil

local worldMonstersByPlayer = {}

function SpawnWorldMonster(player, type)

    if worldMonstersByPlayer[player] ~= nil then
        Object.Destroy(worldMonstersByPlayer[player])
        worldMonstersByPlayer[player] = nil
    end

    local worldMonster = GameObject.Instantiate(worldMonsterPrefab)
    worldMonster.transform.position = self.transform.position
    local monsterController = worldMonster:GetComponent(WorldMonsterBehaviour)
    monsterController.SetCharacter(player.character)
    monsterController.SetSprite(type)

    worldMonstersByPlayer[player] = worldMonster
end

function self:ClientStart()

    scene.PlayerLeft:Connect(function(scene, player)
        worldMonstersByPlayer[player] = nil
    end)
end