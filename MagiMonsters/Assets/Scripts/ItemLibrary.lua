--!Type(Module)

--!SerializeField
local itemDatas : {MaterialBase} = {}

function GetItemByID(id: string)
    for _, item in ipairs(itemDatas) do
        if id == item.GetID() then
            return item
        end
    end
end