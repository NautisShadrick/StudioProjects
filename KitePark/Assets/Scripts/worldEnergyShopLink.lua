--!Type(Client)

local uiManager = require("EventUIModule")

local tapHandler = nil

function self:Start()
    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(function()
        uiManager.OpenEnergyShop()
    end)
end