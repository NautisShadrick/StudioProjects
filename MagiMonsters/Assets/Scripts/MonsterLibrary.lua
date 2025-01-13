--!Type(Module)

--!SerializeField
local StromCat: MonsterBase = nil
--!SerializeField
local Rocktail: MonsterBase = nil

monsters = {
    StromCat = StromCat,
    Rocktail = Rocktail
}

export type MonsterData = {
    name: string,
    speciesName: string,
    maxHealth: number,
    currentHealth: number,
    maxMana: number,
    currentMana: number,
    actionIDs: {string}
}

function GetDefaultMonsterData(monsterName: string): MonsterData
    return {
        name = monsters[monsterName].GetName(),
        speciesName = monsterName,
        maxHealth = monsters[monsterName].GetMaxHP(),
        currentHealth = monsters[monsterName].GetMaxHP(),
        maxMana = monsters[monsterName].GetMaxMana(),
        currentMana = monsters[monsterName].GetMaxMana(),
        actionIDs = monsters[monsterName].GetActions()
    }
end