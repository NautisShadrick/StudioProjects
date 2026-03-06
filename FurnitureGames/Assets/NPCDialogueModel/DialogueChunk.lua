--!Type(ScriptableObject)

--!SerializeField
local Pages: {DialoguePage} = {}

--!SerializeField
local isStoryBeat : boolean = false

function GetPages()
    return Pages
end

function IsStoryBeat()
    return isStoryBeat
end