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
-- Each snapshot also carries what the action that produced it DID (an item spawned, a ghost
-- unlocked, a tier discovered, a refusal). Delivering the truth and its animation trigger in ONE
-- message is what keeps the HUD from ever animating a state it has not received yet, or
-- receiving a state a frame before it knows why.
--
-- Discovery rewards are decided here, never on the client: the server's own board is the only
-- thing that can produce a new tier, so a tampered client cannot claim anything. Rewards are a
-- PLACEHOLDER for now -- they are printed, not granted (see grantReward).
--
-- Storage is server-only and rate limited (~10-20 calls/sec), so saves are debounced through
-- a dirty flag and one sweep timer rather than written per merge. The one exception is a
-- discovery, which is flushed immediately (see discover()).
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

-- Server -> owning player only. The board truth, plus (optionally) what produced it:
--   { cells, energy, highestTier,
--     spawned = index?, rejected = reason?,
--     unlocked = { index, opened = {index} }?, discovered = tier? }
BoardStateEvent = Event.new("MIslandBoardStateEvent")

--------------------------------
------     LOCAL STATE    ------
--------------------------------
----------- SERVER -------------
-- boards[player] = {
--   cells       -- {Config.Cell}, the authoritative board
--   energy      -- number remaining in this event's pool
--   eventId     -- which event the board belongs to
--   highestTier -- the highest tier this board has ever produced this event (the discovery
--                  track). The ladder is linear, so "discovered" is always exactly 1..highestTier.
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
local localHighestTier: number = 1
local localLoaded: boolean = false
-- Listener lists, so the HUD can subscribe without the manager knowing about the UI.
local boardChangedListeners: {any} = {}
local spawnedListeners: {any} = {}
local unlockedListeners: {any} = {}
local rejectedListeners: {any} = {}
local discoveredListeners: {any} = {}

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

-- `extras` describes what just happened, for the HUD to animate. See BoardStateEvent.
local function sendSnapshot(player: Player, extras)
    local _board = boards[player]
    if not _board then
        return
    end
    local _payload = {
        cells = cloneCells(_board.cells),
        energy = _board.energy,
        highestTier = _board.highestTier,
    }
    if extras then
        for key, value in pairs(extras) do
            _payload[key] = value
        end
    end
    BoardStateEvent:FireClient(player, _payload)
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
    if board.readFailed or not board.loaded then
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
        highestTier = board.highestTier,
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
        -- Every spawn is tier 1, so the bottom rung is known from the very first tap.
        highestTier = config.SPAWN_TIER,
        dirty = false,
        loaded = true,
        readFailed = false,
    }
end

-- PLACEHOLDER reward grant: prints what the player earned and grants nothing. This is the one
-- function to replace when a real reward system exists. It only ever runs server-side, and
-- `reward` always comes from MergeIslandConfig, never from the client.
local function grantReward(player: Player, reward)
    if not reward then
        return
    end
    print("[MergeIslandManager] REWARD (placeholder, not granted): " .. tostring(player.name)
        .. " earned " .. config.RewardText(reward))
end

-- Record a newly produced tier. Returns the tier when it is a first-time discovery, else nil.
-- The save is flushed IMMEDIATELY rather than waiting for the sweep, so a discovery (and the
-- reward that goes with it) cannot be lost to a crash and then earned a second time.
-- Discoveries are rare (at most MAX_TIER - 1 per event), so this cannot pressure the rate limit.
local function discover(player: Player, board, tier: number): number | nil
    if type(tier) ~= "number" or tier <= board.highestTier then
        return nil
    end
    board.highestTier = tier
    for _, reward in ipairs(config.DiscoveryRewards(tier)) do
        grantReward(player, reward)
    end
    markDirty(board)
    flush(player, board)
    return tier
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
        elseif value.eventId ~= config.EVENT_ID then
            -- A new event: a clean board, a full pool, and an empty discovery track, so this
            -- event's rewards can be won.
            _board = freshBoard()
            _board.dirty = true
        else
            _board = {
                cells = value.cells,
                energy = tonumber(value.energy) or 0,
                eventId = value.eventId,
                highestTier = math.max(config.SPAWN_TIER, math.min(config.MAX_TIER,
                    tonumber(value.highestTier) or config.SPAWN_TIER)),
                dirty = false,
                loaded = true,
                readFailed = false,
            }
        end

        boards[player] = _board
        sendSnapshot(player)
    end)
end

local function reject(player: Player, reason: string)
    -- The board rides along: a client that thought this was legal is out of sync, and the
    -- snapshot is what puts it right.
    sendSnapshot(player, { rejected = reason })
end

----------- CLIENT -------------
local function notify(listeners, ...)
    for _, fn in ipairs(listeners) do
        fn(...)
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

-- The top of the discovery track: every tier from 1 to this one has been found this event.
function GetHighestTier(): number
    return localHighestTier
end

-- True once every rung of the ladder has been discovered, i.e. the grand prize is won.
function IsWon(): boolean
    return localHighestTier >= config.MAX_TIER
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

-- Subscriptions for the HUD. For any one snapshot they fire in this order, AFTER the local
-- mirror has been updated: OnSpawned / OnRejected, then OnBoardChanged, then OnUnlocked, then
-- OnDiscovered. Spawn/reject come first so the HUD can settle its optimistic spawn state
-- before it repaints.
function OnBoardChanged(fn)
    if fn then
        table.insert(boardChangedListeners, fn)
    end
end

-- fn(index): an item was placed at `index` by a spawn.
function OnSpawned(fn)
    if fn then
        table.insert(spawnedListeners, fn)
    end
end

-- fn(index, openedIndices): the ghost at `index` was satisfied and these cells broke open.
function OnUnlocked(fn)
    if fn then
        table.insert(unlockedListeners, fn)
    end
end

-- fn(reason): an intent was refused. `reason` is one of the Config REJECT_* values.
function OnRejected(fn)
    if fn then
        table.insert(rejectedListeners, fn)
    end
end

-- fn(tier): `tier` was produced for the first time this event (its rewards are being paid).
function OnDiscovered(fn)
    if fn then
        table.insert(discoveredListeners, fn)
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
        localHighestTier = tonumber(snapshot.highestTier) or config.SPAWN_TIER
        localLoaded = true

        if snapshot.spawned then
            notify(spawnedListeners, snapshot.spawned)
        end
        if snapshot.rejected then
            notify(rejectedListeners, snapshot.rejected)
        end
        notify(boardChangedListeners)
        if snapshot.unlocked then
            notify(unlockedListeners, snapshot.unlocked.index, snapshot.unlocked.opened or {})
        end
        if snapshot.discovered then
            notify(discoveredListeners, snapshot.discovered)
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
            highestTier = config.SPAWN_TIER,
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
        sendSnapshot(player, { spawned = _index })
    end)

    MoveRequest:Connect(function(player, from, to)
        local _board = boards[player]
        if not _board or not _board.loaded then
            return
        end

        local _result = config.ResolveDrop(_board.cells, from, to)
        if not _result.ok then
            reject(player, _result.reason)
            return
        end

        config.ApplyDrop(_board.cells, _result)
        markDirty(_board)

        local _extras = {}
        if _result.kind == config.KIND_UNLOCK then
            _extras.unlocked = {
                index = _result.to,
                opened = config.ExpandFrom(_board.cells, _result.to),
            }
        end
        -- A move never changes a tier, so only a merge or an unlock can discover one.
        if _result.kind ~= config.KIND_MOVE then
            _extras.discovered = discover(player, _board, _result.tier)
        end
        sendSnapshot(player, _extras)
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
