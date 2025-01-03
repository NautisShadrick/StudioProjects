--!Type(UI)

--!Bind
local timer_label: Label = nil


function timeUntil(targetYear, targetMonth, targetDay, targetHour, targetMinute)
    -- Get the current time in UTC
    local currentTime = os.time(os.date("!*t"))

    -- Create the target time table in UTC
    local targetTime = os.time({
        year = targetYear,
        month = targetMonth,
        day = targetDay,
        hour = targetHour or 0,
        min = targetMinute or 0,
        sec = 0
    })

    -- Calculate the difference in seconds
    local diffInSeconds = os.difftime(targetTime, currentTime)

    -- If the time has already passed, return "0:0:0"
    if diffInSeconds <= 0 then
        return "0:0:0:0"
    end

    -- Convert the difference to days, hours, and minutes
    local days = math.floor(diffInSeconds / (24 * 3600))
    diffInSeconds = diffInSeconds % (24 * 3600)

    local hours = math.floor(diffInSeconds / 3600)
    diffInSeconds = diffInSeconds % 3600

    local minutes = math.floor(diffInSeconds / 60)

    local sec = diffInSeconds % 60

    -- Return the formatted string
    return string.format("%d:%02d:%02d:%02d", days, hours, minutes, sec)
end

-- Example usage
local targetYear = 2025
local targetMonth = 1
local targetDay = 10  -- Assuming today is January 3rd
local targetHour = 12  -- Target time is 12:00 PM
local targetMinute = 0
timeUntil(targetYear, targetMonth, targetDay, targetHour, targetMinute)

function self:Start()
    --local updateTimer = Timer.Every(1, function()
    --    local timeLeft = timeUntil(targetYear, targetMonth, targetDay, targetHour, targetMinute)
    --    timer_label.text = timeLeft
    --end)
end