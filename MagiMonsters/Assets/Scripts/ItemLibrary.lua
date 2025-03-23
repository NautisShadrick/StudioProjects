--!Type(Module)

--!SerializeField
local itemDatas : {MaterialBase} = {}
--!SerializeField
local consumableDatas : {ConsumableBase} = {}

function GetItemByID(id: string)
    for _, item in ipairs(itemDatas) do
        if id == item.GetID() then
            return item
        end
    end
    return nil
end

function GetConsumableByID(id: string)
    for _, consumable in ipairs(consumableDatas) do
        if id == consumable.GetID() then
            return consumable
        end
    end
    return nil
end
