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

function CreateMonsterForCollection(monster, index)

    local monsterData = monsterLibrary.GetDefaultMonsterData(monster.speciesName)

    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("inventory-action")

    local _actionImage = Image.new()
    _actionImage:AddToClassList("inventory-action-image")
    _actionImage.image = monsterData.monsterSprite

    local _actionName = Label.new()
    _actionName:AddToClassList("inventory-action-name")
    _actionName.text = monster.name

    local _addToTeamButton = Label.new()
    _addToTeamButton:AddToClassList("add_button")
    _addToTeamButton.text = "Add"

    _newMonster:Add(_actionName)
    _newMonster:Add(_actionImage)
    _newMonster:Add(_addToTeamButton)

    _monsterScrollView:Add(_newMonster)

    _newMonster:RegisterPressCallback(function()
        playerTracker.AddMonsterToTeam(index)
    end)

    _addToTeamButton:RegisterPressCallback(function()
        playerTracker.AddMonsterToTeam(index)
    end)
    
    _newMonster:RegisterLongPressCallback(function()
        uiManager.CloseTeamManagerUI()
        uiManager.OpenMonsterInfoUI(index)
    end)

    return _newMonster
end
function CreateTeam(monster, index)

    local monsterData = monsterLibrary.GetDefaultMonsterData(monster.speciesName)

    local _newMonster = VisualElement.new()
    _newMonster:AddToClassList("team-monster")

    local _actionImage = Image.new()
    _actionImage:AddToClassList("team-monster-image")
    _actionImage.image = monsterData.monsterSprite

    local _actionName = Label.new()
    _actionName:AddToClassList("team-monster-name")
    _actionName.text = monster.name

    local _removeFromTeamButton = Label.new()
    _removeFromTeamButton:AddToClassList("add_button")
    _removeFromTeamButton.text = "Remove"

    _newMonster:Add(_actionName)
    _newMonster:Add(_actionImage)
    _newMonster:Add(_removeFromTeamButton)

    active_team_container:Add(_newMonster)

    _newMonster:RegisterPressCallback(function()
        playerTracker.RemoveMonsterFromTeam(index)
    end)

    _removeFromTeamButton:RegisterPressCallback(function()
        playerTracker.RemoveMonsterFromTeam(index)
    end)

    _newMonster:RegisterLongPressCallback(function()
        uiManager.CloseTeamManagerUI()
        uiManager.OpenMonsterInfoUI(index)
    end)


    return _newMonster
end

function PopulateCollection(actions)
    _monsterScrollView:Clear()

    for i, action in ipairs(actions) do
        CreateMonsterForCollection(action[1], action[2])
    end
    currentSelectedMonster = nil
end
function PopulateTeam(actions)
    active_team_container:Clear()

    for i, action in ipairs(actions) do
        CreateTeam(action[1], action[2])
    end
    currentSelectedMonster = nil
end

function self:Start()
    
    playerTracker.players[client.localPlayer].currentMonsterTeam.Changed:Connect(function()
        InitializeTeamManagerUI()
    end)

    playerTracker.players[client.localPlayer].monsterCollection.Changed:Connect(function()
        InitializeTeamManagerUI()
    end)

    uiManager.CloseTeamManagerUI()
end

close_button:RegisterPressCallback(function()
    uiManager.CloseTeamManagerUI()
end)

function InitializeTeamManagerUI()

    local monsterCollection = playerTracker.players[client.localPlayer].monsterCollection.value
    local monsterTeamIndexes = playerTracker.players[client.localPlayer].currentMonsterTeam.value

    local _teamMonsters = {}
    for i, mosnterIndex in ipairs(monsterTeamIndexes) do
        table.insert(_teamMonsters, {monsterCollection[mosnterIndex], mosnterIndex})
    end

    local _collectionExcludingTeamMembers = {}
    for i, monster in ipairs(monsterCollection) do
        local isInTeam = false
        for j, teamMonster in ipairs(_teamMonsters) do
            if monster == teamMonster[1] then
                isInTeam = true
                break
            end
        end
        if not isInTeam then
            table.insert(_collectionExcludingTeamMembers, {monster, i})
        end
    end

    PopulateCollection(_collectionExcludingTeamMembers)
    PopulateTeam(_teamMonsters)

    -- playerTracker.TrackPlayers(client, OnCharacterInstantiate)
end