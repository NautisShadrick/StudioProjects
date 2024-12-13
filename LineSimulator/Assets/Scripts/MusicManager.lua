--!Type(Module)

--!SerializeField
local outsideMusic: AudioShader = nil
--!SerializeField
local insideMusic: AudioShader = nil

local gameManager = require("GameManager")

function PlayInside()
    Audio:StopMusic(false)
    Audio:PlayMusic(insideMusic, 1, false, true)
end

function PlayOutside()
    Audio:StopMusic(false)
    Audio:PlayMusic(outsideMusic, 1, false, true)
end

function self:ClientStart()
    Audio:PlayMusic(outsideMusic, 1, false, true)

    gameManager.EnterParty:Connect(function()
        PlayInside()
    end)

    gameManager.LeaveParty:Connect(function()
        PlayOutside()
    end)
end