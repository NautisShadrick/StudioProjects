--!Type(ScriptableObject)

--!SerializeField
local actionName: string = ""
--!SerializeField
local actionElement: string = ""
--!SerializeField
local actionDamage: number = 0
--!SerializeField
local actionManaCost: number = 0

function GetActionName()
    return actionName
end

function GetActionElement()
    return actionElement
end

function GetActionDamage()
    return actionDamage
end

function GetActionManaCost()
    return actionManaCost
end