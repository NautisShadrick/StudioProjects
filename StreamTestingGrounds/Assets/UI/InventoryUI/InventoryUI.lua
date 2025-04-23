--!Type(UI)

--!Bind
local content : UIScrollView = nil

local testItems = {
    {id = "item_1", amount = 1},
    {id = "item_2", amount = 4},
    {id = "item_3", amount = 8},
    {id = "item_4", amount = 7},
    {id = "item_5", amount = 1},
    {id = "item_6", amount = 2},
    {id = "item_7", amount = 3},
    {id = "item_8", amount = 5},
    {id = "item_9", amount = 6},
    {id = "item_10", amount = 9},
    {id = "item_11", amount = 10},
    {id = "item_12", amount = 11},
    {id = "item_13", amount = 12},
    {id = "item_14", amount = 13},
    {id = "item_15", amount = 14},
}

function CreateItem(item)
    local newItemContainer = VisualElement.new()
    newItemContainer:AddToClassList("inventory-item")

    local newItemIcon = Image.new()
    newItemIcon:AddToClassList("inventory-item__icon")

    local newItemName = Label.new()
    newItemName:AddToClassList("inventory-item__name")
    newItemName.text = item.id

    local newItemAmount = Label.new()
    newItemAmount:AddToClassList("inventory-item__amount")
    newItemAmount.text = "x"..item.amount
    
    newItemContainer:Add(newItemIcon)
    newItemContainer:Add(newItemName)
    newItemContainer:Add(newItemAmount)

    content:Add(newItemContainer)

    newItemContainer:RegisterPressCallback(function()
        -- Handle item click event
        print("Item clicked: " .. item.id)
    end)

    return newItemContainer

end

function UpdateInventory(items)
    for i, item in ipairs(items) do
        -- Create inentory UI item and add it to the content
        local newItem = CreateItem(item)
    end
end

function self:Start()
    UpdateInventory(testItems)
end