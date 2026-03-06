--!Type(Module)

-- Helper function to check if a character is CJK (Chinese, Japanese, Korean)
function isCJKCharacter(char)
    if not char or #char == 0 then return false end
    
    local byte1 = char:byte(1)
    if not byte1 then return false end
    
    -- Check for CJK Unicode ranges
    if #char >= 3 then
        local byte2 = char:byte(2) or 0
        local byte3 = char:byte(3) or 0
        
        -- CJK Unified Ideographs (U+4E00-U+9FFF)
        if byte1 == 0xE4 and byte2 >= 0xB8 and byte2 <= 0xBF then return true end
        if byte1 >= 0xE5 and byte1 <= 0xE9 and byte2 >= 0x80 and byte2 <= 0xBF then return true end
        
        -- Hiragana (U+3040-U+309F)
        if byte1 == 0xE3 and byte2 == 0x81 and byte3 >= 0x80 and byte3 <= 0xBF then return true end
        if byte1 == 0xE3 and byte2 == 0x82 and byte3 >= 0x80 and byte3 <= 0x9F then return true end
        
        -- Katakana (U+30A0-U+30FF)
        if byte1 == 0xE3 and byte2 == 0x82 and byte3 >= 0xA0 and byte3 <= 0xBF then return true end
        if byte1 == 0xE3 and byte2 == 0x83 and byte3 >= 0x80 and byte3 <= 0xBF then return true end
        
        -- Hangul Syllables (U+AC00-U+D7AF)
        if byte1 >= 0xEA and byte1 <= 0xED then return true end
    end
    
    return false
end

-- Helper function to check if text contains CJK characters
function containsCJKCharacters(text)
    if not text or #text == 0 then return false end
    
    local i = 1
    while i <= #text do
        local byte = text:byte(i)
        local charLen = 1
        if byte >= 240 then charLen = 4
        elseif byte >= 224 then charLen = 3
        elseif byte >= 192 then charLen = 2
        end
        local char = text:sub(i, i + charLen - 1)
        i = i + charLen
        
        if isCJKCharacter(char) then
            return true
        end
    end
    
    return false
end

-- Helper function to adjust the Y scale of the NPC avatar based on its rig
function fixAvatarYscale(npcAvatar :Character) 
    local avatarScale = npcAvatar.transform.localScale

    local rigTransform = npcAvatar.transform:Find("Rig")
    if rigTransform then
        local rigScaleY = rigTransform.localScale.y
        if rigScaleY ~= 0 then
            local ratio = avatarScale.y / rigScaleY
            npcAvatar.transform.localScale = Vector3.new(
                avatarScale.x,
                ratio, -- set Y to the ratio
                avatarScale.z
            )
        else
            print("Rig Y scale is 0, cannot divide")
        end
    else
        print("Could not find Rig child")
    end
end