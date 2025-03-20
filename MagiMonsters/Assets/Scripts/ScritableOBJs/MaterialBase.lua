--!Type(ScriptableObject)

--!SerializeField
local id: string = ""
--!SerializeField
local displayName: string = ""
--!SerializeField
local sprite : Texture = nil
--!SerializeField
local description: string = ""
--!SerializeField
local element: string = ""
--!SerializeField
local rarity: number = 0
--!SerializeField
local value: number = 0

function GetID()
    return id
end

function GetDisplayName()
    return displayName
end

function GetSprite()
    return sprite
end

function GetDescription()
    return description
end

function GetElement()
    return element
end

function GetRarity()
    return rarity
end

function GetValue()
    return value
end

function GetItemData()
    return {
        id = id,
        displayName = displayName,
        sprite = sprite,
        description = description,
        element = element,
        rarity = rarity,
        value = value
    }
end