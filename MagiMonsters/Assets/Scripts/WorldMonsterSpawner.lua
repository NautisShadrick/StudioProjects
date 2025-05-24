--!Type(Module)

--!SerializeField
local worldMonsterPrefab : GameObject = nil

local worldMonstersByPlayer = {}

function SpawnWorldMonster(player, type)

    print("Spawning world monster for player: ", player.name, " of type: ", type)

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
        Object.Destroy(worldMonstersByPlayer[player])
        worldMonstersByPlayer[player] = nil
    end)
end