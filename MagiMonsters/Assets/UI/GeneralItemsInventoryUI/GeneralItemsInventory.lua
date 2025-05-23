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
--!Bind
local equip_button : Label = nil

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

local Recipes = {
    "minor_health_potion",
    "major_health_potion",
    "revive_potion",
}

local currentTab = 3
local lastSlectedRecipe = Recipes[1]

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
    _eggImage.image = monsterLibrary.eggTextures["air"]

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

function CreateMonsterEntry(playerMonsterInfo, defaultMonsterSpeciesData, index, _isEquipped)
    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("inventory-item")
    if _isEquipped then
        _newMonster:RemoveFromClassList("inventory-item")
        _newMonster:AddToClassList("inventory-item-selected")
    end

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

    local currentHealth = playerMonsterInfo.currentHealth or -1
    local maxHealth = playerMonsterInfo.maxHealth or -1
    local currentMana = playerMonsterInfo.currentMana or -1
    local maxMana = playerMonsterInfo.maxMana or -1
    local level = playerMonsterInfo.level or -1

    info_name.text = itemName
    info_description.text = itemDesc
    info_image.image = itemSprite

    ingredients:Clear()
    craft_button.style.opacity = 1

    local basicStats = {
        {nil, "HP", currentHealth, maxHealth},
        {nil, "MP", currentMana, maxMana},
        {nil, "XP", "x", "y"},
    }

    for i, stat in ipairs(basicStats) do
        local _newStat = VisualElement.new()
        _newStat:AddToClassList("material-item")

        local _statImage = Image.new()
        _statImage:AddToClassList("material-image")
        _statImage.image = stat[1]

        local _statName = Label.new()
        _statName:AddToClassList("material-name")
        _statName.text = stat[2]

        local _statAmount = Label.new()
        _statAmount:AddToClassList("material-amount")
        _statAmount.text = tostring(stat[3]) .. " / " .. tostring(stat[4])

        _newStat:Add(_statImage)
        _newStat:Add(_statName)
        _newStat:Add(_statAmount)

        ingredients:Add(_newStat)
        
    end

    craft_button.text = "Manage"
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
        lastSlectedRecipe = recipe.GetID()
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

    SetItemInfoRecipe(itemLibrary.GetConsumableByID(lastSlectedRecipe))
    currentSelection = itemLibrary.GetConsumableByID(lastSlectedRecipe)
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

    for i, monsterRef in ipairs(monsters) do

        local monster = monsterRef[1]
        local monsterIndex = monsterRef[2]

        if i == playerTracker.players[client.localPlayer].currentMosnterIndex.value then
            SetItemInfoMonster(monster, monsterLibrary.monsters[monster.speciesName])
            currentSelectedMonster = i
            currentSelection = nil
        end
        
        local monsterData = monsterLibrary.monsters[monster.speciesName]
        if monsterData then
            -- Check if this is the currently equipped monster
            local _isEquipped = false
            local _currentMonsterIndex = playerTracker.players[client.localPlayer].currentMosnterIndex.value
            if monsterIndex == _currentMonsterIndex then
                _isEquipped = true
            end

            local newItem = CreateMonsterEntry(monster, monsterData, monsterIndex, _isEquipped)
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

    playerTracker.players[client.localPlayer].currentMosnterIndex.Changed:Connect(function(newIndex, oldIndex)
        if currentTab == 1 then
            SetSection(1)
        end
    end)

    uiManager.CloseGeneralInventoryUI()
end

function SetSection(section)
    print("Setting Section: ", section)
    equip_button.style.display = DisplayStyle.None
    if section == 1 then
        --print("Setting Section: Monsters")
        currentTab = 1
        card_header.text = "My Monsters"

        --Get only the monsters on the players current team
        local _currentMonsterTeam = playerTracker.players[client.localPlayer].currentMonsterTeam.value
        local _currentMonsterCollection = playerTracker.players[client.localPlayer].monsterCollection.value
        local _currentMonsters = {}
        for i, monsterIndex in ipairs(_currentMonsterTeam) do
            table.insert(_currentMonsters, {_currentMonsterCollection[monsterIndex], monsterIndex})
        end
        PopulateMonsters(_currentMonsters)

        info_container:EnableInClassList("hidden", false)
        equip_button.style.display = DisplayStyle.Flex
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
        uiManager.CloseGeneralInventoryUI()
        uiManager.OpenMonsterInfoUI(currentSelectedMonster)
    end
end)

equip_button:RegisterPressCallback(function()
    if currentSelectedMonster then
        print("Equipping Monster: ", currentSelectedMonster)
        gameManager.EquipMonster(currentSelectedMonster)
    end
end)