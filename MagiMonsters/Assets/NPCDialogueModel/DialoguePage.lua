--!Type(ScriptableObject)

--!SerializeField
local Messages: {DialogueTextBlock} = {}
--!SerializeField
local responses: {string} = {}
--!SerializeField
local responseIDs: {string} = {}
--!SerializeField
local Chunks: {DialogueChunk} = {}

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