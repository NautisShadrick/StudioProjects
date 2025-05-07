--!Type(UI)

--!Bind
local player_xp_container : VisualElement = nil
--!Bind
local rewards_container : VisualElement = nil
--!Bind
local rewards_list : VisualElement = nil
--!Bind
local monsters_container : VisualElement = nil
--!Bind
local continue_button : Label = nil
--!Bind
local continue_button_premium : Label = nil

local itemLibrary = require("ItemLibrary")
local uiManager = require("UIManager")
local monsterLibrary = require("MonsterLibrary")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local testRewards = {
    {id = "wild_berries", amount = 5},
    {id = "fresh_herbs", amount = 3},
    {id = "sharp_thorns", amount = 1},
    {id = "mushrooms", amount = 2},
    {id = "tree_sap", amount = 1},
}

local monsterXPChanges = {
    {monster = "Terrakita", name = "Gavinor", toXP = 100, fromXP = 50, Level = 1, maxXP = 250},
    {monster = "Zapkit", name = "Sheerkan", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Toothless", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Shockrah", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
    {monster = "Zapkit", name = "Flash", toXP = 200, fromXP = 100, Level = 2, maxXP = 500},
}

local ContinueButtonPremiumPopInTween = Tween:new(
0.2,
1,
.5,
false,
false,
TweenModule.Easing.easeOutBack,
function(value, t)
    -- Tween update callback
    continue_button_premium.style.opacity = StyleFloat.new(math.min(t*2,1))
    continue_button_premium.style.scale = StyleScale.new(Vector2.new(value, value))
end,
function()
    -- Tween complete callback
    continue_button_premium.style.scale = StyleScale.new(Vector2.new(1, 1))
    continue_button_premium.style.opacity = StyleFloat.new(1.0)

    
end
)
local ContinueButtonPopInTween = Tween:new(
    0.2,
    1,
    .5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        -- Tween update callback
        continue_button.style.opacity = StyleFloat.new(math.min(t*2,1))
        continue_button.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Tween complete callback
        continue_button.style.scale = StyleScale.new(Vector2.new(1, 1))
        continue_button.style.opacity = StyleFloat.new(1.0)
        ContinueButtonPremiumPopInTween:start()
    end
)
local MonstersPopInTween = Tween:new(
    0.2,
    1,
    .5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        -- Tween update callback
        monsters_container.style.opacity = StyleFloat.new(math.min(t*2,1))
        monsters_container.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Tween complete callback
        monsters_container.style.scale = StyleScale.new(Vector2.new(1, 1))
        monsters_container.style.opacity = StyleFloat.new(1.0)

        Timer.After(1, function()
            ContinueButtonPopInTween:start()
        end)
    end
)
local RewardsPopInTween = Tween:new(
    0.2,
    1,
    .5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        -- Tween update callback
        rewards_container.style.opacity = StyleFloat.new(math.min(t*2,1))
        rewards_container.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Tween complete callback
        rewards_container.style.scale = StyleScale.new(Vector2.new(1, 1))
        rewards_container.style.opacity = StyleFloat.new(1.0)

        Timer.After(1, function()
            MonstersPopInTween:start()
        end)
    end
)
local PlayerXPPopInTween = Tween:new(
    0.2,
    1,
    .5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value, t)
        -- Tween update callback
        player_xp_container.style.opacity = StyleFloat.new(math.min(t*2,1))
        player_xp_container.style.scale = StyleScale.new(Vector2.new(value, value))
    end,
    function()
        -- Tween complete callback
        player_xp_container.style.scale = StyleScale.new(Vector2.new(1, 1))
        player_xp_container.style.opacity = StyleFloat.new(1.0)
        Timer.After(1, function()
            RewardsPopInTween:start()
        end)
    end
)

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

    local ItemPopInTween = Tween:new(
        0.2,
        1,
        .5,
        false,
        false,
        TweenModule.Easing.easeOutBack,
        function(value, t)
            -- Tween update callback
            _item.style.opacity = StyleFloat.new(math.min(t*2,1))
            _item.style.scale = StyleScale.new(Vector2.new(value, value))
        end,
        function()
            -- Tween complete callback
            _item.style.scale = StyleScale.new(Vector2.new(1, 1))
            _item.style.opacity = StyleFloat.new(1.0)
        end
    )
    ItemPopInTween:start()

    return _item
end

function PopulateRewardsList(rewards)
    if rewards_list == nil then
        return
    end

    --Create an index based table for the rewards
    local iRewards = {}
    for _, reward in rewards do
        table.insert(iRewards, reward)
    end

    for i, reward in iRewards do
        Timer.After(i * .5, function()
            local item = CreateRewardItem(reward.id, reward.amount)
        end)
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

    local ItemPopInTween = Tween:new(
        0.2,
        1,
        .5,
        false,
        false,
        TweenModule.Easing.easeOutBack,
        function(value, t)
            -- Tween update callback
            monsterXPContainer.style.opacity = StyleFloat.new(math.min(t*2,1))
            monsterXPContainer.style.scale = StyleScale.new(Vector2.new(value, value))
        end,
        function()
            -- Tween complete callback
            monsterXPContainer.style.scale = StyleScale.new(Vector2.new(1, 1))
            monsterXPContainer.style.opacity = StyleFloat.new(1.0)
        end
    )
    ItemPopInTween:start()


    return monsterXPContainer
end

function PopulateXpBars(_monsterXPChanges)
    for i, monsterXP in _monsterXPChanges do
        Timer.After(i * .5, function()
            local monsterData = monsterLibrary.GetDefaultMonsterData(monsterXP.monster)
            if monsterData ~= nil then
            local xpBar = CreateXpBar(monsterXP.name, monsterXP.toXP, monsterXP.fromXP, monsterXP.Level, monsterXP.maxXP, monsterData.monsterSprite)
            -- Add xpBar to the UI
            end
        end)
    end
end

function InitializePostBattle(loot)

    player_xp_container.style.scale = StyleScale.new(Vector2.new(0.01,0.01))
    player_xp_container.style.opacity = StyleFloat.new(0.0)

    rewards_container.style.scale = StyleScale.new(Vector2.new(0.01,0.01))
    rewards_container.style.opacity = StyleFloat.new(0.0)

    monsters_container.style.scale = StyleScale.new(Vector2.new(0.01,0.01))
    monsters_container.style.opacity = StyleFloat.new(0.0)

    continue_button.style.scale = StyleScale.new(Vector2.new(0.01,0.01))
    continue_button.style.opacity = StyleFloat.new(0.0)

    continue_button_premium.style.scale = StyleScale.new(Vector2.new(0.01,0.01))
    continue_button_premium.style.opacity = StyleFloat.new(0.0)

    PlayerXPPopInTween:start()

    -- Clear previous rewards and XP bars
    rewards_list:Clear()
    monsters_container:Clear()

    -- Stack all rewards with the same ID together into a new loot table
    local stackedLoot = {}
    for i, reward in loot do
        if stackedLoot[reward.id] == nil then
            stackedLoot[reward.id] = {id = reward.id, amount = 0}
        end
        stackedLoot[reward.id].amount = stackedLoot[reward.id].amount + reward.amount
    end

    Timer.After(1.6, function() if stackedLoot ~= {} then PopulateRewardsList(stackedLoot) end end)
    Timer.After(2.5, function() PopulateXpBars(monsterXPChanges) end)
end

function self:Start()
    self.gameObject:SetActive(false)
end

continue_button:RegisterPressCallback(function()
    self.gameObject:SetActive(false)
end)
continue_button_premium:RegisterPressCallback(function()
    self.gameObject:SetActive(false)
end)
