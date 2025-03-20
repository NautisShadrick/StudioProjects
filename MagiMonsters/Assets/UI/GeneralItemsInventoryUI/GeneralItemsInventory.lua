--!Type(UI)

--!Bind
local card_header : Label = nil

--!Bind
local materials_tab : VisualElement = nil
--!Bind
local recipes_tab : VisualElement = nil

--!Bind
local _inventoryScrollView : UIScrollView = nil

--!Bind
local info_text : VisualElement = nil
--!Bind
local info_name : Label = nil
--!Bind
local info_image : Image = nil
--!Bind
local info_description : Label = nil
--!Bind
local ingredients : VisualElement = nil

--!Bind
local craft_button : Label = nil

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")
local actionLibrary = require("ActionLibrary")
local itemLibrary = require("ItemLibrary")
local inventoryManager = require("PlayerInventoryManager")
local gameManager = require("GameManager")
local uiManager = require("UIManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

-- 1 : Materials, 2 : Consumables, 3 : Monsters

function CreateItem(item)
    local _newItem = VisualElement.new()
    _newItem:AddToClassList("inventory-item")

    local _itemImage = Image.new()
    _itemImage:AddToClassList("inventory-item-image")
    _itemImage.image = itemLibrary.GetItemByID(item.id).GetSprite()

    local _itemName = Label.new()
    _itemName:AddToClassList("inventory-item-name")
    _itemName.text = itemLibrary.GetItemByID(item.id).GetDisplayName()

    local _itemAmount = Label.new()
    _itemAmount:AddToClassList("inventory-item-amount")
    _itemAmount.text = "x" .. item.amount

    _newItem:Add(_itemImage)
    _newItem:Add(_itemName)
    _newItem:Add(_itemAmount)

    _inventoryScrollView:Add(_newItem)

    _newItem:RegisterPressCallback(function()
        SetItemInfoMaterial(item.id)
    end)

    return _newItem
end

function PopulateInventory(items)
    _inventoryScrollView:Clear()

    for i, item in ipairs(items) do
        CreateItem(item)
    end

end

local testRecipes = {
    health_potion_small = {
        displayName = "Small Health Potion",
        description = "A small potion that restores a small amount of health.",
        materials = {
            {id = "mushrooms", amount = 2},
            {id = "fresh_herbs", amount = 1},
            {id = "tree_sap", amount = 1},
        }
    },
    mana_potion_small = {
        displayName = "Small Mana Potion",
        description = "A small potion that restores a small amount of mana.",
        materials = {
            {id = "tree_sap", amount = 1},
            {id = "mushrooms", amount = 1}
        }
    },
    revive_potion = {
        displayName = "Revive Potion",
        description = "A potion that revives a fallen ally.",
        materials = {
            {id = "wild_berries", amount = 1},
            {id = "fire_essence", amount = 1}
        }
    },
}

function SetItemInfoRecipe(recipe)
    local itemName = recipe.displayName or "item name"
    local itemDesc = recipe.description or "item description"
    local itemMaterials = recipe.materials

    info_name.text = itemName
    info_description.text = itemDesc

    ingredients:Clear()
    
    for i, material in ipairs(itemMaterials) do
        local _newIngredient = VisualElement.new()
        _newIngredient:AddToClassList("material-item")

        local _materialImage = Image.new()
        _materialImage:AddToClassList("material-image")
        _materialImage.image = itemLibrary.GetItemByID(material.id).GetSprite()

        local _materialName = Label.new()
        _materialName:AddToClassList("material-name")
        _materialName.text = itemLibrary.GetItemByID(material.id).GetDisplayName()

        local _materialAmount = Label.new()
        _materialAmount:AddToClassList("material-amount")
        _materialAmount.text = "x" .. material.amount

        _newIngredient:Add(_materialImage)
        _newIngredient:Add(_materialName)
        _newIngredient:Add(_materialAmount)


        ingredients:Add(_newIngredient)
    end

    craft_button:EnableInClassList("hidden", false)

end

function SetItemInfoMaterial(item)
    local itemName = itemLibrary.GetItemByID(item).GetDisplayName() or "item name"
    local itemDesc = itemLibrary.GetItemByID(item).GetDescription() or "item description"
    local itemSprite = itemLibrary.GetItemByID(item).GetSprite()

    info_name.text = itemName
    info_description.text = itemDesc
    info_image.image = itemSprite

    ingredients:Clear()

    craft_button:EnableInClassList("hidden", true)
end

function CreateRecipe(recipe)
    print("Creating Recipe: ", recipe.displayName)
    local _newItem = VisualElement.new()
    _newItem:AddToClassList("inventory-item")

    local _itemImage = Image.new()
    _itemImage:AddToClassList("inventory-item-image")
    --_itemImage.image = recipe.GetSprite()

    local _itemName = Label.new()
    _itemName:AddToClassList("inventory-item-name")
    _itemName.text = recipe.displayName

    local _materialsContainer = VisualElement.new()
    _materialsContainer:AddToClassList("materials-container")

    local _craftButton = Label.new()
    _craftButton:AddToClassList("craft-button")
    _craftButton.text = "Craft"

    _newItem:Add(_itemImage)
    _newItem:Add(_itemName)

    _inventoryScrollView:Add(_newItem)

    _newItem:RegisterPressCallback(function()
        SetItemInfoRecipe(recipe)
    end)

    return _newItem
end

function PopulateRecipies(recipes)
    _inventoryScrollView:Clear()

    for id, recipe in recipes do
        CreateRecipe(recipe)
    end
end

function self:Start()

    PopulateInventory(playerTracker.players[client.localPlayer].playerInventory.value)
    playerTracker.players[client.localPlayer].playerInventory.Changed:Connect(function(newInv, oldInv)
        PopulateInventory(newInv)
    end)
end

materials_tab:RegisterPressCallback(function()
    card_header.text = "Materials"
    PopulateInventory(playerTracker.players[client.localPlayer].playerInventory.value)
end)

recipes_tab:RegisterPressCallback(function()
    card_header.text = "Recipes"
    PopulateRecipies(testRecipes)
end)