--!Type(UI)

--!SerializeField
local noElementIcon : Texture = nil

--!Bind
local card_header : Label = nil
--!Bind
local close_button : VisualElement = nil
--!Bind
local monster_image : Image = nil
--!Bind
local _actionScrollView : UIScrollView = nil
--!Bind
local stat_container : VisualElement = nil

--!Bind
local monster_one_tab : VisualElement = nil
--!Bind
local monster_two_tab : VisualElement = nil
--!Bind
local monster_three_tab : VisualElement = nil
--!Bind
local monster_four_tab : VisualElement = nil

--!Bind
local monster_one_icon   : Image = nil
--!Bind  
local monster_two_icon   : Image = nil
--!Bind
local monster_three_icon : Image = nil
--!Bind
local monster_four_icon  : Image = nil

local _tabs = {monster_one_tab, monster_two_tab, monster_three_tab, monster_four_tab}
local _images = {monster_one_icon, monster_two_icon, monster_three_icon, monster_four_icon}

local playerTracker = require("PlayerTracker")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local uiManager = require("UIManager")


function CreateAction(actionID)

    local actionData = actionLibrary.GetActionByID(actionID)

    local _newAction = VisualElement.new()
    _newAction:AddToClassList("inventory-action")

    local _actionImage = Image.new()
    _actionImage:AddToClassList("inventory-action-image")
    _actionImage.image = uiManager.GetIcon(actionData.GetActionElement()) or noElementIcon

    local _actionName = Label.new()
    _actionName:AddToClassList("inventory-action-name")
    _actionName.text = actionData.GetActionName()

    _newAction:Add(_actionImage)
    _newAction:Add(_actionName)

    _actionScrollView:Add(_newAction)

    --_newAction:RegisterPressCallback(function()
    --end)

    return _newAction
end

function PopulateActions(actions)
    _actionScrollView:Clear()

    for i, action in ipairs(actions) do
        CreateAction(action)
    end
    currentSelectedMonster = nil
end

function CreateStat(stat)

    local _newStat = VisualElement.new()
    _newStat:AddToClassList("stat-entry")

    local _statImage = Image.new()
    _statImage:AddToClassList("stat-image")
    _statImage.image = uiManager.GetStatIcon(stat.name)

    local _statValue = Label.new()
    _statValue:AddToClassList("stat-value")
    _statValue.text = stat.value

    _newStat:Add(_statImage)
    _newStat:Add(_statValue)

    stat_container:Add(_newStat)

    --_newAction:RegisterPressCallback(function()
    --end)

    return _newStat
end

function PopulateStats(stats)
    stat_container:Clear()

    for i, stat in ipairs(stats) do
        CreateStat(stat)
    end
end

function SetTabs()
    local playerMonsters = playerTracker.players[client.localPlayer].monsterCollection.value
    local _team = {}

    for i = 1, 4 do
        local _monster = playerMonsters[i]
        if _monster then table.insert(_team, _monster) end
    end
    
    for i = 1, 4 do
        local _monster = _team[i]
        if _monster then
            _tabs[i].style.display = DisplayStyle.Flex
            _images[i].image = monsterLibrary.GetDefaultMonsterData(_monster.speciesName).monsterSprite
        else
            _tabs[i].style.display = DisplayStyle.None
        end
    end
end

local testActions = {
    "bite",
    "bark",
    "tackle",
    "lightning_lash",
}

local testStats = {
    {
        name = "health",
        value = 100,
    },
    {
        name = "mana",
        value = 60,
    },
    {
        name = "attack",
        value = 50,
    },
    {
        name = "defense",
        value = 30,
    },
    {
        name = "accuracy",
        value = 10,
    },
}

function InitializeUI(playerMonsterIndex)

    local playerMonster = playerTracker.players[client.localPlayer].monsterCollection.value[playerMonsterIndex]
    local _monsterSprite = monsterLibrary.GetDefaultMonsterData(playerMonster.speciesName).monsterSprite
    local _actions = playerMonster.actionIDs
    --local _stats = playerMonster.stats

    PopulateActions(_actions)
    PopulateStats(testStats)
    monster_image.image = _monsterSprite
    card_header.text = playerMonster.name

    SetTabs()
end

function self:Start()
    uiManager.CloseMonsterInfoUI()
end

close_button:RegisterPressCallback(function()
    uiManager.CloseMonsterInfoUI()
end)

for i, tab in ipairs(_tabs) do
    tab:RegisterPressCallback(function()
        InitializeUI(i)
    end)
end