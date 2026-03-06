--!Type(ScriptableObject)

-- One string, one chunk per line: [#RRGGBB][animID][message text]
-- Example:
--   [#F2F2F2][0][Hello there!]
--   [#FF6666][1][Wobbly text!]
-- animID: 0 = none, 1 = wave, 2 = bounce
--!SerializeField
local messagesData: string = ""
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

-- Scans messagesData for all [#RRGGBB][animID][message text] triplets.
-- Works whether entries are on separate lines or all on one line.
-- Note: message text cannot contain ']'
function GetMessages()
    local parsed = {}
    for colorStr, animStr, msg in messagesData:gmatch("%[([^%]]+)%]%[([^%]]+)%]%[([^%]]*)%]") do
        local color = Color.new(0.949, 0.949, 0.949)
        if colorStr:sub(1, 1) == "#" then
            local hex = colorStr:sub(2)
            local r = (tonumber(hex:sub(1, 2), 16) or 242) / 255
            local g = (tonumber(hex:sub(3, 4), 16) or 242) / 255
            local b = (tonumber(hex:sub(5, 6), 16) or 242) / 255
            local a = #hex >= 8 and (tonumber(hex:sub(7, 8), 16) or 255) / 255 or 1
            color = Color.new(r, g, b, a)
        end
        local animID = tonumber(animStr) or 0
        local message = msg
        parsed[#parsed + 1] = {
            GetMessageData = function()
                return message, animID, color, false
            end
        }
    end
    return parsed
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