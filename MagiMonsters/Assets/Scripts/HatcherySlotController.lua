--!Type(Client)

--!SerializeField
local eggSlot : GameObject = nil
--!SerializeField
local meterUI : GameObject = nil
--!SerializeField
local slotId : number = 1
--!SerializeField
local eggSprite : SpriteRenderer = nil

local playerTracker = require("PlayerTracker")
local hatcheryController = require("HatcheryController")
local uiManager = require("UIManager")
local monsterLibrary = require("MonsterLibrary")

local tapHandler = nil
local meterUIScript = nil

local hasEgg = false
local isReady = false

function GetMonsterDataInSlot(slotId)
    local playerinfo = playerTracker.players[client.localPlayer]
    local _hatcheryData = playerinfo.hatcheryData.value
    for i, _hatcherySlot in ipairs(_hatcheryData) do
        if _hatcherySlot.slotId == slotId then
            return monsterLibrary.monsters[_hatcherySlot.monster]
        end
    end
    return nil
end

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
                --uiManager.OpenNameMonsterUI(slotId)
                uiManager.OpenHatchEggUI(slotId)
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

            local monsterData = GetMonsterDataInSlot(slotId)
            local element = monsterData.GetElement()

            eggSprite.sprite = monsterLibrary.eggSprites[element]
            meterUIScript.SetIcon(monsterLibrary.eggTextures[element])
            
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