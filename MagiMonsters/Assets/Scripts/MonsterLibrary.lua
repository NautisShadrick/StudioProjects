--!Type(Module)

--!SerializeField
local Zapkit: MonsterBase = nil
--!SerializeField
local Terrakita: MonsterBase = nil

--!SerializeField
local airEggSprite: Texture = nil

monsters = {
    Zapkit = Zapkit,
    Terrakita = Terrakita
}

eggSprites = {
    ["air"] = airEggSprite
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