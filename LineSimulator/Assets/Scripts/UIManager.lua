--!Type(Module)

--!SerializeField
local ActionButtonOBJ: GameObject = nil
--!SerializeField
local HudButtonsOBJ: GameObject = nil
--!SerializeField
local PurchaseConfirmationOBJ: GameObject = nil

local actionButtonScript: ActionButton = nil
local hudButtonsScript: HudButtons = nil
local purchaseConfirmationScript: PurchaseConfirmation = nil

local gameManager = require("GameManager")

function self:ClientStart()
    actionButtonScript = ActionButtonOBJ:GetComponent(ActionButton)
    hudButtonsScript = HudButtonsOBJ:GetComponent(HudButtons)
    purchaseConfirmationScript = PurchaseConfirmationOBJ:GetComponent(PurchaseConfirmation)
    PurchaseConfirmationOBJ:SetActive(false)
end

function HideMainUI()
    ActionButtonOBJ:SetActive(false)
    HudButtonsOBJ:SetActive(false)
end
function ShowMainUI()
    ActionButtonOBJ:SetActive(true)
    HudButtonsOBJ:SetActive(true)
end

function ShowConfirmationPopup(_Title: string, _Description: string, Price: number, iconID: string, actionID: string)
    HideMainUI()
    PurchaseConfirmationOBJ:SetActive(true)
    purchaseConfirmationScript.OpenPopup(_Title, _Description, Price, iconID, actionID)
end

function CloseConfirmationPopup()
    PurchaseConfirmationOBJ:SetActive(false)
    ShowMainUI()
end

function DoAction(actionID: string)
    if actionID == "action_fart" then
        gameManager.FartBackwards()
    end
    if actionID == "action_bomb" then
        gameManager.FartBomb()
    end
    if actionID == "action_poop" then
        gameManager.Poop()
    end
    if actionID == "action_toilet" then
        gameManager.Party()
    end
    if actionID == "fire_alarm" then
        gameManager.FireAlarm()
    end
end