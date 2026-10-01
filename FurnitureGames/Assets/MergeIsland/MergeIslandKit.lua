--!Type(Module)

-- MergeIslandKit -- the ONE seam between Merge Island and the Game Event Kit.
--
-- Merge Island is built to become a GEK feature (GEK/Optional/MergeIsland). Every call it makes
-- into kit services -- the currency, reward grants, persisted records, per-event reward tables,
-- the feature gate and schedule window, cheats, alerts, analytics, sound -- goes through this
-- module, and each function here has the SAME contract as the GEK member named in its comment.
-- Porting is therefore replacing this file's bodies with those calls; the game code above it does
-- not change. This is the only Merge Island file that knows it is running standalone.
--
-- The standalone stand-ins are honest about the contracts they imitate: the currency is async
-- (with optional simulated latency) and can fail, record stores load with retries and refuse to
-- report a record that never loaded, and reward tables are read as data rows shaped exactly like
-- the JSON they become. What they cannot do is pay real tickets or items: GrantRewards logs those.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
-- QA ONLY: enables the Merge Island cheats (the HUD's RESET button, /replay of a top-up).
-- GEK: GEK.CanUseCheats(playerName). MUST BE OFF FOR RELEASE.
--!SerializeField
local _debugCheats: boolean = false

-- QA ONLY: pretend the feature's schedule window is closed. GEK: the GEKFeatures schedule.
--!SerializeField
local _debugWindowClosed: boolean = false

-- QA ONLY: seconds every currency call waits before answering, to feel the backend round trip
-- a real ModifyPlayer has. 0 answers at once.
--!SerializeField
local _debugCurrencyLatency: number = 0

-- QA ONLY: every record load fails (after its retries), to test the refuse-to-play path.
--!SerializeField
local _debugFailLoad: boolean = false

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- The GEKFeatures flag id this feature will be registered under.
FEATURE_ID = "merge_island"

-- Standalone only: the event every record is keyed to. Bumping it starts a NEW EVENT for every
-- player on their next load (fresh board, fresh ledger, empty wallet). GEK: GEK.GetEventID().
local STANDALONE_EVENT_ID = "event_003"

-- Standalone only: the Merge Tokens granted once per event, standing in for the event's
-- participation-track grant (51 in the spec). In the Game Event Kit this is 0: the track grants
-- the tokens, and Merge Island grants none of its own.
STANDALONE_STARTER_TOKENS = 51

-- Record loads retry after these delays (seconds), then give up. GEK: MinigameUtils LOAD_RETRY_DELAYS.
local LOAD_RETRY_DELAYS = { 2, 5, 10 }

-- Debounced record writes (MarkDirty) are swept on this interval, at most this many per sweep,
-- which keeps a room of busy players inside the Storage rate limit (~10-20 calls/sec).
local SWEEP_INTERVAL_SECONDS = 5
local MAX_WRITES_PER_SWEEP = 8

local LOG_PREFIX = "[MergeIslandKit] "

-- The per-event reward tables, standing in for the EventSettings JSON fields of the same names
-- (GEK.RewardTable(id)). Every row is plain data shaped exactly as the JSON will be, so moving
-- them is a copy into GEK/RewardDefaults/<id>.json and the event's EventSettings asset.
--   mergeIslandDiscovery: [{ tier, rewards: [{ kind, itemId?, amount, label }] }] -- paid once,
--                         the first time a tier is made. Merge Tokens are kind "coins".
--   mergeIslandJackpot:   [{ kind, itemId?, amount, label, icon? }] -- paid once, when every
--                         tier has been made. `icon` is the standalone card art class; the kit
--                         draws real items from their item art.
--   mergeIslandTopUps:    [{ amount, productId, priceLabel }] -- the out-of-tokens packs, each
--                         buyable once per event. PLACEHOLDER amounts, prices and product ids.
local REWARD_TABLES = {
    mergeIslandDiscovery = {
        { tier = 4, rewards = {
            { kind = "coins", amount = 5, label = "Merge Tokens" },
        } },
        { tier = 5, rewards = {
            { kind = "coins", amount = 5, label = "Merge Tokens" },
            { kind = "tickets", amount = 50, label = "Tickets" },
        } },
        { tier = 6, rewards = {
            { kind = "coins", amount = 10, label = "Merge Tokens" },
            { kind = "tickets", amount = 75, label = "Tickets" },
        } },
        { tier = 7, rewards = {
            { kind = "coins", amount = 10, label = "Merge Tokens" },
            { kind = "tickets", amount = 125, label = "Tickets" },
        } },
        { tier = 8, rewards = {
            { kind = "coins", amount = 15, label = "Merge Tokens" },
            { kind = "tickets", amount = 200, label = "Tickets" },
        } },
        { tier = 9, rewards = {
            { kind = "coins", amount = 20, label = "Merge Tokens" },
            { kind = "tickets", amount = 300, label = "Tickets" },
        } },
        { tier = 10, rewards = {
            { kind = "coins", amount = 20, label = "Merge Tokens" },
            { kind = "tickets", amount = 500, label = "Tickets" },
        } },
        { tier = 11, rewards = {
            { kind = "coins", amount = 25, label = "Merge Tokens" },
            { kind = "tickets", amount = 800, label = "Tickets" },
        } },
        { tier = 12, rewards = {
            { kind = "coins", amount = 30, label = "Merge Tokens" },
            { kind = "tickets", amount = 1200, label = "Tickets" },
        } },
    },
    mergeIslandJackpot = {
        { kind = "item", itemId = "merge_jackpot_hat", amount = 1, label = "Captain's Hat",
          icon = "jackpot-icon-hat" },
        { kind = "item", itemId = "merge_jackpot_coat", amount = 1, label = "Captain's Coat",
          icon = "jackpot-icon-coat" },
        { kind = "item", itemId = "merge_jackpot_boots", amount = 1, label = "Captain's Boots",
          icon = "jackpot-icon-boots" },
        { kind = "item", itemId = "merge_jackpot_cutlass", amount = 1, label = "Captain's Cutlass",
          icon = "jackpot-icon-cutlass" },
    },
    mergeIslandTopUps = {
        { amount = 25, productId = "merge_island_tokens_25", priceLabel = "900 Gold" },
        { amount = 60, productId = "merge_island_tokens_60", priceLabel = "1,800 Gold" },
        { amount = 150, productId = "merge_island_tokens_150", priceLabel = "3,900 Gold" },
    },
}

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- Per-player analytics counters, printed as one line when the player leaves. Cleared on
-- disconnect. GEK: AnalyticsModule_GEK.
local counters: {[Player]: {[string]: number}} = {}
-- Reward tables already reported broken, so each alerts once.
local reportedTables: {[string]: boolean} = {}

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local _copy = {}
    for key, inner in pairs(value) do
        _copy[key] = deepCopy(inner)
    end
    return _copy
end

-- Run `fn` after the simulated backend latency (immediately when it is 0).
local function afterLatency(fn)
    if _debugCurrencyLatency and _debugCurrencyLatency > 0 then
        Timer.After(_debugCurrencyLatency, fn)
    else
        fn()
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
-- GEK: GEK.IsFeatureEnabled(FEATURE_ID). A disabled feature connects no handlers.
function IsFeatureEnabled(): boolean
    return true
end

-- GEK: GEK.IsFeatureActive(FEATURE_ID) -- flag AND schedule window; fails closed.
function IsWindowOpen(): boolean
    return not _debugWindowClosed
end

-- GEK: GEK.GetEventID(). Only valid once OnEventReady has fired.
function GetEventId(): string
    return STANDALONE_EVENT_ID
end

-- GEK: GEK.OnEventReady(cb) -- fires at once when the event data is already there.
function OnEventReady(cb)
    if cb then
        cb()
    end
end

-- GEK: GEK.LogError(message). Callers supply their own "[Module] ALERT:" prefix.
function LogError(message: string)
    print("<color=red>" .. tostring(message) .. "</color>")
end

-- GEK: GEK.CanUseCheats(player.name). The client asks the server (the snapshot's canCheat).
function CanUseCheats(player: Player?): boolean
    return _debugCheats
end

-- GEK: MinigameUtils_GEK.GetFullBoostMultiplier(player) (server). Scales ticket payouts only.
function GetFullBoostMultiplier(player: Player): number
    return 1
end

-- GEK: GEK.RewardTable(id) -- a FRESH copy of the per-event table, or {} plus one alert when the
-- table is missing or empty, so a feature visibly grants nothing instead of a past event's data.
function RewardTable(id: string): any
    local _table = REWARD_TABLES[id]
    if type(_table) ~= "table" or next(_table) == nil then
        if not reportedTables[id] then
            reportedTables[id] = true
            LogError(LOG_PREFIX .. "ALERT: reward table '" .. tostring(id) .. "' is missing or empty")
        end
        return {}
    end
    return deepCopy(_table)
end

-- GEK: AudioManager_GEK / the theme's sound set. Sound is decoration, so a missing clip never
-- breaks gameplay.
function PlaySfx(name: string)
    pcall(function()
        Sounds[name]:Play()
    end)
end

-- GEK: AnalyticsModule_GEK.LogBulkAction(player, name, amount) (amount 1 = LogPlayerAction).
function LogAction(player: Player, name: string, amount: number?)
    if not server or not player then
        return
    end
    local _amount = amount or 1
    if _amount <= 0 then
        return
    end
    local _counters = counters[player]
    if not _counters then
        _counters = {}
        counters[player] = _counters
    end
    _counters[name] = (_counters[name] or 0) + _amount
end

-- GEK: MinigameUtils_GEK.NewRecordStore(config), with two additions this seam relies on and the
-- port upstreams into the kit: per-player writes are SERIALIZED (one write in flight; persists
-- requested meanwhile share one follow-up write of the freshest record, so two writes can never
-- land out of order and erase a claim), and MarkDirty debounces frequent changes into a capped
-- sweep. A record that never loads stays nil and the game refuses to play.
--
-- config = { id = "merge_island board", storageKey = "MergeIslandBoard", defaults = {} }
-- store.Get(player) -> record | nil (nil until loaded)
-- store.IsLoaded(player) / store.IsLoadFailed(player) -> boolean
-- store.Persist(player, cb) -- write now (serialized); cb(ok)
-- store.MarkDirty(player) -- write within SWEEP_INTERVAL_SECONDS
-- store.SetOnLoaded(fn(player, record)) / store.SetOnLoadFailed(fn(player))
-- store.ServerInit() -- call from the game module's self:ServerAwake()
function NewRecordStore(config)
    if not server then
        return nil
    end
    local store = {}
    store.id = config.id or "minigame"
    local _key = config.storageKey
    local _defaults = config.defaults or {}
    -- [Player] = { loaded, failed, data, writing, queued, queuedCallbacks, dirty, leaving }
    local _records = {}
    local _onLoaded = nil
    local _onLoadFailed = nil
    local _sweepCursor = 0

    local function writeNow(player: Player, rec, callbacks)
        rec.writing = true
        rec.dirty = false
        local _name = tostring(player.name)
        Storage.SetPlayerValue(player, _key, deepCopy(rec.data), function(err)
            rec.writing = false
            local _ok = err == StorageError.None
            if not _ok then
                -- Left dirty so the sweep retries it while the player is here.
                rec.dirty = true
                LogError(LOG_PREFIX .. "[" .. store.id .. " store] ALERT: persist failed for " .. _name
                    .. ": " .. tostring(err))
            end
            for _, cb in ipairs(callbacks) do
                cb(_ok)
            end
            if rec.queued then
                local _next = rec.queuedCallbacks
                rec.queued = false
                rec.queuedCallbacks = {}
                writeNow(player, rec, _next)
                return
            end
            if rec.leaving then
                if rec.dirty then
                    LogError(LOG_PREFIX .. "[" .. store.id .. " store] ALERT: final persist failed for "
                        .. _name .. " after disconnect; last changes lost")
                end
                if _records[player] == rec then
                    _records[player] = nil
                end
            end
        end)
    end

    local function load(player: Player, attempt: number)
        local _rec = _records[player]
        if not _rec then
            return
        end
        Storage.GetPlayerValue(player, _key, function(value, err)
            if _records[player] ~= _rec or _rec.leaving then
                return
            end
            if err ~= StorageError.None or _debugFailLoad then
                local _delay = LOAD_RETRY_DELAYS[attempt]
                if _delay then
                    Timer.After(_delay, function()
                        load(player, attempt + 1)
                    end)
                    return
                end
                _rec.failed = true
                LogError(LOG_PREFIX .. "[" .. store.id .. " store] ALERT: load failed for "
                    .. tostring(player.name) .. " after retries (" .. tostring(err)
                    .. ") -- game disabled this session")
                if _onLoadFailed then
                    _onLoadFailed(player)
                end
                return
            end
            -- Stored fields over the defaults, so an older record picks up fields added since.
            local _data = deepCopy(_defaults)
            if type(value) == "table" then
                for key, inner in pairs(value) do
                    _data[key] = inner
                end
            end
            _rec.data = _data
            _rec.loaded = true
            if _onLoaded then
                _onLoaded(player, _data)
            end
        end)
    end

    function store.Get(player: Player)
        local _rec = _records[player]
        if not _rec or not _rec.loaded then
            return nil
        end
        return _rec.data
    end

    function store.IsLoaded(player: Player): boolean
        local _rec = _records[player]
        return (_rec and _rec.loaded and not _rec.leaving) or false
    end

    function store.IsLoadFailed(player: Player): boolean
        local _rec = _records[player]
        return (_rec and _rec.failed) or false
    end

    function store.Persist(player: Player, cb)
        local _rec = _records[player]
        if not _rec or not _rec.loaded or _rec.leaving then
            if cb then
                cb(false)
            end
            return
        end
        if _rec.writing then
            _rec.queued = true
            if cb then
                table.insert(_rec.queuedCallbacks, cb)
            end
            return
        end
        writeNow(player, _rec, if cb then { cb } else {})
    end

    function store.MarkDirty(player: Player)
        local _rec = _records[player]
        if _rec and _rec.loaded and not _rec.leaving then
            _rec.dirty = true
        end
    end

    function store.SetOnLoaded(fn)
        _onLoaded = fn
    end

    function store.SetOnLoadFailed(fn)
        _onLoadFailed = fn
    end

    function store.ServerInit()
        server.PlayerConnected:Connect(function(player: Player)
            _records[player] = {
                loaded = false,
                failed = false,
                data = nil,
                writing = false,
                queued = false,
                queuedCallbacks = {},
                dirty = false,
                leaving = false,
            }
            load(player, 1)
        end)

        -- The record outlives the player until its last write lands, so a change made just
        -- before leaving is not lost and a write in flight cannot be overtaken.
        server.PlayerDisconnected:Connect(function(player: Player)
            local _rec = _records[player]
            if not _rec then
                return
            end
            if not _rec.loaded then
                _records[player] = nil
                _rec.leaving = true
                return
            end
            _rec.leaving = true
            if _rec.writing then
                _rec.queued = _rec.queued or _rec.dirty
                return
            end
            if _rec.dirty then
                writeNow(player, _rec, {})
                return
            end
            _records[player] = nil
        end)

        Timer.Every(SWEEP_INTERVAL_SECONDS, function()
            local _pending = {}
            for player, rec in pairs(_records) do
                if rec.loaded and rec.dirty and not rec.writing and not rec.leaving then
                    table.insert(_pending, player)
                end
            end
            if #_pending == 0 then
                return
            end
            -- Round-robin so a long queue drains fairly instead of starving the tail.
            for _ = 1, math.min(#_pending, MAX_WRITES_PER_SWEEP) do
                _sweepCursor = (_sweepCursor % #_pending) + 1
                store.Persist(_pending[_sweepCursor], nil)
            end
        end)
    end

    return store
end

-- GEK: MinigameUtils_GEK.NewCurrency({ type = "item", itemId, bet }) -- an event-inventory item
-- whose balance the BACKEND owns. Debit and Grant are each one async write, never
-- check-then-debit, and either can fail; the caller pre-checks and holds its own lock.
--
-- Standalone it is a per-player wallet record (keyed to the event, so a new event starts empty)
-- with optional simulated latency. Members the port changes:
--   currency.GetBalance(player)  -- GEK takes the player's tracker entry: GetBalance(pData)
--   currency.ServerInit()        -- standalone only (the kit's currency needs no init)
--   currency.IsReady(player)     -- GEK: PlayerTracker_GEK has the player
--   currency.SetOnReady(fn)      -- GEK: PlayerTracker_GEK's connected hook
function NewCurrency(config)
    local currency = {}
    currency.type = config.type or "item"
    currency.itemId = config.itemId
    currency.bet = config.bet

    if not server then
        function currency.GetBalance(player: Player): number
            return 0
        end
        return currency
    end

    local _wallet = NewRecordStore({
        id = tostring(config.itemId) .. " wallet",
        storageKey = "MergeIslandWallet",
        defaults = { eventId = "", balance = 0 },
    })
    local _onReady = nil

    function currency.ServerInit()
        _wallet.SetOnLoaded(function(player: Player, record)
            if record.eventId ~= GetEventId() then
                -- Event inventory items do not carry over between events.
                record.eventId = GetEventId()
                record.balance = 0
                _wallet.Persist(player, nil)
            end
            if _onReady then
                _onReady(player)
            end
        end)
        _wallet.SetOnLoadFailed(function(player: Player)
            if _onReady then
                _onReady(player)
            end
        end)
        _wallet.ServerInit()
    end

    function currency.SetOnReady(fn)
        _onReady = fn
    end

    function currency.IsReady(player: Player): boolean
        return _wallet.IsLoaded(player)
    end

    function currency.IsLoadFailed(player: Player): boolean
        return _wallet.IsLoadFailed(player)
    end

    function currency.GetBalance(player: Player): number
        local _record = _wallet.Get(player)
        return (_record and math.max(0, math.floor(tonumber(_record.balance) or 0))) or 0
    end

    -- cb(ok, balanceAfter). A failed write is reverted in memory, so the caller can treat a
    -- failure as "nothing was spent".
    function currency.Debit(player: Player, amount: number, cb)
        afterLatency(function()
            local _record = _wallet.Get(player)
            local _amount = math.floor(tonumber(amount) or 0)
            if not _record or not _wallet.IsLoaded(player) or _amount < 1 then
                if cb then
                    cb(false, currency.GetBalance(player))
                end
                return
            end
            if currency.GetBalance(player) < _amount then
                if cb then
                    cb(false, currency.GetBalance(player))
                end
                return
            end
            _record.balance = currency.GetBalance(player) - _amount
            _wallet.Persist(player, function(ok)
                if not ok then
                    _record.balance = currency.GetBalance(player) + _amount
                end
                if cb then
                    cb(ok, currency.GetBalance(player))
                end
            end)
        end)
    end

    -- cb(ok, balanceAfter).
    function currency.Grant(player: Player, amount: number, cb)
        afterLatency(function()
            local _record = _wallet.Get(player)
            local _amount = math.floor(tonumber(amount) or 0)
            if not _record or not _wallet.IsLoaded(player) or _amount < 1 then
                if cb then
                    cb(false, currency.GetBalance(player))
                end
                return
            end
            _record.balance = currency.GetBalance(player) + _amount
            _wallet.Persist(player, function(ok)
                if not ok then
                    _record.balance = math.max(0, currency.GetBalance(player) - _amount)
                end
                if cb then
                    cb(ok, currency.GetBalance(player))
                end
            end)
        end)
    end

    return currency
end

-- GEK: MinigameUtils_GEK.GrantRewards(player, rewards, currency, cb, betName) -- folds a list of
-- { kind = coins|tickets|item|energy|tokens, itemId?, amount } into ONE backend write; cb(ok).
-- A reported failure may hide a grant that landed, so callers never retry it.
--
-- Standalone, Merge Tokens ("coins") are real (they go through `currency`); every other kind is
-- logged as earned and NOT granted, since no backend exists here to grant it.
function GrantRewards(player: Player, rewards: {any}, currency, cb, betName: string?)
    if not server then
        if cb then
            cb(false)
        end
        return
    end
    local _coins = 0
    local _logged = {}
    for _, reward in ipairs(rewards or {}) do
        local _amount = math.max(1, math.floor(tonumber(reward.amount) or 0))
        if reward.kind == "coins" then
            _coins = _coins + _amount
        elseif reward.kind == "item" and (type(reward.itemId) ~= "string" or reward.itemId == "") then
            print(LOG_PREFIX .. "WARNING: item reward with no itemId skipped")
        elseif reward.kind == "item" then
            table.insert(_logged, "item " .. reward.itemId .. " x" .. _amount)
        elseif reward.kind == "tickets" or reward.kind == "energy" or reward.kind == "tokens" then
            table.insert(_logged, reward.kind .. " x" .. _amount)
        else
            print(LOG_PREFIX .. "WARNING: unknown reward kind '" .. tostring(reward.kind) .. "' skipped")
        end
    end
    local _name = tostring(player.name)
    local _bet = betName or (currency and currency.bet) or "?"
    local function finish(ok: boolean)
        if ok and #_logged > 0 then
            print(LOG_PREFIX .. "REWARD (standalone, not granted): " .. _name .. " earned "
                .. table.concat(_logged, ", ") .. " [bet=" .. _bet .. "]")
        end
        if cb then
            cb(ok)
        end
    end
    if _coins > 0 and currency then
        currency.Grant(player, _coins, function(ok)
            finish(ok)
        end)
        return
    end
    afterLatency(function()
        finish(true)
    end)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:ServerAwake()
    if _debugCheats then
        print(LOG_PREFIX .. "WARNING: _debugCheats ENABLED -- Merge Island cheats are open to every"
            .. " player (QA only, must be OFF for release)")
    end
    if _debugWindowClosed then
        print(LOG_PREFIX .. "WARNING: _debugWindowClosed ENABLED -- the window reads as closed")
    end
    if _debugFailLoad then
        print(LOG_PREFIX .. "WARNING: _debugFailLoad ENABLED -- every record load fails")
    end
    if _debugCurrencyLatency and _debugCurrencyLatency > 0 then
        print(LOG_PREFIX .. "currency latency simulated: " .. tostring(_debugCurrencyLatency) .. "s")
    end

    server.PlayerDisconnected:Connect(function(player: Player)
        local _counters = counters[player]
        counters[player] = nil
        if not _counters then
            return
        end
        local _keys = {}
        for key in pairs(_counters) do
            table.insert(_keys, key)
        end
        table.sort(_keys)
        local _parts = { "[MergeIslandKit] SESSION_SUMMARY player_name=" .. tostring(player.name) }
        for _, key in ipairs(_keys) do
            table.insert(_parts, key .. "=" .. tostring(_counters[key]))
        end
        print(table.concat(_parts, " | "))
    end)
end
