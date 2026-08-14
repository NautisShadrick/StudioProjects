--!Type(Client)

--!SerializeField
local musicClip : AudioShader = nil
--!SerializeField
--!Range(0,1)
local volume : number = 0.25

function self:Start()
    Timer.After(60, function()
        Audio:PlayMusic(musicClip, volume)
    end)
end