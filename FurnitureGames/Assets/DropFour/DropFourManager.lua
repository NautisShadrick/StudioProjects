--!Type(ClientAndServer)

-- DropFourManager -- game engine + networking for every Drop Four table in the world.
--
-- ONE manager serves every table. Each table is an isolated 2-seat game with up to
-- MAX_SEATS - PLAYERS_PER_GAME spectators queued behind it; a player can hold a seat at
-- only one table at a time.
--
-- The board is authoritative on the server. Clients render from the replicated `board`
-- value (so spectators and mid-joiners are correct with no bespoke sync) and animate the
-- single new disc off discDroppedEvent.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("How many Drop Four tables this world has. Place one DropFourTable prefab per table, with tableId 1..N.")
--!SerializeField
local tableCount : number = 2
--!Tooltip("TESTING ONLY. Lets the host start with nobody else seated, alternating disc colors each drop so one player can play both sides. Turn this OFF before publishing.")
--!SerializeField
local allowSoloTesting : boolean = false

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Board geometry. Row 1 is the TOP row; row ROWS is the bottom, where discs land first.
ROWS = 6
COLS = 7
local WIN_LENGTH = 4
local CELL_COUNT = ROWS * COLS

-- Exposed globally: the HUD derives its timer-fill percent from these. The real turn
-- length is TURN_SECONDS, but the visual bar is scaled to TURN_DISPLAY_SECONDS so players
-- see a 15s countdown with a 1s grace buffer before the timeout fires.
TURN_SECONDS = 16
TURN_DISPLAY_SECONDS = 15

-- Networked values must be created with matching names on BOTH client and server at load
-- time, so the pool size has to be a compile-time constant -- a SerializeField is not
-- guaranteed to be deserialized before this script's body runs, and a client/server
-- mismatch would silently break replication. So: allocate MAX_TABLES value sets up front
-- and let the inspector-driven `tableCount` gate which of them are actually usable.
-- Unused tables never change, so they never replicate.
local MAX_TABLES = 8

local MAX_SEATS = 4          -- 2 players + 2 spectators queued for the next game
-- Exposed globally: the lobby renders exactly this many seat slots, and shows anyone beyond
-- them as a queued-spectator count instead.
PLAYERS_PER_GAME = 2
local WIN_POPUP_SECONDS = 3
local SEAT_LOBBY = "lobby"
local SEAT_READY = "ready"
local SEAT_PLAYING = "playing"
local STATE_LOBBY = "LOBBY"
local STATE_PLAYING = "PLAYING"

--------------------------------
------  TYPE DEFINITIONS  ------
--------------------------------
-- One board cell: 0 = empty, 1 or 2 = index into the table's currentPlayers roster.
export type CellMark = number
-- A cell coordinate, as carried by gameWonEvent for the win flash.
export type Cell = {
    row: number,
    col: number,
}

--------------------------------
------   PER-TABLE STATE  ------
--------------------------------
-- tables[i] holds EVERYTHING for one table. The networked values are created in this
-- top-level loop on BOTH client and server with matching names, so each pair links up.
-- The server-only fields are dead weight on the client and are never replicated.
tables = {}
for i = 1, MAX_TABLES do
    tables[i] = {
        id = i,

        -- replicated (server writes, all clients read)
        seats = TableValue.new("D4Seats_" .. i, {}),
        tableState = StringValue.new("D4TableState_" .. i, STATE_LOBBY),
        currentPlayers = TableValue.new("D4CurrentPlayers_" .. i, {}),
        currentTurnIndex = NumberValue.new("D4CurrentTurnIndex_" .. i, 1),
        board = TableValue.new("D4Board_" .. i, {}),

        -- server-only game engine state
        roundActive = false,
        -- Solo-testing only: which color the next drop uses, since a 1-player roster would
        -- otherwise make every disc the same color. Starts at 2 so the first drop is a 1.
        soloMark = 2,
        -- Authoritative turn countdown, ticked by the 1s clock. NOT replicated: clients
        -- run their own local countdown off the per-turn signals (currentTurnIndex change
        -- / yourTurnEvent / gameStartedEvent), which removes ~16 replications per turn.
        serverTimer = TURN_SECONDS,
    }
end

--------------------------------
------     NETWORKING     ------
--------------------------------
-- Events are shared across tables. Client->server intents resolve the sender's table from
-- their seat (joinLobbyRequest carries the tableId explicitly, since the sender has no
-- seat yet). Server->client traffic is either per-player or table-scoped via FireClients
-- with that table's seated players -- never FireAllClients, or every table would see every
-- other table's popups.
DropRequest = Event.new("D4DropRequest")
DiscDroppedEvent = Event.new("D4DiscDroppedEvent")
YourTurnEvent = Event.new("D4YourTurnEvent")
GameWonEvent = Event.new("D4GameWonEvent")
GameDrawnEvent = Event.new("D4GameDrawnEvent")
GameEndedEvent = Event.new("D4GameEndedEvent")

-- Table-lobby flow: tapping an in-world table fires JoinLobbyRequest with that table's id.
-- Non-host seated players ready up via ReadyToggleRequest; the HOST (seat 1) starts the
-- game via StartGameRequest once at least one non-host seat is ready. Game end returns
-- every playing seat to the lobby, unreadied. Spectators hold a "lobby" seat and are
-- eligible for the next game.
JoinLobbyRequest = Event.new("D4JoinLobbyRequest")
LeaveGameRequest = Event.new("D4LeaveGameRequest")
ReadyToggleRequest = Event.new("D4ReadyToggleRequest")
StartGameRequest = Event.new("D4StartGameRequest")
JoinDeniedEvent = Event.new("D4JoinDeniedEvent")
GameStartedEvent = Event.new("D4GameStartedEvent")

--------------------------------
------  CLIENT VIEW TABLE ------
--------------------------------
-- A client can only interact with one table at a time: the one it is seated at (or just
-- tapped). viewTableId picks which table's values the UI renders. The global aliases
-- (Seats, TableState, Board, ...) are re-pointed on every view switch so `.value` reads in
-- the UI scripts keep working. `.Changed` subscriptions must NOT use the aliases -- use
-- ConnectViewValue, which filters by the current view and replays on view switches. SERVER
-- code never touches the aliases; it always goes through tables[i].
local viewTableId = 1
-- key (in tables[i]) -> list of listener fns
local viewValueListeners = {}

-- Aliases (client reads only)
Seats = tables[1].seats
TableState = tables[1].tableState
CurrentPlayers = tables[1].currentPlayers
CurrentTurnIndex = tables[1].currentTurnIndex
Board = tables[1].board

local function refreshViewAliases()
    local _t = tables[viewTableId]
    Seats = _t.seats
    TableState = _t.tableState
    CurrentPlayers = _t.currentPlayers
    CurrentTurnIndex = _t.currentTurnIndex
    Board = _t.board
end

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- How many tables are actually in play. Clamped so a mis-set inspector value can never index
-- past the allocated pool. Resolved once and cached: this is called from the 1s turn clock,
-- so warning on every call would spam the log once per second forever.
local resolvedTableCount: number | nil = nil

local function activeTableCount(): number
    if resolvedTableCount then
        return resolvedTableCount
    end
    if type(tableCount) ~= "number" or tableCount < 1 then
        print("[DropFourManager] tableCount is not a positive number; falling back to 1")
        resolvedTableCount = 1
    elseif tableCount > MAX_TABLES then
        print("[DropFourManager] tableCount " .. tostring(tableCount) .. " exceeds MAX_TABLES "
            .. tostring(MAX_TABLES) .. "; clamping. Raise MAX_TABLES to go higher.")
        resolvedTableCount = MAX_TABLES
    else
        resolvedTableCount = math.floor(tableCount)
    end
    return resolvedTableCount
end

-- A table is usable only if it exists in the pool AND is within the configured count.
local function tableById(id: number)
    if type(id) ~= "number" then
        return nil
    end
    if id < 1 or id > activeTableCount() then
        return nil
    end
    return tables[id]
end

-- Flat board index for a cell. Row 1 is the top row.
local function cellIndex(row: number, col: number): number
    return (row - 1) * COLS + col
end

-- Board read that treats out-of-bounds as empty, so the win scan needs no edge cases.
local function cellAt(board, row: number, col: number): CellMark
    if row < 1 or row > ROWS or col < 1 or col > COLS then
        return 0
    end
    return board[cellIndex(row, col)] or 0
end

local function emptyBoard(): {CellMark}
    local _board = {}
    for i = 1, CELL_COUNT do
        _board[i] = 0
    end
    return _board
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function GetViewTableId(): number
    return viewTableId
end

-- Whether a tableId is one this world actually serves. A placed table prefab uses it to warn
-- about a tableId above tableCount, which would otherwise fail silently: the client would
-- render an empty lobby for it and every join request would be dropped server-side.
function IsTableActive(id: number): boolean
    return tableById(id) ~= nil
end

-- Subscribe to a per-table value BY KEY ("seats", "tableState", "currentPlayers",
-- "currentTurnIndex", "board"). The callback fires only for the table currently in view,
-- and is replayed with the current value when the view switches tables.
function ConnectViewValue(key: string, fn)
    if not key or not fn then
        print("[DropFourManager] ConnectViewValue needs a key and a function")
        return
    end
    if not viewValueListeners[key] then
        viewValueListeners[key] = {}
    end
    table.insert(viewValueListeners[key], fn)
    for i = 1, MAX_TABLES do
        local _t = tables[i]
        _t[key].Changed:Connect(function(newValue, oldValue)
            if i == viewTableId then
                fn(newValue, oldValue)
            end
        end)
    end
end

function SetViewTable(id: number)
    if not tables[id] then
        return
    end
    if id == viewTableId then
        return
    end
    viewTableId = id
    refreshViewAliases()
    -- Replay every subscribed value so the UI re-renders for the new table
    for key, fns in pairs(viewValueListeners) do
        local _v = tables[id][key]
        for _, fn in ipairs(fns) do
            fn(_v.value, _v.value)
        end
    end
end

-- Connect fn to seat changes on ANY table (NOT view-filtered like ConnectViewValue). The
-- launcher uses this to follow the local player's authoritative seat across table
-- switches -- the destination table's seat change would otherwise be filtered out by the
-- current view.
function ConnectAnySeatsChanged(fn)
    if not fn then
        return
    end
    for i = 1, MAX_TABLES do
        tables[i].seats.Changed:Connect(function() fn() end)
    end
end

-- The table the local player is seated at, or nil (client)
function GetSeatedTableId(): number | nil
    -- Match by stable player id, NOT the Player object: a Player nested in a replicated
    -- TableValue is not guaranteed to == client.localPlayer.
    local _localId = client.localPlayer.id
    for i = 1, activeTableCount() do
        for _, s in ipairs(tables[i].seats.value) do
            if s.id == _localId then
                return i
            end
        end
    end
    return nil
end

-- Is it this player's turn at the table in view? (UI checks for the local player; the
-- server uses isPlayersTurnAt with an explicit table.)
function GetPlayersTurn(player : Player): boolean
    if not player then
        return false
    end
    for i, p in ipairs(CurrentPlayers.value) do
        if p == player then
            return i == CurrentTurnIndex.value
        end
    end
    return false
end

-- The roster slot (1 or 2) the local player occupies at the viewed table, or nil when they
-- are not playing. The board view uses it to pick the local disc color.
function GetLocalPlayerMark(): number | nil
    for i, p in ipairs(CurrentPlayers.value) do
        if p == client.localPlayer then
            return i
        end
    end
    return nil
end

-- Lowest empty row in a column on the viewed table, or nil when the column is full.
-- Client-side hint only; the server re-derives it against its own board.
function GetLandingRow(col: number): number | nil
    local _board = Board.value
    for _row = ROWS, 1, -1 do
        if cellAt(_board, _row, col) == 0 then
            return _row
        end
    end
    return nil
end

-- AFK hook. FurnitureGames has no AFK module today; Drop Four taps land on UI elements,
-- which an Input.Tapped-based AFK listener would not see, so every player intent pings
-- here. Kept as a no-op call site so wiring an AFK module later is a one-line change.
function NotifyActivity()
end

--------------------------------
------  SHARED HELPERS    ------
--------------------------------
-- Cell index helpers are needed by the board view too (it renders from the flat array).
function CellIndex(row: number, col: number): number
    return cellIndex(row, col)
end

function CellAt(board, row: number, col: number): CellMark
    if not board then
        return 0
    end
    return cellAt(board, row, col)
end

----------- SERVER -------------

local serverTurnClock = nil

-- The table a player is seated at (any seat status), or nil
local function tableOf(player: Player)
    for i = 1, activeTableCount() do
        for _, s in ipairs(tables[i].seats.value) do
            if s.player == player then
                return tables[i]
            end
        end
    end
    return nil
end

-- Every player holding a seat at this table (playing AND spectating). Used to scope
-- server->client broadcasts to one table.
local function seatedPlayersOf(t): {Player}
    local _list = {}
    for _, s in ipairs(t.seats.value) do
        table.insert(_list, s.player)
    end
    return _list
end

-- Is it this player's turn at this table?
local function isPlayersTurnAt(t, player: Player): boolean
    for i, p in ipairs(t.currentPlayers.value) do
        if p == player then
            return i == t.currentTurnIndex.value
        end
    end
    return false
end

-- True only for players in this table's CURRENT GAME (not spectators)
local function isPlayingAt(t, player: Player): boolean
    for _, p in ipairs(t.currentPlayers.value) do
        if p == player then
            return true
        end
    end
    return false
end

-- Read-only lookups may use seats.value directly; ALL mutations must go through a clone so
-- the TableValue setter always sees a brand-new table (in-place mutation + reassignment of
-- the same reference may not replicate nested field changes like seat status flips).
local function cloneSeats(t): {any}
    local _copy = {}
    for i, s in ipairs(t.seats.value) do
        _copy[i] = { player = s.player, status = s.status, id = s.id, userId = s.userId }
    end
    return _copy
end

local function findSeatIndex(t, player: Player): number | nil
    for i, s in ipairs(t.seats.value) do
        if s.player == player then
            return i
        end
    end
    return nil
end

--------------------------------
------   BOARD ENGINE     ------
--------------------------------
-- Count how far a run of `mark` extends from (row, col) in one direction, not counting the
-- origin cell. Collects the cells it walks so the caller can build the winning line.
local function runLength(board, row: number, col: number, dRow: number, dCol: number,
        mark: CellMark, into: {Cell}): number
    local _n = 0
    local _r = row + dRow
    local _c = col + dCol
    while cellAt(board, _r, _c) == mark do
        _n = _n + 1
        table.insert(into, { row = _r, col = _c })
        _r = _r + dRow
        _c = _c + dCol
    end
    return _n
end

-- Win scan from the PLACED cell only -- four axes, both directions each. O(1) per move
-- instead of sweeping the whole board. Returns the winning cells (>= WIN_LENGTH of them)
-- so the UI can flash them, or nil.
local function findWinningLine(board, row: number, col: number, mark: CellMark): {Cell} | nil
    local _axes = {
        { 0, 1 },   -- horizontal
        { 1, 0 },   -- vertical
        { 1, 1 },   -- diagonal down-right
        { 1, -1 },  -- diagonal down-left
    }
    for _, axis in ipairs(_axes) do
        local _cells = { { row = row, col = col } }
        local _count = 1
            + runLength(board, row, col, axis[1], axis[2], mark, _cells)
            + runLength(board, row, col, -axis[1], -axis[2], mark, _cells)
        if _count >= WIN_LENGTH then
            return _cells
        end
    end
    return nil
end

local function isBoardFull(board): boolean
    for i = 1, CELL_COUNT do
        if (board[i] or 0) == 0 then
            return false
        end
    end
    return true
end

-- Columns that still have room, as a list of column numbers.
local function openColumns(board): {number}
    local _open = {}
    for _col = 1, COLS do
        if cellAt(board, 1, _col) == 0 then
            table.insert(_open, _col)
        end
    end
    return _open
end

--------------------------------
------ SEATING / LIFECYCLE ------
--------------------------------
-- Cross-section lifecycle functions (StartGame/EndGame/CanHostStart/PlayerJoinLobby/
-- PlayerLeaveGame) are globals on purpose: they call each other across file sections, and
-- globals resolve at call time, so their placement is not load-bearing the way local
-- forward references are.

function PlayerJoinLobby(player: Player, tableId: number)
    local _t = tableById(tableId)
    if not _t then
        return
    end
    -- Repeat taps / already seated here: nothing to do
    if findSeatIndex(_t, player) then
        return
    end
    -- One seat per player ACROSS tables. If already seated elsewhere, tapping a new table
    -- SWITCHES tables when the old seat is a lobby/ready seat (leave old, join new). Only
    -- deny mid-game -- leaving then would forfeit the match.
    local _elsewhere = tableOf(player)
    if _elsewhere then
        local _idx = findSeatIndex(_elsewhere, player)
        local _seat = _idx and _elsewhere.seats.value[_idx]
        if _seat and _seat.status == SEAT_PLAYING then
            JoinDeniedEvent:FireClient(player, "seated_elsewhere")
            return
        end
    end
    -- Capacity check on the TARGET table BEFORE giving up the old seat, so a failed switch
    -- to a full table can't leave the player seatless.
    if #_t.seats.value >= MAX_SEATS then
        JoinDeniedEvent:FireClient(player, "table_full")
        return
    end
    -- Safe to switch now: free the old lobby/ready seat first.
    if _elsewhere then
        PlayerLeaveGame(player)
    end
    local _seats = cloneSeats(_t)
    -- userId (account id) is stored as a plain string so the client can open the player's
    -- mini profile -- the replicated seat.player Player is not reliable to read .user.id
    -- off on the client (same reason we store id).
    table.insert(_seats, {
        player = player,
        status = SEAT_LOBBY,
        id = player.id,
        userId = player.user and player.user.id,
    })
    _t.seats.value = _seats
end

-- result is "win" (winner set), "draw", or "abandoned" (every playing player left).
-- Announces immediately, then after WIN_POPUP_SECONDS returns every playing seat to the
-- lobby, unreadied, and clears the game state.
function EndGame(t, result: string, winner: Player | nil, winningCells: {Cell} | nil)
    if not t.roundActive then
        return -- double-end guard
    end
    t.roundActive = false

    local _seated = seatedPlayersOf(t)
    if result == "win" and winner then
        GameWonEvent:FireClients(_seated, winner, winningCells or {})
    elseif result == "draw" then
        GameDrawnEvent:FireClients(_seated)
    else
        GameEndedEvent:FireClients(_seated)
    end

    Timer.After(WIN_POPUP_SECONDS, function()
        local _seats = cloneSeats(t)
        for _, s in ipairs(_seats) do
            if s.status == SEAT_PLAYING then
                s.status = SEAT_LOBBY
            end
        end
        t.seats.value = _seats
        t.currentPlayers.value = {}
        t.board.value = emptyBoard()
        t.tableState.value = STATE_LOBBY
        -- Back in the lobby: the host starts the next game explicitly (no auto-start).
        -- Former players were just unreadied above and re-ready for the next round.
    end)
end

-- Advance the turn without a move (used after a timeout auto-drop resolves nothing).
local function advanceTurn(t)
    local _total = #t.currentPlayers.value
    if _total == 0 then
        return
    end
    t.currentTurnIndex.value = (t.currentTurnIndex.value % _total) + 1
    t.serverTimer = TURN_SECONDS
    local _next = t.currentPlayers.value[t.currentTurnIndex.value]
    if _next then
        YourTurnEvent:FireClient(_next)
    end
end

function PlayerLeaveGame(player: Player)
    local _t = tableOf(player)
    if not _t then
        return
    end
    local _seatIndex = findSeatIndex(_t, player)
    if not _seatIndex then
        return
    end

    local _seats = cloneSeats(_t)
    local _wasPlaying = _seats[_seatIndex].status == SEAT_PLAYING
    table.remove(_seats, _seatIndex)
    _t.seats.value = _seats

    if not _wasPlaying then
        -- A lobby/spectator seat freed; nothing else to do (the host starts the game
        -- explicitly -- no auto-start on seat changes).
        return
    end

    -- Playing player: remove from the turn order, keeping the turn pointing at the same
    -- player after the roster shrinks.
    local _roster = _t.currentPlayers.value
    local _leaveIndex = nil
    for i, p in ipairs(_roster) do
        if p == player then
            _leaveIndex = i
            break
        end
    end

    if _leaveIndex then
        table.remove(_roster, _leaveIndex)
        _t.currentPlayers.value = _roster

        if _leaveIndex < _t.currentTurnIndex.value then
            _t.currentTurnIndex.value = _t.currentTurnIndex.value - 1
        elseif _leaveIndex == _t.currentTurnIndex.value then
            -- It was the leaver's turn: the same slot now holds the next player
            if _t.currentTurnIndex.value > #_roster then
                _t.currentTurnIndex.value = 1
            end
            _t.serverTimer = TURN_SECONDS
            local _next = _roster[_t.currentTurnIndex.value]
            if _next and _t.roundActive then
                YourTurnEvent:FireClient(_next)
            end
        end
    end

    -- Last one standing wins; an empty table just ends the game.
    if _t.roundActive then
        if #_t.currentPlayers.value == 1 then
            EndGame(_t, "win", _t.currentPlayers.value[1], {})
        elseif #_t.currentPlayers.value == 0 then
            EndGame(_t, "abandoned", nil, nil)
        end
    end
end

-- Fresh empty board, random first player, round live.
local function resetRound(t)
    t.board.value = emptyBoard()
    t.soloMark = 2
    t.currentTurnIndex.value = 1
    t.serverTimer = TURN_SECONDS
    t.roundActive = true

    local _first = t.currentPlayers.value[1]
    if _first then
        YourTurnEvent:FireClient(_first)
    end
end

-- Promote the host (seat 1) and the challenger (seat 2) to playing, and start a fresh game.
-- Drop Four is strictly 2 players, so seats beyond the second stay in the lobby as
-- spectators -- unlike Uno, which dealt in every ready seat.
--
-- Only seats 1 and 2 ever play, deliberately: the lobby renders exactly two slots, so
-- promoting "the first ready seat" (which could be seat 3) would put someone on the board
-- who was never shown in a slot.
function StartGame(t)
    local _seats = cloneSeats(t)
    local _players = {}
    for i, s in ipairs(_seats) do
        if i <= PLAYERS_PER_GAME then
            s.status = SEAT_PLAYING
            table.insert(_players, s.player)
        end
    end
    -- A 1-player match is only ever allowed as a solo test; otherwise the gate should have
    -- caught this already.
    if #_players < PLAYERS_PER_GAME and not allowSoloTesting then
        return
    end
    if #_players == 0 then
        return
    end
    -- Shuffle the turn order so who goes first is random every game, instead of always
    -- the host.
    for i = #_players, 2, -1 do
        local _j = math.random(1, i)
        _players[i], _players[_j] = _players[_j], _players[i]
    end
    t.seats.value = _seats
    t.currentPlayers.value = _players
    t.tableState.value = STATE_PLAYING
    -- Authoritative view-switch signal: deterministic on receipt, unlike value replication
    -- ordering. Carries the roster so clients do not need the seats value to have arrived
    -- yet. Scoped to this table's seats.
    GameStartedEvent:FireClients(seatedPlayersOf(t), _players)
    resetRound(t)
end

-- True when the host (seat 1) is allowed to start: the table is in the lobby and the
-- CHALLENGER (seat 2) is ready. Uno required every non-host seat to be ready, which here
-- would let an unreadied spectator block the game forever; checking seat 2 specifically also
-- keeps this in step with StartGame, which only ever promotes seats 1 and 2. The host has no
-- ready state -- they are the starter. Clients mirror this to enable/disable Start Game; the
-- server is authoritative.
function CanHostStart(t): boolean
    if not t then
        return false
    end
    if t.tableState.value ~= STATE_LOBBY then
        return false
    end
    -- Solo testing: the host alone is enough.
    if allowSoloTesting and #t.seats.value >= 1 then
        return true
    end
    local _challenger = t.seats.value[2]
    return _challenger ~= nil and _challenger.status == SEAT_READY
end

--------------------------------
------   MOVE RESOLUTION  ------
--------------------------------
-- Place a disc for `player` in `col` at this table. Shared by the player-initiated
-- DropRequest and the timeout auto-drop, so both go through identical validation.
local function dropDisc(t, player: Player, col: number): boolean
    if not t.roundActive then
        return false
    end
    if not isPlayingAt(t, player) then
        return false
    end
    if not isPlayersTurnAt(t, player) then
        return false
    end
    if type(col) ~= "number" then
        return false
    end
    col = math.floor(col)
    if col < 1 or col > COLS then
        return false
    end

    -- The client sends only a column; the server derives the landing row from its own
    -- board, so a tampered client cannot place a disc mid-air.
    local _board = t.board.value
    local _row = nil
    for _r = ROWS, 1, -1 do
        if cellAt(_board, _r, col) == 0 then
            _row = _r
            break
        end
    end
    if not _row then
        return false -- column full
    end

    -- Normally the roster slot IS the color, which is safe because we just validated it is
    -- this player's turn. A solo test game has a 1-player roster, so alternate explicitly or
    -- every disc would be the same color and a win would be unreachable.
    local _mark = t.currentTurnIndex.value
    if #t.currentPlayers.value == 1 then
        t.soloMark = (t.soloMark % 2) + 1
        _mark = t.soloMark
    end

    -- Clone before writing: an in-place mutation of the same table reference may not
    -- replicate, same reason cloneSeats exists.
    local _next = {}
    for i = 1, CELL_COUNT do
        _next[i] = _board[i] or 0
    end
    _next[cellIndex(_row, col)] = _mark
    t.board.value = _next

    -- Animation trigger. Deterministic on receipt, and carries the row so clients do not
    -- re-derive it from a board value that may not have arrived yet.
    DiscDroppedEvent:FireClients(seatedPlayersOf(t), col, _row, _mark)

    local _line = findWinningLine(_next, _row, col, _mark)
    if _line then
        EndGame(t, "win", player, _line)
        return true
    end

    if isBoardFull(_next) then
        EndGame(t, "draw", nil, nil)
        return true
    end

    advanceTurn(t)
    return true
end

-- Turn-timeout auto-move: an idle player does not get a free pass, because in Connect Four
-- passing forever would deadlock the board. Drop into a random open column. The move
-- happens server-side and replicates like any other. Auto-moves deliberately do NOT count
-- as player activity -- a player who times out every turn keeps accruing idle time.
local function autoDropTurn(t, player: Player)
    local _open = openColumns(t.board.value)
    if #_open == 0 then
        -- No legal move anywhere: the board is full, which is a draw.
        EndGame(t, "draw", nil, nil)
        return
    end
    local _col = _open[math.random(1, #_open)]
    if not dropDisc(t, player, _col) then
        -- Validation refused the auto-move (shouldn't happen); don't stall the table.
        advanceTurn(t)
    end
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:ServerStart()
    -- The server boots with every table in an empty LOBBY; nothing starts until a host
    -- presses Start Game.
    for i = 1, MAX_TABLES do
        tables[i].board.value = emptyBoard()
    end

    server.PlayerDisconnected:Connect(function(player)
        PlayerLeaveGame(player)
    end)

    JoinLobbyRequest:Connect(function(player: Player, tableId)
        PlayerJoinLobby(player, tableId)
    end)

    ReadyToggleRequest:Connect(function(player: Player)
        local _t = tableOf(player)
        if not _t then
            return
        end
        -- No readying while a game is in progress at this table. Everyone unreadies on
        -- game end, so spectators just re-ready in the lobby.
        if _t.tableState.value == STATE_PLAYING then
            return
        end
        local _seatIndex = findSeatIndex(_t, player)
        if not _seatIndex then
            return
        end
        -- The host (seat 1) has no ready state -- they start the game instead.
        if _seatIndex == 1 then
            return
        end
        -- Only the challenger (seat 2) can ready. Seats beyond that are spectators queued for
        -- the next game, and readying them would set a status that StartGame never acts on.
        if _seatIndex > PLAYERS_PER_GAME then
            return
        end
        local _seats = cloneSeats(_t)
        if _seats[_seatIndex].status == SEAT_READY then
            _seats[_seatIndex].status = SEAT_LOBBY
        else
            _seats[_seatIndex].status = SEAT_READY
        end
        -- Replicating seats IS the broadcast: every client's lobby re-renders the new
        -- ready state, and the host's Start Game button re-evaluates CanHostStart off the
        -- same replicated value. No auto-start.
        _t.seats.value = _seats
    end)

    -- Host-only explicit start. Validate the sender owns seat 1 and the lobby gate is
    -- satisfied; the server is authoritative (a non-host or premature request is ignored).
    StartGameRequest:Connect(function(player: Player)
        local _t = tableOf(player)
        if not _t then
            return
        end
        local _host = _t.seats.value[1]
        if not _host or _host.id ~= player.id then
            return
        end
        if not CanHostStart(_t) then
            return
        end
        StartGame(_t)
    end)

    LeaveGameRequest:Connect(function(player: Player)
        PlayerLeaveGame(player)
    end)

    DropRequest:Connect(function(player: Player, col)
        local _t = tableOf(player)
        if not _t then
            return
        end
        dropDisc(_t, player, col)
    end)

    -- One 1s clock drives every active table's turn timer independently.
    serverTurnClock = Timer.Every(1, function()
        for i = 1, activeTableCount() do
            local _t = tables[i]
            if _t.roundActive and #_t.currentPlayers.value > 0 then
                if _t.serverTimer > 0 then
                    _t.serverTimer = _t.serverTimer - 1
                else
                    local _idle = _t.currentPlayers.value[_t.currentTurnIndex.value]
                    if _idle then
                        autoDropTurn(_t, _idle)
                    else
                        advanceTurn(_t)
                    end
                end
            end
        end
    end)
end
