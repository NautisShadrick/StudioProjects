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

function OpenPopup(_Title: string, _Description: string, Price: number, iconID: string, actionID: string)
    Title.text = _Title
    Description.text = _Description
    button_label.text = "$" .. tostring(Price)
    Icon:AddToClassList(iconID)
    myAction = actionID
end

purchase_button_main:RegisterPressCallback(function()
    uiManager.DoAction(myAction)
    uiManager.CloseConfirmationPopup()
end)

exit:RegisterPressCallback(function()
    uiManager.CloseConfirmationPopup()
end)