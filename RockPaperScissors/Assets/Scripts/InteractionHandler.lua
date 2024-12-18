--!Type(Client)

local gameManager = require("GameManager")

function self:ClientAwake()
    local tapHandler = self.gameObject:GetComponent(TapHandler)
    print("Got handler")
    tapHandler.Tapped:Connect(function()
        print("Tapped")
        gameManager.StartChallenge()
    end)
end