--!Type(UI)

--!Bind
local action_button_main : VisualElement = nil
--!Bind
local button_label : Label = nil
--!Bind
local wallet_label : Label = nil

local GameManager = require("GameManager")

local myPlace = 0

action_button_main:RegisterPressCallback(function()
    print("Requesting to Skip the sucker infront of me")
    GameManager.skipRequest:FireServer()
end)

function self:Awake()
    GameManager.UpdateWalletEvent:Connect(function(player, wallet)
        if player ~= client.localPlayer then return end
        wallet_label.text = "$" .. wallet
    end)

    GameManager.UpdatePlaceEvent:Connect(function(player, place)
        myPlace = place
        button_label.text = "Skip for $" .. GetSkipCost()
    end)
end

function GetSkipCost()
    return math.floor(100 / myPlace)
end
