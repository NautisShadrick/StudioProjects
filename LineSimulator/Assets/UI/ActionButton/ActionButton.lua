--!Type(UI)

--!Bind
local action_button_main : VisualElement = nil
--!Bind
local button_label : Label = nil
--!Bind
local wallet_label : Label = nil

local GameManager = require("GameManager")

local myPlace = 0

local free = false

function CheckWallet()
    local currentMoney = GameManager.GetMoney()
    local skipCost = GameManager.GetSkipCost(client.localPlayer)
    local hasEnoughMoney = currentMoney >= skipCost
    return hasEnoughMoney
end

action_button_main:RegisterPressCallback(function()
    if not CheckWallet() or GameManager.GetPlace() == 1 then return end
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
        if GameManager.GetPlace() == 0 then return end
        myPlace = place
        button_label.text = "Skip for $" .. GameManager.GetSkipCost(client.localPlayer)
        UpdateButton()
    end)
    GameManager.UpdateTimerEvent:Connect(function(timer)
        if GameManager.GetPlace() > 1 then return end
        button_label.text = "Toilet Time: " .. tostring(timer)
        action_button_main:EnableInClassList("disabled", not CheckWallet())
    end)

    GameManager.EnterParty:Connect(function()
        action_button_main:EnableInClassList("hidden", true)
    end)

    GameManager.LeaveParty:Connect(function()
        action_button_main:EnableInClassList("hidden", false)
    end)

end

function UpdateButton()
    action_button_main:EnableInClassList("disabled", not CheckWallet())
end