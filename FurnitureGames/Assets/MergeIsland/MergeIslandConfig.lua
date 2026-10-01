--!Type(Module)

-- MergeIslandConfig -- the item ladder, economy tables, and the SHARED rules for Merge Island.
--
-- The item chain is a SINGLE LINEAR LADDER: tier 1 merges into tier 2, up to MAX_TIER. There
-- is no item "type" dimension, so a cell is fully described by its state and its tier, and two
-- items match if and only if their tiers match.
--
-- This module is pure: no state, no networking, no lifecycle hooks. That is the point. The
-- server calls ResolveDrop to validate and apply a move; the client calls the SAME function to
-- decide whether a drag should snap back. One source of truth means the client's optimistic
-- feedback can never disagree with the server's authoritative answer. The same goes for every
-- economy table below: the HUD advertises exactly what the server pays.
--
-- Randomness is deliberately kept OUT of ResolveDrop/ApplyDrop -- they are deterministic, so
-- both sides agree. The functions that roll dice (RandomEmptyOpenCell, RollSpawnLuck) are only
-- ever called by the server. The board layout itself is fixed (see GHOST_MAP).
--
-- Economy (Merge minigame spec v1, north star: Coin Master's Merge Island):
--   * Every generator tap costs 1 Merge Token and spawns a tier-1 item on a random free cell.
--     The spawn multiplier spends M tokens for the item M tier-1s would merge into. Only x1
--     exists at first; making item 8 unlocks x2 and item 10 unlocks x4 (see SPAWN_MULTIPLIERS).
--   * A spawn can roll "Lucky!" (+1 tier) or, at x2 and up, "Legendary!" (+2 tiers). See
--     SPAWN_LUCK.
--   * The first time an item is made it fills its slot on the 12-item discovery track and pays
--     that tier's `rewards` table (tiers 1-3 pay nothing). Filling the whole track wins the
--     JACKPOT set, once per event. After that the player can keep playing for fun but earns
--     nothing more, and the top tier cannot merge any further.
--   * Out of tokens, the dispenser offers TOPUP_OFFERS, each buyable once per event.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Board geometry. Row 1 is the TOP row, so the start area below sits at the bottom of the board.
COLS = 7
ROWS = 7
CELL_COUNT = COLS * ROWS

-- The fixed board layout, one row per line, top row first. Each number is the tier a cell's
-- ghost ACCEPTS (the item that unlocks it); 0 marks the starting playable area. Every board
-- uses this same map. A ghost can never ask for MAX_TIER (satisfying a tier-T ghost yields T+1).
GHOST_MAP = {
    { 6, 2, 3, 3, 1, 3, 3 },
    { 3, 1, 6, 3, 8, 3, 8 },
    { 1, 1, 6, 3, 6, 6, 3 },
    { 8, 1, 1, 1, 6, 1, 3 },
    { 1, 8, 1, 1, 1, 6, 3 },
    { 8, 8, 0, 0, 0, 1, 6 },
    { 1, 1, 0, 0, 0, 1, 3 },
}

-- Cell states. Numeric so the persisted payload stays small.
STATE_HIDDEN = 0    -- locked, nothing shown (plain tile)
STATE_GHOST = 1     -- locked, shows the silhouette of the tier it accepts
STATE_OPEN = 2      -- unlocked; may or may not hold an item

-- Bumped whenever the persisted board SHAPE changes. A save from a different version is
-- discarded rather than half-read, which is what keeps a format change from producing a board
-- that is subtly wrong instead of obviously fresh.
-- v3: start area moved from the board centre to the bottom-centre rectangle.
-- v4: saves carry the discovery progress (highestTier).
-- v5: 5x7 board, 8 tiers, Merge Tokens, Merge Points and the progression track.
-- v6: 7x7 board.
-- v7: 12 tiers; points and the track are gone, saves carry jackpotWon.
-- v8: ghost tiers come from the fixed GHOST_MAP instead of a random ramp.
SAVE_VERSION = 8

-- Bumping EVENT_ID starts a NEW EVENT for every player on their next load: a fresh board, a
-- fresh token grant and an empty discovery track -- so every event's jackpot can be won once.
EVENT_ID = "event_003"

-- Merge Tokens: the generator's play currency. TOKENS_START stands in for the event's
-- participation-track grant (51 in the spec) until this runs inside the Game Event Kit.
TOKENS_START = 51
SPAWN_COST = 1
-- Spawns enter the ladder at the bottom...
SPAWN_TIER = 1
-- ...unless the player raised the spawn multiplier. The HUD's multiplier button cycles through
-- the UNLOCKED ones; a tap at multiplier M costs M * SPAWN_COST and spawns the item that M
-- bottom-tier items would merge into: x1 -> tier 1, x2 -> tier 2, x4 -> tier 3. `unlockTier` is
-- the item whose first discovery unlocks it (x1 is always there). Each `mult` must be a power of
-- two, in ascending order, starting at 1. x4 is the cap: grinding low tiers at the late stages is
-- what the multiplier exists to spare the player.
SPAWN_MULTIPLIERS = {
    { mult = 1, unlockTier = 1 },
    { mult = 2, unlockTier = 8 },
    { mult = 4, unlockTier = 10 },
}

-- Spawn luck, per multiplier: the chance a spawn comes out "Lucky!" (LUCK_BONUS.lucky tiers above
-- the multiplier's tier) or "Legendary!" (LUCK_BONUS.legendary tiers above it). x1 has no
-- Legendary.
LUCK_NONE = "none"
LUCK_LUCKY = "lucky"
LUCK_LEGENDARY = "legendary"
LUCK_BONUS = { [LUCK_NONE] = 0, [LUCK_LUCKY] = 1, [LUCK_LEGENDARY] = 2 }
SPAWN_LUCK = {
    [1] = { lucky = 0.036, legendary = 0 },
    [2] = { lucky = 0.036, legendary = 0.041 },
    [4] = { lucky = 0.036, legendary = 0.041 },
}

-- The out-of-tokens offers. Each can be bought ONCE per event; once all are bought, an empty
-- dispenser just shakes. PLACEHOLDER amounts and prices (TODO Charles), and a PLACEHOLDER
-- purchase: see MergeIslandManager's TopUpRequest.
TOPUP_OFFERS = {
    { amount = 25, priceLabel = "900 Gold" },
    { amount = 60, priceLabel = "1,800 Gold" },
    { amount = 150, priceLabel = "3,900 Gold" },
}

-- On satisfying a ghost, do its locked neighbours become fully playable (true), or merely get
-- revealed as new ghosts (false)? Existing ghost neighbours stay ghosts when false.
UNLOCK_NEIGHBOURS_OPEN = false
-- PENDING PLAYTEST DECISION. Whether adjacency (for both unlocking and ghost seeding) counts
-- the four diagonals as well as the four orthogonals.
ADJACENCY_INCLUDES_DIAGONALS = false

-- Rejection reasons, surfaced to the client so the UI can explain a refused action.
REJECT_OUT_OF_BOUNDS = "out_of_bounds"
REJECT_NO_ITEM = "no_item"
REJECT_SAME_CELL = "same_cell"
REJECT_LOCKED = "locked"
REJECT_MISMATCH = "mismatch"
REJECT_MAX_TIER = "max_tier"
REJECT_NO_ENERGY = "no_energy"
REJECT_BOARD_FULL = "board_full"
REJECT_TOPUP_UNAVAILABLE = "topup_unavailable"
REJECT_OFFER_BOUGHT = "offer_bought"

-- Drop outcome kinds.
KIND_MOVE = "move"          -- item relocated to an empty open cell
KIND_MERGE = "merge"        -- two matching items became one of the next tier
KIND_UNLOCK = "unlock"      -- a ghost was satisfied: next tier placed AND the board expands

-- Reward kinds. Tokens are REAL in this build (they go straight into the player's wallet).
-- Everything else (discovery tickets, the jackpot) is a PLACEHOLDER: the server logs what it
-- would grant (see grantReward in MergeIslandManager) and the HUD displays it. The kind decides
-- the icon and the wording.
REWARD_TOKENS = "tokens"
REWARD_TICKETS = "tickets"
REWARD_ITEM = "item"

--------------------------------
------  TYPE DEFINITIONS  ------
--------------------------------
-- One board cell. For STATE_GHOST, `tier` is the tier the ghost ACCEPTS. For STATE_OPEN it is
-- the tier of the item sitting on it, and nil when the cell is empty.
export type Cell = {
    state: number,
    tier: number | nil,
}

-- What ResolveDrop reports back. `ok` false means the drag must snap back and `reason` explains
-- why. `ok` true carries everything ApplyDrop needs.
export type DropResult = {
    ok: boolean,
    reason: string | nil,
    kind: string | nil,
    from: number | nil,
    to: number | nil,
    tier: number | nil,
}

--------------------------------
------    GLOBAL STATE    ------
--------------------------------
-- The item ladder, ordered bottom to top: a tier's INDEX is its tier number. Exposed globally
-- because both the server (validation) and the UI (tile art and labels) read it.
--
-- `class` is the USS class that carries the tier's art. The ladder IS the discovery track (one
-- slot per row), so adding a tier is one more row here.
--
-- `rewards` is paid ONCE, the first time the tier is made this event, and the HUD's track bubble
-- advertises the next one. Tokens are real; the rest are PLACEHOLDERS (see REWARD_* above), and
-- every amount is a PLACEHOLDER pending the economy spec. A row without `rewards` pays nothing.
ITEM_TIERS = {
    { label = "Shell", class = "item-tier-1" },
    { label = "Bottle", class = "item-tier-2" },
    { label = "Compass", class = "item-tier-3" },
    { label = "Treasure Map", class = "item-tier-4", rewards = {
        { kind = REWARD_TOKENS, amount = 5, label = "Merge Tokens" },
    } },
    { label = "Treasure Chest", class = "item-tier-5", rewards = {
        { kind = REWARD_TOKENS, amount = 5, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 50, label = "Tickets" },
    } },
    { label = "Golden Idol", class = "item-tier-6", rewards = {
        { kind = REWARD_TOKENS, amount = 10, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 75, label = "Tickets" },
    } },
    { label = "Pirate Ship", class = "item-tier-7", rewards = {
        { kind = REWARD_TOKENS, amount = 10, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 125, label = "Tickets" },
    } },
    { label = "Lighthouse", class = "item-tier-8", rewards = {
        { kind = REWARD_TOKENS, amount = 15, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 200, label = "Tickets" },
    } },
    { label = "Treasure Island", class = "item-tier-9", rewards = {
        { kind = REWARD_TOKENS, amount = 20, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 300, label = "Tickets" },
    } },
    { label = "Golden Trident", class = "item-tier-10", rewards = {
        { kind = REWARD_TOKENS, amount = 20, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 500, label = "Tickets" },
    } },
    { label = "Jeweled Scepter", class = "item-tier-11", rewards = {
        { kind = REWARD_TOKENS, amount = 25, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 800, label = "Tickets" },
    } },
    { label = "Royal Crown", class = "item-tier-12", rewards = {
        { kind = REWARD_TOKENS, amount = 30, label = "Merge Tokens" },
        { kind = REWARD_TICKETS, amount = 1200, label = "Tickets" },
    } },
}

-- The top of the ladder. An item here cannot merge any further, and no ghost may ask for it
-- (satisfying a tier-T ghost yields T+1, so there would be nothing to produce).
MAX_TIER = #ITEM_TIERS

-- The jackpot: won once per event, the first time the player makes the top tier -- which is
-- also the moment the discovery track fills. PLACEHOLDER set: the server logs it rather than
-- granting it. The HUD's "Find all items to win" panel shows one card per entry, drawn from its
-- `icon` class. Four entries fill the panel; more will not fit.
JACKPOT = {
    { kind = REWARD_ITEM, itemId = "merge_jackpot_hat", amount = 1, label = "Captain's Hat",
      icon = "jackpot-icon-hat" },
    { kind = REWARD_ITEM, itemId = "merge_jackpot_coat", amount = 1, label = "Captain's Coat",
      icon = "jackpot-icon-coat" },
    { kind = REWARD_ITEM, itemId = "merge_jackpot_boots", amount = 1, label = "Captain's Boots",
      icon = "jackpot-icon-boots" },
    { kind = REWARD_ITEM, itemId = "merge_jackpot_cutlass", amount = 1, label = "Captain's Cutlass",
      icon = "jackpot-icon-cutlass" },
}

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- Neighbour offsets, resolved once from ADJACENCY_INCLUDES_DIAGONALS.
local orthogonalOffsets: {{number}} = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
}
local diagonalOffsets: {{number}} = {
    { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 },
}

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function neighbourOffsets(): {{number}}
    if not ADJACENCY_INCLUDES_DIAGONALS then
        return orthogonalOffsets
    end
    local _all = {}
    for _, o in ipairs(orthogonalOffsets) do
        table.insert(_all, o)
    end
    for _, o in ipairs(diagonalOffsets) do
        table.insert(_all, o)
    end
    return _all
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
-- Flat board index for a cell, or nil when out of bounds. Row 1 is the top row.
function CellIndex(row: number, col: number): number | nil
    if row < 1 or row > ROWS or col < 1 or col > COLS then
        return nil
    end
    return (row - 1) * COLS + col
end

-- Row/col for a flat index. Returns nil, nil when the index is off the board.
function CellCoords(index: number): (number | nil, number | nil)
    if type(index) ~= "number" or index < 1 or index > CELL_COUNT then
        return nil, nil
    end
    local _zero = math.floor(index) - 1
    return math.floor(_zero / COLS) + 1, (_zero % COLS) + 1
end

-- A never-nil cell read, so callers do not need bounds branches. Off-board reads look HIDDEN,
-- which is always the safe answer (nothing can be dropped there).
function CellAt(cells, index: number): Cell
    if not cells or type(index) ~= "number" then
        return { state = STATE_HIDDEN }
    end
    return cells[index] or { state = STATE_HIDDEN }
end

-- Flat indices adjacent to `index`, honouring ADJACENCY_INCLUDES_DIAGONALS.
function Neighbours(index: number): {number}
    local _row, _col = CellCoords(index)
    if not _row then
        return {}
    end
    local _out = {}
    for _, offset in ipairs(neighbourOffsets()) do
        local _n = CellIndex(_row + offset[1], _col + offset[2])
        if _n then
            table.insert(_out, _n)
        end
    end
    return _out
end

-- Display info for one rung of the ladder, used by the UI to pick a class and a label. Accepts
-- an optional tier so callers can pass a cell's `tier` field straight through -- an empty cell
-- has none, and "no rung" is the correct answer rather than a caller-side branch.
function TierInfo(tier: number?)
    if type(tier) ~= "number" then
        return nil
    end
    return ITEM_TIERS[tier]
end

-- A tier's first-discovery rewards, or an empty list when it pays nothing.
function DiscoveryRewards(tier: number?): {any}
    local _info = TierInfo(tier)
    return (_info and _info.rewards) or {}
end

-- Every first-discovery reward for tiers fromTier..toTier, summed per kind (and item/icon), in
-- ladder order. A multiplied or lucky spawn can jump the track several tiers at once, and each
-- tier it skips over counts as discovered, so each one pays. Shared so the HUD shows exactly
-- what the server pays.
function DiscoveryRewardsBetween(fromTier: number, toTier: number): {any}
    local _out = {}
    local _byKey = {}
    for tier = math.max(1, fromTier), math.min(MAX_TIER, toTier) do
        for _, reward in ipairs(DiscoveryRewards(tier)) do
            local _key = tostring(reward.kind) .. "|" .. tostring(reward.itemId or reward.icon or "")
            local _merged = _byKey[_key]
            if _merged then
                _merged.amount = _merged.amount + reward.amount
            else
                _merged = {
                    kind = reward.kind,
                    amount = reward.amount,
                    label = reward.label,
                    icon = reward.icon,
                    itemId = reward.itemId,
                }
                _byKey[_key] = _merged
                table.insert(_out, _merged)
            end
        end
    end
    return _out
end

-- The Merge Tokens part of DiscoveryRewardsBetween.
function DiscoveryTokensBetween(fromTier: number, toTier: number): number
    local _total = 0
    for _, reward in ipairs(DiscoveryRewardsBetween(fromTier, toTier)) do
        if reward.kind == REWARD_TOKENS then
            _total = _total + reward.amount
        end
    end
    return _total
end

-- The lowest tier above `highestTier` that pays a discovery reward, or nil when none is left.
function NextRewardTier(highestTier: number): number | nil
    for tier = math.max(1, highestTier + 1), MAX_TIER do
        if #DiscoveryRewards(tier) > 0 then
            return tier
        end
    end
    return nil
end

-- Does this cell hold a draggable item?
function HasItem(cells, index: number): boolean
    local _cell = CellAt(cells, index)
    return _cell.state == STATE_OPEN and _cell.tier ~= nil
end

-- The GHOST_MAP entry for a cell: the tier its ghost accepts, or 0 for a start cell. Off-board
-- or missing entries read as 0.
function MapTier(index: number): number
    local _row, _col = CellCoords(index)
    if not _row then
        return 0
    end
    local _mapRow = GHOST_MAP[_row]
    return (_mapRow and _mapRow[_col]) or 0
end

-- Is this cell part of the initial playable area?
function IsStartCell(index: number): boolean
    return MapTier(index) == 0
end

-- The ghost spec for a cell, read from GHOST_MAP. Clamped below the top tier, since satisfying a
-- tier-T ghost yields T+1.
function GhostFor(index: number): Cell
    local _tier = math.max(1, math.min(MapTier(index), MAX_TIER - 1))
    return { state = STATE_GHOST, tier = _tier }
end

-- Decide what dropping the item at `from` onto `to` does. PURE and DETERMINISTIC: the client
-- uses it to gate a drag, the server uses it to validate one. Never mutates `cells`.
function ResolveDrop(cells, from: number, to: number): DropResult
    if type(from) ~= "number" or type(to) ~= "number" or from ~= from or to ~= to then
        return { ok = false, reason = REJECT_OUT_OF_BOUNDS }
    end
    from = math.floor(from)
    to = math.floor(to)
    if from < 1 or from > CELL_COUNT or to < 1 or to > CELL_COUNT then
        return { ok = false, reason = REJECT_OUT_OF_BOUNDS }
    end
    if from == to then
        return { ok = false, reason = REJECT_SAME_CELL }
    end
    if not HasItem(cells, from) then
        return { ok = false, reason = REJECT_NO_ITEM }
    end

    -- HasItem above already guarantees a tier here; `or 0` is only to keep it a plain number for
    -- the type checker, since a cell's tier field is legitimately optional.
    local _tier: number = CellAt(cells, from).tier or 0
    local _target = CellAt(cells, to)

    -- Locked and blank: nothing to interact with.
    if _target.state == STATE_HIDDEN then
        return { ok = false, reason = REJECT_LOCKED }
    end

    -- A ghost is a lock AND a merge partner: a matching item is consumed, the ghost cell becomes
    -- the NEXT tier, and the board expands from there.
    if _target.state == STATE_GHOST then
        if _target.tier ~= _tier then
            return { ok = false, reason = REJECT_MISMATCH }
        end
        if _tier >= MAX_TIER then
            return { ok = false, reason = REJECT_MAX_TIER }
        end
        return { ok = true, kind = KIND_UNLOCK, from = from, to = to, tier = _tier + 1 }
    end

    -- Open and empty: a plain relocation.
    if not HasItem(cells, to) then
        return { ok = true, kind = KIND_MOVE, from = from, to = to, tier = _tier }
    end

    -- Open and occupied: merge only when the tiers match.
    if _target.tier ~= _tier then
        return { ok = false, reason = REJECT_MISMATCH }
    end
    if _tier >= MAX_TIER then
        return { ok = false, reason = REJECT_MAX_TIER }
    end
    return { ok = true, kind = KIND_MERGE, from = from, to = to, tier = _tier + 1 }
end

-- Apply a resolved drop, mutating `cells` in place. The board expansion that follows an unlock
-- is deliberately NOT here: the server owns it (see ExpandFrom).
function ApplyDrop(cells, result: DropResult)
    if not cells or not result or not result.ok then
        return
    end
    cells[result.from] = { state = STATE_OPEN }
    cells[result.to] = { state = STATE_OPEN, tier = result.tier }
end

-- SERVER ONLY. Any HIDDEN cell touching an OPEN cell becomes a ghost. This is what
-- makes new objectives appear every time the board grows -- the frontier is always ghosted,
-- everything beyond it stays blank. Returns the indices that were ghosted.
function SeedGhostRing(cells): {number}
    if not cells then
        return {}
    end
    -- Collect first, then write: reading and writing in one pass is a trap worth not setting.
    local _toGhost = {}
    for i = 1, CELL_COUNT do
        if CellAt(cells, i).state == STATE_HIDDEN then
            for _, n in ipairs(Neighbours(i)) do
                if CellAt(cells, n).state == STATE_OPEN then
                    table.insert(_toGhost, i)
                    break
                end
            end
        end
    end
    for _, i in ipairs(_toGhost) do
        cells[i] = GhostFor(i)
    end
    return _toGhost
end

-- SERVER ONLY. Grow the board outward from a just-satisfied ghost at `index`: break
-- its locked neighbours open (UNLOCK_NEIGHBOURS_OPEN) or just reveal them as ghosts, then re-seed
-- a fresh ghost ring against the new frontier. Returns the indices that changed (opened, or newly
-- revealed ghosts), so the client can animate them breaking.
function ExpandFrom(cells, index: number): {number}
    if not cells then
        return {}
    end
    local _opened = {}
    if UNLOCK_NEIGHBOURS_OPEN then
        for _, n in ipairs(Neighbours(index)) do
            if CellAt(cells, n).state ~= STATE_OPEN then
                cells[n] = { state = STATE_OPEN }
                table.insert(_opened, n)
            end
        end
    end
    -- Re-ghost the new frontier. This is also what grows the board in the
    -- UNLOCK_NEIGHBOURS_OPEN = false mode: the satisfied ghost itself became playable in
    -- ApplyDrop, so its hidden neighbours are now adjacent to an open cell and get ghosted here.
    local _revealed = SeedGhostRing(cells)
    if UNLOCK_NEIGHBOURS_OPEN then
        return _opened
    end
    return _revealed
end

-- SERVER ONLY. A brand-new board: everything hidden, GHOST_MAP's start cells opened,
-- and the first ghost ring seeded around it.
function NewBoard(): {Cell}
    local _cells = {}
    for i = 1, CELL_COUNT do
        if IsStartCell(i) then
            _cells[i] = { state = STATE_OPEN }
        else
            _cells[i] = { state = STATE_HIDDEN }
        end
    end
    SeedGhostRing(_cells)
    return _cells
end

-- Every empty playable cell, in index order.
function EmptyOpenCells(cells): {number}
    local _out = {}
    for i = 1, CELL_COUNT do
        local _cell = CellAt(cells, i)
        if _cell.state == STATE_OPEN and _cell.tier == nil then
            table.insert(_out, i)
        end
    end
    return _out
end

-- SERVER ONLY (rolls dice). A random empty playable cell, or nil when there is nowhere to spawn.
function RandomEmptyOpenCell(cells): number | nil
    local _empty = EmptyOpenCells(cells)
    if #_empty == 0 then
        return nil
    end
    return _empty[math.random(1, #_empty)]
end

-- Share of the playable area holding an item, 0..100 (telemetry's board_fill_pct).
function BoardFillPct(cells): number
    local _open, _filled = 0, 0
    for i = 1, CELL_COUNT do
        local _cell = CellAt(cells, i)
        if _cell.state == STATE_OPEN then
            _open = _open + 1
            if _cell.tier then
                _filled = _filled + 1
            end
        end
    end
    if _open == 0 then
        return 0
    end
    return math.floor(_filled * 100 / _open + 0.5)
end

-- The multipliers a player who has discovered up to `highestTier` can use, ascending.
function UnlockedMultipliers(highestTier: number): {number}
    local _out = {}
    for _, row in ipairs(SPAWN_MULTIPLIERS) do
        if highestTier >= row.unlockTier then
            table.insert(_out, row.mult)
        end
    end
    return _out
end

-- The largest unlocked multiplier.
function MaxMultiplier(highestTier: number): number
    local _unlocked = UnlockedMultipliers(highestTier)
    return _unlocked[#_unlocked] or 1
end

-- Is `mult` an offered multiplier, and unlocked at `highestTier`? The server checks every spawn
-- request with it.
function IsMultiplierUnlocked(mult, highestTier: number): boolean
    for _, m in ipairs(UnlockedMultipliers(highestTier)) do
        if m == mult then
            return true
        end
    end
    return false
end

-- SERVER ONLY (rolls dice). The luck of one spawn at multiplier `mult`: LUCK_NONE, LUCK_LUCKY or
-- LUCK_LEGENDARY.
function RollSpawnLuck(mult: number): string
    local _odds = SPAWN_LUCK[mult]
    if not _odds then
        return LUCK_NONE
    end
    local _roll = math.random()
    if _roll < _odds.legendary then
        return LUCK_LEGENDARY
    end
    if _roll < _odds.legendary + _odds.lucky then
        return LUCK_LUCKY
    end
    return LUCK_NONE
end

-- Tokens one generator tap costs at multiplier `mult`.
function SpawnCost(mult: number): number
    return SPAWN_COST * mult
end

-- The tier one generator tap spawns at multiplier `mult` (log2 of it, above SPAWN_TIER), plus the
-- LUCK_BONUS of its luck roll. Never the top tier: that is only ever made by merging.
function SpawnTierFor(mult: number, luck: string?): number
    local _tier = SPAWN_TIER
    local _m = 1
    while _m < mult do
        _m = _m * 2
        _tier = _tier + 1
    end
    _tier = _tier + (LUCK_BONUS[luck or LUCK_NONE] or 0)
    return math.min(_tier, math.max(1, MAX_TIER - 1))
end

-- A fresh "which offers were bought" list: one false per TOPUP_OFFERS entry.
function NewOffersBought(): {boolean}
    local _out = {}
    for i = 1, #TOPUP_OFFERS do
        _out[i] = false
    end
    return _out
end

-- Is any offer still unbought?
function HasOffersLeft(bought): boolean
    for i = 1, #TOPUP_OFFERS do
        if not (bought and bought[i]) then
            return true
        end
    end
    return false
end

-- Short player-facing text for a reward, e.g. "+2 Merge Tokens". An item's own label wins.
function RewardText(reward): string
    if not reward then
        return ""
    end
    local _amount = tonumber(reward.amount) or 0
    if reward.kind == REWARD_ITEM then
        local _label = reward.label or reward.itemId or "Item"
        if _amount > 1 then
            return tostring(_amount) .. "x " .. _label
        end
        return _label
    end
    return tostring(_amount) .. " " .. (reward.label or reward.kind or "")
end
