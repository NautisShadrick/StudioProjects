--!Type(Client)

--!SerializeField
local worldMonsterPrefab : GameObject = nil

function SpawnWorldMonster()
    local worldMonster = GameObject.Instantiate(worldMonsterPrefab)
    worldMonster.transform.position = self.transform.position
    worldMonster:GetComponent(WorldMonsterBehaviour).SetCharacter(self.gameObject:GetComponent(Character))
end

function self:Start()
    SpawnWorldMonster()
end