--!Type(ScriptableObject)

--!SerializeField
local sprite : Sprite = nil
--!SerializeField
local partId : string = ""

function GetSprite(): Sprite
    return sprite
end

function GetPartId(): string
    return partId
end