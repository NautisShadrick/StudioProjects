--!Type(UI)

--!Bind
local Icon: VisualElement = nil
--!Bind
local Title: Label = nil
--!Bind
local Description: Label = nil
--!Bind
local button_label: Label = nil
--!Bind
local purchase_button_main: VisualElement = nil
--!Bind
local exit: VisualElement = nil

local myAction = ""

local uiManager = require("UIManager")
local gameManager = require("GameManager")

function OpenPopup(_Title: string, _Description: string, Price: number, iconID: string, actionID: string)
    Title.text = _Title
    Description.text = _Description
    button_label.text = "$" .. tostring(Price)
    Icon:ClearClassList()
    Icon:AddToClassList("item_icon")
    Icon:AddToClassList(iconID)
    myAction = actionID

    local _playerHasEnoughMoney = gameManager.players[client.localPlayer].wallet.value >= Price
    purchase_button_main:EnableInClassList("disabled", not _playerHasEnoughMoney)
end

purchase_button_main:RegisterPressCallback(function()
    uiManager.DoAction(myAction)
    uiManager.CloseConfirmationPopup()
end)

exit:RegisterPressCallback(function()
    uiManager.CloseConfirmationPopup()
end)