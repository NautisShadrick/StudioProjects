--!Type(UI)

--!Bind
local active_team_container : VisualElement = nil
--!Bind
local _monsterScrollView : UIScrollView = nil
--!Bind
local close_button : VisualElement = nil

local playerTracker = require("PlayerTracker")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local uiManager = require("UIManager")

local testCollection = {
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
    "Terrakita",
}

local testTeam = {
    "Terrakita",
    "Zapkit",
    "Terrakita",
    "Zapkit",
}

function CreateMonsterForCollection(monsterID)

    local monsterData = monsterLibrary.GetDefaultMonsterData(monsterID)

    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("inventory-action")

    local _actionImage = Image.new()
    _actionImage:AddToClassList("inventory-action-image")
    _actionImage.image = monsterData.monsterSprite

    local _actionName = Label.new()
    _actionName:AddToClassList("inventory-action-name")
    _actionName.text = monsterData.name

    local _addToTeamButton = Label.new()
    _addToTeamButton:AddToClassList("add_button")
    _addToTeamButton.text = "Add"

    _newMonster:Add(_actionName)
    _newMonster:Add(_actionImage)
    _newMonster:Add(_addToTeamButton)

    _monsterScrollView:Add(_newMonster)

    _newMonster:RegisterPressCallback(function()
    end)

    _addToTeamButton:RegisterPressCallback(function()
    end)


    return _newMonster
end
function CreateTeam(monsterID)

    local monsterData = monsterLibrary.GetDefaultMonsterData(monsterID)

    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("team-monster")

    local _actionImage = Image.new()
    _actionImage:AddToClassList("team-monster-image")
    _actionImage.image = monsterData.monsterSprite

    local _actionName = Label.new()
    _actionName:AddToClassList("team-monster-name")
    _actionName.text = monsterData.name

    local _removeFromTeamButton = Label.new()
    _removeFromTeamButton:AddToClassList("add_button")
    _removeFromTeamButton.text = "Remove"

    _newMonster:Add(_actionName)
    _newMonster:Add(_actionImage)
    _newMonster:Add(_removeFromTeamButton)

    active_team_container:Add(_newMonster)

    _newMonster:RegisterPressCallback(function()
    end)

    _removeFromTeamButton:RegisterPressCallback(function()
    end)


    return _newMonster
end

function PopulateCollection(actions)
    _monsterScrollView:Clear()

    for i, action in ipairs(actions) do
        CreateMonsterForCollection(action)
    end
    currentSelectedMonster = nil
end
function PopulateTeam(actions)
    active_team_container:Clear()

    for i, action in ipairs(actions) do
        CreateTeam(action)
    end
    currentSelectedMonster = nil
end

function self:Start()
    PopulateCollection(testCollection)
    PopulateTeam(testTeam)
    uiManager.CloseTeamManagerUI()
end

close_button:RegisterPressCallback(function()
    uiManager.CloseTeamManagerUI()
end)