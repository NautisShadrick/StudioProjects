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

local refreshEvent = Event.new("RefreshEvent")

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
local itemLibrary = require("ItemLibrary")
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

function UseItemButton(itemID: string)
    print("Using item", itemID)
    gameManger.UseItem(itemID)
    refreshEvent:Fire("Items")
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
                    elementID = actionLibrary.GetActionByID(actionID).GetActionElement(),
                    callback = function() gameManger.ClientDoAction(actionID) end
                }
            )
            --print(actionLibrary.GetActionByID(actionID).GetActionElement())

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
    local _availableItemButtons : {menuButton} = {}
    local _playerItems = playerTracker.GetPlayerInventory()

    local _playerConsumables = {}
    for j, item in ipairs(_playerItems) do
        local itemData = itemLibrary.GetConsumableByID(item.id)
        if itemData then
            table.insert(_playerConsumables, itemData)
        end
    end

    for i = 1, math.ceil(#_playerConsumables / 4) * 4 do
        local itemData = _playerConsumables[i]
        if itemData then
            table.insert(
                _availableItemButtons,
                {
                    title = itemData.GetDisplayName(),
                    elementID = itemData.GetElement(),
                    callback = function()
                        UseItemButton(itemData.GetID())
                    end
                }
            )
        else
            table.insert(
                _availableItemButtons,
                {
                    title = "-",
                    elementID = nil,
                    callback = function() end
                }
            )
        end
    end

    print("Available items: ", #_availableItemButtons)
    for i, item in ipairs(_availableItemButtons) do print(typeof(item)) end

    currentButtonsPage = 0
    currentTotalButtons = _availableItemButtons
    UpdateButtons(_availableItemButtons)
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
    gameManger.Flee()
end

Menu_One =
{
    {title = "Fight", elementID = nil, callback = FightButtonCallback},
    {title = "Items", elementID = nil, callback = ItemsButtonCallback},
    {title = "Monsters", elementID = nil, callback = MonstersButtonCallback},
    {title = "Flee", elementID = nil, callback = FleeButtonCallback},
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

function self:Start()
    refreshEvent:Connect(function(event)
        if event == "Items" then
            ItemsButtonCallback()
        elseif event == "Monsters" then
            MonstersButtonCallback()
        end
    end)
end