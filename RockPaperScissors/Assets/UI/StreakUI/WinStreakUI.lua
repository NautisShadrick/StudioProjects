--!Type(UI)

--!Bind
local streak_lable: Label = nil

function UpdateWinStreak(streak: number)
    print("Updating win streak to " .. tostring(streak))
    streak = streak or 0
    local _streakText = tostring(streak)
    streak_lable.text = _streakText
end