--!Type(UI)

-- DropFourLobbyUI -- the lobby view inside the Drop Four window. Renders the seat slots, a
-- READY/UNREADY toggle (or START GAME for the host), a Leave Queue button, and a status
-- line, purely from the replicated seats/tableState values -- so a client joining
-- mid-state renders correctly with no bespoke sync events.
--
-- The lobby owns its own chrome (collapse chevron + title + info button); the chevron and
-- Leave Queue route back to the launcher through DropFourRegistry, because the launcher
-- owns the isOpen state and the anti-flash suppressor and this is a separate UI component.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("The DropFourManager on the parent GameObject. It is a ClientAndServer script, not a Module, so it must be referenced here rather than required.")
--!SerializeField
local manager : DropFourManager = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
local STATE_PLAYING = "PLAYING"
local SEAT_READY = "ready"

-- Window slide, matching the board / HUD / launcher views so the whole window reads as one
-- panel. Percent translate is transient and settles to 0 (= no offset).
local SLIDE_SECONDS = 0.35
local SLIDE_OFFSCREEN_PCT = 100

-- Rules drawer: slide-up + scrim fade.
local RULES_SHOW_DURATION = 0.35
local RULES_HIDE_DURATION = 0.25
local RULES_SLIDE_DISTANCE = 300
-- Token id for the ref-counted world-controls suppression while the drawer is open.
local RULES_WC_ID = "DropFourRules"

-- Animated "..." waiting indicator: one shared frame cycles . -> .. -> ... -> .. on a loop,
-- driving every non-ready seat's dots label in sync.
local WAITING_FRAMES = {".", "..", "...", ".."}
local WAITING_FRAME_SECONDS = 0.4

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
local _lobbyWindow : VisualElement = nil
--!Bind
local _tableLabel : Label = nil
--!Bind
local _seatsContainer : VisualElement = nil
--!Bind
local _queueLabel : Label = nil
--!Bind
local _statusLabel : Label = nil
--!Bind
local _readyButton : Label = nil
--!Bind
local _leaveButton : Label = nil
--!Bind
local _minimizeButton : VisualElement = nil
--!Bind
local _infoButton : VisualElement = nil
--!Bind
local _rulesOverlay : VisualElement = nil
--!Bind
local _rulesScrim : VisualElement = nil
--!Bind
local _rulesDrawer : VisualElement = nil

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- Set on JoinDeniedEvent ("table_full" | "seated_elsewhere"); cleared as soon as the local
-- player holds a seat.
local deniedReason: string | nil = nil
local slideTween = nil
local rulesVisible: boolean = false
local rulesAnimating: boolean = false
local rulesTween = nil
-- Rebuilt on every render() (the labels are destroyed by seats_container:Clear).
local waitingLabels: {Label} = {}
local waitingStep: number = 0
local waitingTimer = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- Localized string lookup. No localization database is assigned to this world yet, so
-- every call falls through to the English fallback; keeping the indirection means wiring a
-- loc table later needs no changes here. `_G.Strings` keeps the strict checker happy.
local function L(key: string, fallback: string): string
    local _s: any = _G.Strings
    return tostring((_s and _s[key]) or fallback)
end

-- Only the panel host slides. The backdrop is a static dim scrim, so translating it would
-- drag the dim overlay up and down on open/close. Climbing to the document root is also
-- wrong -- that can be a larger shared element that slides everything too far.
local function slideApply(pct: number)
    if _lobbyWindow then
        _lobbyWindow.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.Percent(pct)))
    end
end

local function playSlide(fromPct: number, toPct: number, easing)
    if slideTween then
        slideTween:stop()
    end
    slideApply(fromPct)
    slideTween = Tween:new(
        fromPct, toPct, SLIDE_SECONDS, false, false, easing,
        function(value) slideApply(value) end,
        function() slideApply(toPct) end
    )
    slideTween:start()
end

local function currentWaitingText(): string
    return WAITING_FRAMES[(waitingStep % #WAITING_FRAMES) + 1]
end

-- value 0 = fully hidden (drawer down, scrim clear), 1 = fully shown.
local function rulesApply(value: number)
    if _rulesScrim then
        _rulesScrim.style.opacity = StyleFloat.new(value)
    end
    if _rulesDrawer then
        _rulesDrawer.style.translate = StyleTranslate.new(
            Translate.new(Length.new(0), Length.new(RULES_SLIDE_DISTANCE * (1 - value))))
        _rulesDrawer.style.opacity = StyleFloat.new(value)
    end
end

local function showRules()
    if rulesVisible or rulesAnimating then
        return
    end
    if rulesTween then
        rulesTween:stop()
    end
    rulesAnimating = true
    rulesVisible = true
    tableRegistry.SuppressWorldControls(RULES_WC_ID)
    _rulesOverlay.style.display = DisplayStyle.Flex
    rulesApply(0)
    rulesTween = Tween:new(0, 1, RULES_SHOW_DURATION, false, false, Easing.easeOutQuad,
        function(value) rulesApply(value) end,
        function()
            rulesApply(1)
            rulesAnimating = false
        end)
    rulesTween:start()
end

local function hideRules()
    if not rulesVisible or rulesAnimating then
        return
    end
    if rulesTween then
        rulesTween:stop()
    end
    rulesAnimating = true
    rulesTween = Tween:new(1, 0, RULES_HIDE_DURATION, false, false, Easing.easeInQuad,
        function(value) rulesApply(value) end,
        function()
            rulesApply(0)
            rulesAnimating = false
            rulesVisible = false
            _rulesOverlay.style.display = DisplayStyle.None
            tableRegistry.ReleaseWorldControls(RULES_WC_ID)
        end)
    rulesTween:start()
end

local function localSeatStatus(): string | nil
    for _, s in ipairs(manager.Seats.value) do
        if s.id == client.localPlayer.id then
            return s.status
        end
    end
    return nil
end

-- Which seat the local player holds: 1 = host, 2 = challenger, 3+ = queued spectator.
local function localSeatIndex(): number | nil
    for i, s in ipairs(manager.Seats.value) do
        if s.id == client.localPlayer.id then
            return i
        end
    end
    return nil
end

local function makeSeatElement(seat, isHost: boolean): VisualElement
    local _slot = VisualElement.new()
    _slot:AddToClassList("seat")

    local _wrap = VisualElement.new()
    _wrap:AddToClassList("avatar-wrap")
    _slot:Add(_wrap)

    if not seat then
        local _empty = VisualElement.new()
        _empty:AddToClassList("seat-empty-box")
        _wrap:Add(_empty)
        return _slot
    end

    local _avatar = UIUserThumbnail.new()
    _avatar:Load(seat.player)
    _avatar.showOnlineIndicator = false
    _avatar:AddToClassList("seat-avatar")
    if seat.status == SEAT_READY then
        _avatar:AddToClassList("seat-avatar-ready")
    end
    _wrap:Add(_avatar)

    -- UIUserThumbnail is a UIView that consumes the press internally (independent of
    -- pickingMode), so a callback on it OR on the slot behind it never fires. Overlay a
    -- transparent plain VisualElement ON TOP (added last = highest z-order) to intercept
    -- the tap -- its RegisterPressCallback does fire.
    local _hit = VisualElement.new()
    _hit:AddToClassList("seat-hit")
    _hit.pickingMode = PickingMode.Position
    _hit:RegisterPressCallback(function()
        if seat.userId then
            UI:OpenMiniProfile(seat.userId)
        end
    end)
    _wrap:Add(_hit)

    -- State caption. The host (seat 1) has no ready state -- just the "Host" label.
    -- Everyone else shows "..." while waiting and a green check badge once ready.
    if isHost then
        local _host = Label.new()
        _host.text = L("drop_four_host", "Host")
        _host:AddToClassList("seat-host-label")
        _host.pickingMode = PickingMode.Ignore
        _slot:Add(_host)
    elseif seat.status == SEAT_READY then
        local _check = VisualElement.new()
        _check:AddToClassList("seat-ready-check")
        _check.pickingMode = PickingMode.Ignore
        _wrap:Add(_check)
    else
        local _dots = Label.new()
        _dots.text = currentWaitingText()
        _dots:AddToClassList("seat-waiting-dots")
        _dots.pickingMode = PickingMode.Ignore
        _slot:Add(_dots)
        table.insert(waitingLabels, _dots)
    end

    return _slot
end

local function render()
    local _seats = manager.Seats.value
    local _localStatus = localSeatStatus()
    if _localStatus ~= nil then
        deniedReason = nil
    end

    -- "Table: N" subtitle. render() re-fires on view switches via the ConnectViewValue
    -- replay, so this stays correct if the viewed table changes.
    _tableLabel.text = L("drop_four_table", "Table") .. ": " .. tostring(manager.GetViewTableId())

    _seatsContainer:Clear()
    -- The old dots labels were just destroyed; rebuild the live list as seats render.
    waitingLabels = {}
    -- Drop Four is 2 players, so the lobby shows exactly 2 slots: seat 1 is the host, seat 2
    -- the challenger. The table still SEATS more than that (MAX_SEATS on the manager) --
    -- those extra players are spectators queued for the next game, surfaced as a count below
    -- rather than as empty slots that imply a 4-player game.
    local _playerSeats = manager.PLAYERS_PER_GAME
    for i = 1, _playerSeats do
        _seatsContainer:Add(makeSeatElement(_seats[i], i == 1))
    end

    local _queued = #_seats - _playerSeats
    if _queued > 0 then
        local _word = (_queued == 1) and L("drop_four_queued_one", "player")
            or L("drop_four_queued_many", "players")
        _queueLabel.text = "+" .. tostring(_queued) .. " " .. _word .. " "
            .. L("drop_four_queued_suffix", "waiting to play")
        _queueLabel.style.display = DisplayStyle.Flex
    else
        _queueLabel.style.display = DisplayStyle.None
    end

    -- Action button: HOST (seat 1) gets "Start Game", enabled only when CanHostStart; the
    -- CHALLENGER (seat 2) gets a Ready/Unready toggle. Queued spectators get no button --
    -- only seats 1 and 2 ever play, so readying from seat 3 would do nothing.
    local _localIndex = localSeatIndex()
    local _isHost = _localIndex == 1
    local _isChallenger = _localIndex == 2
    local _viewTable = manager.tables[manager.GetViewTableId()]
    if (_isHost or _isChallenger) and manager.TableState.value ~= STATE_PLAYING then
        _readyButton.style.display = DisplayStyle.Flex
        if _isHost then
            _readyButton.text = L("drop_four_start_game", "Start Game")
            _readyButton:RemoveFromClassList("ready-button-unready")
            -- Mirror the server gate off the replicated seats so the button greys and
            -- ungreys live as the challenger readies up.
            if _viewTable ~= nil and manager.CanHostStart(_viewTable) then
                _readyButton:RemoveFromClassList("ready-button-disabled")
            else
                _readyButton:AddToClassList("ready-button-disabled")
            end
        else
            _readyButton:RemoveFromClassList("ready-button-disabled")
            if _localStatus == SEAT_READY then
                _readyButton.text = L("drop_four_unready", "Unready")
                _readyButton:AddToClassList("ready-button-unready")
            else
                _readyButton.text = L("drop_four_ready", "Ready")
                _readyButton:RemoveFromClassList("ready-button-unready")
            end
        end
    else
        _readyButton.style.display = DisplayStyle.None
    end

    -- Leave Queue: shown whenever the local player holds a seat (unseated viewers just
    -- browsing a table have nothing to leave).
    if _localStatus ~= nil then
        _leaveButton.style.display = DisplayStyle.Flex
    else
        _leaveButton.style.display = DisplayStyle.None
    end

    -- Status line
    if deniedReason and _localStatus == nil then
        if deniedReason == "seated_elsewhere" then
            _statusLabel.text = L("drop_four_status_seated_elsewhere",
                "You're already playing at another table")
        else
            _statusLabel.text = L("drop_four_status_table_full", "Table is full -- try again later")
        end
    elseif manager.TableState.value == STATE_PLAYING then
        _statusLabel.text = L("drop_four_status_in_progress",
            "Game in progress -- you're in the next one")
    elseif _localStatus == nil then
        _statusLabel.text = L("drop_four_status_take_a_seat", "Tap the table to take a seat")
    elseif _localIndex ~= nil and _localIndex > _playerSeats then
        -- Seated, but behind the two players.
        _statusLabel.text = L("drop_four_status_queued", "You're in the queue for the next game")
    elseif _isHost and _viewTable ~= nil and manager.CanHostStart(_viewTable) then
        -- The gate can also open with nobody else seated when the manager's solo-testing
        -- switch is on, so don't claim there's a challenger unless there is one.
        if #_seats >= 2 then
            _statusLabel.text = L("drop_four_status_ready_to_start", "Challenger ready! Tap Start Game.")
        else
            _statusLabel.text = L("drop_four_status_solo_test", "Solo test mode -- tap Start Game.")
        end
    elseif _isHost and #_seats < 2 then
        _statusLabel.text = L("drop_four_status_waiting_challenger", "Waiting for a challenger...")
    elseif _isHost then
        _statusLabel.text = L("drop_four_status_waiting_ready", "Waiting for the challenger to ready up")
    else
        _statusLabel.text = L("drop_four_status_waiting_host", "Ready up and wait for the host to start")
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function SlideIn()
    playSlide(SLIDE_OFFSCREEN_PCT, 0, Easing.easeOutQuad)
end

function SlideOut()
    playSlide(0, SLIDE_OFFSCREEN_PCT, Easing.easeInQuad)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    if manager == nil then
        error("DropFourLobbyUI: manager SerializeField is not assigned")
    end

    -- One timer cycles the shared "..." frame; render() rebuilds the label list, so this
    -- ticks whatever is currently on screen.
    if not waitingTimer then
        waitingTimer = Timer.Every(WAITING_FRAME_SECONDS, function()
            waitingStep = waitingStep + 1
            local _txt = currentWaitingText()
            for _, lbl in ipairs(waitingLabels) do
                lbl.text = _txt
            end
        end)
    end

    _readyButton:RegisterPressCallback(function()
        manager.NotifyActivity()
        -- Branch by role at press time. The server validates both paths (host check +
        -- CanHostStart for start; host seat ignored for ready), so a greyed or premature
        -- press is a harmless no-op.
        local _seats = manager.Seats.value
        local _isHost = (_seats[1] ~= nil and _seats[1].id == client.localPlayer.id)
        if _isHost then
            local _t = manager.tables[manager.GetViewTableId()]
            if _t ~= nil and manager.CanHostStart(_t) then
                Sounds.HapticsLight:Play()
                manager.StartGameRequest:FireServer()
            end
        else
            Sounds.HapticsLight:Play()
            manager.ReadyToggleRequest:FireServer()
        end
    end)

    -- Chrome lives in the lobby panel but the handlers live in the launcher.
    _minimizeButton:RegisterPressCallback(function() tableRegistry.Minimize() end)
    _leaveButton:RegisterPressCallback(function() tableRegistry.Leave() end)

    -- How-to-play drawer: open on the header info button, dismiss on a tap anywhere.
    _infoButton:RegisterPressCallback(function() showRules() end)
    _rulesScrim:RegisterPressCallback(function() hideRules() end)
    _rulesDrawer:RegisterPressCallback(function() hideRules() end)
    _rulesOverlay.style.display = DisplayStyle.None

    manager.ConnectViewValue("seats", function() render() end)
    manager.ConnectViewValue("tableState", function() render() end)

    manager.JoinDeniedEvent:Connect(function(reason)
        deniedReason = reason or "table_full"
        -- A denied join left the view on the tapped table; snap it back to where we are
        -- actually still seated.
        local _seatedId = manager.GetSeatedTableId()
        if _seatedId then
            manager.SetViewTable(_seatedId)
        end
        render()
    end)

    -- Spectators watch the result from the lobby view; the status line carries the
    -- announcement during the end-of-game grace window.
    manager.GameWonEvent:Connect(function(winner)
        if winner ~= nil then
            _statusLabel.text = winner.name .. " " .. L("drop_four_won_suffix", "won! Next game soon...")
        end
    end)
    manager.GameDrawnEvent:Connect(function()
        _statusLabel.text = L("drop_four_drawn", "Draw! Next game soon...")
    end)
    manager.GameEndedEvent:Connect(function()
        _statusLabel.text = L("drop_four_game_ended", "Game ended. Next game soon...")
    end)

    render()
end

function self:OnEnable()
    SlideIn()
end

-- If the lobby is minimized while the rules drawer is open, reset it and release the
-- world-controls suppressor so the controls can't get stuck hidden (Release is idempotent).
function self:OnDisable()
    if rulesTween then
        rulesTween:stop()
        rulesTween = nil
    end
    rulesVisible = false
    rulesAnimating = false
    if _rulesOverlay then
        _rulesOverlay.style.display = DisplayStyle.None
    end
    tableRegistry.ReleaseWorldControls(RULES_WC_ID)
end
