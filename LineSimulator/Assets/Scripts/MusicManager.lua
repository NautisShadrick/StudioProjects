--!Type(Module)

--!SerializeField
local outsideMusic: AudioShader = nil
--!SerializeField
local insideMusic: AudioShader = nil

function SwitchMusic()
    Audio:StopMusic(false)
    Audio:PlayMusic(insideMusic, 1, false, true)
end

function self:ClientStart()
    Audio:PlayMusic(outsideMusic, 1, false, true)
end