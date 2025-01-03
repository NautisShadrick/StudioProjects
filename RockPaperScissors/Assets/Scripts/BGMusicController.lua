--!Type(Module)

--!SerializeField
local bgMusic: AudioShader = nil

function self:ClientAwake()
    Audio:PlayMusic(bgMusic, .8, true, true)
end