--!Type(Module)

--!SerializeField
local actionDatas : {AttackBase} = {}

function GetActionByID(id: string)
    for _, action in ipairs(actionDatas) do
        --print(item.GetID(), id)
        if id == action.GetID() then
            return action
        end
    end
    print("Action not found: " .. id)
    return nil
end
