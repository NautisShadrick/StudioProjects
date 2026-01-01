--!Type(Client)

local uiManager = require("EventUIModule") -- Import UIManager for UI operations.

local tapHandler = nil

function self:Start()
    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(function()
        uiManager.EndTutorial()
    end)
end