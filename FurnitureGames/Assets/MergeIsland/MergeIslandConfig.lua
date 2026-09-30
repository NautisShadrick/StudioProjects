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
-- both sides agree. The functions that roll dice (RandomGhostFor, SeedGhostRing, ExpandFrom,
-- NewBoard, RandomEmptyOpenCell, RollBonus) are only ever called by the server.
--
-- Economy (Merge minigame spec v1, north star: Coin Master's Merge Island):
--   * Every generator tap costs 1 Merge Token, spawns a tier-1 item on a random free cell, and
--     has a 10% chance of a second bonus tier-1 item.
--   * The first time an item is made it fills its slot on the 12-item discovery track.
--     Discoveries pay nothing on their own; filling the whole track wins the JACKPOT set, once
--     per event.
--   * Items at DELIVER_MIN_TIER+ can be delivered for guaranteed tickets plus a bonus spin;
--     the top tier delivers itself.
--   * Any item can be sold; tier 3+ refunds a token.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Board geometry. Row 1 is the TOP row, so the start area below sits at the bottom of the board.
COLS = 7
ROWS = 7
CELL_COUNT = COLS * ROWS

-- The starting playable area, as an inclusive row/col rectangle: the bottom-centre 3x2 block.
--     1111111
--     1111111
--     1111111
--     1111111
--     1111111
--     1100011
--     1100011
-- Everything outside it starts locked, and ghost rings are measured outward FROM this rectangle
-- (not from the board centre), so moving or resizing it re-tiers the whole board automatically.
START_ROW_MIN = 6
START_ROW_MAX = 7
START_COL_MIN = 3
START_COL_MAX = 5

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
SAVE_VERSION = 7

-- Bumping EVENT_ID starts a NEW EVENT for every player on their next load: a fresh board, a
-- fresh token grant and an empty discovery track -- so every event's jackpot can be won once.
EVENT_ID = "event_003"

-- Merge Tokens: the generator's play currency. TOKENS_START stands in for the event's
-- participation-track grant (51 in the spec) until this runs inside the Game Event Kit.
TOKENS_START = 51
SPAWN_COST = 1
-- Every spawn enters the ladder at the bottom.
SPAWN_TIER = 1
-- Chance a tap spawns a SECOND tier-1 item (only when a second free cell exists).
BONUS_SPAWN_CHANCE = 0.10
-- The empty-state flash top-up. PLACEHOLDER purchase: see MergeIslandManager's TopUpRequest.
TOPUP_AMOUNT = 25
TOPUP_PRICE_LABEL = "900 Gold"

-- Ghost tier ramp. Ghost rings are numbered outward from the edge of the start area, so ring 1
-- is the first locked ring. The ramp is spread over the board's REAL depth: ring 1 asks for
-- tier 1 and the farthest ring asks for the top ghost tier (MAX_TIER - 1), so every item in the
-- ladder shows up as a lock and the island gets harder the further out it grows. The curve
-- (> 1) keeps the first rings gentle and steepens toward the far edge. On the 7x7 board with a
-- bottom 3x2 start (five rings) that is: ring 1 -> 1, 2 -> 3, 3 -> 5, 4 -> 8, 5 -> 11.
GHOST_RAMP_CURVE = 1.2
-- Chance a ghost rolls one tier above its ring's base, so a ring is not visually uniform.
GHOST_TIER_JITTER_CHANCE = 0.25

-- PENDING PLAYTEST DECISION. On satisfying a ghost, do its locked neighbours become fully
-- playable (true), or merely turn into new ghosts (false)? The prototype is ambiguous and this
-- materially changes pacing, so it is one flag.
UNLOCK_NEIGHBOURS_OPEN = true
-- PENDING PLAYTEST DECISION. Whether adjacency (for both unlocking and ghost seeding) counts
-- the four diagonals as well as the four orthogonals.
ADJACENCY_INCLUDES_DIAGONALS = false

-- Delivery. Items at DELIVER_MIN_TIER and above can be tapped and delivered; the top tier is
-- delivered automatically the moment it is made (it cannot merge any further).
DELIVER_MIN_TIER = 5

-- Sell refunds: tiers below SELL_REFUND_MIN_TIER refund nothing (a sell is a board-space
-- relief valve, not a token source); tier SELL_REFUND_MIN_TIER and above refund SELL_REFUND.
SELL_REFUND_MIN_TIER = 3
SELL_REFUND = 1

-- Rejection reasons, surfaced to the client so the UI can explain a refused action.
REJECT_OUT_OF_BOUNDS = "out_of_bounds"
REJECT_NO_ITEM = "no_item"
REJECT_SAME_CELL = "same_cell"
REJECT_LOCKED = "locked"
REJECT_MISMATCH = "mismatch"
REJECT_MAX_TIER = "max_tier"
REJECT_NO_ENERGY = "no_energy"
REJECT_BOARD_FULL = "board_full"
REJECT_NOT_DELIVERABLE = "not_deliverable"
REJECT_TOPUP_UNAVAILABLE = "topup_unavailable"

-- Drop outcome kinds.
KIND_MOVE = "move"          -- item relocated to an empty open cell
KIND_MERGE = "merge"        -- two matching items became one of the next tier
KIND_UNLOCK = "unlock"      -- a ghost was satisfied: next tier placed AND the board expands

-- Reward kinds. Tokens are REAL in this build (they go straight into the player's wallet).
-- Everything else (delivery tickets, spinner batteries, the jackpot) is a PLACEHOLDER: the
-- server logs what it would grant (see grantReward in MergeIslandManager) and the HUD displays
-- it. The kind decides the icon and the wording.
REWARD_TOKENS = "tokens"
REWARD_TICKETS = "tickets"
REWARD_ENERGY = "energy"
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
-- slot per row), so adding a tier is one more row here, plus a DELIVERY row if it delivers.
ITEM_TIERS = {
    { label = "Shell", class = "item-tier-1" },
    { label = "Bottle", class = "item-tier-2" },
    { label = "Compass", class = "item-tier-3" },
    { label = "Treasure Map", class = "item-tier-4" },
    { label = "Treasure Chest", class = "item-tier-5" },
    { label = "Golden Idol", class = "item-tier-6" },
    { label = "Pirate Ship", class = "item-tier-7" },
    { label = "Lighthouse", class = "item-tier-8" },
    { label = "Treasure Island", class = "item-tier-9" },
    { label = "Golden Trident", class = "item-tier-10" },
    { label = "Jeweled Scepter", class = "item-tier-11" },
    { label = "Royal Crown", class = "item-tier-12" },
}

-- The top of the ladder. An item here cannot merge any further (it auto-delivers), and no ghost
-- may ask for it (satisfying a tier-T ghost yields T+1, so there would be nothing to produce).
MAX_TIER = #ITEM_TIERS
AUTO_DELIVER_TIER = MAX_TIER

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

-- Per deliverable tier: the reward-value multiplier (applied to the guaranteed tickets and to
-- any variable-quantity bonus) and the guaranteed tickets. Scales slightly below the 1x/2x/4x/8x
-- item cost so higher tiers are clearly better without being strictly proportional.
DELIVERY = {
    [5] = { mult = 1.0, tickets = 100 },
    [6] = { mult = 1.8, tickets = 180 },
    [7] = { mult = 3.2, tickets = 320 },
    [8] = { mult = 5.5, tickets = 550 },
    [9] = { mult = 9.5, tickets = 950 },
    [10] = { mult = 16, tickets = 1600 },
    [11] = { mult = 28, tickets = 2800 },
    [12] = { mult = 48, tickets = 4800 },
}

-- Bonus spinner outcomes. `scales` marks the variable-quantity rewards the delivery multiplier
-- applies to. Battery and ticket amounts are PLACEHOLDERS pending the economy spec; token
-- amounts are the spec's.
BONUS_REWARDS = {
    battery_max = { kind = REWARD_ENERGY, amount = 100, label = "MAX Battery", icon = "reward-icon-battery-max" },
    battery_small = { kind = REWARD_ENERGY, amount = 25, label = "Small Battery", icon = "reward-icon-battery" },
    tickets_large = { kind = REWARD_TICKETS, amount = 200, label = "Tickets", icon = "reward-icon-ticket-stack", scales = true },
    tickets_small = { kind = REWARD_TICKETS, amount = 50, label = "Tickets", icon = "reward-icon-ticket", scales = true },
    tokens_5 = { kind = REWARD_TOKENS, amount = 5, label = "Merge Tokens", icon = "reward-icon-token-stack" },
    tokens_2 = { kind = REWARD_TOKENS, amount = 2, label = "Merge Tokens", icon = "reward-icon-token" },
}
BONUS_NONE = "none"

-- Weighted odds per delivery band (weights read as percentages; each band sums to 100).
BONUS_TABLES = {
    low = {   -- tier 5-6 deliveries
        { id = "battery_max", weight = 3 },
        { id = "battery_small", weight = 10 },
        { id = "tickets_large", weight = 5 },
        { id = "tickets_small", weight = 15 },
        { id = "tokens_5", weight = 2 },
        { id = "tokens_2", weight = 10 },
        { id = BONUS_NONE, weight = 55 },
    },
    high = {  -- tier 7+ deliveries
        { id = "battery_max", weight = 10 },
        { id = "battery_small", weight = 20 },
        { id = "tickets_large", weight = 15 },
        { id = "tickets_small", weight = 25 },
        { id = "tokens_5", weight = 10 },
        { id = "tokens_2", weight = 15 },
        { id = BONUS_NONE, weight = 5 },
    },
}
BONUS_HIGH_MIN_TIER = 7

-- The spinner wheel's 8 segments, clockwise from 12 o'clock. PRESENTATION ONLY: the server rolls
-- the outcome from BONUS_TABLES and the HUD spins to a segment showing it. The big prizes sit
-- next to "none" so a miss lands one segment away from a win (near-miss).
SPINNER_SEGMENTS = {
    "tickets_small", "battery_small", "tokens_2", BONUS_NONE,
    "battery_max", "tokens_5", BONUS_NONE, "tickets_large",
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

-- Does this cell hold a draggable item?
function HasItem(cells, index: number): boolean
    local _cell = CellAt(cells, index)
    return _cell.state == STATE_OPEN and _cell.tier ~= nil
end

-- Chebyshev distance from the START RECTANGLE: 0 for a cell inside it, 1 for the ring touching
-- it, and so on outward. Measuring from the rectangle rather than a point is what lets the start
-- area sit anywhere (here, bottom-centre) while ghost rings still ramp outward from it.
function RingDistance(index: number): number
    local _row, _col = CellCoords(index)
    if not _row then
        return math.huge
    end
    -- Distance outside the rectangle on each axis, 0 when the cell is within its span.
    local _dRow = math.max(START_ROW_MIN - _row, 0, _row - START_ROW_MAX)
    local _dCol = math.max(START_COL_MIN - _col, 0, _col - START_COL_MAX)
    return math.max(_dRow, _dCol)
end

-- Is this cell part of the initial playable area?
function IsStartCell(index: number): boolean
    return RingDistance(index) == 0
end

-- The farthest ghost ring on this board (computed once; it only depends on the constants).
local _maxRing: number? = nil
function MaxRingDistance(): number
    if not _maxRing then
        local _max = 1
        for i = 1, CELL_COUNT do
            _max = math.max(_max, RingDistance(i))
        end
        _maxRing = _max
    end
    return _maxRing or 1
end

-- Base ghost tier for a ghost ring (ring 1 being the first locked ring outside the start area),
-- ramping from tier 1 at ring 1 to the top ghost tier at the farthest ring (see
-- GHOST_RAMP_CURVE). The top ghost tier is MAX_TIER - 1: satisfying a tier-T ghost yields tier
-- T+1, so a ghost can never sit at the top of the ladder.
function GhostTierForRing(ring: number): number
    local _topGhostTier = math.max(1, MAX_TIER - 1)
    if type(ring) ~= "number" or ring <= 1 then
        return 1
    end
    local _span = MaxRingDistance() - 1
    if _span <= 0 then
        return _topGhostTier
    end
    local _t = math.min(1, (ring - 1) / _span) ^ GHOST_RAMP_CURVE
    return math.min(_topGhostTier, 1 + math.floor(_t * (_topGhostTier - 1) + 0.5))
end

-- SERVER ONLY (rolls dice). A fresh ghost spec for a cell, tiered by how far out it sits.
function RandomGhostFor(index: number): Cell
    -- RingDistance is already 0 inside the start area, so it IS the ghost ring number.
    local _tier = GhostTierForRing(RingDistance(index))
    -- Jitter upward sometimes so a ring is not visually uniform, never past the top ghost tier.
    local _topGhostTier = math.max(1, MAX_TIER - 1)
    if math.random() < GHOST_TIER_JITTER_CHANCE and _tier < _topGhostTier then
        _tier = _tier + 1
    end
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

-- Apply the DETERMINISTIC half of a resolved drop, mutating `cells` in place. The board
-- expansion that follows an unlock is deliberately NOT here: it rolls dice, so it is
-- server-only (see ExpandFrom).
function ApplyDrop(cells, result: DropResult)
    if not cells or not result or not result.ok then
        return
    end
    cells[result.from] = { state = STATE_OPEN }
    cells[result.to] = { state = STATE_OPEN, tier = result.tier }
end

-- SERVER ONLY (rolls dice). Any HIDDEN cell touching an OPEN cell becomes a ghost. This is what
-- makes new objectives appear every time the board grows -- the frontier is always ghosted,
-- everything beyond it stays blank.
function SeedGhostRing(cells)
    if not cells then
        return
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
        cells[i] = RandomGhostFor(i)
    end
end

-- SERVER ONLY (rolls dice). Grow the board outward from a just-satisfied ghost at `index`: break
-- its locked neighbours open, then re-seed a fresh ghost ring against the new frontier. Returns
-- the indices that became playable, so the client can animate them breaking.
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
    SeedGhostRing(cells)
    return _opened
end

-- SERVER ONLY (rolls dice). A brand-new board: everything hidden, the start rectangle opened,
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

-- Is there any legal merge left: two open items of the same (non-top) tier, or an item matching
-- a ghost? A full board with none of these is stuck until the player sells or delivers.
function HasLegalMerge(cells): boolean
    local _seen: {[number]: boolean} = {}
    for i = 1, CELL_COUNT do
        local _cell = CellAt(cells, i)
        if _cell.state == STATE_OPEN and _cell.tier and _cell.tier < MAX_TIER then
            if _seen[_cell.tier] then
                return true
            end
            _seen[_cell.tier] = true
        end
    end
    for i = 1, CELL_COUNT do
        local _cell = CellAt(cells, i)
        if _cell.state == STATE_GHOST and _cell.tier and _seen[_cell.tier] then
            return true
        end
    end
    return false
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

-- Delivery row for a tier, or nil when that tier cannot be delivered.
function DeliveryFor(tier: number?)
    if type(tier) ~= "number" or tier < DELIVER_MIN_TIER then
        return nil
    end
    return DELIVERY[tier]
end

function IsDeliverable(tier: number?): boolean
    return DeliveryFor(tier) ~= nil
end

-- Tokens refunded for selling an item of `tier`.
function SellRefund(tier: number?): number
    if type(tier) ~= "number" or tier < SELL_REFUND_MIN_TIER then
        return 0
    end
    return SELL_REFUND
end

-- The bonus reward for an outcome id, scaled by a delivery multiplier where it applies. Returns
-- nil for BONUS_NONE. Shared so the HUD's wheel labels agree with what the server pays.
function BonusReward(id: string, mult: number?)
    local _base = BONUS_REWARDS[id]
    if not _base then
        return nil
    end
    local _amount = _base.amount
    if _base.scales and mult then
        _amount = math.floor(_base.amount * mult + 0.5)
    end
    return { kind = _base.kind, amount = _amount, label = _base.label, icon = _base.icon, id = id }
end

-- SERVER ONLY (rolls dice). The bonus outcome id for delivering `tier`.
function RollBonus(tier: number): string
    local _table = if tier >= BONUS_HIGH_MIN_TIER then BONUS_TABLES.high else BONUS_TABLES.low
    local _total = 0
    for _, row in ipairs(_table) do
        _total = _total + row.weight
    end
    local _roll = math.random() * _total
    local _acc = 0
    for _, row in ipairs(_table) do
        _acc = _acc + row.weight
        if _roll < _acc then
            return row.id
        end
    end
    return BONUS_NONE
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
