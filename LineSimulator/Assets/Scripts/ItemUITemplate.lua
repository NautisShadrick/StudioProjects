--!Type(ScriptableObject)

--!SerializeField
local Title: string = ""
--!SerializeField
local Description: string = ""
--!SerializeField
local Price: number = 0
--!SerializeField
local IconID: string = ""
--!SerializeField
local ActionID: string = ""

function GetTitle(): string
    return Title
end

function GetDescription(): string
    return Description
end

function GetPrice(): number
    return Price
end

function GetIconID(): string
    return IconID
end

function GetActionID(): string
    return ActionID
end