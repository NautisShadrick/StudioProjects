--!Type(Client)

local gameManager = require("GameManager")
local playerTracker = require("PlayerTracker")

local tappedPlayer = nil

function self:ClientAwake()
    local tapHandler = self.gameObject:GetComponent(TapHandler)

    tapHandler.Tapped:Connect(function()

        if tappedPlayer == nil then print(" I DONT HAVE A PLAYER"); return end
        if tappedPlayer == client.localPlayer then return end


        if playerTracker.players[tappedPlayer].isReady.value == false then return end
        if gameManager.localPlayerIsResponding then return end
        gameManager.StartChallenge(tappedPlayer)
    end)

end

function self:ClientStart()
    tappedPlayer = self.gameObject.transform.parent.gameObject:GetComponent(Character).player
end