--!Type(Module)

--!SerializeField
local bgm : AudioShader = nil

--!SerializeField
local sounds : {AudioShader} = {}

function PlaySound(id: number)
    Audio:PlayShader(sounds[id])
end

function self:ClientStart()
    Audio:PlayMusic(bgm, .85, true, true)
end