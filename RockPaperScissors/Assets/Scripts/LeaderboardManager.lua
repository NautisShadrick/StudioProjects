--!Type(Module)
local EntryRequest = Event.new("EntryRequest")
local EntryRepsonse = Event.new("EntryResponse")

local LocalEntryRequest = Event.new("LocalEntryRequest")
local LocalEntryResponse = Event.new("LocalEntryResponse")

local gamesPlayedLeaderboardID = "games_played_lb"

local requestConnection : EventConnection | nil = nil
local localRequestConnection : EventConnection | nil = nil

------- Client -------

function RequestEntries(cb)
    EntryRequest:FireServer()
    requestConnection = EntryRepsonse:Connect(function(entries)
        if requestConnection then
            requestConnection:Disconnect()
            requestConnection = nil
        end
        print("Entries Recieved from Server")
        print(#entries)
        if cb then cb(entries) end
    end)
end

function RequestLocalEntry(cb)
    LocalEntryRequest:FireServer()
    localRequestConnection = LocalEntryResponse:Connect(function(entry)
        if localRequestConnection then
            localRequestConnection:Disconnect()
            localRequestConnection = nil
        end
        print("Local Entry Recieved from Server")
        if cb then cb(entry) end
    end)
end

function self:ClientAwake()
end

------- Server -------

function GetEntries(cb)
    Leaderboard.GetEntries(gamesPlayedLeaderboardID, 0, 25, function(entries, error)
        if error ~= 0 then print(tostring(error)); return end
        --print(typeof(entries))

        for i, entry in ipairs(entries) do
            print("Entry: " .. entry.name .. " has a score of " .. entry.score)
        end
        print(#entries)
        cb(entries)
    end)
end

function GetPlayerEntry(player: Player, cb)
    Leaderboard.GetEntryForPlayer(gamesPlayedLeaderboardID, player, function(entry, error)
        if error ~= 0 then print(tostring(error)); return end
        print("Fetched Player Entry")
        cb(entry)
    end)
end

function IncrementPlayerScore(player: Player)
    Leaderboard.IncrementScoreForPlayer(gamesPlayedLeaderboardID, player, 1, function(entry, error)
        if error ~= 0 then print(tostring(error)); return end
        print("New Entry: " .. entry.name .. " has a score of " .. entry.score)
    end)
end

function self:ServerAwake()
    EntryRequest:Connect(function(player)
        GetEntries(function(entries)
            print("Firing Entry Response")
            print(#entries)
            print(typeof(entries))

            local _TableEntries = {}
            for i, entry in ipairs(entries) do
                table.insert(_TableEntries, {name = entry.name, score = entry.score, rank = entry.rank})
            end

            EntryRepsonse:FireClient(player,_TableEntries)
        end)
    end)

    LocalEntryRequest:Connect(function(player)
        GetPlayerEntry(player, function(entry)

            local _TableEntry = {}
            if entry == nil then
                print("DEFAULTS")
                _TableEntry = {name = "Play a game to join", score = 0, rank = 0}
            else
                _TableEntry = {name = entry.name, score = entry.score, rank = entry.rank}
            end
            LocalEntryResponse:FireClient(player, _TableEntry)
        end)
    end)
end