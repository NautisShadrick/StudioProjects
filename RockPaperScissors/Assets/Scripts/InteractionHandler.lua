--!Type(Client)

local gameManager = require("GameManager")

local tappedPlayer = nil

function self:ClientAwake()
    local tapHandler = self.gameObject:GetComponent(TapHandler)

    tapHandler.Tapped:Connect(function()
        if gameManager.localPlayerIsResponding then return end
        if tappedPlayer == nil then print(" I DONT HAVE A PLAYER"); return end
        gameManager.StartChallenge(tappedPlayer)
    end)

end

function self:ClientStart()
    tappedPlayer = self.gameObject.transform.parent.gameObject:GetComponent(Character).player
end