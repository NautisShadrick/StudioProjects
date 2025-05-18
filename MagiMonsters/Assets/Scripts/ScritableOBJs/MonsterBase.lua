--!Type(ScriptableObject)

--!SerializeField
local MonsterName: string = ""
--!SerializeField
local MonsterElement: string = ""
--!SerializeField
local MaxHP: number = 0
--!SerializeField
local MaxMana: number = 0
--!SerializeField
local MonsterActions: {string} = {}
--!SerializeField
local MonsterSprite: Texture = nil
--!SerializeField
local MonsterLootTable: DropLootTable = nil

function GetName()
    return MonsterName
end

function GetMaxHP()
    return MaxHP
end

function GetMaxMana()
    return MaxMana
end

function GetElement()
    return MonsterElement
end

function GetActions()
    return MonsterActions
end

function GetSprite()
    return MonsterSprite
end

function GetLootTable()
    return MonsterLootTable
end

function GetBaseStatsByLevel(level)
    local baseStats = {
    {
        name = "health",
        value = 100,
    },
    {
        name = "mana",
        value = 60,
    },
    {
        name = "attack",
        value = 50,
    },
    {
        name = "defense",
        value = 30,
    },
    {
        name = "accuracy",
        value = 10,
    },
}
    return baseStats
end