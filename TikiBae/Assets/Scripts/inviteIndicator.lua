--!Type(Client)


local tapHandler
local myPlayer

local uiManager = require("UIManager")
local playerTracker = require("PlayerTracker")

function self:Start()

    myPlayer = self.transform.parent.gameObject:GetComponent(Character).player

    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(function()
        if playerTracker.players[myPlayer].currentPartnerID.value ~= "" then
            return
        end
        playerTracker.inviteRequest:FireServer(myPlayer)
    end)

    playerTracker.players[myPlayer].currentPartnerID.Changed:Connect(function(id)
        self.transform:GetChild(0).gameObject:SetActive(id == "")
    end)
end