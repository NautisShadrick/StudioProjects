--!Type(Module)

-- MergeIslandManager -- the authoritative engine and persistence layer for Merge Island.
--
-- Merge Island is SINGLE PLAYER PER PLAYER: every player has their own private board. It is
-- still fully server-authoritative -- the client sends intents ("spawn", "move from A to B",
-- "deliver", "sell") and the server decides what actually happens, using the shared rules and
-- economy tables in MergeIslandConfig.
--
-- Boards are NOT replicated with per-player networked values. That pattern creates matching
-- values on every client for every player, which would push every cell of everyone's board to
-- everyone. Instead the server pushes a full snapshot to the OWNING player only, via FireClient.
-- 49 cells is small enough that a full snapshot per action beats the complexity of deltas.
--
-- Each snapshot also carries what the action that produced it DID (items spawned, a ghost
-- unlocked, a tier discovered, the jackpot won, an item delivered or sold, a refusal).
-- Delivering the truth and its animation trigger in ONE message is what keeps the HUD from ever
-- animating a state it has not received yet, or receiving a state a frame before it knows why.
--
-- Economy: Merge Tokens and the discovery progress live in the board record, so the board, the
-- wallet and the discovery track can never disagree. Tokens are real in this build. Every other
-- reward (tickets, batteries, the jackpot) is a PLACEHOLDER: grantReward logs it and grants
-- nothing. When this moves into the Game Event Kit, grantReward is the swap point (GEK:
-- MinigameUtils.GrantRewards).
--
-- Money safety: anything that pays out (a delivery, a sell refund, the jackpot) is committed to
-- the board record and FLUSHED before the grant is issued, so a crash between the two can never
-- let the same payout be earned twice.
--
-- Storage is server-only and rate limited (~10-20 calls/sec), so ordinary moves are debounced
-- through a dirty flag and one sweep timer. Payouts flush immediately; they are rare enough not
-- to pressure the limit.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
-- QA ONLY: the out-of-tokens top-up grants its tokens for free (there is no purchase flow in
-- this standalone build). MUST BE OFF FOR RELEASE; with it off the offer only logs.
--!SerializeField
local _debugFreeTopUp: boolean = false

-- QA ONLY: shows the HUD's RESET button, which wipes the player's board, tokens, discoveries
-- and jackpot back to a brand-new island. MUST BE OFF FOR RELEASE.
--!SerializeField
local _debugAllowReset: boolean = true

--------------------------------
------     CONSTANTS      ------
--------------------------------
local STORAGE_KEY = "MergeIslandState"

-- Persistence pacing. The sweep is what keeps us inside the Storage rate limit: at most
-- MAX_SAVES_PER_SWEEP writes every SAVE_INTERVAL_SECONDS, no matter how fast players merge.
local SAVE_INTERVAL_SECONDS = 5
local MAX_SAVES_PER_SWEEP = 8

-- Intent rate limit, as a token bucket: a burst of up to INTENT_BURST, refilling at
-- INTENT_RATE per second. Real play never gets near it (an animation runs per action); it only
-- stops a flood of requests, each of which costs a full snapshot. Excess intents are dropped.
local INTENT_BURST = 10
local INTENT_RATE = 12

local TELEMETRY_PREFIX = "[MergeTelemetry] "

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
DeliverRequest = Event.new("MIslandDeliverRequest")
SellRequest = Event.new("MIslandSellRequest")
TopUpRequest = Event.new("MIslandTopUpRequest")
-- QA: wipe this player's island (gated by _debugAllowReset).
ResetRequest = Event.new("MIslandResetRequest")
-- (isStart) -- the HUD opened or closed; telemetry only.
SessionRequest = Event.new("MIslandSessionRequest")
-- Sent when a client's HUD comes up, so it does not have to wait for the next mutation to
-- learn the board. Also covers the race where the server finished loading storage before the
-- client was listening.
StateRequest = Event.new("MIslandStateRequest")

-- Server -> owning player only. The board truth, plus (optionally) what produced it:
--   { cells, tokens, highestTier,
--     spawned = {index}?, rejected = reason?,
--     unlocked = { index, opened = {index} }?, discovered = tier?, jackpot = true?,
--     delivered = { index, tier, tickets, bonusId, bonus?, auto }?,
--     sold = { index, tier, refund }?,
--     boardFull = true?, showTopUp = true?, toppedUp = amount?,
--     moved = true? (this snapshot answers a MoveRequest, accepted or rejected),
--     reset = true? (the island was just wiped), canReset }
BoardStateEvent = Event.new("MIslandBoardStateEvent")

--------------------------------
------     LOCAL STATE    ------
--------------------------------
----------- SERVER -------------
-- boards[player] = {
--   cells       -- {Config.Cell}, the authoritative board
--   tokens      -- Merge Tokens in the wallet
--   eventId     -- which event the board belongs to
--   createdAt   -- os.time() the board was created (telemetry: time since event start)
--   highestTier -- the highest item tier this board has ever produced this event. The ladder is
--                  linear, so "discovered" is always exactly 1..highestTier.
--   jackpotWon  -- the jackpot (every tier discovered) has been paid this event
--   zeroOfferShown -- the out-of-tokens offer has been shown since tokens last rose above 0
--   dirty       -- has changed since the last successful save
--   loaded      -- storage read has completed; intents are refused before this
--   readFailed  -- the storage read ERRORED. We play in memory but NEVER save, because
--                  overwriting a key we failed to read would destroy real progress.
--   lastIntentAt, intentBudget, session -- in memory only (throttle, telemetry)
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
local localTokens: number = 0
local localHighestTier: number = 1
local localLoaded: boolean = false
local localCanReset: boolean = false
-- Listener lists, so the HUD can subscribe without the manager knowing about the UI.
local listeners = {
    boardChanged = {},
    spawned = {},
    unlocked = {},
    rejected = {},
    discovered = {},
    jackpot = {},
    delivered = {},
    sold = {},
    boardFull = {},
    topUp = {},
    reset = {},
}

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
----------- SERVER -------------
-- One structured line per spec'd telemetry event, for log search:
--   [MergeTelemetry] <event> player=<name> k=v ...
-- Keys are sorted so lines diff cleanly.
local function telemetry(eventName: string, player: Player, fields)
    local _keys = {}
    for key in pairs(fields or {}) do
        table.insert(_keys, key)
    end
    table.sort(_keys)
    local _parts = { TELEMETRY_PREFIX .. eventName, "player=" .. tostring(player and player.name) }
    for _, key in ipairs(_keys) do
        table.insert(_parts, key .. "=" .. tostring(fields[key]))
    end
    print(table.concat(_parts, " "))
end

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
        tokens = _board.tokens,
        highestTier = _board.highestTier,
        canReset = _debugAllowReset,
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
-- the write is retried rather than silently dropped -- unless the player has already left, in
-- which case there is no next sweep for them and the loss is logged instead.
-- `onSaved(ok)` (optional) runs once the write has landed, or immediately with false when this
-- board cannot be saved at all. Payouts are issued from it (mark-then-grant).
local function flush(player: Player, board, onSaved)
    if board.readFailed or not board.loaded then
        if onSaved then
            onSaved(false)
        end
        return
    end
    board.dirty = false
    -- Captured up front: the disconnect path flushes and then drops the player, so reading
    -- player.name inside the callback could happen after they are gone.
    local _name = tostring(player.name)
    Storage.SetPlayerValue(player, STORAGE_KEY, {
        version = config.SAVE_VERSION,
        cells = cloneCells(board.cells),
        tokens = board.tokens,
        eventId = board.eventId,
        createdAt = board.createdAt,
        highestTier = board.highestTier,
        jackpotWon = board.jackpotWon,
        zeroOfferShown = board.zeroOfferShown,
    }, function(error)
        local _ok = error == StorageError.None
        if not _ok then
            if boards[player] == board then
                print("[MergeIslandManager] save failed for " .. _name
                    .. " (" .. tostring(error) .. "); will retry")
                board.dirty = true
            else
                print("[MergeIslandManager] ALERT: final save failed for " .. _name
                    .. " (" .. tostring(error) .. ") after disconnect; last changes lost")
            end
        end
        if onSaved then
            onSaved(_ok)
        end
    end)
end

-- Issue placeholder grants only once the record that marks them paid is durable. A failed save
-- withholds them (loudly) rather than risk paying twice.
local function flushThenGrant(player: Player, board, grants: {() -> ()}, what: string)
    local _name = tostring(player.name)
    flush(player, board, function(ok)
        if not ok then
            print("[MergeIslandManager] ALERT: " .. what .. " payout withheld for " .. _name
                .. " (record not saved)")
            return
        end
        for _, grant in ipairs(grants) do
            grant()
        end
    end)
end

-- Is a stored payload usable? A board saved under a different grid size or an older cell shape
-- (or a truncated write) must be rejected outright: a half-read board misbehaves subtly, which
-- is much worse to debug than an obviously fresh one. Tiers outside the ladder are rejected too,
-- so a ladder edit without a SAVE_VERSION bump cannot leave invisible, unmergeable items.
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
        if _cell.tier ~= nil and (type(_cell.tier) ~= "number" or _cell.tier < 1
            or _cell.tier > config.MAX_TIER) then
            return false
        end
    end
    return true
end

local function freshBoard(): any
    return {
        cells = config.NewBoard(),
        tokens = config.TOKENS_START,
        eventId = config.EVENT_ID,
        createdAt = os.time(),
        -- Every spawn is tier 1, so the bottom rung is known from the very first tap.
        highestTier = config.SPAWN_TIER,
        jackpotWon = false,
        zeroOfferShown = false,
        dirty = false,
        loaded = true,
        readFailed = false,
        lastIntentAt = nil,
        intentBudget = INTENT_BURST,
        session = nil,
    }
end

-- PLACEHOLDER reward grant for everything except Merge Tokens (which the caller has already
-- credited to the wallet): logs what the player earned and grants nothing. This is the one
-- function to replace when a real reward system exists. It only ever runs server-side, and
-- `reward` always comes from MergeIslandConfig, never from the client.
local function grantReward(player: Player, reward, source: string)
    if not reward or reward.kind == config.REWARD_TOKENS then
        return
    end
    print("[MergeIslandManager] REWARD (placeholder, not granted): " .. tostring(player.name)
        .. " earned " .. config.RewardText(reward) .. " from " .. source)
end

-- Accept an intent? Refuses before the storage read lands, and throttles floods.
local function acceptIntent(board): boolean
    if not board or not board.loaded then
        return false
    end
    local _now = Time.time
    local _budget = math.min(INTENT_BURST,
        (board.intentBudget or INTENT_BURST) + (_now - (board.lastIntentAt or _now)) * INTENT_RATE)
    board.lastIntentAt = _now
    if _budget < 1 then
        board.intentBudget = _budget
        return false
    end
    board.intentBudget = _budget - 1
    return true
end

-- Tokens rose above zero: the next time they run out, the offer may show again.
local function addTokens(board, amount: number)
    if amount <= 0 then
        return
    end
    board.tokens = board.tokens + amount
    board.zeroOfferShown = false
end

-- The out-of-tokens offer shows once per time the wallet hits zero (a second 0-token tap does
-- not resurface it). Sets extras.showTopUp when it should appear now.
local function maybeOfferTopUp(board, extras)
    if board.tokens > 0 or board.zeroOfferShown then
        return
    end
    board.zeroOfferShown = true
    extras.showTopUp = true
end

-- Record a newly produced tier. Returns the tier when it is a first-time discovery, else nil.
local function discover(board, tier: number): number | nil
    if type(tier) ~= "number" or tier <= board.highestTier then
        return nil
    end
    board.highestTier = tier
    return tier
end

-- Pay the jackpot if every tier has been discovered and it has not been paid yet. Returns true
-- when it was paid now. Marks it paid (in the same write as the discovery that earned it), and
-- issues the grants once that write has landed.
local function settleJackpot(player: Player, board): boolean
    if board.jackpotWon or board.highestTier < config.MAX_TIER then
        return false
    end
    board.jackpotWon = true
    markDirty(board)
    local _grants = {}
    for _, reward in ipairs(config.JACKPOT) do
        table.insert(_grants, function()
            grantReward(player, reward, "jackpot")
        end)
    end
    flushThenGrant(player, board, _grants, "jackpot")
    telemetry("jackpot_won", player, {
        time_since_event_start = os.time() - (board.createdAt or os.time()),
    })
    return true
end

-- Deliver the item at `index`: clear the cell, pay the guaranteed tickets, roll and pay the
-- bonus. Assumes the caller validated that the cell holds a deliverable item. Returns the
-- snapshot's `delivered` extra.
local function deliverAt(player: Player, board, index: number, auto: boolean)
    local _tier = config.CellAt(board.cells, index).tier or 0
    local _row = config.DeliveryFor(_tier)
    if not _row then
        return nil
    end
    board.cells[index] = { state = config.STATE_OPEN }
    local _bonusId = config.RollBonus(_tier)
    local _bonus = config.BonusReward(_bonusId, _row.mult)
    if _bonus and _bonus.kind == config.REWARD_TOKENS then
        -- Tokens ride the same write that clears the cell, so they cannot be paid twice.
        addTokens(board, _bonus.amount)
    end
    markDirty(board)
    local _tickets = { kind = config.REWARD_TICKETS, amount = _row.tickets, label = "Tickets" }
    local _source = "delivery (tier " .. tostring(_tier) .. ")"
    flushThenGrant(player, board, {
        function() grantReward(player, _tickets, _source) end,
        function() grantReward(player, _bonus, _source .. " bonus") end,
    }, "delivery")
    telemetry("item_delivered", player, {
        tier = _tier,
        auto = auto,
        reward_multiplier = _row.mult,
        guaranteed_reward_type = config.REWARD_TICKETS,
        guaranteed_reward_amount = _row.tickets,
        bonus_reward_type = if _bonus then _bonus.kind else config.BONUS_NONE,
        bonus_reward_amount = if _bonus then _bonus.amount else 0,
    })
    return {
        index = index,
        tier = _tier,
        tickets = _row.tickets,
        bonusId = _bonusId,
        bonus = _bonus,
        auto = auto,
    }
end

-- Board is full and nothing can merge: tell the HUD (and telemetry) so it can point at Sell.
local function checkBoardFull(player: Player, board, extras)
    if #config.EmptyOpenCells(board.cells) > 0 or config.HasLegalMerge(board.cells) then
        return
    end
    extras.boardFull = true
    telemetry("board_full_reached", player, {
        timestamp = os.time(),
        tokens_remaining = board.tokens,
    })
end

local function endSession(player: Player, board)
    local _session = board and board.session
    if not _session then
        return
    end
    board.session = nil
    telemetry("minigame_session_end", player, {
        session_duration_ms = math.floor((Time.time - _session.startedAt) * 1000),
        merges_in_session = _session.merges,
        tokens_spent_in_session = _session.tokensSpent,
        token_balance = board.tokens,
        board_fill_pct = config.BoardFillPct(board.cells),
    })
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
            -- A new event: a clean board, a fresh token grant and an empty discovery track, so
            -- this event's jackpot can be won.
            _board = freshBoard()
            _board.dirty = true
        else
            _board = freshBoard()
            _board.cells = value.cells
            _board.tokens = math.max(0, math.floor(tonumber(value.tokens) or 0))
            _board.createdAt = tonumber(value.createdAt) or os.time()
            _board.highestTier = math.max(config.SPAWN_TIER, math.min(config.MAX_TIER,
                tonumber(value.highestTier) or config.SPAWN_TIER))
            _board.jackpotWon = value.jackpotWon == true
            _board.zeroOfferShown = value.zeroOfferShown == true
        end

        boards[player] = _board
        -- A jackpot earned but not yet paid (a crash between the two flushes) is paid now. No
        -- `jackpot` extra: the celebration belongs to the moment it was earned, and the HUD
        -- already shows the panel as won once every tier is discovered.
        settleJackpot(player, _board)
        sendSnapshot(player)
    end)
end

local function reject(player: Player, reason: string, extras)
    -- The board rides along: a client that thought this was legal is out of sync, and the
    -- snapshot is what puts it right.
    local _extras = extras or {}
    _extras.rejected = reason
    sendSnapshot(player, _extras)
end

----------- CLIENT -------------
local function notify(list, ...)
    for _, fn in ipairs(list) do
        fn(...)
    end
end

local function subscribe(list, fn)
    if fn then
        table.insert(list, fn)
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

function GetTokens(): number
    return localTokens
end

-- The top of the discovery track: every tier from 1 to this one has been found this event.
function GetHighestTier(): number
    return localHighestTier
end

-- False until the first snapshot arrives, so the HUD can show a loading state instead of an
-- empty board that looks like a bug.
function IsLoaded(): boolean
    return localLoaded
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

function RequestDeliver(index: number)
    if type(index) ~= "number" then
        return
    end
    DeliverRequest:FireServer(index)
end

function RequestSell(index: number)
    if type(index) ~= "number" then
        return
    end
    SellRequest:FireServer(index)
end

function RequestTopUp()
    TopUpRequest:FireServer()
end

-- QA: is the reset button enabled on the server?
function CanReset(): boolean
    return localCanReset
end

function RequestReset()
    ResetRequest:FireServer()
end

function ReportSession(isStart: boolean)
    SessionRequest:FireServer(isStart == true)
end

-- Subscriptions for the HUD. For any one snapshot they fire in this order, AFTER the local
-- mirror has been updated: OnSpawned / OnRejected, then OnBoardChanged, then OnUnlocked,
-- OnDiscovered, OnJackpot, OnDelivered, OnSold, OnBoardFull, OnTopUp. Spawn/reject come
-- first so the HUD can settle its optimistic spawn state before it repaints.
-- fn(isMoveAnswer, rejected): the board was repainted from a snapshot; isMoveAnswer marks the
-- server's answer to a MoveRequest.
function OnBoardChanged(fn)
    subscribe(listeners.boardChanged, fn)
end

-- fn(indices): items were placed at these cells by one generator tap (1, or 2 with the bonus).
function OnSpawned(fn)
    subscribe(listeners.spawned, fn)
end

-- fn(index, openedIndices): the ghost at `index` was satisfied and these cells broke open.
function OnUnlocked(fn)
    subscribe(listeners.unlocked, fn)
end

-- fn(reason): an intent was refused. `reason` is one of the Config REJECT_* values.
function OnRejected(fn)
    subscribe(listeners.rejected, fn)
end

-- fn(tier): `tier` was produced for the first time this event.
function OnDiscovered(fn)
    subscribe(listeners.discovered, fn)
end

-- fn(): every tier has now been discovered and the jackpot was paid. Fires after OnDiscovered
-- for the top tier, in the same snapshot.
function OnJackpot(fn)
    subscribe(listeners.jackpot, fn)
end

-- fn(delivered): see BoardStateEvent. Already paid by the server.
function OnDelivered(fn)
    subscribe(listeners.delivered, fn)
end

-- fn(sold): { index, tier, refund }.
function OnSold(fn)
    subscribe(listeners.sold, fn)
end

-- fn(): the board is full with no legal merge left.
function OnBoardFull(fn)
    subscribe(listeners.boardFull, fn)
end

-- fn(showOffer, toppedUp): the out-of-tokens offer should show, and/or a top-up landed.
function OnTopUp(fn)
    subscribe(listeners.topUp, fn)
end

-- fn(): the island was wiped. Fires BEFORE OnBoardChanged for that snapshot, so the HUD can drop
-- every in-flight animation and presentation state before it repaints the fresh board.
function OnReset(fn)
    subscribe(listeners.reset, fn)
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
        localTokens = tonumber(snapshot.tokens) or 0
        localHighestTier = tonumber(snapshot.highestTier) or config.SPAWN_TIER
        localLoaded = true
        localCanReset = snapshot.canReset == true

        if snapshot.reset then
            notify(listeners.reset)
        end
        if snapshot.spawned then
            notify(listeners.spawned, snapshot.spawned)
        end
        if snapshot.rejected then
            notify(listeners.rejected, snapshot.rejected)
        end
        notify(listeners.boardChanged, snapshot.moved == true, snapshot.rejected ~= nil)
        if snapshot.unlocked then
            notify(listeners.unlocked, snapshot.unlocked.index, snapshot.unlocked.opened or {})
        end
        if snapshot.discovered then
            notify(listeners.discovered, snapshot.discovered)
        end
        if snapshot.jackpot then
            notify(listeners.jackpot)
        end
        if snapshot.delivered then
            notify(listeners.delivered, snapshot.delivered)
        end
        if snapshot.sold then
            notify(listeners.sold, snapshot.sold)
        end
        if snapshot.boardFull then
            notify(listeners.boardFull)
        end
        if snapshot.showTopUp or snapshot.toppedUp then
            notify(listeners.topUp, snapshot.showTopUp == true, tonumber(snapshot.toppedUp) or 0)
        end
    end)

    -- Ask for the board immediately; the server also pushes one when its storage read lands,
    -- so whichever happens second wins and the client is never left blank.
    StateRequest:FireServer()
end

function self:ServerAwake()
    if _debugAllowReset then
        print("[MergeIslandManager] WARNING: _debugAllowReset ENABLED -- players can wipe their"
            .. " island from the HUD (QA only, must be OFF for release)")
    end
    if _debugFreeTopUp then
        print("[MergeIslandManager] WARNING: _debugFreeTopUp ENABLED -- the out-of-tokens top-up"
            .. " is free (QA only, must be OFF for release)")
    end

    -- The first parameter is the scene the player joined; named _joinedScene so it does not
    -- shadow the global `scene`.
    scene.PlayerJoined:Connect(function(_joinedScene, player)
        -- Placeholder entry so an intent arriving before the storage read completes is
        -- refused rather than acting on a nil board.
        local _placeholder = freshBoard()
        _placeholder.cells = {}
        _placeholder.tokens = 0
        _placeholder.loaded = false
        boards[player] = _placeholder
        loadBoard(player)
    end)

    server.PlayerDisconnected:Connect(function(player)
        local _board = boards[player]
        endSession(player, _board)
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

    SessionRequest:Connect(function(player, isStart)
        local _board = boards[player]
        if not _board or not _board.loaded then
            return
        end
        if isStart == true then
            endSession(player, _board)
            _board.session = { startedAt = Time.time, merges = 0, tokensSpent = 0 }
            telemetry("minigame_session_start", player, {
                token_balance = _board.tokens,
                board_fill_pct = config.BoardFillPct(_board.cells),
            })
        else
            endSession(player, _board)
        end
    end)

    SpawnRequest:Connect(function(player)
        local _board = boards[player]
        if not acceptIntent(_board) then
            return
        end
        local _extras = {}
        if _board.tokens < config.SPAWN_COST then
            maybeOfferTopUp(_board, _extras)
            reject(player, config.REJECT_NO_ENERGY, _extras)
            return
        end
        local _first = config.RandomEmptyOpenCell(_board.cells)
        if not _first then
            checkBoardFull(player, _board, _extras)
            reject(player, config.REJECT_BOARD_FULL, _extras)
            return
        end

        _board.tokens = _board.tokens - config.SPAWN_COST
        -- Every spawn enters at the bottom of the single ladder; there is no type to roll.
        _board.cells[_first] = { state = config.STATE_OPEN, tier = config.SPAWN_TIER }
        local _spawned = { _first }
        local _bonus = false
        if math.random() < config.BONUS_SPAWN_CHANCE then
            local _second = config.RandomEmptyOpenCell(_board.cells)
            if _second then
                _board.cells[_second] = { state = config.STATE_OPEN, tier = config.SPAWN_TIER }
                table.insert(_spawned, _second)
                _bonus = true
            end
        end
        if _board.session then
            _board.session.tokensSpent = _board.session.tokensSpent + config.SPAWN_COST
        end
        markDirty(_board)

        telemetry("generator_tapped", player, {
            spawned_tier = config.SPAWN_TIER,
            bonus_item_spawned = _bonus,
            free_cells_after = #config.EmptyOpenCells(_board.cells),
        })

        _extras.spawned = _spawned
        checkBoardFull(player, _board, _extras)
        maybeOfferTopUp(_board, _extras)
        sendSnapshot(player, _extras)
    end)

    MoveRequest:Connect(function(player, from, to)
        local _board = boards[player]
        if not acceptIntent(_board) then
            return
        end

        local _result = config.ResolveDrop(_board.cells, from, to)
        if not _result.ok then
            reject(player, _result.reason, { moved = true })
            return
        end

        config.ApplyDrop(_board.cells, _result)
        markDirty(_board)

        -- `moved` tags this as the answer to a move, so the HUD settles its parked drop on this
        -- snapshot and no other.
        local _extras = { moved = true }
        if _result.kind == config.KIND_UNLOCK then
            _extras.unlocked = {
                index = _result.to,
                opened = config.ExpandFrom(_board.cells, _result.to),
            }
        end
        -- A move never changes a tier, so only a merge or an unlock can discover.
        if _result.kind ~= config.KIND_MOVE then
            if _board.session then
                _board.session.merges = _board.session.merges + 1
            end
            telemetry("merge_executed", player, {
                tier_produced = _result.tier,
                board_fill_pct = config.BoardFillPct(_board.cells),
                unlock = _result.kind == config.KIND_UNLOCK,
            })
            -- A discovery pays nothing itself, so it rides the sweep -- unless it completes the
            -- track, in which case settleJackpot flushes before paying.
            _extras.discovered = discover(_board, _result.tier)
            if settleJackpot(player, _board) then
                _extras.jackpot = true
            end
            -- The top tier cannot merge any further: it delivers itself.
            if _result.tier >= config.AUTO_DELIVER_TIER then
                _extras.delivered = deliverAt(player, _board, _result.to, true)
            end
        end
        sendSnapshot(player, _extras)
    end)

    DeliverRequest:Connect(function(player, index)
        local _board = boards[player]
        if not acceptIntent(_board) then
            return
        end
        if type(index) ~= "number" or index ~= index then
            return
        end
        index = math.floor(index)
        if not config.HasItem(_board.cells, index) then
            reject(player, config.REJECT_NO_ITEM)
            return
        end
        if not config.IsDeliverable(config.CellAt(_board.cells, index).tier) then
            reject(player, config.REJECT_NOT_DELIVERABLE)
            return
        end
        sendSnapshot(player, { delivered = deliverAt(player, _board, index, false) })
    end)

    SellRequest:Connect(function(player, index)
        local _board = boards[player]
        if not acceptIntent(_board) then
            return
        end
        if type(index) ~= "number" or index ~= index then
            return
        end
        index = math.floor(index)
        if not config.HasItem(_board.cells, index) then
            reject(player, config.REJECT_NO_ITEM)
            return
        end
        local _tier = config.CellAt(_board.cells, index).tier or 0
        local _refund = config.SellRefund(_tier)
        _board.cells[index] = { state = config.STATE_OPEN }
        addTokens(_board, _refund)
        markDirty(_board)
        if _refund > 0 then
            flush(player, _board)
        end
        telemetry("item_sold", player, { tier = _tier, tokens_refunded = _refund })
        sendSnapshot(player, { sold = { index = index, tier = _tier, refund = _refund } })
    end)

    ResetRequest:Connect(function(player)
        local _board = boards[player]
        if not _debugAllowReset or not acceptIntent(_board) then
            return
        end
        -- A brand-new island, exactly as a first-ever load would make it. The session carries
        -- over (the HUD is still open); the telemetry counters restart with the new island.
        local _fresh = freshBoard()
        _fresh.readFailed = _board.readFailed
        _fresh.lastIntentAt = _board.lastIntentAt
        _fresh.intentBudget = _board.intentBudget
        if _board.session then
            _fresh.session = { startedAt = Time.time, merges = 0, tokensSpent = 0 }
        end
        boards[player] = _fresh
        markDirty(_fresh)
        flush(player, _fresh)
        print("[MergeIslandManager] RESET (debug): " .. tostring(player.name) .. " wiped their island")
        sendSnapshot(player, { reset = true })
    end)

    TopUpRequest:Connect(function(player)
        local _board = boards[player]
        if not acceptIntent(_board) then
            return
        end
        if not _debugFreeTopUp then
            -- PLACEHOLDER: no purchase flow in this build. The GEK port routes this through a
            -- real token pack (PurchaseManager_GEK / the coin-sale deeplink).
            print("[MergeIslandManager] TOP-UP (placeholder, not granted): " .. tostring(player.name)
                .. " tapped Buy " .. tostring(config.TOPUP_AMOUNT) .. " Merge Tokens for "
                .. config.TOPUP_PRICE_LABEL)
            reject(player, config.REJECT_TOPUP_UNAVAILABLE)
            return
        end
        addTokens(_board, config.TOPUP_AMOUNT)
        markDirty(_board)
        flush(player, _board)
        print("[MergeIslandManager] TOP-UP (debug, free): " .. tostring(player.name) .. " +"
            .. tostring(config.TOPUP_AMOUNT) .. " Merge Tokens")
        sendSnapshot(player, { toppedUp = config.TOPUP_AMOUNT })
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
