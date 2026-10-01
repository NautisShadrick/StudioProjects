--!Type(Module)

-- Feature gate: present in every build, inert unless the feature is enabled. KEEP THIS AT THE TOP
-- OF THE FILE (a helper defined mid-file is a nil global for the other VM).
local function GekFeatureOn(): boolean
    return require("MergeIslandKit").IsFeatureEnabled()
end

-- MergeIslandManager -- the authoritative engine, persistence and payouts for Merge Island.
-- Becomes MergeIslandModule_GEK in the Game Event Kit; every kit service it uses goes through
-- MergeIslandKit, so the port does not touch this file's logic.
--
-- Merge Island is SINGLE PLAYER PER PLAYER: every player has their own private board. It is fully
-- server-authoritative: the client sends intents ("spawn", "move from A to B"), each tagged with a
-- request id, and the server decides what happens using the shared rules in MergeIslandConfig.
-- EVERY intent is answered, accepted or not, so the client never has to guess which tap a reply
-- belongs to.
--
-- Boards are not replicated with networked values (that would push every player's cells to every
-- client). The server pushes a full snapshot to the OWNING player only. 49 cells is small enough
-- that a snapshot per action beats deltas. Each snapshot also carries what produced it (spawns,
-- a move's outcome, an unlock, a discovery and what it paid, a refusal), so the HUD never animates
-- a state it has not received.
--
-- Three records per player, each its own store:
--   * the WALLET -- Merge Tokens, an event-inventory item the backend owns (MergeIslandKit currency).
--     The server never keeps its own copy of the balance.
--   * the BOARD (MergeIslandBoard) -- the cells. Saved debounced. A save that is from another event,
--     another SAVE_VERSION or unreadable is replaced by a fresh board, and nothing else is lost.
--   * the LEDGER (MergeIslandLedger) -- everything a payout depends on: discovery progress, what has
--     been paid, the jackpot, the packs bought, purchase receipts and the OWED list. Written at once.
--     A board reset never touches it, which is why no format change or reset can pay twice.
--
-- Payouts are mark-then-grant and at most once:
--   1. The action marks the ledger (paidThroughTier / jackpotPaid) and appends an OWED entry
--      holding the exact rewards (tickets already boosted -- the amount granted is final).
--   2. Granting an owed entry first persists it as `attempted`, then makes ONE GrantRewards call.
--   3. Success or failure, the entry is then removed. A reported failure is never retried (a
--      timeout can hide a grant that landed); it raises an ALERT for a manual comp. An entry still
--      `attempted` on a later load is the same case. An entry never attempted is simply paid on
--      the next load, so a disconnect or a storage hiccup can delay a payout but never drop or
--      double it.
-- Payouts the player is watching are PARKED until the HUD reports the presentation done (or a
-- fallback timer), because item grants pop the platform reward screen the moment they land.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
-- QA ONLY: an out-of-tokens pack is fulfilled at once with a synthetic receipt, standing in for a
-- real purchase (there is no purchase flow standalone). MUST BE OFF FOR RELEASE; with it off a
-- pack tap only logs.
--!SerializeField
local _debugFreeTopUp: boolean = false

--------------------------------
------     CONSTANTS      ------
--------------------------------
local BOARD_STORAGE_KEY = "MergeIslandBoard"
local LEDGER_STORAGE_KEY = "MergeIslandLedger"
-- The event-inventory item that is the Merge Token, and the bet id every backend write carries.
local CURRENCY_ITEM_ID = "merge_token"
local BET_ID = "merge_island"

-- Intent rate limit, as a token bucket: a burst of up to INTENT_BURST, refilling at INTENT_RATE
-- per second. Real play never gets near it; it only stops a flood of requests, each of which
-- costs a snapshot. A throttled intent is still answered (rate_limited).
local INTENT_BURST = 10
local INTENT_RATE = 12

-- A parked payout is granted after this long even if the HUD never reports the presentation done.
local PARKED_GRANT_FALLBACK_SECONDS = 30
-- A payout whose `attempted` mark could not be saved is tried again after this long.
local GRANT_RETRY_SECONDS = 5

-- PresentationDoneRequest's id for "every parked payout" (sent when the HUD closes).
PAYOUT_ALL = 0

-- The snapshot's loadState.
LOAD_READY = "ready"
LOAD_LOADING = "loading"
LOAD_FAILED = "failed"

-- Cheat commands (CheatRequest), honoured only when MergeIslandKit.CanUseCheats allows.
CHEAT_RESET_BOARD = "reset_board"     -- a fresh board; discoveries and payouts are kept
CHEAT_RESET_ALL = "reset_all"         -- board AND ledger: the track and jackpot can be won again
CHEAT_REPLAY_TOPUP = "replay_topup"   -- redeliver the last debug pack receipt (must grant nothing)

local TELEMETRY_PREFIX = "[MergeTelemetry] "
local LOG_PREFIX = "[MergeIsland] "

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local config = require("MergeIslandConfig")
local kit = require("MergeIslandKit")

--------------------------------
------     NETWORKING     ------
--------------------------------
-- Client -> server intents. Every one is re-validated server-side; a tampered client gains nothing.
-- (multiplier, requestId) -- one of Config.SPAWN_MULTIPLIERS, unlocked.
SpawnRequest = Event.new("MIslandSpawnRequest")
-- (from, to, requestId)
MoveRequest = Event.new("MIslandMoveRequest")
-- (offerIndex) -- an index into the token-pack table.
TopUpRequest = Event.new("MIslandTopUpRequest")
-- (command) -- one of the CHEAT_* commands.
CheatRequest = Event.new("MIslandCheatRequest")
-- (isStart) -- the HUD opened or closed; telemetry only.
SessionRequest = Event.new("MIslandSessionRequest")
-- Sent when a client's HUD comes up, and answered with a snapshot whatever the load state.
StateRequest = Event.new("MIslandStateRequest")
-- (payoutId) -- the HUD finished presenting this payout (PAYOUT_ALL: every one); grant it now.
PresentationDoneRequest = Event.new("MIslandPresentationDoneRequest")

-- Server -> owning player only:
--   { loadState = LOAD_*, windowOpen, canCheat,
--     -- once loaded:
--     cells, tokens, highestTier, jackpotWon, offersBought = {boolean},
--     -- what produced it (each optional):
--     spawns = {{ requestId, index, tier, luck? }}, spawnRejects = {{ requestId, reason }},
--     move = { requestId, from, to, kind?, tier?, rejected? },
--     rejected = reason (a refusal worth telling the player about),
--     unlocked = { index, opened = {index} },
--     discovered = tier, paid = {reward} (the discovery rewards it paid), payoutId?, jackpot = true?,
--     payoutSettled = payoutId, toppedUp = amount?, reset = true? }
BoardStateEvent = Event.new("MIslandBoardStateEvent")

--------------------------------
------    GLOBAL STATE    ------
--------------------------------
-- The per-event reward tables, loaded at Awake on BOTH VMs (SerializeField-backed values are not
-- readable at module load): the server pays from them, the HUD advertises from them. Global so
-- the HUD reads the very rows the server pays.
DISCOVERY = {}
JACKPOT = {}
TOPUPS = {}

-- The Merge Token. Declared at the top level on both sides, like the kit's minigame currencies.
CURRENCY = kit.NewCurrency({ type = "item", itemId = CURRENCY_ITEM_ID, bet = BET_ID })

--------------------------------
------     LOCAL STATE    ------
--------------------------------
----------- SERVER -------------
local boardStore = kit.NewRecordStore({
    id = "merge_island board",
    storageKey = BOARD_STORAGE_KEY,
    defaults = { version = 0, eventId = "", cells = {} },
})
local ledgerStore = kit.NewRecordStore({
    id = "merge_island ledger",
    storageKey = LEDGER_STORAGE_KEY,
    defaults = {
        eventId = "",
        highestTier = 1,
        paidThroughTier = 1,
        jackpotPaid = false,
        starterGranted = false,
        offersBought = {},
        -- [purchaseId] = offerIndex, for every receipt ever fulfilled (kept across resets and
        -- events, so a redelivered receipt is always recognised).
        purchases = {},
        -- { { id, source, rewards, attempted, topUp? } }, see the header.
        owed = {},
        nextPayoutId = 1,
    },
})

-- False when the reward tables failed validation: the server then grants nothing and leaves
-- every payout mark where it is, so fixing the tables pays what was earned meanwhile.
local rewardTablesValid: boolean = false

-- runtime[player] = in-memory, never persisted:
--   ready          -- every record loaded and reconciled; intents are refused before this
--   intentBudget, lastIntentAt -- the throttle
--   session        -- { startedAt, merges, tokensSpent } while the HUD is open (telemetry)
--   spawnQueue     -- spawns accepted and waiting for the next debit: { requestId, mult, cost, cell }
--   debitInFlight  -- one token debit at a time; taps meanwhile are batched into the next one
--   committedCost  -- tokens queued or in flight, held off the balance for the affordability check
--   reserved       -- [cell] = true for cells held by a spawn that is being paid for
--   parked         -- [payoutId] = fallback Timer for payouts waiting on the HUD
--   granting       -- [payoutId] = true while a grant call is in flight
--   lastDebugPurchase -- { offerIndex, purchaseId } of the last debug pack (CHEAT_REPLAY_TOPUP)
-- Cleared on disconnect.
local runtime: {[Player]: any} = {}

----------- CLIENT -------------
-- The local player's mirror of their own state. Rendered by the HUD; never trusted for anything
-- the server decides.
local localCells: {any} = {}
local localTokens: number = 0
local localHighestTier: number = 1
local localJackpotWon: boolean = false
local localOffersBought: {boolean} = {}
local localLoadState: string = LOAD_LOADING
local localWindowOpen: boolean = true
local localCanCheat: boolean = false
-- Listener lists, so the HUD can subscribe without the manager knowing about the UI.
local listeners = {
    boardChanged = {},
    spawned = {},
    spawnRejected = {},
    rejected = {},
    unlocked = {},
    discovered = {},
    jackpot = {},
    payoutSettled = {},
    reset = {},
}

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
----------- SHARED -------------
-- Read the three per-event tables and check them. Both VMs load them; only the server alerts.
local function loadRewardTables()
    DISCOVERY = kit.RewardTable("mergeIslandDiscovery")
    JACKPOT = kit.RewardTable("mergeIslandJackpot")
    TOPUPS = kit.RewardTable("mergeIslandTopUps")
    local _issues = config.ValidateRewardTables(DISCOVERY, JACKPOT, TOPUPS)
    rewardTablesValid = #_issues == 0
    if not rewardTablesValid and server then
        kit.LogError(LOG_PREFIX .. "ALERT: reward tables invalid -- nothing is granted until fixed:\n  "
            .. table.concat(_issues, "\n  "))
    end
end

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

-- A copy of the board for sending, so a later in-place mutation can never race the serializer.
local function cloneCells(cells): {any}
    local _copy = {}
    for i = 1, config.CELL_COUNT do
        local _cell = cells and cells[i]
        if _cell then
            _copy[i] = { state = _cell.state, tier = _cell.tier }
        else
            _copy[i] = { state = config.STATE_HIDDEN }
        end
    end
    return _copy
end

local function copyRewards(rewards): {any}
    local _out = {}
    for _, reward in ipairs(rewards or {}) do
        table.insert(_out, {
            kind = reward.kind,
            itemId = reward.itemId,
            amount = reward.amount,
            label = reward.label,
            icon = reward.icon,
        })
    end
    return _out
end

local function describeRewards(rewards): string
    local _parts = {}
    for _, reward in ipairs(rewards or {}) do
        table.insert(_parts, config.RewardText(reward)
            .. (if reward.itemId then " [" .. tostring(reward.itemId) .. "]" else ""))
    end
    return table.concat(_parts, ", ")
end

-- A board record is usable only if it has this version and every cell is well formed; tiers
-- outside the ladder are rejected too, so a ladder edit without a SAVE_VERSION bump cannot leave
-- invisible, unmergeable items.
local function isValidBoard(board): boolean
    if type(board) ~= "table" or type(board.cells) ~= "table" or board.version ~= config.SAVE_VERSION then
        return false
    end
    for i = 1, config.CELL_COUNT do
        local _cell = board.cells[i]
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

local function resetBoard(board, eventId: string)
    board.version = config.SAVE_VERSION
    board.eventId = eventId
    board.cells = config.NewBoard()
end

-- Back to a fresh track for `eventId`. Purchases, the owed list and the payout counter survive:
-- a receipt must be recognised forever, and what is owed is owed whatever the track says.
local function resetLedgerProgress(ledger, eventId: string)
    ledger.eventId = eventId
    ledger.highestTier = config.SPAWN_TIER
    ledger.paidThroughTier = config.SPAWN_TIER
    ledger.jackpotPaid = false
    ledger.starterGranted = false
    ledger.offersBought = config.ReadOffersBought(TOPUPS, nil)
end

-- Loaded ledgers are read defensively: anything malformed falls back to the safe value.
local function normaliseLedger(ledger)
    ledger.highestTier = math.max(config.SPAWN_TIER, math.min(config.MAX_TIER,
        math.floor(tonumber(ledger.highestTier) or config.SPAWN_TIER)))
    ledger.paidThroughTier = math.max(config.SPAWN_TIER, math.min(ledger.highestTier,
        math.floor(tonumber(ledger.paidThroughTier) or config.SPAWN_TIER)))
    ledger.jackpotPaid = ledger.jackpotPaid == true
    ledger.starterGranted = ledger.starterGranted == true
    ledger.offersBought = config.ReadOffersBought(TOPUPS, ledger.offersBought)
    if type(ledger.purchases) ~= "table" then
        ledger.purchases = {}
    end
    if type(ledger.owed) ~= "table" then
        ledger.owed = {}
    end
    ledger.nextPayoutId = math.max(1, math.floor(tonumber(ledger.nextPayoutId) or 1))
end

local function loadState(player: Player): string
    local _rt = runtime[player]
    if _rt and _rt.ready then
        return LOAD_READY
    end
    if boardStore.IsLoadFailed(player) or ledgerStore.IsLoadFailed(player)
        or (CURRENCY.IsLoadFailed and CURRENCY.IsLoadFailed(player)) then
        return LOAD_FAILED
    end
    return LOAD_LOADING
end

-- `extras` describes what just happened, for the HUD to animate. See BoardStateEvent.
local function sendSnapshot(player: Player, extras)
    if not runtime[player] then
        return
    end
    local _state = loadState(player)
    local _payload = {
        loadState = _state,
        windowOpen = kit.IsWindowOpen(),
        canCheat = kit.CanUseCheats(player),
    }
    if _state == LOAD_READY then
        local _board = boardStore.Get(player)
        local _ledger = ledgerStore.Get(player)
        _payload.cells = cloneCells(_board.cells)
        _payload.tokens = CURRENCY.GetBalance(player)
        _payload.highestTier = _ledger.highestTier
        _payload.jackpotWon = _ledger.jackpotPaid
        _payload.offersBought = config.ReadOffersBought(TOPUPS, _ledger.offersBought)
    end
    if extras then
        for key, value in pairs(extras) do
            _payload[key] = value
        end
    end
    BoardStateEvent:FireClient(player, _payload)
end

-- Accept an intent? Throttles floods with a token bucket.
local function acceptIntent(rt): boolean
    local _now = Time.time
    local _budget = math.min(INTENT_BURST,
        (rt.intentBudget or INTENT_BURST) + (_now - (rt.lastIntentAt or _now)) * INTENT_RATE)
    rt.lastIntentAt = _now
    if _budget < 1 then
        rt.intentBudget = _budget
        return false
    end
    rt.intentBudget = _budget - 1
    return true
end

local function findOwed(ledger, payoutId: number)
    for i, entry in ipairs(ledger.owed) do
        if entry.id == payoutId then
            return entry, i
        end
    end
    return nil, nil
end

-- Append an owed payout to the ledger (in memory; the caller persists). Returns its id.
local function addOwed(ledger, source: string, rewards: {any}, topUp: number?): number
    local _id = ledger.nextPayoutId
    ledger.nextPayoutId = _id + 1
    table.insert(ledger.owed, {
        id = _id,
        source = source,
        rewards = rewards,
        attempted = false,
        topUp = topUp,
    })
    return _id
end

-- Grant one owed payout, at most once (see the header). Safe to call repeatedly: an entry that is
-- already being granted, or gone, is ignored.
local function grantOwed(player: Player, payoutId: number)
    local _rt = runtime[player]
    local _ledger = ledgerStore.Get(player)
    if not _rt or not _rt.ready or not _ledger or _rt.granting[payoutId] then
        return
    end
    local _entry = findOwed(_ledger, payoutId)
    if not _entry or _entry.attempted then
        return
    end
    _rt.granting[payoutId] = true
    _entry.attempted = true
    local _name = tostring(player.name)
    local _userId = tostring(player.user and player.user.id)

    ledgerStore.Persist(player, function(markedOk)
        local _rtNow = runtime[player]
        if not markedOk then
            -- Not durably marked: granting now could pay twice after a crash. Try again shortly.
            _entry.attempted = false
            if _rtNow then
                _rtNow.granting[payoutId] = nil
                Timer.After(GRANT_RETRY_SECONDS, function()
                    grantOwed(player, payoutId)
                end)
            end
            return
        end
        kit.GrantRewards(player, _entry.rewards, CURRENCY, function(ok)
            -- Settled either way: a reported failure can hide a grant that landed.
            local _ledgerNow = ledgerStore.Get(player)
            if _ledgerNow then
                local _, _index = findOwed(_ledgerNow, payoutId)
                if _index then
                    table.remove(_ledgerNow.owed, _index)
                end
                ledgerStore.Persist(player, nil)
            end
            if runtime[player] then
                runtime[player].granting[payoutId] = nil
            end
            if not ok then
                kit.LogError(LOG_PREFIX .. "ALERT: " .. tostring(_entry.source) .. " payout #"
                    .. tostring(payoutId) .. " reported FAILURE for " .. _name .. " (" .. _userId .. "): "
                    .. describeRewards(_entry.rewards) .. " -- no retry (at-most-once); comp manually")
            else
                print(LOG_PREFIX .. _name .. " (" .. _userId .. ") earned " .. describeRewards(_entry.rewards)
                    .. " from " .. tostring(_entry.source) .. " (payout #" .. tostring(payoutId) .. ")")
                for _, reward in ipairs(_entry.rewards) do
                    kit.LogAction(player, "mi_reward_" .. tostring(reward.kind), tonumber(reward.amount) or 0)
                end
            end
            if runtime[player] then
                sendSnapshot(player, {
                    payoutSettled = payoutId,
                    toppedUp = if ok then _entry.topUp else nil,
                })
            end
        end, BET_ID)
    end)
end

-- Release a parked payout: grant it now. `reason` is logged.
local function releaseParked(player: Player, payoutId: number, reason: string)
    local _rt = runtime[player]
    if not _rt then
        return
    end
    local _timer = _rt.parked[payoutId]
    if not _timer then
        return
    end
    _rt.parked[payoutId] = nil
    _timer:Stop()
    print(LOG_PREFIX .. "parked payout #" .. tostring(payoutId) .. " RELEASED for " .. tostring(player.name)
        .. " via " .. reason)
    grantOwed(player, payoutId)
end

-- Hold a payout until the HUD has shown it, with a fallback so a lost report cannot strand it.
local function parkPayout(player: Player, payoutId: number)
    local _rt = runtime[player]
    if not _rt then
        return
    end
    _rt.parked[payoutId] = Timer.After(PARKED_GRANT_FALLBACK_SECONDS, function()
        releaseParked(player, payoutId, "fallback-" .. PARKED_GRANT_FALLBACK_SECONDS .. "s")
    end)
end

-- Pay what the track now owes: the discovery rewards of every tier past paidThroughTier, plus the
-- jackpot once the top tier is found. Marks the ledger, records ONE owed payout for the whole lot
-- (one action, one backend write), persists, and either parks it for the HUD (`present`) or grants
-- it now. Returns payoutId, the discovery rewards paid (for the HUD), and whether it includes the
-- jackpot; nil when nothing was owed. With broken reward tables nothing is marked or paid.
local function settlePayouts(player: Player, present: boolean): (number?, {any}?, boolean)
    local _ledger = ledgerStore.Get(player)
    local _rt = runtime[player]
    if not _ledger or not _rt or not _rt.ready or not rewardTablesValid then
        return nil, nil, false
    end
    local _from = _ledger.paidThroughTier + 1
    local _to = _ledger.highestTier
    local _discovery = if _to >= _from then config.DiscoveryRewardsBetween(DISCOVERY, _from, _to) else {}
    local _jackpot = _ledger.highestTier >= config.MAX_TIER and not _ledger.jackpotPaid
    if _to > _ledger.paidThroughTier then
        _ledger.paidThroughTier = _to
    end
    if #_discovery == 0 and not _jackpot then
        return nil, nil, false
    end

    -- Tickets are boosted now, so the amount recorded is the amount granted (the backend applies
    -- no boost of its own).
    local _boost = kit.GetFullBoostMultiplier(player)
    for _, reward in ipairs(_discovery) do
        if reward.kind == config.REWARD_TICKETS then
            reward.amount = math.ceil(reward.amount * _boost)
        end
    end
    local _rewards = copyRewards(_discovery)
    local _source = "discovery (tiers " .. tostring(_from) .. "-" .. tostring(_to) .. ")"
    if _jackpot then
        _ledger.jackpotPaid = true
        for _, reward in ipairs(copyRewards(JACKPOT)) do
            table.insert(_rewards, reward)
        end
        _source = _source .. " + jackpot"
    end
    local _id = addOwed(_ledger, _source, _rewards, nil)
    ledgerStore.Persist(player, nil)
    if present then
        parkPayout(player, _id)
    else
        grantOwed(player, _id)
    end
    return _id, copyRewards(_discovery), _jackpot
end

-- A newly produced tier: record it, pay for it, and describe it in `extras` for the HUD.
local function applyDiscovery(player: Player, tier: number, extras)
    local _ledger = ledgerStore.Get(player)
    if not _ledger or type(tier) ~= "number" or tier <= _ledger.highestTier then
        return
    end
    local _from = _ledger.highestTier + 1
    _ledger.highestTier = math.min(tier, config.MAX_TIER)
    extras.discovered = _ledger.highestTier
    kit.LogAction(player, "mi_discoveries", _ledger.highestTier - _from + 1)
    telemetry("discovery", player, { tier = _ledger.highestTier, tiers_crossed = _ledger.highestTier - _from + 1 })

    local _payoutId, _paid, _jackpot = settlePayouts(player, true)
    if not _payoutId then
        -- Nothing paid, so settlePayouts did not persist; progress is saved all the same.
        ledgerStore.Persist(player, nil)
        return
    end
    extras.payoutId = _payoutId
    extras.paid = _paid
    if _jackpot then
        extras.jackpot = true
        kit.LogAction(player, "mi_jackpots", 1)
        local _board = boardStore.Get(player)
        telemetry("jackpot_won", player, { board_fill_pct = config.BoardFillPct(_board and _board.cells) })
    end
end

-- The once-per-event starter grant (standalone only; 0 in the Game Event Kit).
local function grantStarterTokens(player: Player)
    local _ledger = ledgerStore.Get(player)
    local _amount = kit.STANDALONE_STARTER_TOKENS or 0
    if not _ledger or _ledger.starterGranted or _amount <= 0 then
        return
    end
    _ledger.starterGranted = true
    local _id = addOwed(_ledger, "starter grant",
        { { kind = config.REWARD_COINS, amount = _amount, label = "Merge Tokens" } }, nil)
    grantOwed(player, _id)
end

-- Everything loaded: reconcile the records with the current event, settle what is owed, and tell
-- the client. Runs once per session.
local function initPlayer(player: Player)
    local _rt = runtime[player]
    if not _rt or _rt.ready then
        return
    end
    local _board = boardStore.Get(player)
    local _ledger = ledgerStore.Get(player)
    if not _board or not _ledger then
        return
    end
    local _eventId = kit.GetEventId()
    local _name = tostring(player.name)

    normaliseLedger(_ledger)
    if _ledger.eventId ~= _eventId then
        -- A new event: a fresh track, so this event's rewards and jackpot can be won.
        resetLedgerProgress(_ledger, _eventId)
        ledgerStore.Persist(player, nil)
    end
    if _board.eventId ~= _eventId or not isValidBoard(_board) then
        if _board.eventId == _eventId then
            print(LOG_PREFIX .. "discarding unreadable board for " .. _name .. " (progress and payouts kept)")
        end
        resetBoard(_board, _eventId)
        boardStore.Persist(player, nil)
    end
    _rt.ready = true

    -- Owed from an earlier session. One already attempted may or may not have landed: never retried.
    local _stale = {}
    for _, entry in ipairs(_ledger.owed) do
        if entry.attempted then
            table.insert(_stale, entry)
        end
    end
    for _, entry in ipairs(_stale) do
        local _, _index = findOwed(_ledger, entry.id)
        table.remove(_ledger.owed, _index)
        kit.LogError(LOG_PREFIX .. "ALERT: " .. tostring(entry.source) .. " payout #" .. tostring(entry.id)
            .. " for " .. _name .. " (" .. tostring(player.user and player.user.id) .. ") was attempted but never"
            .. " confirmed: " .. describeRewards(entry.rewards) .. " -- not retried; check and comp if missing")
    end
    if #_stale > 0 then
        ledgerStore.Persist(player, nil)
    end
    for _, entry in ipairs(_ledger.owed) do
        grantOwed(player, entry.id)
    end
    settlePayouts(player, false)
    grantStarterTokens(player)
    sendSnapshot(player)
end

local function tryReady(player: Player)
    local _rt = runtime[player]
    if not _rt or _rt.ready then
        return
    end
    if not (boardStore.IsLoaded(player) and ledgerStore.IsLoaded(player) and CURRENCY.IsReady(player)) then
        return
    end
    kit.OnEventReady(function()
        initPlayer(player)
    end)
end

local function endSession(player: Player, rt)
    local _session = rt and rt.session
    if not _session then
        return
    end
    rt.session = nil
    local _board = boardStore.Get(player)
    telemetry("minigame_session_end", player, {
        session_duration_ms = math.floor((Time.time - _session.startedAt) * 1000),
        merges_in_session = _session.merges,
        tokens_spent_in_session = _session.tokensSpent,
        token_balance = CURRENCY.GetBalance(player),
        board_fill_pct = config.BoardFillPct(_board and _board.cells),
    })
end

-- A random empty playable cell that no paid-for spawn is holding, or nil.
local function freeSpawnCell(cells, reserved): number | nil
    local _free = {}
    for _, index in ipairs(config.EmptyOpenCells(cells)) do
        if not reserved[index] then
            table.insert(_free, index)
        end
    end
    if #_free == 0 then
        return nil
    end
    return _free[math.random(1, #_free)]
end

local function rejectSpawn(player: Player, requestId: number, reason: string)
    sendSnapshot(player, {
        spawnRejects = { { requestId = requestId, reason = reason } },
        rejected = reason,
    })
end

-- Pay for every queued spawn with ONE debit, then place them. One debit is in flight at a time;
-- taps that arrive meanwhile are batched into the next, so fast tapping costs few backend writes.
local function pumpSpawns(player: Player)
    local _rt = runtime[player]
    if not _rt or _rt.debitInFlight or #_rt.spawnQueue == 0 then
        return
    end
    local _batch = _rt.spawnQueue
    _rt.spawnQueue = {}
    local _total = 0
    for _, entry in ipairs(_batch) do
        _total = _total + entry.cost
    end
    _rt.debitInFlight = true
    local _name = tostring(player.name)
    local _userId = tostring(player.user and player.user.id)

    CURRENCY.Debit(player, _total, function(ok, balanceAfter)
        local _rtNow = runtime[player]
        if not _rtNow then
            if ok then
                kit.LogError(LOG_PREFIX .. "ALERT: " .. _name .. " (" .. _userId .. ") spent " .. tostring(_total)
                    .. " " .. CURRENCY_ITEM_ID .. " but left before " .. tostring(#_batch)
                    .. " spawn(s) were placed; comp manually")
            end
            return
        end
        _rtNow.debitInFlight = false
        _rtNow.committedCost = math.max(0, _rtNow.committedCost - _total)
        for _, entry in ipairs(_batch) do
            _rtNow.reserved[entry.cell] = nil
        end

        if not ok then
            print(LOG_PREFIX .. "spawn debit of " .. tostring(_total) .. " failed for " .. _name)
            local _rejects = {}
            for _, entry in ipairs(_batch) do
                table.insert(_rejects, { requestId = entry.requestId, reason = config.REJECT_DEBIT_FAILED })
            end
            sendSnapshot(player, { spawnRejects = _rejects, rejected = config.REJECT_DEBIT_FAILED })
            pumpSpawns(player)
            return
        end

        print(LOG_PREFIX .. _name .. " (" .. _userId .. ") spent " .. tostring(_total) .. " " .. CURRENCY_ITEM_ID
            .. " on " .. tostring(#_batch) .. " spawn(s); balance " .. tostring(balanceAfter))
        kit.LogAction(player, "mi_spawns", #_batch)
        kit.LogAction(player, "mi_tokens_spent", _total)

        local _board = boardStore.Get(player)
        local _results = {}
        local _topTier = 0
        for _, entry in ipairs(_batch) do
            -- The multiplier picks the rung (x2 -> tier 2, x4 -> tier 3); a Lucky or Legendary
            -- roll bumps it higher.
            local _luck = config.RollSpawnLuck(entry.mult)
            local _tier = config.SpawnTierFor(entry.mult, _luck)
            _board.cells[entry.cell] = { state = config.STATE_OPEN, tier = _tier }
            table.insert(_results, {
                requestId = entry.requestId,
                index = entry.cell,
                tier = _tier,
                luck = if _luck ~= config.LUCK_NONE then _luck else nil,
            })
            _topTier = math.max(_topTier, _tier)
            if _rtNow.session then
                _rtNow.session.tokensSpent = _rtNow.session.tokensSpent + entry.cost
            end
            telemetry("generator_tapped", player, {
                spawned_tier = _tier,
                luck = _luck,
                multiplier = entry.mult,
                tokens_spent = entry.cost,
                free_cells_after = #config.EmptyOpenCells(_board.cells),
            })
        end
        boardStore.MarkDirty(player)

        local _extras = { spawns = _results }
        -- A multiplied or lucky spawn can produce a tier before any merge has.
        applyDiscovery(player, _topTier, _extras)
        sendSnapshot(player, _extras)
        pumpSpawns(player)
    end)
end

----------- CLIENT -------------
local function notify(list, ...)
    for _, fn in ipairs(list) do
        fn(...)
    end
end

-- Add `fn` to `list`; returns the function that removes it again.
local function subscribe(list, fn)
    if not fn then
        return function() end
    end
    table.insert(list, fn)
    return function()
        for i, existing in ipairs(list) do
            if existing == fn then
                table.remove(list, i)
                return
            end
        end
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
----------- SERVER -------------
-- Fulfil an out-of-tokens pack receipt. The Game Event Kit's PurchaseManager_GEK routes the
-- pack's product here (a feature-fulfilled receipt): validate, persist a durable mark keyed by the
-- receipt, acknowledge, then grant what is owed. cb(ok, reason?): ok = acknowledge the receipt.
-- A redelivered receipt is acknowledged and grants nothing; a second real charge for a pack
-- already bought is acknowledged, grants nothing and is logged for a manual comp.
function FulfillTopUp(player: Player, offerIndex: number, purchaseId: string, cb)
    local function finish(ok: boolean, reason: string?)
        if cb then
            cb(ok, reason)
        end
    end
    if not player then
        print(LOG_PREFIX .. "ERROR: FulfillTopUp called without a player")
        finish(false, config.REJECT_INVALID)
        return
    end
    local _rt = runtime[player]
    local _ledger = ledgerStore.Get(player)
    if not _rt or not _rt.ready or not _ledger then
        -- Transient: the kit parks the receipt unacknowledged and retries it.
        finish(false, config.REJECT_LOADING)
        return
    end
    local _offer = TOPUPS[offerIndex]
    if not _offer or type(purchaseId) ~= "string" or purchaseId == "" or not rewardTablesValid then
        finish(false, config.REJECT_INVALID)
        return
    end
    if _ledger.purchases[purchaseId] ~= nil then
        print(LOG_PREFIX .. "receipt " .. purchaseId .. " redelivered for " .. tostring(player.name)
            .. "; acknowledged, nothing granted")
        finish(true, nil)
        return
    end
    _ledger.purchases[purchaseId] = offerIndex
    if _ledger.offersBought[offerIndex] then
        kit.LogError(LOG_PREFIX .. "ALERT: " .. tostring(player.name) .. " (" .. tostring(player.user and player.user.id)
            .. ") was charged again for pack " .. tostring(offerIndex) .. " (receipt " .. purchaseId
            .. ") already bought this event; acknowledged, nothing granted -- comp manually")
        ledgerStore.Persist(player, nil)
        finish(true, nil)
        return
    end
    _ledger.offersBought[offerIndex] = true
    local _payoutId = addOwed(_ledger, "token pack " .. tostring(offerIndex),
        { { kind = config.REWARD_COINS, amount = _offer.amount, label = "Merge Tokens" } }, _offer.amount)
    ledgerStore.Persist(player, function(ok)
        if not ok then
            -- Not durable, so not acknowledged: undo, and the redelivered receipt tries again.
            local _, _index = findOwed(_ledger, _payoutId)
            if _index then
                table.remove(_ledger.owed, _index)
            end
            _ledger.purchases[purchaseId] = nil
            _ledger.offersBought[offerIndex] = false
            finish(false, config.REJECT_LOADING)
            return
        end
        telemetry("offer_purchased", player, {
            offer = offerIndex,
            tokens_granted = _offer.amount,
            offers_left = if config.HasOffersLeft(TOPUPS, _ledger.offersBought) then "yes" else "no",
        })
        finish(true, nil)
        grantOwed(player, _payoutId)
    end)
end

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

function IsJackpotWon(): boolean
    return localJackpotWon
end

-- False until the first READY snapshot arrives, so the HUD can show a loading state.
function IsLoaded(): boolean
    return localLoadState == LOAD_READY
end

-- LOAD_READY, LOAD_LOADING or LOAD_FAILED.
function GetLoadState(): string
    return localLoadState
end

-- Whether new spawns are allowed right now (the feature's schedule window).
function IsWindowOpen(): boolean
    return localWindowOpen
end

-- Whether the server allows this player the QA cheats.
function CanUseCheats(): boolean
    return localCanCheat
end

-- The per-event tables, as loaded on this VM.
function GetDiscoveryTable(): {any}
    return DISCOVERY
end

function GetJackpotTable(): {any}
    return JACKPOT
end

function GetTopUpTable(): {any}
    return TOPUPS
end

-- Local legality gate for a drag, using the SAME rules the server will apply. Purely for instant
-- feedback: an illegal drop snaps back with no round trip, and the server re-validates every move.
function CanDrop(from: number, to: number): boolean
    if not IsLoaded() then
        return false
    end
    return config.ResolveDrop(localCells, from, to).ok
end

function ResolveLocalDrop(from: number, to: number)
    return config.ResolveDrop(localCells, from, to)
end

function RequestSpawn(multiplier: number, requestId: number)
    if type(requestId) ~= "number" then
        print("[MergeIslandManager] ERROR: RequestSpawn needs a request id")
        return
    end
    SpawnRequest:FireServer(multiplier, requestId)
end

function RequestMove(from: number, to: number, requestId: number)
    if type(from) ~= "number" or type(to) ~= "number" then
        return
    end
    MoveRequest:FireServer(from, to, requestId)
end

-- GEK: this becomes PurchaseManager_GEK's purchase prompt for the pack's productId; the server
-- side is FulfillTopUp.
function RequestTopUp(offerIndex: number)
    TopUpRequest:FireServer(offerIndex)
end

-- Has the pack at `offerIndex` been bought this event?
function IsOfferBought(offerIndex: number): boolean
    return localOffersBought[offerIndex] == true
end

-- Is any out-of-tokens pack still for sale?
function HasOffersLeft(): boolean
    return config.HasOffersLeft(TOPUPS, localOffersBought)
end

-- QA: one of the CHEAT_* commands. The server refuses it unless cheats are allowed.
function RequestCheat(command: string)
    CheatRequest:FireServer(command)
end

function ReportSession(isStart: boolean)
    SessionRequest:FireServer(isStart == true)
end

-- The HUD finished presenting payout `payoutId` (PAYOUT_ALL: every one); the server grants it.
function ReportPresentationDone(payoutId: number?)
    PresentationDoneRequest:FireServer(payoutId or PAYOUT_ALL)
end

-- Subscriptions for the HUD. Each returns its unsubscribe function. For any one snapshot they
-- fire in this order, AFTER the local mirror has been updated: OnReset, OnSpawned /
-- OnSpawnRejected (per request), OnRejected, OnBoardChanged, OnUnlocked, OnDiscovered, OnJackpot,
-- OnPayoutSettled.
--
-- fn(moveAnswer): the board was repainted from a snapshot. `moveAnswer` is the server's answer to
-- a MoveRequest ({ requestId, from, to, kind?, tier?, rejected? }), or nil.
function OnBoardChanged(fn)
    return subscribe(listeners.boardChanged, fn)
end

-- fn(requestId, index, luck, tier): the tap `requestId` placed an item of `tier` at `index`;
-- `luck` is the Config.LUCK_* it rolled.
function OnSpawned(fn)
    return subscribe(listeners.spawned, fn)
end

-- fn(requestId, reason): the tap `requestId` was refused and spent nothing.
function OnSpawnRejected(fn)
    return subscribe(listeners.spawnRejected, fn)
end

-- fn(reason): an intent was refused for a reason worth telling the player (Config REJECT_*).
function OnRejected(fn)
    return subscribe(listeners.rejected, fn)
end

-- fn(index, openedIndices): the ghost at `index` was satisfied and these cells broke open (or,
-- with UNLOCK_NEIGHBOURS_OPEN off, were revealed as new ghosts).
function OnUnlocked(fn)
    return subscribe(listeners.unlocked, fn)
end

-- fn(tier, paid, payoutId): `tier` was produced for the first time this event; `paid` is the
-- discovery rewards it paid (empty for none). `payoutId`, when set, is waiting on
-- ReportPresentationDone.
function OnDiscovered(fn)
    return subscribe(listeners.discovered, fn)
end

-- fn(): the discovery just reported also won the jackpot (same payout).
function OnJackpot(fn)
    return subscribe(listeners.jackpot, fn)
end

-- fn(payoutId, toppedUp): payout `payoutId` was granted (the balance in this snapshot includes
-- it); `toppedUp` is set when it was a token pack.
function OnPayoutSettled(fn)
    return subscribe(listeners.payoutSettled, fn)
end

-- fn(): the island was wiped. Fires BEFORE OnBoardChanged for that snapshot, so the HUD can drop
-- every in-flight animation and presentation state before it repaints the fresh board.
function OnReset(fn)
    return subscribe(listeners.reset, fn)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:ClientAwake()
    if not GekFeatureOn() then
        return
    end
    loadRewardTables()

    BoardStateEvent:Connect(function(snapshot)
        if not snapshot then
            return
        end
        localLoadState = snapshot.loadState or LOAD_LOADING
        localWindowOpen = snapshot.windowOpen ~= false
        localCanCheat = snapshot.canCheat == true
        if localLoadState == LOAD_READY then
            localCells = snapshot.cells or {}
            localTokens = tonumber(snapshot.tokens) or 0
            localHighestTier = tonumber(snapshot.highestTier) or config.SPAWN_TIER
            localJackpotWon = snapshot.jackpotWon == true
            localOffersBought = config.ReadOffersBought(TOPUPS, snapshot.offersBought)
        end

        if snapshot.reset then
            notify(listeners.reset)
        end
        for _, spawned in ipairs(snapshot.spawns or {}) do
            notify(listeners.spawned, spawned.requestId, spawned.index, spawned.luck or config.LUCK_NONE,
                tonumber(spawned.tier))
        end
        for _, refused in ipairs(snapshot.spawnRejects or {}) do
            notify(listeners.spawnRejected, refused.requestId, refused.reason)
        end
        if snapshot.rejected then
            notify(listeners.rejected, snapshot.rejected)
        end
        notify(listeners.boardChanged, snapshot.move)
        if snapshot.unlocked then
            notify(listeners.unlocked, snapshot.unlocked.index, snapshot.unlocked.opened or {})
        end
        if snapshot.discovered then
            notify(listeners.discovered, snapshot.discovered, snapshot.paid or {}, snapshot.payoutId)
        end
        if snapshot.jackpot then
            notify(listeners.jackpot)
        end
        if snapshot.payoutSettled then
            notify(listeners.payoutSettled, snapshot.payoutSettled, tonumber(snapshot.toppedUp))
        end
    end)

    -- Ask for the state at once; the server also pushes one when its records finish loading, so
    -- whichever lands second wins and the client is never left blank.
    StateRequest:FireServer()
end

function self:ServerAwake()
    if not GekFeatureOn() then
        return
    end
    if _debugFreeTopUp then
        print(LOG_PREFIX .. "WARNING: _debugFreeTopUp ENABLED -- the out-of-tokens packs are free"
            .. " (QA only, must be OFF for release)")
    end
    loadRewardTables()

    CURRENCY.ServerInit()
    boardStore.ServerInit()
    ledgerStore.ServerInit()
    CURRENCY.SetOnReady(tryReady)
    boardStore.SetOnLoaded(tryReady)
    ledgerStore.SetOnLoaded(tryReady)
    -- A record that never loads leaves the player unable to play; tell their HUD.
    local function onLoadFailed(player: Player)
        sendSnapshot(player)
    end
    boardStore.SetOnLoadFailed(onLoadFailed)
    ledgerStore.SetOnLoadFailed(onLoadFailed)

    server.PlayerConnected:Connect(function(player: Player)
        runtime[player] = {
            ready = false,
            intentBudget = INTENT_BURST,
            lastIntentAt = nil,
            session = nil,
            spawnQueue = {},
            debitInFlight = false,
            committedCost = 0,
            reserved = {},
            parked = {},
            granting = {},
            lastDebugPurchase = nil,
        }
        tryReady(player)
    end)

    -- Parked payouts are NOT granted on the way out: they stay owed in the ledger and are paid
    -- on the next load, which a grant to a departed player could not guarantee.
    server.PlayerDisconnected:Connect(function(player: Player)
        local _rt = runtime[player]
        if _rt then
            endSession(player, _rt)
            for _, timer in pairs(_rt.parked) do
                timer:Stop()
            end
        end
        runtime[player] = nil
    end)

    StateRequest:Connect(function(player: Player)
        sendSnapshot(player)
    end)

    SessionRequest:Connect(function(player: Player, isStart)
        local _rt = runtime[player]
        if not _rt or not _rt.ready then
            return
        end
        endSession(player, _rt)
        if isStart == true then
            _rt.session = { startedAt = Time.time, merges = 0, tokensSpent = 0 }
            local _board = boardStore.Get(player)
            telemetry("minigame_session_start", player, {
                token_balance = CURRENCY.GetBalance(player),
                board_fill_pct = config.BoardFillPct(_board and _board.cells),
            })
        end
    end)

    PresentationDoneRequest:Connect(function(player: Player, payoutId)
        local _rt = runtime[player]
        if not _rt then
            return
        end
        if payoutId == PAYOUT_ALL then
            local _ids = {}
            for id in pairs(_rt.parked) do
                table.insert(_ids, id)
            end
            for _, id in ipairs(_ids) do
                releaseParked(player, id, "presentation-done")
            end
            return
        end
        if type(payoutId) == "number" then
            releaseParked(player, payoutId, "presentation-done")
        end
    end)

    SpawnRequest:Connect(function(player: Player, multiplier, requestId)
        local _rt = runtime[player]
        if not _rt or type(requestId) ~= "number" then
            return
        end
        if not acceptIntent(_rt) then
            rejectSpawn(player, requestId, config.REJECT_RATE_LIMITED)
            return
        end
        if not _rt.ready then
            rejectSpawn(player, requestId, config.REJECT_LOADING)
            return
        end
        if not kit.IsWindowOpen() then
            rejectSpawn(player, requestId, config.REJECT_WINDOW_CLOSED)
            return
        end
        local _ledger = ledgerStore.Get(player)
        -- Only an offered, unlocked multiplier is honoured; anything else is a stale or tampered client.
        if not config.IsMultiplierUnlocked(multiplier, _ledger.highestTier) then
            rejectSpawn(player, requestId, config.REJECT_MULTIPLIER_LOCKED)
            return
        end
        local _cost = config.SpawnCost(multiplier)
        if CURRENCY.GetBalance(player) - _rt.committedCost < _cost then
            rejectSpawn(player, requestId, config.REJECT_NO_ENERGY)
            return
        end
        local _cell = freeSpawnCell(boardStore.Get(player).cells, _rt.reserved)
        if not _cell then
            rejectSpawn(player, requestId, config.REJECT_BOARD_FULL)
            return
        end
        _rt.reserved[_cell] = true
        _rt.committedCost = _rt.committedCost + _cost
        table.insert(_rt.spawnQueue, { requestId = requestId, mult = multiplier, cost = _cost, cell = _cell })
        pumpSpawns(player)
    end)

    MoveRequest:Connect(function(player: Player, from, to, requestId)
        local _rt = runtime[player]
        if not _rt then
            return
        end
        local function refuse(reason: string, tell: boolean)
            sendSnapshot(player, {
                move = { requestId = requestId, from = from, to = to, rejected = reason },
                rejected = if tell then reason else nil,
            })
        end
        if not acceptIntent(_rt) then
            refuse(config.REJECT_RATE_LIMITED, false)
            return
        end
        if not _rt.ready then
            refuse(config.REJECT_LOADING, true)
            return
        end
        -- A cell held for a spawn that is being paid for cannot take a move.
        if type(to) == "number" and _rt.reserved[math.floor(to)] then
            refuse(config.REJECT_RESERVED, false)
            return
        end
        local _board = boardStore.Get(player)
        local _result = config.ResolveDrop(_board.cells, from, to)
        if not _result.ok then
            refuse(_result.reason, true)
            return
        end

        config.ApplyDrop(_board.cells, _result)
        boardStore.MarkDirty(player)

        local _extras = {
            move = {
                requestId = requestId,
                from = _result.from,
                to = _result.to,
                kind = _result.kind,
                tier = _result.tier,
            },
        }
        if _result.kind == config.KIND_UNLOCK then
            _extras.unlocked = {
                index = _result.to,
                opened = config.ExpandFrom(_board.cells, _result.to),
            }
        end
        -- A move never changes a tier, so only a merge or an unlock can discover.
        if _result.kind ~= config.KIND_MOVE then
            if _rt.session then
                _rt.session.merges = _rt.session.merges + 1
            end
            kit.LogAction(player, "mi_merges", 1)
            telemetry("merge_executed", player, {
                tier_produced = _result.tier,
                board_fill_pct = config.BoardFillPct(_board.cells),
                unlock = _result.kind == config.KIND_UNLOCK,
            })
            applyDiscovery(player, _result.tier, _extras)
        end
        sendSnapshot(player, _extras)
    end)

    TopUpRequest:Connect(function(player: Player, offerIndex)
        local _rt = runtime[player]
        if not _rt or not acceptIntent(_rt) or not _rt.ready then
            return
        end
        if type(offerIndex) ~= "number" or offerIndex ~= offerIndex then
            return
        end
        offerIndex = math.floor(offerIndex)
        local _offer = TOPUPS[offerIndex]
        if not _offer then
            return
        end
        if ledgerStore.Get(player).offersBought[offerIndex] then
            sendSnapshot(player, { rejected = config.REJECT_OFFER_BOUGHT })
            return
        end
        if not _debugFreeTopUp then
            print(LOG_PREFIX .. "TOP-UP (placeholder, no purchase flow): " .. tostring(player.name)
                .. " tapped pack " .. tostring(offerIndex) .. " (" .. tostring(_offer.productId) .. "): "
                .. tostring(_offer.amount) .. " Merge Tokens for " .. tostring(_offer.priceLabel))
            sendSnapshot(player, { rejected = config.REJECT_TOPUP_UNAVAILABLE })
            return
        end
        local _purchaseId = "debug_" .. tostring(player.user and player.user.id) .. "_"
            .. tostring(os.time()) .. "_" .. tostring(offerIndex)
        _rt.lastDebugPurchase = { offerIndex = offerIndex, purchaseId = _purchaseId }
        print(LOG_PREFIX .. "TOP-UP (debug, free): " .. tostring(player.name) .. " pack " .. tostring(offerIndex)
            .. " via synthetic receipt " .. _purchaseId)
        FulfillTopUp(player, offerIndex, _purchaseId, function(ok, reason)
            if not ok then
                sendSnapshot(player, { rejected = reason or config.REJECT_TOPUP_UNAVAILABLE })
            end
        end)
    end)

    CheatRequest:Connect(function(player: Player, command)
        local _rt = runtime[player]
        if not _rt or not _rt.ready then
            return
        end
        if not kit.CanUseCheats(player) then
            print(LOG_PREFIX .. "cheat '" .. tostring(command) .. "' rejected: cheats disabled for "
                .. tostring(player.name))
            return
        end
        if command == CHEAT_REPLAY_TOPUP then
            local _last = _rt.lastDebugPurchase
            if not _last then
                print(LOG_PREFIX .. "cheat replay_topup: no debug receipt this session")
                return
            end
            FulfillTopUp(player, _last.offerIndex, _last.purchaseId, function(ok, reason)
                print(LOG_PREFIX .. "cheat replay_topup " .. _last.purchaseId .. " -> ok=" .. tostring(ok)
                    .. " " .. tostring(reason or ""))
            end)
            return
        end
        if command ~= CHEAT_RESET_BOARD and command ~= CHEAT_RESET_ALL then
            return
        end
        -- A spawn being paid for holds a cell on the current board; let it land first.
        if _rt.debitInFlight or #_rt.spawnQueue > 0 then
            print(LOG_PREFIX .. "cheat " .. command .. " deferred: a spawn is being paid for; try again")
            return
        end
        local _eventId = kit.GetEventId()
        local _board = boardStore.Get(player)
        resetBoard(_board, _eventId)
        boardStore.Persist(player, nil)
        if command == CHEAT_RESET_ALL then
            resetLedgerProgress(ledgerStore.Get(player), _eventId)
            ledgerStore.Persist(player, nil)
            grantStarterTokens(player)
        end
        if _rt.session then
            _rt.session = { startedAt = Time.time, merges = 0, tokensSpent = 0 }
        end
        print(LOG_PREFIX .. "RESET (cheat " .. command .. "): " .. tostring(player.name))
        sendSnapshot(player, { reset = true })
    end)
end
