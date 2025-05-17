--!Type(UI)

--!Bind
local _actionScrollView : UIScrollView = nil

local playerTracker = require("PlayerTracker")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local uiManager = require("UIManager")


function CreateAction(item)

    local actionData = actionLibrary.GetAction(item.id)

    local _newItem = VisualElement.new()
    _newItem:AddToClassList("inventory-item")

    local _itemImage = Image.new()
    _itemImage:AddToClassList("inventory-item-image")
    _itemImage.image = itemData.GetSprite()

    local _itemName = Label.new()
    _itemName:AddToClassList("inventory-item-name")
    _itemName.text = itemData.GetDisplayName()

    local _itemAmount = Label.new()
    _itemAmount:AddToClassList("inventory-item-amount")
    _itemAmount.text = "x" .. item.amount

    _newItem:Add(_itemImage)
    _newItem:Add(_itemName)
    _newItem:Add(_itemAmount)

    _inventoryScrollView:Add(_newItem)

    _newItem:RegisterPressCallback(function()
        SetItemInfoMaterial(item.id)
        currentSelection = itemData
    end)

    return _newItem
end

function PopulateActions(actions)
    _actionScrollView:Clear()

    for i, action in ipairs(actions) do
        CreateAction(action)
    end
    currentSelectedMonster = nil
end


local testActions = {
    { id = 1, amount = 1 },
    { id = 2, amount = 2 },
    { id = 3, amount = 3 },
}

function self:Start()

end