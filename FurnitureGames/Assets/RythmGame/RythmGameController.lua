--!Type(ClientAndServer)

--!SerializeField
local SongFile : AudioShader = nil

local mySongData : SongEntry = nil 

--!SerializeField
local gameUI : RythmGameMainHud = nil
--!SerializeField
local RewardParticlesUI : RewardParticle = nil
--!SerializeField
local Mainmenu : RythmGameMenuUI = nil

-- Active arrows per direction (0=Left, 1=Down, 2=Up, 3=Right)
-- Each entry is a table: { spawnTime, targetTime, active }
local activeArrows = {
    [0] = {},
    [1] = {},
    [2] = {},
    [3] = {},
}

-- Timing windows (in seconds)
local PERFECT_WINDOW = 0.1
local GOOD_WINDOW = 0.2
local OK_WINDOW = 0.35

local PERFECT_SCORE = 100
local GOOD_SCORE = 70
local OK_SCORE = 50

-- How long arrow takes to reach the button
local ARROW_TRAVEL_TIME = 2.0

function SpawnArrow(direction)
    local spawnTime = Time.time
    local targetTime = spawnTime + ARROW_TRAVEL_TIME

    local arrowData = {
        spawnTime = spawnTime,
        targetTime = targetTime,
        active = true
    }

    table.insert(activeArrows[direction], arrowData)
    gameUI.CreateArrow(direction)

    -- Auto-miss after arrow passes (give a little grace period)
    Timer.After(ARROW_TRAVEL_TIME + OK_WINDOW + 0.1, function()
        if arrowData.active then
            arrowData.active = false
            --print("MISS - Too late! Direction: " .. direction)
        end
    end)
end

function TryHit(direction)
    local arrows = activeArrows[direction]
    if #arrows == 0 then
        return "miss", 0 , 0
    end

    -- Get the oldest arrow for this direction
    local arrowData = arrows[1]
    if not arrowData.active then
        table.remove(arrows, 1)
        return TryHit(direction) -- Try next arrow
    end

    local currentTime = Time.time
    local timeDiff = math.abs(currentTime - arrowData.targetTime)

    -- Check if too early (arrow hasn't arrived yet)
    if currentTime < arrowData.targetTime - OK_WINDOW then
        return "miss", 0 , 0
    end

    -- Mark as hit and remove
    arrowData.active = false
    table.remove(arrows, 1)

    -- Determine accuracy
    if timeDiff <= PERFECT_WINDOW then
        print("PERFECT! Direction: " .. direction .. " Diff: " .. timeDiff)
        return "perfect", timeDiff, PERFECT_SCORE
    elseif timeDiff <= GOOD_WINDOW then
        print("GOOD! Direction: " .. direction .. " Diff: " .. timeDiff)
        return "good", timeDiff , GOOD_SCORE
    elseif timeDiff <= OK_WINDOW then
        print("OK! Direction: " .. direction .. " Diff: " .. timeDiff)
        return "ok", timeDiff , OK_SCORE
    else
        print("MISS! Direction: " .. direction .. " Diff: " .. timeDiff)
        return "miss", timeDiff , 0
    end
end

function self:ClientStart()
    -- Register button press callbacks directly
    for dir, button in pairs(gameUI.Buttons) do
        button:RegisterPressCallback(function()
            local message, timeDiff, score = TryHit(dir)
            print(typeof(message), typeof(timeDiff), typeof(score))
            RewardParticlesUI.TicketAward(score, button)
        end)
    end
    gameUI.gameObject:SetActive(false)
    Mainmenu.gameObject:SetActive(false)
end

local currentBeatTimer = nil
function StartGameWithSong(songData : SongEntry)
    mySongData = songData
    gameUI.gameObject:SetActive(true)
    Mainmenu.gameObject:SetActive(false)

    local audioFile = songData.GetSongShader()
    local timeBetweenBeats = 60 / songData.GetBPM()

    if currentBeatTimer then
        currentBeatTimer:Stop()
        currentBeatTimer = nil
    end

    currentBeatTimer = Timer.Every(timeBetweenBeats, function()
        SpawnArrow(math.random(0,3))
    end)
    Timer.After(2, function()
        audioFile:Play()
    end)

end

function self:OnTriggerEnter(collider: Collider)
    local char = collider.gameObject:GetComponent(Character)
    if not char then return end
    local player = char.player
    if not player then return end
    if player == client.localPlayer then
        Mainmenu.gameObject:SetActive(true)

    end
end

function self:OnTriggerExit(collider: Collider)
    local char = collider.gameObject:GetComponent(Character)
    if not char then return end
    local player = char.player
    if not player then return end
    if player == client.localPlayer then
        Mainmenu.gameObject:SetActive(false)
    end
end