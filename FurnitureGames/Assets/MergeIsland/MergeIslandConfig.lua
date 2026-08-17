--!Type(Module)

-- MergeIslandConfig -- the item ladder, tuning constants, and the SHARED drop rules for
-- Merge Island.
--
-- The item chain is a SINGLE LINEAR LADDER: tier 1 merges into tier 2, up to MAX_TIER. There
-- is no item "type" dimension, so a cell is fully described by its state and its tier, and two
-- items match if and only if their tiers match.
--
-- This module is pure: no state, no networking, no lifecycle hooks. That is the point. The
-- server calls ResolveDrop to validate and apply a move; the client calls the SAME function to
-- decide whether a drag should snap back. One source of truth means the client's optimistic
-- feedback can never disagree with the server's authoritative answer.
--
-- Randomness is deliberately kept OUT of ResolveDrop/ApplyDrop -- they are deterministic, so
-- both sides agree. The functions that roll dice (RandomGhostFor, SeedGhostRing, ExpandFrom,
-- NewBoard) are only ever called by the server.
--
-- NOTE: this module must be attached to a GameObject in the scene to be require-able.

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Board geometry. Row 1 is the top row. The playable area starts as a square of START_RADIUS
-- cells around the centre (radius 1 = the 3x3 seen in the prototype).
COLS = 7
ROWS = 7
CELL_COUNT = COLS * ROWS
START_RADIUS = 1

-- Cell states. Numeric so the persisted payload stays small.
STATE_HIDDEN = 0    -- locked, nothing shown (plain tile)
STATE_GHOST = 1     -- locked, shows the silhouette of the tier it accepts
STATE_OPEN = 2      -- unlocked; may or may not hold an item

-- Bumped whenever the persisted board SHAPE changes. A save from a different version is
-- discarded rather than half-read, which is what keeps a format change from producing a board
-- that is subtly wrong instead of obviously fresh.
SAVE_VERSION = 2

-- Energy. A fixed pool is granted per event window; there is no passive regen. Bumping
-- EVENT_ID re-grants the pool to every player on their next load, which is how a new event
-- starts.
EVENT_ID = "event_001"
ENERGY_POOL_PER_EVENT = 40
SPAWN_COST = 1
-- Every spawn enters the ladder at the bottom.
SPAWN_TIER = 1

-- Ghost tier ramp. Ghost rings are numbered outward from the edge of the start area, so ring 1
-- is the first locked ring. One ring per tier step suits a 7x7 board (which only has two ghost
-- rings); widen RINGS_PER_TIER if the grid grows.
RINGS_PER_TIER = 1
-- Chance a ghost rolls one tier above its ring's base, so a ring is not visually uniform.
GHOST_TIER_JITTER_CHANCE = 0.25

-- PENDING PLAYTEST DECISION. On satisfying a ghost, do its locked neighbours become fully
-- playable (true), or merely turn into new ghosts (false)? The prototype is ambiguous and this
-- materially changes pacing, so it is one flag.
UNLOCK_NEIGHBOURS_OPEN = true
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

-- Drop outcome kinds.
KIND_MOVE = "move"          -- item relocated to an empty open cell
KIND_MERGE = "merge"        -- two matching items became one of the next tier
KIND_UNLOCK = "unlock"      -- a ghost was satisfied: next tier placed AND the board expands

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
-- `class` is a USS class name, which is what makes the art swappable: dropping in real sprites
-- later means editing this table, not the game logic. Adding a tier is one more row here --
-- nothing else needs to change.
ITEM_TIERS = {
    { label = "Shell", class = "item-tier-1" },
    { label = "Bottle", class = "item-tier-2" },
    { label = "Compass", class = "item-tier-3" },
    { label = "Treasure Map", class = "item-tier-4" },
    { label = "Treasure Chest", class = "item-tier-5" },
}

-- The top of the ladder. An item here cannot merge any further, and no ghost may ask for it
-- (satisfying a tier-T ghost yields T+1, so there would be nothing to produce).
MAX_TIER = #ITEM_TIERS

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

-- Chebyshev distance from the board centre. Concentric squares, so the start area and every
-- ghost ring are square -- which is what the prototype's outward expansion looks like.
function RingDistance(index: number): number
    local _row, _col = CellCoords(index)
    if not _row then
        return math.huge
    end
    local _centreRow = math.floor((ROWS + 1) / 2)
    local _centreCol = math.floor((COLS + 1) / 2)
    return math.max(math.abs(_row - _centreRow), math.abs(_col - _centreCol))
end

-- Base ghost tier for a ghost ring (ring 1 being the first locked ring outside the start area).
-- Clamped to MAX_TIER - 1: satisfying a tier-T ghost yields tier T+1, so a ghost can never sit
-- at the top of the ladder.
function GhostTierForRing(ring: number): number
    local _topGhostTier = math.max(1, MAX_TIER - 1)
    if type(ring) ~= "number" or ring < 1 then
        return 1
    end
    local _base = 1 + math.floor((ring - 1) / RINGS_PER_TIER)
    if _base > _topGhostTier then
        return _topGhostTier
    end
    return _base
end

-- SERVER ONLY (rolls dice). A fresh ghost spec for a cell, tiered by how far out it sits.
function RandomGhostFor(index: number): Cell
    local _ring = RingDistance(index) - START_RADIUS
    local _tier = GhostTierForRing(_ring)
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
    if type(from) ~= "number" or type(to) ~= "number" then
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

-- SERVER ONLY (rolls dice). A brand-new board: everything hidden, the centre square opened, and
-- the first ghost ring seeded around it.
function NewBoard(): {Cell}
    local _cells = {}
    for i = 1, CELL_COUNT do
        if RingDistance(i) <= START_RADIUS then
            _cells[i] = { state = STATE_OPEN }
        else
            _cells[i] = { state = STATE_HIDDEN }
        end
    end
    SeedGhostRing(_cells)
    return _cells
end

-- First empty playable cell, or nil when there is nowhere to spawn. Scanned in index order so
-- spawns fill predictably rather than scattering.
function FirstEmptyOpenCell(cells): number | nil
    for i = 1, CELL_COUNT do
        local _cell = CellAt(cells, i)
        if _cell.state == STATE_OPEN and _cell.tier == nil then
            return i
        end
    end
    return nil
end
