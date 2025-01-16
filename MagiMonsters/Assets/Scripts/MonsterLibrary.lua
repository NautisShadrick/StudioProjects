--!Type(Module)

--!SerializeField
local StormCat: MonsterBase = nil
--!SerializeField
local Rocktail: MonsterBase = nil

monsters = {
    StormCat = StormCat,
    Rocktail = Rocktail
}

export type MonsterData = {
    name: string,
    speciesName: string,
    maxHealth: number,
    currentHealth: number,
    maxMana: number,
    currentMana: number,
    level: number,
    actionIDs: {string}
}

function GetDefaultMonsterData(monsterName: string): MonsterData
    print(typeof(monsters[monsterName]))
    return {
        name = monsters[monsterName].GetName(),
        speciesName = monsterName,
        maxHealth = monsters[monsterName].GetMaxHP(),
        currentHealth = monsters[monsterName].GetMaxHP(),
        maxMana = monsters[monsterName].GetMaxMana(),
        currentMana = monsters[monsterName].GetMaxMana(),
        level = 1,
        actionIDs = monsters[monsterName].GetActions()
    }
end