--!Type(Module)

--!SerializeField
local BGMusic : AudioShader = nil
--!SerializeField
local wavesSound : AudioShader = nil
--!SerializeField
local matchSound : AudioShader = nil
--!SerializeField
local passSound : AudioShader = nil
--!SerializeField
local shimmerLoop : AudioShader = nil
--!SerializeField
local rustleSound : AudioShader = nil
--!SerializeField
local popSound : AudioShader = nil

audioClips = {
    ["waves"] = wavesSound,
    ["match"] = matchSound,
    ["pass"] = passSound,
    ["shimmer"] = shimmerLoop,
    ["rustle"] = rustleSound,
    ["pop"] = popSound
}

function PlaySound(soundName)
    if audioClips[soundName] ~= nil then
        Audio:PlayShader(audioClips[soundName])
    else
        print("Sound not found: " .. soundName)
    end
end

function self:ClientAwake()
    Audio:PlayMusic(BGMusic, 0.5, true, true)
    Audio:PlaySound(wavesSound, self.gameObject, .3, 1, false, true)
end