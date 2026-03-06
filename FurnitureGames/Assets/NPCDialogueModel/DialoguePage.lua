--!Type(ScriptableObject)

--!SerializeField
local Messages: {DialogueTextBlock} = {}
--!SerializeField
local responses: {string} = {}
--!SerializeField
local responseIDs: {string} = {}
--!SerializeField
local Chunks: {DialogueChunk} = {}
--!SerializeField
local NPCEmote: string = ""
--!SerializeField
local PageImage: Texture = nil
--!SerializeField
local Sound: AudioShader = nil
--!SerializeField
local npcOutfit: CharacterOutfit = nil
--!SerializeField
local showNPC: boolean = true
--!SerializeField
local nameOverride: string = ""
--!SerializeField
local bgOverride: Texture = nil
--!SerializeField
local npcImageOverride: Texture2D = nil

function SetMessage(id, message)
    Messages[id].SetMessage(message)
end

function GetMessages()
    return Messages
end

function GetResponses()
    return responses
end

function GetNewChunks()
    return Chunks
end

function GetResponseIDs()
    return responseIDs
end

function GetNPCEmote()
    return NPCEmote
end

function GetPageImage()
    return PageImage
end

function GetSound()
    return Sound
end

function GetNPCOutfit()
    return npcOutfit
end

function GetShowNPC()
    return showNPC
end

function GetNameOverride()
    return nameOverride
end

function GetBGOverride()
    return bgOverride
end

function GetNPCImageOverride()
    return npcImageOverride
end