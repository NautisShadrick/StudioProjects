--!Type(UI)

--!Bind
local action_button_main : VisualElement = nil
--!Bind
local button_label : Label = nil
--!Bind
local wallet_label : Label = nil

local GameManager = require("GameManager")

local myPlace = 0


function CheckWallet()
    local currentMoney = GameManager.GetMoney()
    local skipCost = GameManager.GetSkipCost(client.localPlayer)
    local hasEnoughMoney = currentMoney >= skipCost
    return hasEnoughMoney
end

action_button_main:RegisterPressCallback(function()
    if not CheckWallet() then return end
    print("Requesting to Skip the sucker infront of me")
    GameManager.skipRequest:FireServer()
end)

function self:Awake()

    GameManager.UpdateWalletEvent:Connect(function(player, wallet)
        if player ~= client.localPlayer then return end
        wallet_label.text = "$" .. wallet
        UpdateButton()
    end)
    GameManager.UpdatePlaceEvent:Connect(function(player, place)
        myPlace = place
        button_label.text = "Skip for $" .. GameManager.GetSkipCost(client.localPlayer)
        UpdateButton()
    end)

end

function UpdateButton()
    action_button_main:EnableInClassList("disabled", not CheckWallet())
end