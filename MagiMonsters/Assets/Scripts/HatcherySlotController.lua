--!Type(Client)

--!SerializeField
local eggSlot : GameObject = nil
--!SerializeField
local meterUI : GameObject = nil

local playerTracker = require("PlayerTracker")
local hatcheryController = require("HatcheryController")

local tapHandler = nil
local meterUIScript = nil

function self:Start()
    meterUIScript = meterUI:GetComponent(HealthBarUI)
    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(function()
        -- Interacted With do something
        print("Interacted with Egg Slot")
        hatcheryController.StartEggRequest:FireServer()
    end)

    hatcheryController.UpdateEggStatsEvent:Connect(function(timeRemaining, totalDuration)
        meterUI:SetActive(true)
        meterUIScript.SyncToRemainingTime(timeRemaining, totalDuration)
        eggSlot:SetActive(true)
    end)
end