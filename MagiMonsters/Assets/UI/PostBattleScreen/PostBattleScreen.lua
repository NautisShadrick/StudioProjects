--!Type(UI)

--!Bind
local rewards_list : VisualElement = nil
--!Bind
local monsters_container : VisualElement = nil

local itemLibrary = require("ItemLibrary")
local uiManager = require("UIManager")
local monsterLibrary = require("MonsterLibrary")

local testRewards = {
    {item = "wild_berries", amount = 5},
    {item = "fresh_herbs", amount = 3},
    {item = "sharp_thorns", amount = 1},
    {item = "mushrooms", amount = 2},
    {item = "tree_sap", amount = 1},
}

local monsterXPChanges = {
    {monster = "Terrakita", name = "Gavinor", toXP = 100, fromXP = 50, Level = 1, maxXP = 250},
    {monster = "Zapkit", name = "Sheerkan", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Toothless", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Shockrah", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Flash", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
}

function CreateRewardItem(item, amount)

    local itemData = itemLibrary.GetItemByID(item)
    if itemData == nil then
        -- Not a material, check if it's a consumable
        itemData = itemLibrary.GetConsumableByID(item)
    end
    if itemData == nil then
        -- Not a consumable or material
        return nil
    end

    local itemElement = itemData.GetElement()

    local _item = VisualElement.new()
    _item:AddToClassList("reward-item")

    if itemElement ~= nil then
        local _glow = VisualElement.new()
        _glow:AddToClassList("glow-"..itemElement)
        _item:Add(_glow)

        _item:AddToClassList("bg-"..itemElement)
    end

    local item_sprite = Image.new()
    item_sprite:AddToClassList("item-sprite")
    item_sprite.image = itemData.GetSprite()

    local item_amount = Label.new()
    item_amount:AddToClassList("item-amount")
    item_amount.text = amount

    _item:Add(item_sprite)
    _item:Add(item_amount)


    _item:RegisterPressCallback(function()
        -- Handle item click event here
    end)

    rewards_list:Add(_item)

    return _item
end

function PopulateRewardsList(rewards)
    if rewards_list == nil then
        return
    end

    for i, reward in rewards do
        local item = CreateRewardItem(reward.item, reward.amount)
    end
end

function CreateXpBar(name, toXP, fromXP, Level, maxXP, sprite)

    local monsterXPContainer = VisualElement.new()
    monsterXPContainer:AddToClassList("monster-xp-container")

    local xpBar = VisualElement.new()
    xpBar:AddToClassList("xp-bar")

    local xpBarHolder = VisualElement.new()
    xpBarHolder:AddToClassList("xp-bar-holder")
    xpBar:Add(xpBarHolder)

    local xpBarFill = VisualElement.new()
    xpBarFill:AddToClassList("xp-bar-fill")
    xpBarHolder:Add(xpBarFill)

    local xpBarText = Label.new()
    xpBarText:AddToClassList("xp-bar-text")
    xpBar:Add(xpBarText)
    xpBarText.text = string.format("%s/%s", tostring(toXP), tostring(maxXP))

    local monsterSprite = Image.new()
    monsterSprite:AddToClassList("monster-sprite")
    monsterSprite.image = sprite

    local monsterLevelContainer = VisualElement.new()
    monsterLevelContainer:AddToClassList("monster-level-container")
    monsterXPContainer:Add(monsterLevelContainer)

    local monsterLevel = Label.new()
    monsterLevel:AddToClassList("monster-level")
    monsterLevel.text = tostring(Level)
    monsterLevelContainer:Add(monsterLevel)


    monsters_container:Add(monsterXPContainer)
    monsterXPContainer:Add(xpBar)
    monsterXPContainer:Add(monsterSprite)


    return monsterXPContainer
end

function PopulateXpBars(_monsterXPChanges)
    for i, monsterXP in _monsterXPChanges do
        local monsterData = monsterLibrary.GetDefaultMonsterData(monsterXP.monster)
        if monsterData ~= nil then
            local xpBar = CreateXpBar(monsterXP.name, monsterXP.toXP, monsterXP.fromXP, monsterXP.Level, monsterXP.maxXP, monsterData.monsterSprite)
            -- Add xpBar to the UI
        end
    end
end

function self:Start()
    PopulateRewardsList(testRewards)
    PopulateXpBars(monsterXPChanges)
end
