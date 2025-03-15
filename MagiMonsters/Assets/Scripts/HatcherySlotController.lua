--!Type(Client)

--!SerializeField
local eggSlot : GameObject = nil
--!SerializeField
local meterUI : GameObject = nil
--!SerializeField
local slotId : number = 1

local playerTracker = require("PlayerTracker")
local hatcheryController = require("HatcheryController")
local uiManager = require("UIManager")

local tapHandler = nil
local meterUIScript = nil

local hasEgg = false
local isReady = false

function self:Start()
    meterUIScript = meterUI:GetComponent(HealthBarUI)
    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(function()
        -- Interacted With do something
        if not hasEgg then
            uiManager.OpenHatcherySelection(slotId)
        else
            if isReady then
                -- Hatch Monster
                print("Hatching Monster")
                uiManager.OpenNameMonsterUI(slotId)
            else
                print("Egg is not ready yet")
                -- Show info
            end
        end
    end)

    hatcheryController.UpdateEggStatsEvent:Connect(function(timeRemaining, totalDuration, updatedSlotId)
        if updatedSlotId == slotId then
            -- This is the info fo this slot
            meterUI:SetActive(true)
            meterUIScript.SyncToRemainingTime(timeRemaining, totalDuration)
            eggSlot:SetActive(true)
            
            hasEgg = true
            if timeRemaining <= 0 then
                -- Egg is ready
                isReady = true
                meterUI:SetActive(false)
            end
        end
    end)

    hatcheryController.SlotHatchedEvent:Connect(function(updatedSlotId)
        if updatedSlotId == slotId then
            eggSlot:SetActive(false)
            hasEgg = false
            isReady = false
        end
    end)
end