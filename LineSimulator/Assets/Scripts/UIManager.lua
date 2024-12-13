--!Type(Module)

--!SerializeField
local ActionButtonOBJ: GameObject = nil
--!SerializeField
local HudButtonsOBJ: GameObject = nil
--!SerializeField
local PurchaseConfirmationOBJ: GameObject = nil

--!SerializeField
local testData: ScriptableObject = nil

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
end