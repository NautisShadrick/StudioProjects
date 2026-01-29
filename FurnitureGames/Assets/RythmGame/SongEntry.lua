--!Type(ScriptableObject)

--!SerializeField
local SongShader : AudioShader = nil
function GetSongShader()
    return SongShader
end
--!SerializeField
local SongName : string = ""
function GetName()
    return SongName
end
--!SerializeField
local SongBPM : number = 120
function GetBPM()
    return SongBPM
end
--!SerializeField
local SongDuration : number = 120
function GetDuration()
    return SongDuration
end