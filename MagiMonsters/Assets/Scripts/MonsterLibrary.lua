--!Type(Module)

--!SerializeField
local MonsterDatas: {MonsterBase} = {}

--!SerializeField
local airEggSprite: Texture = nil
--!SerializeField
local earthEggSprite: Texture = nil
--!SerializeField
local waterEggSprite: Texture = nil

monsters = {
}

eggSprites = {
    ["air"] = airEggSprite,
    ["earth"] = earthEggSprite,
    ["water"] = waterEggSprite,
}

export type MonsterData = {
    name: string,
    speciesName: string,
    maxHealth: number,
    currentHealth: number,
    maxMana: number,
    currentMana: number,
    level: number,
    actionIDs: {string},
    monsterSprite: Texture
}

function AddMonstersToTable()
    for _, monsterData in pairs(MonsterDatas) do
        print("Adding monster: " .. monsterData.GetName())
        monsters[monsterData.GetName()] = monsterData
    end
end

function GetDefaultMonsterData(monsterName: string): MonsterData
    return {
        name = monsters[monsterName].GetName(),
        speciesName = monsterName,
        maxHealth = monsters[monsterName].GetMaxHP(),
        currentHealth = monsters[monsterName].GetMaxHP(),
        maxMana = monsters[monsterName].GetMaxMana(),
        currentMana = monsters[monsterName].GetMaxMana(),
        level = 1,
        actionIDs = monsters[monsterName].GetActions(),
        monsterSprite = monsters[monsterName].GetSprite(),
        lootTable = monsters[monsterName].GetLootTable()
    }
end

function GetStorageMonsterData(monsterName: string)
    return {
        name = monsters[monsterName].GetName(),
        speciesName = monsterName,
        maxHealth = monsters[monsterName].GetMaxHP(),
        currentHealth = monsters[monsterName].GetMaxHP(),
        maxMana = monsters[monsterName].GetMaxMana(),
        currentMana = monsters[monsterName].GetMaxMana(),
        level = 1,
        actionIDs = monsters[monsterName].GetActions(),
        stats = monsters[monsterName].GetBaseStatsByLevel(1),
    }
end

function self:Start()
    AddMonstersToTable()
end