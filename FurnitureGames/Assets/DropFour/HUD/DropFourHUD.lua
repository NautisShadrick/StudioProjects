--!Type(UI)

-- DropFourHUD -- the two player tiles above the board (avatar, disc color, active-turn ring
-- and countdown) plus the announcement layer.
--
-- The turn timer is NOT replicated. The server keeps the authoritative countdown; each
-- client runs its own, restarting on every per-turn signal (currentTurnIndex change /
-- YourTurnEvent / GameStartedEvent) and stopping at game end. That removes ~16 networked
-- value updates per turn, and local drift is cosmetic only.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("The DropFourManager on the parent GameObject. It is a ClientAndServer script, not a Module, so it must be referenced here rather than required.")
--!SerializeField
local manager : DropFourManager = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Current player is a fixed accent green; the other player is a fixed gold. Neither
-- follows the disc colors -- these mean "acting now" and "up next".
local CURRENT_GREEN = Color.new(0.318, 1, 0.647, 1)
local NEXT_GOLD = Color.new(1, 0.78, 0.129, 1)

-- Announcement queue: transient messages play ONE AT A TIME at a fixed spot so they never
-- stack or fire simultaneously. Two looks:
--   "band"  -> YOUR moments (your turn / you win / draw): wide band, big bold text.
--   "toast" -> what the OTHER player did: smaller speech bubble, higher up, showing their
--              profile icon instead of their name (names are too long) plus a phrase.
local ANNOUNCE_HOLD = 1.3
local ANNOUNCE_IN_SECONDS = 0.3
local ANNOUNCE_OUT_SECONDS = 0.2
local ANNOUNCE_MIN_SCALE = 0.01
-- Toast box size, kept in sync with .announce-toast in the USS. Used to anchor the bubble
-- above a player's tile.
local TOAST_W = 160
local TOAST_H = 68
-- Held true briefly at game start so the first "YOUR TURN" does not pop while the window is
-- still sliding in. Items still enqueue; they just wait to show.
local ANNOUNCE_START_PAUSE = 0.45

local SLIDE_SECONDS = 0.35
local SLIDE_OFFSCREEN_PCT = 100

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--------------------------------
------     UI BINDINGS    ------
--------------------------------
--!Bind
local _hudRoot : VisualElement = nil
--!Bind
local _playersContainer : VisualElement = nil

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- [player.id] -> { playerElement, glowFrame, nextLabel, timerLabel, timerFill }
local elementsByPlayerID = {}
local slideTween = nil

-- FIFO of { style = "band"|"toast", text, player? }
local announceQueue: {any} = {}
local announceActive: boolean = false
local announcePaused: boolean = false

local localTimerRemaining: number = 0
local localTimerHandle = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- Localized string lookup; falls through to English until a loc database is assigned.
local function L(key: string, fallback: string): string
    local _s: any = _G.Strings
    return tostring((_s and _s[key]) or fallback)
end

local function slideApply(pct: number)
    if _hudRoot then
        _hudRoot.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.Percent(pct)))
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

-- The glow is a border outline, so colorize all four sides.
local function setGlowColor(glowFrame: VisualElement, color: Color)
    local _sc = StyleColor.new(color)
    glowFrame.style.borderTopColor = _sc
    glowFrame.style.borderBottomColor = _sc
    glowFrame.style.borderLeftColor = _sc
    glowFrame.style.borderRightColor = _sc
end

local function createPlayerElement(player: Player, mark: number)
    local _playerElement = VisualElement.new()
    _playerElement:AddToClassList("player")
    -- Tapping a tile opens the mini profile. Registered on the tile (a plain
    -- VisualElement, not the UIUserThumbnail, which swallows presses) with pickingMode set
    -- in Lua, since dynamically created elements are not reliably tappable otherwise.
    _playerElement.pickingMode = PickingMode.Position
    _playerElement:RegisterPressCallback(function()
        if player and player.user then
            UI:OpenMiniProfile(player.user.id)
        end
    end)

    local _glowFrame = VisualElement.new()
    _glowFrame:AddToClassList("glow-frame")
    _glowFrame.pickingMode = PickingMode.Ignore
    _playerElement:Add(_glowFrame)

    local _nextLabel = Label.new()
    _nextLabel.text = L("drop_four_next", "NEXT")
    _nextLabel:AddToClassList("next-label")
    _nextLabel.pickingMode = PickingMode.Ignore
    _nextLabel.style.display = DisplayStyle.None
    _playerElement:Add(_nextLabel)

    local _timerLabel = Label.new()
    _timerLabel:AddToClassList("turn-timer-label")
    _timerLabel.pickingMode = PickingMode.Ignore
    _timerLabel.style.display = DisplayStyle.None
    _playerElement:Add(_timerLabel)

    local _avatar = UIUserThumbnail.new()
    _avatar:Load(player)
    _avatar.showOnlineIndicator = false
    _avatar:AddToClassList("avatar")
    _glowFrame:Add(_avatar)

    local _timerBar = VisualElement.new()
    _timerBar:AddToClassList("timer-bar")
    _avatar:Add(_timerBar)
    local _timerFill = VisualElement.new()
    _timerFill:AddToClassList("timer-fill")
    _timerBar:Add(_timerFill)
    _timerFill.style.height = Length.Percent(0)

    -- Which disc color this player is playing, so nobody has to guess.
    local _badgeRow = VisualElement.new()
    _badgeRow:AddToClassList("disc-badge-container")
    _badgeRow.pickingMode = PickingMode.Ignore
    _playerElement:Add(_badgeRow)

    local _badge = VisualElement.new()
    _badge:AddToClassList("disc-badge")
    _badge:AddToClassList(mark == 2 and "disc-badge-2" or "disc-badge-1")
    _badge.pickingMode = PickingMode.Ignore
    _badgeRow:Add(_badge)

    local _name = Label.new()
    _name.text = player.name
    _name:AddToClassList("player-name")
    _name.pickingMode = PickingMode.Ignore
    _playerElement:Add(_name)

    _playersContainer:Add(_playerElement)

    elementsByPlayerID[player.id] = {
        playerElement = _playerElement,
        glowFrame = _glowFrame,
        nextLabel = _nextLabel,
        timerLabel = _timerLabel,
        timerFill = _timerFill,
    }
end

local function populatePlayers(players)
    _playersContainer:Clear()
    elementsByPlayerID = {}
    if not players then
        return
    end
    for i, player in ipairs(players) do
        createPlayerElement(player, i)
    end
end

-- Paint the current player's timer bar and countdown label from localTimerRemaining.
local function updateTimerDisplay()
    local _current = manager.CurrentPlayers.value[manager.CurrentTurnIndex.value]
    if not _current then
        return
    end
    local _elements = elementsByPlayerID[_current.id]
    if not _elements then
        return
    end
    -- Scale to the display length, not the real turn length, and clamp so the first second
    -- reads as a full bar -- that is the 1s grace before the server's timeout.
    local _percent = math.min((localTimerRemaining / manager.TURN_DISPLAY_SECONDS) * 100, 100)
    _elements.timerFill.style.height = Length.Percent(_percent)
    local _secs = math.min(math.ceil(localTimerRemaining), manager.TURN_DISPLAY_SECONDS)
    if localTimerRemaining > 0 then
        _elements.timerLabel.text = _secs .. L("drop_four_seconds_suffix", "s")
    else
        _elements.timerLabel.text = ""
    end
end

local function stopLocalTimer()
    if localTimerHandle then
        localTimerHandle:Stop()
        localTimerHandle = nil
    end
end

-- (Re)start the local countdown for a fresh turn. Idempotent: the per-turn signals can land
-- together, so re-calling just resets to a full turn.
local function startLocalTimer()
    stopLocalTimer()
    localTimerRemaining = manager.TURN_SECONDS
    updateTimerDisplay()
    localTimerHandle = Timer.Every(1, function()
        if localTimerRemaining > 0 then
            localTimerRemaining = localTimerRemaining - 1
            updateTimerDisplay()
        end
    end)
end

-- Highlight the acting player (green ring + timer fill + countdown) and the other player
-- (gold ring + "NEXT" tag). Called from the turn/roster handlers AND after every roster
-- rebuild, which recreates the elements with their glows hidden.
local function applyHighlights(turnIndex: number)
    local _players = manager.CurrentPlayers.value
    for _, elements in pairs(elementsByPlayerID) do
        elements.glowFrame:RemoveFromClassList("glow-frame-on")
        elements.timerFill.style.height = Length.Percent(0)
        elements.nextLabel.style.display = DisplayStyle.None
        elements.timerLabel.style.display = DisplayStyle.None
    end

    local _current = _players[turnIndex]
    if not _current then
        return
    end

    local _curEl = elementsByPlayerID[_current.id]
    if _curEl then
        setGlowColor(_curEl.glowFrame, CURRENT_GREEN)
        _curEl.glowFrame:AddToClassList("glow-frame-on")
        local _pct = math.min((localTimerRemaining / manager.TURN_DISPLAY_SECONDS) * 100, 100)
        _curEl.timerFill.style.height = Length.Percent(_pct)
        local _secs = math.min(math.ceil(localTimerRemaining), manager.TURN_DISPLAY_SECONDS)
        if localTimerRemaining > 0 then
            _curEl.timerLabel.text = _secs .. L("drop_four_seconds_suffix", "s")
        else
            _curEl.timerLabel.text = ""
        end
        _curEl.timerLabel.style.display = DisplayStyle.Flex
    end

    -- With two players the "next" player is simply the other one.
    local _count = #_players
    if _count > 1 then
        local _nextIndex = (turnIndex % _count) + 1
        local _next = _players[_nextIndex]
        if _next and _next.id ~= _current.id then
            local _nextEl = elementsByPlayerID[_next.id]
            if _nextEl then
                setGlowColor(_nextEl.glowFrame, NEXT_GOLD)
                _nextEl.glowFrame:AddToClassList("glow-frame-on")
                _nextEl.nextLabel.style.display = DisplayStyle.Flex
            end
        end
    end
end

-- Build the on-screen element for a queued announcement.
local function buildAnnounceElement(item): VisualElement
    if item.style == "band" then
        local _label = Label.new()
        _label.text = item.text
        _label:AddToClassList("announce-band")
        _label.pickingMode = PickingMode.Ignore
        return _label
    end

    local _bubble = VisualElement.new()
    _bubble:AddToClassList("announce-toast")
    _bubble.pickingMode = PickingMode.Ignore

    if item.player then
        local _avatar = UIUserThumbnail.new()
        _avatar:Load(item.player)
        _avatar.showOnlineIndicator = false
        _avatar:AddToClassList("toast-avatar")
        _avatar.pickingMode = PickingMode.Ignore
        _bubble:Add(_avatar)
    end

    local _label = Label.new()
    _label.text = item.text
    _label:AddToClassList("toast-text")
    _label.pickingMode = PickingMode.Ignore
    _bubble:Add(_label)

    return _bubble
end

-- Place a toast centered above a player's tile, tail pointing down at them. Coordinates are
-- converted from world space into the HUD root's local (scaled) units. Returns false if the
-- tile is not laid out yet, in which case the USS fallback position holds.
local function positionToastAbovePlayer(bubble: VisualElement, player: Player): boolean
    local _entry = elementsByPlayerID[player.id]
    if not _entry then
        return false
    end
    local _parentWorld = _hudRoot.worldBound
    local _tileWorld = _entry.playerElement.worldBound
    if _parentWorld.width <= 0 or _tileWorld.width <= 0 then
        return false
    end

    local _parentLocalWidth = nil
    pcall(function() _parentLocalWidth = _hudRoot.layout.width end)
    if not _parentLocalWidth or _parentLocalWidth <= 0 then
        return false
    end
    local _scaleFactor = _parentWorld.width / _parentLocalWidth
    if _scaleFactor <= 0 then
        _scaleFactor = 1
    end

    local _centerX = (_tileWorld.center.x - _parentWorld.x) / _scaleFactor
    local _tileTop = (_tileWorld.y - _parentWorld.y) / _scaleFactor
    local _left = _centerX - TOAST_W / 2
    -- Sit just above the tile; the bubble's tail overlaps it slightly.
    local _top = _tileTop - TOAST_H + 8
    if _top < 0 then
        _top = 0
    end
    bubble.style.left = Length.new(_left)
    bubble.style.top = Length.new(_top)
    return true
end

local function processAnnounceQueue()
    if announceActive or announcePaused then
        return
    end
    local _item = table.remove(announceQueue, 1)
    if not _item then
        return
    end
    announceActive = true

    local _el = buildAnnounceElement(_item)
    _hudRoot:Add(_el)
    _el:BringToFront()
    if _item.style == "toast" and _item.player then
        positionToastAbovePlayer(_el, _item.player)
    end

    local _outTween = Tween:new(
        1, ANNOUNCE_MIN_SCALE, ANNOUNCE_OUT_SECONDS, false, false, Easing.linear,
        function(v) _el.style.scale = StyleScale.new(Scale.new(Vector2.new(v, v))) end,
        function()
            _el:RemoveFromHierarchy()
            announceActive = false
            processAnnounceQueue()
        end
    )

    _el.style.scale = StyleScale.new(Scale.new(Vector2.new(ANNOUNCE_MIN_SCALE, ANNOUNCE_MIN_SCALE)))
    local _inTween = Tween:new(
        ANNOUNCE_MIN_SCALE, 1, ANNOUNCE_IN_SECONDS, false, false, Easing.easeOutBack,
        function(v) _el.style.scale = StyleScale.new(Scale.new(Vector2.new(v, v))) end,
        function()
            _el.style.scale = StyleScale.new(Scale.new(Vector2.new(1, 1)))
            Timer.After(ANNOUNCE_HOLD, function() _outTween:start() end)
        end
    )
    _inTween:start()
end

local function enqueueBand(text: string)
    table.insert(announceQueue, { style = "band", text = text })
    processAnnounceQueue()
end

local function enqueueToast(text: string, player: Player)
    table.insert(announceQueue, { style = "toast", text = text, player = player })
    processAnnounceQueue()
end

-- Drop everything still waiting, so stale messages from the previous turn or round do not
-- bleed in. Whatever is currently on screen finishes its own out-animation.
local function clearAnnounceQueue()
    announceQueue = {}
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
        error("DropFourHUD: manager SerializeField is not assigned")
    end

    populatePlayers(manager.CurrentPlayers.value)
    applyHighlights(manager.CurrentTurnIndex.value)

    -- This view's GameObject starts inactive, so Start runs on its FIRST activation -- which
    -- is the same moment GameStartedEvent fires. If Start loses that race the event handler
    -- below never ran, so seed the countdown here too when a game is already underway.
    -- startLocalTimer is idempotent, so the duplicate case is harmless.
    if #manager.CurrentPlayers.value > 0 then
        startLocalTimer()
    end

    manager.ConnectViewValue("currentPlayers", function(newValue)
        populatePlayers(newValue)
        -- The rebuild recreated every element with its glow hidden; light the current and
        -- next players up again. This also covers game start, where the turn index goes
        -- 1 -> 1 and never fires Changed.
        applyHighlights(manager.CurrentTurnIndex.value)
    end)

    manager.ConnectViewValue("currentTurnIndex", function(turnIndex)
        -- A turn change is a new countdown for every client, since the bar moves to the new
        -- current player.
        startLocalTimer()
        applyHighlights(turnIndex)
    end)

    manager.YourTurnEvent:Connect(function()
        -- Per-turn signal that fires even when currentTurnIndex does not change (a 2-player
        -- game where the roster shrank, or the very first turn).
        startLocalTimer()
        enqueueBand(L("drop_four_your_turn", "YOUR TURN"))
    end)

    manager.GameStartedEvent:Connect(function(playersList)
        -- Fresh game: drop leftover messages, and hold the queue until the window finishes
        -- sliding in so the first band does not pop mid-slide.
        clearAnnounceQueue()
        announcePaused = true
        Timer.After(ANNOUNCE_START_PAUSE, function()
            announcePaused = false
            processAnnounceQueue()
        end)
        -- The first player gets their own "YOUR TURN" band from YourTurnEvent, so everyone
        -- else gets a toast naming who moves first.
        startLocalTimer()
        local _first = playersList and playersList[1]
        if _first and _first ~= client.localPlayer then
            Timer.After(0.5, function()
                enqueueToast(L("drop_four_goes_first", "goes first!"), _first)
            end)
        end
    end)

    manager.GameWonEvent:Connect(function(winner)
        stopLocalTimer()
        -- The result is the headline: drop anything queued so it shows now.
        clearAnnounceQueue()
        if winner == client.localPlayer then
            enqueueBand(L("drop_four_you_win", "YOU WIN!"))
        elseif winner ~= nil then
            enqueueToast(L("drop_four_wins", "wins!"), winner)
        end
    end)

    manager.GameDrawnEvent:Connect(function()
        stopLocalTimer()
        clearAnnounceQueue()
        enqueueBand(L("drop_four_draw", "DRAW!"))
    end)

    manager.GameEndedEvent:Connect(function()
        stopLocalTimer()
        clearAnnounceQueue()
        enqueueBand(L("drop_four_game_ended", "GAME ENDED"))
    end)
end

function self:OnEnable()
    SlideIn()
end
