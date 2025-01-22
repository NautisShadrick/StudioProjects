--!Type(UI)

--!Bind
local four_button_menu: UILuaView = nil
--!Bind
local buttons_root: VisualElement = nil
--!Bind
local back_button: Label = nil

export type menuButton = {
    title: string,
    callback: () -> ()
}

local playerTracker = require("PlayerTracker")
local gameManger = require("GameManager")
local actionLibrary = require("ActionLibrary")
local uiManager = require("UIManager")

function CreateButton(button: menuButton)
    local _button = VisualElement.new()
    _button:AddToClassList("button-base")

    local _title = Label.new()
    _title:AddToClassList("button-title")
    _title.text = button.title or "Button"

    _button:Add(_title)

    buttons_root:Add(_button)


    _button:RegisterPressCallback(button.callback)
end

function UpdateButtons(buttons:{menuButton})
    buttons_root:Clear()
    for i, button in ipairs(buttons) do
        CreateButton(button)
    end
end

local FightButtonCallback = function()
    print("Fight Button Pressed")
    local _availableActionButtons = {}

    local playerMonster = playerTracker.GetPlayerMonsterData()
    local _actionIDs = playerMonster.actionIDs

    print(#_actionIDs)

    for i = 1, 4 do
        local actionID = _actionIDs[i]
        if actionID then
            table.insert(
                _availableActionButtons, 
                {
                    title = actionID,
                    callback = function() gameManger.ClientDoAction(actionID) end
                }
            )
        else
            table.insert(
                _availableActionButtons, 
                {
                    title = "-",
                    callback = function() end
                }
            )
        end
    end

    UpdateButtons(_availableActionButtons)
end

local ItemsButtonCallback = function()
    print("Items Button Pressed")
end

local MonstersButtonCallback = function()
    print("Monsters Button Pressed")
    local _myMonsters = playerTracker.GetPlayerMonsterCollection()
    local _monsterButtons = {}
    
    for i = 1, 4 do
        local monster = _myMonsters[i]
        if monster then
            table.insert(
                _monsterButtons,
                {
                title = monster.name,
                callback = function() print(monster.name) end
                }
            )
        else
            table.insert(
                _monsterButtons,
                {
                title = "-",
                callback = function() end
                }
            )
        end
    end

    UpdateButtons(_monsterButtons)
end

local FleeButtonCallback = function()
    print("Flee Button Pressed")
end

Menu_One =
{
    {title = "Fight", callback = FightButtonCallback},
    {title = "Items", callback = ItemsButtonCallback},
    {title = "Monsters", callback = MonstersButtonCallback},
    {title = "Flee", callback = FleeButtonCallback}
}

UpdateButtons(Menu_One)

back_button:RegisterPressCallback(function()
    UpdateButtons(Menu_One)
end)
