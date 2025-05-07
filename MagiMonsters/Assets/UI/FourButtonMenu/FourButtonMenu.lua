--!Type(UI)

--!Bind
local four_button_menu: UILuaView = nil
--!Bind
local buttons_root: VisualElement = nil
--!Bind
local back_button: Label = nil
--!Bind
local left_button: VisualElement = nil
--!Bind
local right_button: VisualElement = nil

local currentButtonsPage = 0
local currentTotalButtons = {}

export type menuButton = {
    title: string,
    elementID: string | nil,
    callback: () -> ()
}

local playerTracker = require("PlayerTracker")
local gameManger = require("GameManager")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local uiManager = require("UIManager")

function CreateButton(button: menuButton)
    local _button = VisualElement.new()
    _button:AddToClassList("button-base")

    local elementID = button.elementID
    if elementID and elementID ~= "" then
        local _icon = Image.new()
        _icon:AddToClassList("button-icon")
        _icon.image = uiManager.GetIcon(elementID)
        print(typeof(uiManager.GetIcon(elementID)))
        _button:Add(_icon)

        _button:AddToClassList(elementID)
    end


    local _title = Label.new()
    _title:AddToClassList("button-title")
    _title.text = button.title or "Button"

    _button:Add(_title)

    buttons_root:Add(_button)


    _button:RegisterPressCallback(button.callback)
end

function UpdateButtons(buttons:{menuButton})
    buttons_root:Clear()

    for i = 1 + (4*currentButtonsPage), 4 + (4*currentButtonsPage) do
        CreateButton(buttons[i])
    end

    -- Disable the left and right buttons if there are no more buttons to show in that direction
    if currentButtonsPage == 0 then
        left_button:SetEnabled(false)
    else
        left_button:SetEnabled(true)
    end
    if currentButtonsPage == math.floor(#buttons / 4)-1 then
        right_button:SetEnabled(false)
    else
        right_button:SetEnabled(true)
    end

    --for i, button in ipairs(buttons) do
    --    CreateButton(button)
    --end
end

local FightButtonCallback = function()
    print("Fight Button Pressed")
    local _availableActionButtons : {menuButton} = {}

    local playerMonster = playerTracker.GetPlayerMonsterData()
    local _actionIDs = playerMonster.actionIDs

    for i = 1, math.ceil(#_actionIDs / 4) * 4 do
        local actionID = _actionIDs[i]
        if actionID then
            table.insert(
                _availableActionButtons, 
                {
                    title = actionID,
                    elementID = actionLibrary.actions[actionID].GetActionElement(),
                    callback = function() gameManger.ClientDoAction(actionID) end
                }
            )
            print(actionLibrary.actions[actionID].GetActionElement())

        else
            table.insert(
                _availableActionButtons, 
                {
                    title = "-",
                    elementID = nil,
                    callback = function() end
                }
            )
        end
    end

    currentButtonsPage = 0
    currentTotalButtons = _availableActionButtons
    UpdateButtons(_availableActionButtons)
end

local ItemsButtonCallback = function()
    print("Items Button Pressed")
end

local MonstersButtonCallback = function()
    print("Monsters Button Pressed")
    local _myMonsters = playerTracker.GetPlayerMonsterCollection()
    local _monsterButtons : {menuButton} = {}
    
    for i = 1, 4 do
        local monster = _myMonsters[i]
        if monster then
            table.insert(
                _monsterButtons,
                {
                title = monster.name,
                elementID = monsterLibrary.monsters[monster.speciesName].GetElement(),
                callback = function() gameManger.SwapMonster(i) end
                }
            )
        else
            table.insert(
                _monsterButtons,
                {
                title = "-",
                elementID = nil,
                callback = function() end
                }
            )
        end
    end

    currentButtonsPage = 0
    currentTotalButtons = _monsterButtons
    UpdateButtons(_monsterButtons)
end

local FleeButtonCallback = function()
    print("Flee Button Pressed")
end

Menu_One =
{
    {title = "Fight", elementID = nil, callback = FightButtonCallback},
    {title = "Items", elementID = nil, callback = ItemsButtonCallback},
    {title = "Monsters", elementID = nil, callback = MonstersButtonCallback},
    {title = "Flee", elementID = nil, callback = FleeButtonCallback},
    {title = "extra_1", elementID = nil, callback = function() end},
    {title = "extra_2", elementID = nil, callback = function() end},
    {title = "extra_3", elementID = nil, callback = function() end},
    {title = "extra_4", elementID = nil, callback = function() end}
}

currentTotalButtons = Menu_One
UpdateButtons(Menu_One)

back_button:RegisterPressCallback(function()
    currentButtonsPage = 0
    currentTotalButtons = Menu_One
    UpdateButtons(Menu_One)
end)

left_button:RegisterPressCallback(function()
    print("Left Button Pressed")
    currentButtonsPage = math.max(0, currentButtonsPage - 1)
    UpdateButtons(currentTotalButtons)

end)

right_button:RegisterPressCallback(function()
    print("Right Button Pressed")
    currentButtonsPage = currentButtonsPage + 1
    UpdateButtons(currentTotalButtons)
end)
