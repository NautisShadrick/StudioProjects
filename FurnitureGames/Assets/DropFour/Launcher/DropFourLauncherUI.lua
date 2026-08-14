--!Type(UI)

-- DropFourLauncherUI -- window controller and minimized pill for the Drop Four tables.
--
-- Entry is the in-world table (DropFourTableTap routes through DropFourRegistry); the pill
-- is purely the minimized state and only shows while you hold a seat. Minimizing keeps your
-- seat and the turn timer keeps running; leaving forfeits both.
--
-- View switching has THREE states, not two. Color Splash showed the lobby XOR the game, but
-- Drop Four lets queued players spectate, so:
--   * no seat, or the table is in the lobby  -> lobby view
--   * seated and the table is PLAYING        -> board + HUD
-- and localIsPlaying gates INPUT inside the board view rather than visibility. It is
-- updated from whichever signal arrives first: GameStartedEvent's roster (deterministic on
-- receipt) or seats/tableState replication (covers mid-state joiners and the end-of-game
-- flip, where timing is uncritical).

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("The DropFourManager on the parent GameObject. It is a ClientAndServer script, not a Module, so it must be referenced here rather than required.")
--!SerializeField
local manager : DropFourManager = nil
--!Tooltip("The GameObject carrying DropFourHUD.")
--!SerializeField
local hudObject : GameObject = nil
--!Tooltip("The GameObject carrying DropFourBoardUI.")
--!SerializeField
local boardObject : GameObject = nil
--!Tooltip("The GameObject carrying DropFourLobbyUI.")
--!SerializeField
local lobbyObject : GameObject = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
local STATE_PLAYING = "PLAYING"
local SEAT_PLAYING = "playing"

-- Seconds the view slide-out runs; must match SLIDE_SECONDS in the view scripts.
local SLIDE_OUT_SECONDS = 0.35
-- Token id for the ref-counted world-controls suppression while the quit popup is up.
local QUIT_WC_ID = "DropFourQuitConfirm"

-- Quit-confirm box zoom.
local QUIT_ZOOM_IN = 0.22
local QUIT_ZOOM_OUT = 0.18
local QUIT_START_SCALE = 0.7

-- "Your turn" indicator: a halo the same size as the pill, sitting behind it, whose SCALE
-- pulses so it grows and shrinks around the pill. Each axis is damped independently so the
-- halo is a touch tighter top-to-bottom than side-to-side.
local TURN_GLOW_MIN = 1.1
local TURN_GLOW_MAX = 1.175
local TURN_PULSE_DURATION = 0.6
local TURN_GLOW_X_DAMP = 0.82
local TURN_GLOW_Y_DAMP = 0.72

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local tableRegistry = require("DropFourRegistry")
local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--------------------------------
------     UI BINDINGS    ------
--------------------------------
--!Bind
local _openButton : VisualElement = nil
--!Bind
local _openButtonGlow : VisualElement = nil
--!Bind
local _countBadge : Label = nil
--!Bind
local _quitConfirm : VisualElement = nil
--!Bind
local _quitConfirmBox : VisualElement = nil
--!Bind
local _quitCancel : Label = nil
--!Bind
local _quitConfirmYes : Label = nil

--------------------------------
------     LOCAL STATE    ------
--------------------------------
local isOpen: boolean = false
local localIsPlaying: boolean = false
-- True between firing LeaveGameRequest and the seat removal replicating back. Without it the
-- minimized pill flashes for a frame on leave, because localSeatStatus() still reads
-- "seated" until the new seats value arrives.
local leaving: boolean = false
-- True while the window is sliding down on minimize. The views must finish the slide before
-- they deactivate, so the refresh functions are gated off during the slide and the real
-- deactivation is deferred.
local closing: boolean = false

local quitZoomTween = nil
local turnPulseTween = nil

-- View UI components, resolved from the view GameObjects in Start so the launcher can drive
-- their SlideIn/SlideOut. nil-safe: a missing view just skips.
local hudUI = nil
local boardUI = nil
local lobbyUI = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function setQuitBoxScale(v: number)
    if _quitConfirmBox then
        _quitConfirmBox.style.scale = StyleScale.new(Scale.new(Vector2.new(v, v)))
    end
end

local function stopQuitZoom()
    if quitZoomTween then
        quitZoomTween:stop()
        quitZoomTween = nil
    end
end

local function setGlowScale(s: number)
    if _openButtonGlow then
        local _sx = 1 + (s - 1) * TURN_GLOW_X_DAMP
        local _sy = 1 + (s - 1) * TURN_GLOW_Y_DAMP
        _openButtonGlow.style.scale = StyleScale.new(Scale.new(Vector2.new(_sx, _sy)))
    end
end

local function startTurnPulse()
    if turnPulseTween then
        return -- already pulsing
    end
    if _openButtonGlow then
        _openButtonGlow.style.display = DisplayStyle.Flex
    end
    setGlowScale(TURN_GLOW_MIN)
    turnPulseTween = Tween:new(TURN_GLOW_MIN, TURN_GLOW_MAX, TURN_PULSE_DURATION, true, true,
        Easing.easeInOutQuad,
        function(s) setGlowScale(s) end,
        nil)
    turnPulseTween:start()
end

local function stopTurnPulse()
    if turnPulseTween then
        turnPulseTween:stop()
        turnPulseTween = nil
    end
    setGlowScale(1.0)
    if _openButtonGlow then
        _openButtonGlow.style.display = DisplayStyle.None
    end
end

local function localSeatStatus(): string | nil
    local _seatedId = manager.GetSeatedTableId()
    if not _seatedId then
        return nil
    end
    -- Keep the view pinned to the seated table (covers mid-session joins where replication
    -- lands after Start). No-op when already in view.
    manager.SetViewTable(_seatedId)
    for _, s in ipairs(manager.tables[_seatedId].seats.value) do
        if s.id == client.localPlayer.id then
            return s.status
        end
    end
    return nil
end

local function recomputePlaying()
    localIsPlaying = localSeatStatus() == SEAT_PLAYING
        and manager.TableState.value == STATE_PLAYING
end

local function updateViews()
    -- Hold the views in place while the minimize slide-out plays; finalizeMinimize re-runs
    -- this once the slide is done.
    if closing then
        return
    end
    -- Anyone holding a seat at a table mid-game sees the board -- players to play on it,
    -- queued spectators to watch. The board view itself gates input.
    local _holdsSeat = localSeatStatus() ~= nil
    local _showGame = isOpen and _holdsSeat and manager.TableState.value == STATE_PLAYING
    if hudObject then
        hudObject:SetActive(_showGame)
    end
    if boardObject then
        boardObject:SetActive(_showGame)
    end
    if lobbyObject then
        lobbyObject:SetActive(isOpen and not _showGame)
    end
end

local function updateChrome()
    -- The pill is hidden up front by minimizeWindow and must stay hidden through the slide;
    -- don't let an incoming refresh re-show it mid-close.
    if closing then
        return
    end
    if isOpen then
        _openButton.style.display = DisplayStyle.None
        -- The in-game controls (minimize + Quit) live in the board view, so they appear and
        -- disappear with that view -- no launcher-side toggle needed.
        stopTurnPulse()
        return
    end
    -- Minimized: the pill is the seat indicator. Hidden entirely when unseated, and while a
    -- leave is in flight so it never flashes on the way out.
    if (not leaving) and localSeatStatus() ~= nil then
        _openButton.style.display = DisplayStyle.Flex
    else
        _openButton.style.display = DisplayStyle.None
    end
end

-- The pill's only job while minimized is to flag YOUR TURN: pulse the halo and show a "!".
local function updateTurnPulse()
    local _yourTurn = (not isOpen) and localIsPlaying
        and manager.GetPlayersTurn(client.localPlayer)
    if _yourTurn then
        startTurnPulse()
        _countBadge.text = "!"
        _countBadge.style.display = DisplayStyle.Flex
    else
        stopTurnPulse()
        _countBadge.text = ""
        -- Hide the badge entirely: an empty badge would still render as a red dot, since it
        -- has a fixed size and a background.
        _countBadge.style.display = DisplayStyle.None
    end
end

local function refreshAll()
    updateViews()
    updateChrome()
    updateTurnPulse()
end

-- Re-run the slide-in on every active view. Used when a tap reopens the window mid-close:
-- the views never deactivated, so OnEnable will not re-fire on its own.
local function slideInActive()
    if hudObject and hudUI and hudObject.activeSelf then
        hudUI.SlideIn()
    end
    if boardObject and boardUI and boardObject.activeSelf then
        boardUI.SlideIn()
    end
    if lobbyObject and lobbyUI and lobbyObject.activeSelf then
        lobbyUI.SlideIn()
    end
end

-- Actually hide the window: deactivate the views and refresh the pill. Runs after the slide.
local function finalizeMinimize()
    isOpen = false
    -- Safety net: if the window closed while the quit-confirm was still up, make sure the
    -- popup is hidden and its suppressor released (Release is idempotent).
    stopQuitZoom()
    _quitConfirm.style.display = DisplayStyle.None
    setQuitBoxScale(1)
    tableRegistry.ReleaseWorldControls(QUIT_WC_ID)
    refreshAll()
end

local function minimizeWindow()
    if closing then
        return
    end
    -- OnDisable fires AFTER SetActive(false) -- too late to animate -- so slide the visible
    -- views down first, then defer the real hide until the slide finishes.
    local _any = false
    local function slideOut(obj: GameObject, ui)
        if obj and ui and obj.activeSelf then
            ui.SlideOut()
            _any = true
        end
    end
    slideOut(hudObject, hudUI)
    slideOut(boardObject, boardUI)
    slideOut(lobbyObject, lobbyUI)
    if not _any then
        -- Nothing on screen to animate (shouldn't happen while open); hide now.
        finalizeMinimize()
        return
    end
    closing = true
    Timer.After(SLIDE_OUT_SECONDS, function()
        -- A reopen during the slide clears `closing` (see OpenFromTable); abort.
        if not closing then
            return
        end
        closing = false
        finalizeMinimize()
    end)
end

local function leaveGame()
    leaving = true
    manager.NotifyActivity()
    manager.LeaveGameRequest:FireServer()
    _countBadge.text = ""
    minimizeWindow()
end

local function hideQuitConfirm()
    stopQuitZoom()
    tableRegistry.ReleaseWorldControls(QUIT_WC_ID)
    quitZoomTween = Tween:new(1, 0, QUIT_ZOOM_OUT, false, false, Easing.easeInQuad,
        function(v) setQuitBoxScale(v) end,
        function()
            _quitConfirm.style.display = DisplayStyle.None
            setQuitBoxScale(1) -- reset so the next open starts clean
            quitZoomTween = nil
        end)
    quitZoomTween:start()
end

-- Leaving mid-game is destructive -- you forfeit the match -- so confirm first. Minimize
-- (the chevron) keeps the seat and is NOT gated.
local function showQuitConfirm()
    stopQuitZoom()
    _quitConfirm.style.display = DisplayStyle.Flex
    _quitConfirm:BringToFront()
    tableRegistry.SuppressWorldControls(QUIT_WC_ID)
    setQuitBoxScale(QUIT_START_SCALE)
    quitZoomTween = Tween:new(QUIT_START_SCALE, 1, QUIT_ZOOM_IN, false, false, Easing.easeOutBack,
        function(v) setQuitBoxScale(v) end,
        function()
            setQuitBoxScale(1)
            quitZoomTween = nil
        end)
    quitZoomTween:start()
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
-- Called by DropFourTableTap (via the registry) when an in-world table is tapped, and by the
-- minimized pill (no arg). If we already hold a seat anywhere, the window always opens on
-- OUR table, whichever table was tapped; otherwise the view switches to the tapped table and
-- we ask the server for a seat there (the lobby renders acceptance or the denial).
function OpenFromTable(tappedTableId)
    leaving = false
    if closing then
        -- Reopened mid-close: cancel the pending hide and slide the still-active views back
        -- up (they never deactivated, so OnEnable will not re-fire).
        closing = false
        slideInActive()
    end
    local _seatedId = manager.GetSeatedTableId()
    -- Tapping a DIFFERENT table while holding a lobby/ready seat switches tables: the server
    -- leaves the old seat and joins the new. While PLAYING we never auto-switch (it would
    -- forfeit the match) -- just reopen our own game.
    local _switching = _seatedId ~= nil and tappedTableId ~= nil
        and tappedTableId ~= _seatedId and not localIsPlaying
    local _targetId
    if _seatedId == nil then
        _targetId = tappedTableId or manager.GetViewTableId()
    elseif _switching then
        _targetId = tappedTableId
    else
        _targetId = _seatedId
    end
    manager.SetViewTable(_targetId)
    if not isOpen then
        isOpen = true
    end
    if _seatedId == nil or _switching then
        manager.NotifyActivity()
        manager.JoinLobbyRequest:FireServer(_targetId)
    end
    updateViews()
    updateChrome()
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    if manager == nil then
        error("DropFourLauncherUI: manager SerializeField is not assigned")
    end

    -- Resolve the view components so the launcher can drive their slide-in/out.
    if hudObject then
        hudUI = hudObject:GetComponent(DropFourHUD)
    end
    if boardObject then
        boardUI = boardObject:GetComponent(DropFourBoardUI)
    end
    if lobbyObject then
        lobbyUI = lobbyObject:GetComponent(DropFourLobbyUI)
    end

    -- In-world DropFourTable prefabs open the window through the registry; the tapped
    -- table's id is passed through to OpenFromTable.
    tableRegistry.RegisterLauncher(OpenFromTable)
    -- The lobby's chevron minimizes and its Leave Queue leaves DIRECTLY (giving up a queue
    -- seat is not destructive). The board's Quit routes through RequestQuit -> the confirm.
    tableRegistry.RegisterControls(minimizeWindow, leaveGame, showQuitConfirm)

    _openButton:RegisterPressCallback(function() OpenFromTable() end)
    _quitCancel:RegisterPressCallback(function() hideQuitConfirm() end)
    _quitConfirmYes:RegisterPressCallback(function()
        hideQuitConfirm()
        leaveGame()
    end)
    _quitConfirm.style.display = DisplayStyle.None

    manager.GameStartedEvent:Connect(function(playersList)
        localIsPlaying = false
        for _, p in ipairs(playersList) do
            if p == client.localPlayer then
                localIsPlaying = true
                break
            end
        end
        refreshAll()
    end)

    manager.ConnectViewValue("seats", function()
        -- Leave confirmed once our seat is gone; clear the suppressor.
        if leaving and manager.GetSeatedTableId() == nil then
            leaving = false
        end
        recomputePlaying()
        refreshAll()
    end)

    -- Follow our authoritative seat across tables: when seats change on ANY table (not just
    -- the viewed one) -- e.g. right after a table switch, whose destination-table seat change
    -- ConnectViewValue filters out -- snap the view to where we actually landed.
    -- SetViewTable replays the listeners, re-rendering the lobby and chrome.
    manager.ConnectAnySeatsChanged(function()
        local _s = manager.GetSeatedTableId()
        if _s and _s ~= manager.GetViewTableId() then
            manager.SetViewTable(_s)
        end
    end)

    manager.ConnectViewValue("tableState", function()
        recomputePlaying()
        refreshAll()
    end)

    manager.ConnectViewValue("currentTurnIndex", function() updateTurnPulse() end)
    manager.ConnectViewValue("currentPlayers", function() updateTurnPulse() end)

    -- Mid-state joiners render correctly from the current replicated values.
    recomputePlaying()
    refreshAll()
end
