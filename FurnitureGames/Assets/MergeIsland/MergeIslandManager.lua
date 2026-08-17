--!Type(Module)

-- MergeIslandManager -- the authoritative engine and persistence layer for Merge Island.
--
-- Merge Island is SINGLE PLAYER PER PLAYER: every player has their own private board. It is
-- still fully server-authoritative -- the client sends intents ("spawn", "move from A to B")
-- and the server decides what actually happens, using the shared rules in MergeIslandConfig.
--
-- Boards are NOT replicated with per-player networked values. That pattern creates matching
-- values on every client for every player, which would push all 49 cells of everyone's board
-- to everyone. Instead the server pushes a full snapshot to the OWNING player only, via
-- FireClient. 49 cells is small enough that a full snapshot per action beats the complexity
-- of delta reconciliation.
--
-- Storage is server-only and rate limited (~10-20 calls/sec), so saves are debounced through
-- a dirty flag and one sweep timer rather than written per merge.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------     CONSTANTS      ------
--------------------------------
local STORAGE_KEY = "MergeIslandState"

-- Persistence pacing. The sweep is what keeps us inside the Storage rate limit: at most
-- MAX_SAVES_PER_SWEEP writes every SAVE_INTERVAL_SECONDS, no matter how fast players merge.
local SAVE_INTERVAL_SECONDS = 5
local MAX_SAVES_PER_SWEEP = 8

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local config = require("MergeIslandConfig")

--------------------------------
------     NETWORKING     ------
--------------------------------
-- Client -> server intents. Every one of these is re-validated server-side; a tampered client
-- gains nothing.
SpawnRequest = Event.new("MIslandSpawnRequest")
MoveRequest = Event.new("MIslandMoveRequest")
-- Sent when a client's HUD comes up, so it does not have to wait for the next mutation to
-- learn the board. Also covers the race where the server finished loading storage before the
-- client was listening.
StateRequest = Event.new("MIslandStateRequest")

-- Server -> owning player only. BoardStateEvent is the truth; the other two are animation
-- triggers, deterministic on receipt (the same split DropFour uses for DiscDroppedEvent).
BoardStateEvent = Event.new("MIslandBoardStateEvent")
ActionRejectedEvent = Event.new("MIslandActionRejectedEvent")
SpawnedEvent = Event.new("MIslandSpawnedEvent")
UnlockedEvent = Event.new("MIslandUnlockedEvent")

--------------------------------
------     LOCAL STATE    ------
--------------------------------
----------- SERVER -------------
-- boards[player] = {
--   cells       -- {Config.Cell}, the authoritative board
--   energy      -- number remaining in this event's pool
--   eventId     -- which event the pool was granted for
--   dirty       -- has changed since the last successful save
--   loaded      -- storage read has completed; intents are refused before this
--   readFailed  -- the storage read ERRORED. We play in memory but NEVER save, because
--                  overwriting a key we failed to read would destroy real progress.
-- }
local boards: {[Player]: any} = {}
local saveTimer: Timer = nil
-- Rotates the starting point of each save sweep so the same players are not always first in
-- line when more are dirty than MAX_SAVES_PER_SWEEP allows.
local saveCursor: number = 0

----------- CLIENT -------------
-- The local player's mirror of their own board. Rendered by the HUD; never trusted for
-- anything the server decides.
local localCells: {any} = {}
local localEnergy: number = 0
local localLoaded: boolean = false
-- Listener lists, so the HUD can subscribe without the manager knowing about the UI.
local boardChangedListeners: {any} = {}
local spawnedListeners: {any} = {}
local unlockedListeners: {any} = {}
local rejectedListeners: {any} = {}

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
----------- SERVER -------------
-- A deep-enough copy of the board for sending or storing. Cells are flat records, so one
-- level of copying is sufficient. Snapshots are cloned rather than sent by reference so a
-- later in-place mutation can never race the serializer.
local function cloneCells(cells): {any}
    local _copy = {}
    for i = 1, config.CELL_COUNT do
        local _cell = cells[i]
        if _cell then
            _copy[i] = {
                state = _cell.state,
                tier = _cell.tier,
            }
        else
            _copy[i] = { state = config.STATE_HIDDEN }
        end
    end
    return _copy
end

local function sendSnapshot(player: Player)
    local _board = boards[player]
    if not _board then
        return
    end
    BoardStateEvent:FireClient(player, {
        cells = cloneCells(_board.cells),
        energy = _board.energy,
        eventId = _board.eventId,
    })
end

local function markDirty(board)
    if board.readFailed then
        return
    end
    board.dirty = true
end

-- Write one player's board to storage. dirty is cleared UP FRONT so a mutation that lands
-- mid-flight re-marks it and gets picked up by the next sweep; a failure re-marks it too, so
-- the write is retried rather than silently dropped.
local function flush(player: Player, board)
    if board.readFailed then
        return
    end
    board.dirty = false
    -- Captured up front: the disconnect path flushes and then drops the player, so reading
    -- player.name inside the callback could happen after they are gone.
    local _name = tostring(player.name)
    Storage.SetPlayerValue(player, STORAGE_KEY, {
        version = config.SAVE_VERSION,
        cells = cloneCells(board.cells),
        energy = board.energy,
        eventId = board.eventId,
    }, function(error)
        if error ~= StorageError.None then
            print("[MergeIslandManager] save failed for " .. _name
                .. " (" .. tostring(error) .. "); will retry")
            board.dirty = true
        end
    end)
end

-- Is a stored payload usable? A board saved under a different grid size or an older cell shape
-- (or a truncated write) must be rejected outright: a half-read board misbehaves subtly, which
-- is much worse to debug than an obviously fresh one.
local function isValidSavedBoard(value): boolean
    if type(value) ~= "table" or type(value.cells) ~= "table" then
        return false
    end
    if value.version ~= config.SAVE_VERSION then
        return false
    end
    for i = 1, config.CELL_COUNT do
        local _cell = value.cells[i]
        if type(_cell) ~= "table" or type(_cell.state) ~= "number" then
            return false
        end
    end
    return true
end

local function freshBoard(): any
    return {
        cells = config.NewBoard(),
        energy = config.ENERGY_POOL_PER_EVENT,
        eventId = config.EVENT_ID,
        dirty = false,
        loaded = true,
        readFailed = false,
    }
end

local function loadBoard(player: Player)
    Storage.GetPlayerValue(player, STORAGE_KEY, function(value, error)
        -- The player may have left while the read was in flight.
        if not boards[player] then
            return
        end

        if error ~= StorageError.None then
            -- Read FAILED (as opposed to "no data"). Let them play, but never save over a key
            -- we could not read -- that is how you delete someone's progress.
            print("[MergeIslandManager] storage read failed for " .. tostring(player.name)
                .. " (" .. tostring(error) .. "); running unsaved this session")
            local _board = freshBoard()
            _board.readFailed = true
            boards[player] = _board
            sendSnapshot(player)
            return
        end

        local _board
        if value == nil then
            -- First time this player has ever opened the game.
            _board = freshBoard()
            _board.dirty = true
        elseif not isValidSavedBoard(value) then
            print("[MergeIslandManager] discarding unreadable saved board for "
                .. tostring(player.name) .. "; starting fresh")
            _board = freshBoard()
            _board.dirty = true
        else
            _board = {
                cells = value.cells,
                energy = tonumber(value.energy) or 0,
                eventId = value.eventId,
                dirty = false,
                loaded = true,
                readFailed = false,
            }
            -- A new event window re-grants the pool. This is what EVENT_ID is for.
            if _board.eventId ~= config.EVENT_ID then
                _board.eventId = config.EVENT_ID
                _board.energy = config.ENERGY_POOL_PER_EVENT
                _board.dirty = true
            end
        end

        boards[player] = _board
        sendSnapshot(player)
    end)
end

local function reject(player: Player, reason: string)
    ActionRejectedEvent:FireClient(player, reason)
end

----------- CLIENT -------------
local function notify(listeners)
    for _, fn in ipairs(listeners) do
        fn()
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
----------- CLIENT -------------
-- The local mirror. Read-only as far as the HUD is concerned.
function GetCells(): {any}
    return localCells
end

function GetEnergy(): number
    return localEnergy
end

-- False until the first snapshot arrives, so the HUD can show a loading state instead of an
-- empty board that looks like a bug.
function IsLoaded(): boolean
    return localLoaded
end

function CanSpawn(): boolean
    if not localLoaded then
        return false
    end
    if localEnergy < config.SPAWN_COST then
        return false
    end
    return config.FirstEmptyOpenCell(localCells) ~= nil
end

-- Local legality gate for a drag, using the SAME rules the server will apply. This is purely
-- for instant feedback: an illegal drop snaps back with no round trip, and the server still
-- re-validates every move it is asked to make.
function CanDrop(from: number, to: number): boolean
    if not localLoaded then
        return false
    end
    return config.ResolveDrop(localCells, from, to).ok
end

function ResolveLocalDrop(from: number, to: number)
    return config.ResolveDrop(localCells, from, to)
end

function RequestSpawn()
    SpawnRequest:FireServer()
end

function RequestMove(from: number, to: number)
    if type(from) ~= "number" or type(to) ~= "number" then
        return
    end
    MoveRequest:FireServer(from, to)
end

-- Subscriptions for the HUD. Each fires with no arguments except OnUnlocked/OnSpawned/
-- OnRejected, which carry what the animation needs.
function OnBoardChanged(fn)
    if fn then
        table.insert(boardChangedListeners, fn)
    end
end

function OnSpawned(fn)
    if fn then
        table.insert(spawnedListeners, fn)
    end
end

function OnUnlocked(fn)
    if fn then
        table.insert(unlockedListeners, fn)
    end
end

function OnRejected(fn)
    if fn then
        table.insert(rejectedListeners, fn)
    end
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:ClientAwake()
    BoardStateEvent:Connect(function(snapshot)
        if not snapshot then
            return
        end
        localCells = snapshot.cells or {}
        localEnergy = tonumber(snapshot.energy) or 0
        localLoaded = true
        notify(boardChangedListeners)
    end)

    SpawnedEvent:Connect(function(index)
        for _, fn in ipairs(spawnedListeners) do
            fn(index)
        end
    end)

    UnlockedEvent:Connect(function(index, openedIndices)
        for _, fn in ipairs(unlockedListeners) do
            fn(index, openedIndices or {})
        end
    end)

    ActionRejectedEvent:Connect(function(reason)
        for _, fn in ipairs(rejectedListeners) do
            fn(reason)
        end
    end)

    -- Ask for the board immediately; the server also pushes one when its storage read lands,
    -- so whichever happens second wins and the client is never left blank.
    StateRequest:FireServer()
end

function self:ServerAwake()
    -- The first parameter is the scene the player joined; named _joinedScene so it does not
    -- shadow the global `scene`.
    scene.PlayerJoined:Connect(function(_joinedScene, player)
        -- Placeholder entry so an intent arriving before the storage read completes is
        -- refused rather than acting on a nil board.
        boards[player] = {
            cells = {},
            energy = 0,
            eventId = config.EVENT_ID,
            dirty = false,
            loaded = false,
            readFailed = false,
        }
        loadBoard(player)
    end)

    server.PlayerDisconnected:Connect(function(player)
        local _board = boards[player]
        if _board and _board.dirty and _board.loaded then
            -- Flush immediately, bypassing the sweep cap: there is no next sweep for them.
            flush(player, _board)
        end
        boards[player] = nil
    end)

    StateRequest:Connect(function(player)
        local _board = boards[player]
        if not _board or not _board.loaded then
            return
        end
        sendSnapshot(player)
    end)

    SpawnRequest:Connect(function(player)
        local _board = boards[player]
        if not _board or not _board.loaded then
            return
        end
        if _board.energy < config.SPAWN_COST then
            reject(player, config.REJECT_NO_ENERGY)
            return
        end
        local _index = config.FirstEmptyOpenCell(_board.cells)
        if not _index then
            reject(player, config.REJECT_BOARD_FULL)
            return
        end

        _board.energy = _board.energy - config.SPAWN_COST
        -- Every spawn enters at the bottom of the single ladder; there is no type to roll.
        _board.cells[_index] = {
            state = config.STATE_OPEN,
            tier = config.SPAWN_TIER,
        }
        markDirty(_board)
        sendSnapshot(player)
        SpawnedEvent:FireClient(player, _index)
    end)

    MoveRequest:Connect(function(player, from, to)
        local _board = boards[player]
        if not _board or not _board.loaded then
            return
        end

        local _result = config.ResolveDrop(_board.cells, from, to)
        if not _result.ok then
            -- Re-send the board as well as the reason: a client that thought this was legal is
            -- out of sync, and the snapshot is what puts it right.
            reject(player, _result.reason)
            sendSnapshot(player)
            return
        end

        config.ApplyDrop(_board.cells, _result)

        if _result.kind == config.KIND_UNLOCK then
            local _opened = config.ExpandFrom(_board.cells, _result.to)
            markDirty(_board)
            sendSnapshot(player)
            UnlockedEvent:FireClient(player, _result.to, _opened)
            return
        end

        markDirty(_board)
        sendSnapshot(player)
    end)

    -- One sweep drives every player's persistence. Capped per tick so a room full of players
    -- going dirty at once cannot burst past the Storage rate limit.
    saveTimer = Timer.Every(SAVE_INTERVAL_SECONDS, function()
        local _pending = {}
        for player, board in pairs(boards) do
            if board.dirty and board.loaded and not board.readFailed then
                table.insert(_pending, player)
            end
        end
        if #_pending == 0 then
            return
        end
        local _count = math.min(#_pending, MAX_SAVES_PER_SWEEP)
        for i = 1, _count do
            -- Round-robin so a long queue drains fairly instead of starving the tail.
            saveCursor = (saveCursor % #_pending) + 1
            local _player = _pending[saveCursor]
            local _board = boards[_player]
            if _board then
                flush(_player, _board)
            end
        end
    end)
end
