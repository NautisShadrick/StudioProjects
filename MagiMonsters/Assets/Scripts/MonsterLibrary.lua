--!Type(Module)

--!SerializeField
local Zapkit: MonsterBase = nil
--!SerializeField
local Terakita: MonsterBase = nil

monsters = {
    Zapkit = Zapkit,
    Terakita = Terakita
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