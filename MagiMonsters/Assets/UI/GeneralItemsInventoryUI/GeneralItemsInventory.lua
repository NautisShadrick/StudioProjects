--!Type(UI)

--!Bind
local close_button : VisualElement = nil

--!Bind
local card_header : Label = nil

--!Bind
local monsters_tab : VisualElement = nil
--!Bind
local eggs_tab : VisualElement = nil
--!Bind
local materials_tab : VisualElement = nil
--!Bind
local recipes_tab : VisualElement = nil

--!Bind
local _inventoryScrollView : UIScrollView = nil

--!Bind
local info_container : VisualElement = nil
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

local currentSelection = nil
local canCraft = false

local currentSelectedMonster = nil

local currentTab = 3

-- 1 : Materials, 2 : Consumables, 3 : Monsters

function CreateItem(item)

    local itemData = itemLibrary.GetItemByID(item.id)

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

function CreatEggItem(eggIndex, egg)

    local _newegg = VisualElement.new()
    _newegg:AddToClassList("inventory-item")

    local _eggImage = Image.new()
    _eggImage:AddToClassList("inventory-item-image")
    _eggImage.image = monsterLibrary.eggSprites["air"]

    local _eggName = Label.new()
    _eggName:AddToClassList("inventory-item-name")
    _eggName.text = monsterLibrary.monsters[egg.monster].GetName()

    local _eggDuration = Label.new()
    _eggDuration:AddToClassList("inventory-item-amount")
    _eggDuration.text = egg.totalDuration .. "s"

    _newegg:Add(_eggImage)
    _newegg:Add(_eggName)
    _newegg:Add(_eggDuration)

    _inventoryScrollView:Add(_newegg)

    _newegg:RegisterPressCallback(function()
        print("egg Clicked")
        uiManager.SelectEggForHatchery(eggIndex)
        uiManager.CloseGeneralInventoryUI()
    end)

    return _newegg
end

function CreateMonsterEntry(playerMonsterInfo, defaultMonsterSpeciesData, index)
    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("inventory-item")

    local _monsterImage = Image.new()
    _monsterImage:AddToClassList("inventory-monster-image")
    _monsterImage.image = defaultMonsterSpeciesData.GetSprite()

    local _monsterName = Label.new()
    _monsterName:AddToClassList("inventory-monster-name")
    _monsterName.text = playerMonsterInfo.name

    local _monsterLevel = Label.new()
    _monsterLevel:AddToClassList("inventory-item-amount")
    _monsterLevel.text = "Lv." .. 1

    _newMonster:Add(_monsterImage)
    _newMonster:Add(_monsterName)
    _newMonster:Add(_monsterLevel)

    _inventoryScrollView:Add(_newMonster)

    _newMonster:RegisterPressCallback(function()
        SetItemInfoMonster(playerMonsterInfo, defaultMonsterSpeciesData)
        currentSelectedMonster = index
        currentSelection = nil
    end)

    return _newMonster
end


local Recipes = {
    "minor_health_potion",
    "major_health_potion",
    "revive_potion",
}

function SetItemInfoRecipe(recipe)
    local itemName = recipe.GetDisplayName() or "item name"
    local itemDesc = recipe.GetDescription() or "item description"
    local itemMaterials = recipe.GetMaterials()
    local itemSprite = recipe.GetSprite()

    info_name.text = itemName
    info_description.text = itemDesc
    info_image.image = itemSprite

    ingredients:Clear()
    
    canCraft = true
    craft_button.style.opacity = 1
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
        _materialAmount.text = playerTracker.GetItemAmountFromInv(client.localPlayer, material.id) .. " / " .. material.amount

        _newIngredient:Add(_materialImage)
        _newIngredient:Add(_materialName)
        _newIngredient:Add(_materialAmount)


        ingredients:Add(_newIngredient)

        if playerTracker.GetItemAmountFromInv(client.localPlayer, material.id) < material.amount then
            craft_button.style.opacity = 0.5
            canCraft = false
            _materialAmount:AddToClassList("material-missing")
            -- This Material is lacking
        end
    end

    craft_button.text = "CRAFT"
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


function SetItemInfoMonster(playerMonsterInfo, defaultMonsterSpeciesData)
    local itemName = playerMonsterInfo.name or "monster name"
    local itemDesc = defaultMonsterSpeciesData.GetName() or "monster type"
    local itemSprite = defaultMonsterSpeciesData.GetSprite()
    local monsterActions = playerMonsterInfo.actionIDs or defaultMonsterSpeciesData.GetActions()


    info_name.text = itemName
    info_description.text = itemDesc
    info_image.image = itemSprite

    ingredients:Clear()
    
    canCraft = true
    craft_button.style.opacity = 1
    for i, action in ipairs(monsterActions) do
        local _newAction = VisualElement.new()
        _newAction:AddToClassList("material-item")

        local _actionImage = Image.new()
        _actionImage:AddToClassList("material-image")
        _actionImage.image = uiManager.elementsIconsMap[actionLibrary.actions[action].GetActionElement()]

        local _actionName = Label.new()
        _actionName:AddToClassList("material-name")
        _actionName.text = actionLibrary.actions[action].GetActionName()

        local _actionAmount = Label.new()
        _actionAmount:AddToClassList("material-amount")
        _actionAmount.text = actionLibrary.actions[action].GetActionManaCost() .. "mp"
        
        local _actionDamage = Label.new()
        _actionDamage:AddToClassList("material-amount")
        _actionDamage.text = actionLibrary.actions[action].GetActionDamage() .. "dmg"

        _newAction:Add(_actionImage)
        _newAction:Add(_actionName)
        _newAction:Add(_actionAmount)
        _newAction:Add(_actionDamage)

        ingredients:Add(_newAction)
        
    end

    craft_button.text = "EQUIP"
    craft_button:EnableInClassList("hidden", false)

end

function CreateRecipe(recipe, ownedAmount)
    print("Creating Recipe: ", recipe.GetDisplayName())
    local _newItem = VisualElement.new()
    _newItem:AddToClassList("inventory-item")

    local _itemImage = Image.new()
    _itemImage:AddToClassList("inventory-item-image")
    _itemImage.image = recipe.GetSprite()

    local _itemName = Label.new()
    _itemName:AddToClassList("inventory-item-name")
    _itemName.text = recipe.GetDisplayName()

    local _itemAmount = Label.new()
    _itemAmount:AddToClassList("inventory-item-amount")
    _itemAmount.text = "x" .. ownedAmount

    _newItem:Add(_itemImage)
    _newItem:Add(_itemName)
    _newItem:Add(_itemAmount)

    _inventoryScrollView:Add(_newItem)

    _newItem:RegisterPressCallback(function()
        SetItemInfoRecipe(recipe)
        currentSelection = recipe
    end)

    return _newItem
end

function PopulateInventory(items)
    _inventoryScrollView:Clear()

    for i, item in ipairs(items) do
        if i == 1 then
            SetItemInfoMaterial(item.id)
            currentSelection = itemLibrary.GetItemByID(item.id)
        end
        local _isItem = itemLibrary.GetItemByID(item.id)
        if _isItem then CreateItem(item) end
    end
    currentSelectedMonster = nil
end

function PopulateRecipies(recipes, playerInv)
    _inventoryScrollView:Clear()

    for id, recipeID in recipes do
        local ownedAmount = 0
        for i, item in ipairs(playerInv) do
            if item.id == recipeID then
                ownedAmount = item.amount

            end
        end
        CreateRecipe(itemLibrary.GetConsumableByID(recipeID), ownedAmount)
    end

    SetItemInfoRecipe(itemLibrary.GetConsumableByID(recipes[1]))
    currentSelection = itemLibrary.GetConsumableByID(recipes[1])
    currentSelectedMonster = nil
end

function PopulateEggs(eggs)
    print("Populating Eggs", #eggs)
    _inventoryScrollView:Clear()

    for i, _egg in ipairs(eggs) do
        local newItem = CreatEggItem(i, _egg)
        _inventoryScrollView:Add(newItem)
    end

end

function PopulateMonsters(monsters)
    _inventoryScrollView:Clear()

    for i, monster in ipairs(monsters) do

        if i == 1 then
            SetItemInfoMonster(monster, monsterLibrary.monsters[monster.speciesName])
            currentSelectedMonster = i
            currentSelection = nil
        end
        
        local monsterData = monsterLibrary.monsters[monster.speciesName]
        if monsterData then
            local newItem = CreateMonsterEntry(monster, monsterData, i)
            _inventoryScrollView:Add(newItem)
        end
    end

end

function self:Start()

    PopulateInventory(playerTracker.players[client.localPlayer].playerInventory.value)
    playerTracker.players[client.localPlayer].playerInventory.Changed:Connect(function(newInv, oldInv)
        if currentTab == 3 then PopulateInventory(newInv)
        elseif currentTab == 4 then PopulateRecipies(Recipes, newInv) end
    end)

    uiManager.CloseGeneralInventoryUI()
end

function SetSection(section)
    print("Setting Section: ", section)
    if section == 1 then
        --print("Setting Section: Monsters")
        currentTab = 1
        card_header.text = "My Monsters"
        PopulateMonsters(playerTracker.players[client.localPlayer].monsterCollection.value)
        info_container:EnableInClassList("hidden", false)
    elseif section == 2 then
        print("Setting Section: Eggs")
        currentTab = 2
        card_header.text = "Monster Eggs"
        PopulateEggs(playerTracker.players[client.localPlayer].eggCollection.value)
        info_container:EnableInClassList("hidden", true)
    elseif section == 3 then
        currentTab = 3
        card_header.text = "Materials"
        PopulateInventory(playerTracker.players[client.localPlayer].playerInventory.value)
        info_container:EnableInClassList("hidden", false)
    elseif section == 4 then
        currentTab = 4
        card_header.text = "Recipes"
        PopulateRecipies(Recipes, playerTracker.players[client.localPlayer].playerInventory.value)
        info_container:EnableInClassList("hidden", false)
    end
end

close_button:RegisterPressCallback(function()
    uiManager.CloseGeneralInventoryUI()
end)

monsters_tab:RegisterPressCallback(function()
    SetSection(1)
end)

eggs_tab:RegisterPressCallback(function()
    SetSection(2)
end)

materials_tab:RegisterPressCallback(function()
    SetSection(3)
end)

recipes_tab:RegisterPressCallback(function()
    SetSection(4)
end)

craft_button:RegisterPressCallback(function()
    local currentSelectionIsRecipe = typeof(currentSelection) == "ConsumableBase"
    if currentSelectionIsRecipe and canCraft then
        inventoryManager.TryCraft(currentSelection.GetID())
    end

    if currentSelectedMonster then
        print("Equipping Monster: ", currentSelectedMonster)
        gameManager.EquipMonster(currentSelectedMonster)
    end
end)