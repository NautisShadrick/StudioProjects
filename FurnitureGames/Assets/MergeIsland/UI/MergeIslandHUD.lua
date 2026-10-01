--!Type(UI)

-- MergeIslandHUD -- the full-screen Merge Island board.
--
-- The grid is built ONCE and then repainted from MergeIslandManager's local mirror, which is
-- itself only ever written from a server snapshot. So the view has no game state of its own:
-- every repaint is the authoritative board. The only things the view owns are PRESENTATION
-- state -- what is mid-animation, and how far along the discovery track the player has been
-- SHOWN (which trails the real value until they tap "Tap to Collect").
--
-- Drag uses DragGesture, not raw pointer events. The Studio API does not expose pointer
-- capture, so a PointerMove-based drag would be lost the moment the pointer left the source
-- cell. Pickup identifies the grabbed cell from a per-cell PointerDownEvent (reliable, uses
-- the event target) and only the DROP target is resolved from coordinates.
--
-- Illegal drops never touch the network: the same rule function the server will run is checked
-- locally first, so a refused drag snaps back instantly. The server still re-validates
-- everything it is asked to do.
--
-- Spawns launch IMMEDIATELY but land where the SERVER says: the server picks a random free cell
-- (and sometimes rolls a "Lucky!" or "Legendary!" item higher), so the flight leaves the generator
-- as the multiplier's tier, aims at the board, and bends onto the real cell -- repainted to the
-- real tier -- the moment the confirming snapshot names it. The cell is held empty until the
-- flight lands, so an item never pops in before its flight arrives.
--
-- The multiplier button picks what one generator tap spends and spawns: M tokens for the item M
-- tier-1s would merge into. Only x1 exists at first; x2 and x4 unlock with items 8 and 10, each
-- announced by a "Higher Power Boost Available!" bubble. A tap cycles through the unlocked ones
-- the wallet can afford and flashes "MAX X<n>" on the highest; the button steps itself down when
-- the wallet no longer covers it.
--
-- First discoveries, the jackpot and the out-of-tokens offer queue up as full-screen overlays
-- and play one after another; the server has already paid them by the time they show.
--
-- Every animation runs on TweenModule. This script is large enough that Luau's ~200 locals per
-- scope is a real limit, so helpers are grouped into tables (anim, fx, track, drag, spawn,
-- popup), elements added after the first build are looked up into `ui` rather than bound,
-- and class names live in CLASSES rather than each taking a top-level local.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("Only tier 1 is used, as the world-top button icon. Board art comes from MergeIslandHUD.uss (.item-tier-N).")
--!SerializeField
local tierSprites : {Sprite} = {}

--------------------------------
------  USS CLASS NAMES   ------
--------------------------------
local CLASSES = {
    boardRow = "board-row",
    cell = "cell",
    itemLayer = "item-layer",
    itemSlot = "item-slot",
    tile = "tile",
    tileFace = "tile-face",
    tileHidden = "tile-hidden",
    tileGhost = "tile-ghost",
    tileOpenA = "tile-open-a",
    tileOpenB = "tile-open-b",
    shadow = "cell-shadow",
    shadowVisible = "cell-shadow-visible",
    highlight = "cell-highlight",
    highlightMove = "cell-highlight-move",
    highlightVisible = "cell-highlight-visible",
    item = "cell-item",
    itemVisible = "cell-item-visible",
    itemGhost = "cell-item-ghost",
    itemLifted = "cell-item-lifted",
    tier = "cell-tier",
    brackets = "cell-brackets",
    bracketsVisible = "cell-brackets-visible",
    bracket = "bracket",
    bracketCorners = { "bracket-tl", "bracket-tr", "bracket-bl", "bracket-br" },
    flyingItem = "flying-item",
    worldTopButton = "world-top-button",
    worldTopIcon = "world-top-icon",
    slot = "track-slot",
    slotArt = "track-slot-art",
    slotSil = "track-slot-sil",
    silPrefix = "track-sil-",
    slotFound = "track-slot-found",
    slotNext = "track-slot-next",
    slotCrown = "track-slot-crown",
    tooltipReward = "tooltip-reward",
    tooltipIcon = "tooltip-icon",
    tooltipAmount = "tooltip-amount",
    revealChip = "reveal-reward-chip",
    revealChipIcon = "reveal-reward-chip-icon",
    revealChipLabel = "reveal-reward-label",
    prizeCard = "prize-card",
    prizeCardIcon = "prize-card-icon",
    prizeCardCheck = "prize-card-check",
    prizeWon = "prize-won",
    winPrizeCard = "win-prize-card",
    winPrizeFace = "win-prize-face",
    winPrizeIcon = "win-prize-icon",
    winPrizeLabel = "win-prize-label",
    particle = "fx-particle",
    star = "fx-star",
    sparkle = "fx-sparkle",
    glow = "fx-glow",
    coin = "fx-coin",
    chest = "fx-chest",
    ring = "fx-ring",
    ringGold = "fx-ring-gold",
    sand = "fx-sand",
    bubble = "fx-bubble",
    confettiPrefix = "fx-confetti-",
    floatText = "fx-float-text",
    floatTextEnergy = "fx-float-text-energy",
    floatTextPoints = "fx-float-text-points",
    floatTextMax = "fx-float-text-max",
    luckyText = "fx-lucky-text",
    legendaryText = "fx-legendary-text",
    ticket = "fx-ticket",
    token = "fx-token",
    rewardItem = "reward-icon-item",
    rewardCrown = "reward-icon-crown",
    rewardToken = "reward-icon-token",
    rewardTicket = "reward-icon-ticket",
    -- Every reward-icon-* class, so an element can be cleared before a new icon is applied.
    rewardIcons = {
        "reward-icon-item", "reward-icon-crown", "reward-icon-token", "reward-icon-ticket",
        "reward-icon-recolour", "reward-icon-epic",
        "jackpot-icon-hat", "jackpot-icon-coat", "jackpot-icon-boots", "jackpot-icon-cutlass",
    },
    resetArmed = "reset-button-armed",
    offer = "topup-offer",
    offerIcon = "topup-offer-icon",
    offerAmount = "topup-offer-amount",
    offerBuy = "topup-offer-buy",
    offerPrice = "topup-offer-price",
    offerBought = "topup-offer-bought",
    ctaButton = "cta-button",
    ctaFace = "cta-face",
    ctaLabel = "cta-label",
}

--------------------------------
---- UXML ELEMENT BINDINGS -----
--------------------------------
--!Bind
local _hudRoot : VisualElement = nil
--!Bind
local _backdrop : VisualElement = nil
--!Bind
local _infoButton : VisualElement = nil
--!Bind
local _closeButton : VisualElement = nil
--!Bind
local _prizePanel : VisualElement = nil
--!Bind
local _prizeRow : VisualElement = nil
--!Bind
local _prizeShine : VisualElement = nil
--!Bind
local _trackPanel : VisualElement = nil
--!Bind
local _trackLine : VisualElement = nil
--!Bind
local _trackFill : VisualElement = nil
--!Bind
local _trackSlots : VisualElement = nil
--!Bind
local _trackTooltip : VisualElement = nil
--!Bind
local _tooltipBob : VisualElement = nil
--!Bind
local _tooltipRewards : VisualElement = nil
--!Bind
local _boardFrame : VisualElement = nil
--!Bind
local _boardGrid : VisualElement = nil
--!Bind
local _loadingLabel : Label = nil
--!Bind
local _bottomBar : VisualElement = nil
--!Bind
local _energyChip : VisualElement = nil
--!Bind
local _energyLabel : Label = nil
--!Bind
local _energyBolt : VisualElement = nil
--!Bind
local _generatorButton : VisualElement = nil
--!Bind
local _hintLabel : Label = nil
--!Bind
local _toastLabel : Label = nil
--!Bind
local _fxLayer : VisualElement = nil
--!Bind
local _flightLayer : VisualElement = nil
--!Bind
local _topLayer : VisualElement = nil
--!Bind
local _revealOverlay : VisualElement = nil
--!Bind
local _revealScrim : VisualElement = nil
--!Bind
local _revealContent : VisualElement = nil
--!Bind
local _revealBanner : VisualElement = nil
--!Bind
local _revealTitle : Label = nil
--!Bind
local _revealRays : VisualElement = nil
--!Bind
local _revealRaysBack : VisualElement = nil
--!Bind
local _revealGlow : VisualElement = nil
--!Bind
local _revealSparkles : VisualElement = nil
--!Bind
local _revealItem : VisualElement = nil
--!Bind
local _revealName : Label = nil
--!Bind
local _revealReward : VisualElement = nil
--!Bind
local _revealRewardIcon : VisualElement = nil
--!Bind
local _revealRewardLabel : Label = nil
--!Bind
local _revealTap : VisualElement = nil
--!Bind
local _winOverlay : VisualElement = nil
--!Bind
local _winScrim : VisualElement = nil
--!Bind
local _winContent : VisualElement = nil
--!Bind
local _confettiLayer : VisualElement = nil
--!Bind
local _winBanner : VisualElement = nil
--!Bind
local _winRays : VisualElement = nil
--!Bind
local _winGlow : VisualElement = nil
--!Bind
local _winCrown : VisualElement = nil
--!Bind
local _winTitle : Label = nil
--!Bind
local _winPrizeRow : VisualElement = nil
--!Bind
local _winButton : VisualElement = nil
--!Bind
local _infoOverlay : VisualElement = nil
--!Bind
local _infoScrim : VisualElement = nil
--!Bind
local _infoContent : VisualElement = nil
--!Bind
local _infoPanel : VisualElement = nil
--!Bind
local _infoOk : VisualElement = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- Element sizes Lua needs for positioning. Each must match its USS rule.
local SIZES = {
    item = 40,          -- .cell-item / .flying-item
    itemTopOffset = -1, -- .cell-item sits 1px above the cell centre (top 2px in a 46px cell)
    revealItem = 124,   -- .reveal-item
    slotArt = 24,       -- .track-slot-art
    tooltipWidth = 120, -- .track-tooltip
    stage = 230,        -- .stage-fill
}

-- How far the finger must travel before a drag starts rather than reading as a tap.
local DRAG_MIN_DISTANCE = 6
-- The lifted item is drawn larger so it reads as picked up.
local LIFT_SCALE = 1.28
-- Tilt (degrees) per pixel of horizontal drag, and its cap, so a flick visibly swings the item.
local TILT_PER_PX = 2.4
local TILT_MAX = 20

local TIMING = {
    lift = 0.16,
    snapBack = 0.3,
    glide = 0.1,
    spawnFlight = 0.42,
    spawnTimeout = 4,
    commitTimeout = 3,
    breakStagger = 0.06,
    revealDelay = 0.6,     -- lets the merge pop play before the reveal takes the screen
    revealArm = 0.8,       -- "Tap to Collect" ignores taps until the item has landed
    collectFlight = 0.72,
    winArm = 1.1,
    toastIn = 0.22,
    toastHold = 1.3,
    toastOut = 0.35,
    hudOut = 0.18,
    hintIdle = 5,          -- seconds without input before the board nudges a mergeable pair
    hintRepeat = 3.5,
    spawnGlide = 0.16,     -- a flight that arrived before the server named its cell glides there
    spawnTapGap = 0.12,    -- generator taps closer than this are ignored (server throttles too)
    luck = 1.3,            -- the "Lucky!" / "Legendary!" label's whole pop, hold and fade
    resetArm = 3,          -- the armed RESET button waits this long for its confirming tap
}

-- Toast: fades in while sliding up, holds, then fades out.
local TOAST_RISE_PX = 24
local CONFETTI_COUNT = 44
local REVEAL_SPARKLE_COUNT = 7

local WORLD_TOP_BUTTON_INDEX = 0

-- Prints each gesture point alongside the grid's worldBound, to confirm the drag coordinate
-- space on a new build. See gesturePoint below.
local DEBUG_DRAG = false

local DEFAULT_HINT = "Drag an item onto a matching item to merge it"
-- Once every item is found the jackpot is paid and nothing more can be earned.
local JACKPOT_HINT = "You found every item! Keep merging just for fun"
-- Rejection reasons -> player-facing copy. Reasons the player cannot act on (an out-of-sync
-- move, a drag of nothing) are deliberately absent and fall through to the default hint.
local REJECT_MESSAGES = {
    no_energy = "Out of Merge Tokens!",
    board_full = "Board is full! Merge items to make room",
    mismatch = "Those items don't match",
    max_tier = "That's already the best item!",
    locked = "That sand is still locked",
    topup_unavailable = "Token packs aren't available yet",
    offer_bought = "You already bought that pack",
}

-- Overlay phases. Board input is only accepted in PHASE_IDLE.
local PHASE_IDLE = "idle"
local PHASE_REVEAL_IN = "reveal_in"
local PHASE_REVEAL_READY = "reveal_ready"
local PHASE_COLLECTING = "collecting"
local PHASE_WIN = "win"
local PHASE_INFO = "info"
local PHASE_TOPUP = "topup"

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local manager = require("MergeIslandManager")
local config = require("MergeIslandConfig")
local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- cellElements[index] = { root, tile, item, tier, shadow, highlight, brackets, itemClass, isEven }
-- itemClass remembers which item-tier-N class is currently applied, so a repaint can remove
-- exactly that one instead of clearing the whole class list.
local cellElements: {any} = {}
-- slotElements[tier] = { root, art }, plus the crown at MAX_TIER + 1.
local slotElements: {any} = {}

-- The cell whose PointerDownEvent fired most recently, and which a starting drag will lift.
-- This is how a drag knows what was grabbed without depending on gesture coordinates.
--
-- It is cleared on the grid's own trickle-down handler (which runs BEFORE any cell's) and
-- consumed when a drag begins. Both matter: without them, a press that lands on the grid but
-- not on a cell would start a drag using whatever cell was pressed last, lifting the wrong
-- item.
local pressedIndex: number | nil = nil

-- Live drag, or nil. { fromIndex, element, hoverIndex, hoverTween, x, y, originX, originY,
-- lastX, tilt }. x/y track the lifted element's position so a snap-back never has to read a
-- StyleLength back out of the element.
local dragState: any = nil

-- A legal drop sent to the server and not yet confirmed, or nil.
-- { from, to, kind, element, rejected, timeout }. The dragged element stays parked on the
-- target until the confirming snapshot, so nothing flickers for the round trip. The server tags
-- its answer to a move (`moved`), so a spawn snapshot arriving in between can never be mistaken
-- for it.
local commit: any = nil

-- Spawn flights awaiting their snapshot, oldest first (the server answers in order).
-- { target, element, tween, landed, confirmed, timeout }. `target` is nil until the server
-- names the cell; until then the flight aims at the middle of the board.
local pendingSpawns: {any} = {}
-- Cells kept visually empty until a spawn flight lands on them.
local spawnHolds: {[number]: boolean} = {}
-- Cells currently showing a ghost silhouette, for the ambient breathing.
local ghostIndices: {[number]: boolean} = {}
-- The cell that just produced a discovery (shows the corner brackets), and the most recent
-- landing, which is where a discovery in the same snapshot came from.
local bracketIndex: number | nil = nil
local lastLandingIndex: number | nil = nil

-- The discovery track as SHOWN. It trails manager.GetHighestTier() while a reveal is pending,
-- so the slot fills when the player collects, not when the server decides.
local shownHighestTier: number = 1
local trackSeeded: boolean = false
local fillWidth: number = 0
local fillTween = nil
local layoutRetries: number = 0

-- Full-screen moments waiting their turn, oldest first. Each is one of:
--   { kind = "item", tier }        first discovery of an item tier (the top tier then plays
--                                  the jackpot screen)
--   { kind = "topup" }             the out-of-tokens offer
local revealQueue: {any} = {}
-- The item entry currently in the reveal overlay.
local revealEntry: any = nil
local revealItemClass: string | nil = nil
local phase: string = PHASE_IDLE

-- Elements added after the original build, looked up by name in Start (see bindExtraUi) so
-- they do not each cost a top-level local. Also holds presentation-only state.
local ui: any = {
    -- The jackpot was won in a snapshot whose top-tier reveal has not been collected yet.
    jackpotPending = false,
    -- The small jackpot cards' check marks, popped in when the jackpot is collected.
    prizeChecks = {},
    -- Index into the UNLOCKED multipliers (see spawn.unlocked) of the selected one, and the
    -- item-tier class currently painted on the generator's badge.
    multiplierIndex = 1,
    generatorShellClass = nil,
    -- The highest multiplier the player has been shown unlocking (nil until the track is seeded),
    -- and whether the "Higher Power Boost Available!" bubble is waiting for the next button tap.
    knownMaxMult = nil,
    boostPending = false,
    -- Out-of-tokens offer cards, one per config.TOPUP_OFFERS entry: { root, buy, price }.
    offerCards = {},
    -- The tier the track's reward bubble currently sits over, or nil while it is hidden.
    tooltipTier = nil,
}

-- Endless ambient tweens (stopped on Hide) and the ones owned by the current overlay.
local loopTweens: {any} = {}
local overlayLoops: {any} = {}
local ambientTime: number = 0
local lastInteraction: number = 0
local nextHintAt: number = 0
local generatorEnabled: boolean = false
local generatorBusy: boolean = false

-- Bumped on every toast; a deferred fade-out only runs if its toast is still the newest one, so
-- a superseded toast cannot hide the one that replaced it.
local toastGeneration: number = 0
local toastTween = nil
local isOpen: boolean = false
-- Bumped on every open/close so a deferred close cannot hide a HUD that was reopened.
local openGeneration: number = 0
local worldTopButton: VisualElement = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- Sound is decoration: a missing or renamed shader must never break gameplay, so every play
-- is protected.
local function playSound(name: string)
    pcall(function()
        Sounds[name]:Play()
    end)
end

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

local function clamp(v: number, lo: number, hi: number): number
    return math.max(lo, math.min(hi, v))
end

local function setClass(element: VisualElement, className: string, on: boolean)
    if on then
        element:AddToClassList(className)
    else
        element:RemoveFromClassList(className)
    end
end

---------------- anim: tweens and style setters ----------------
local anim = {}

anim.outCubic = function(t)
    local _u = 1 - t
    return 1 - _u * _u * _u
end
anim.inCubic = function(t)
    return t * t * t
end
anim.inOutSine = function(t)
    return -(math.cos(math.pi * t) - 1) / 2
end
anim.outBack = Easing.easeOutBack
-- A springier overshoot for things that should feel like they POP.
anim.outBackStrong = function(t)
    local _c1 = 2.6
    local _c3 = _c1 + 1
    local _u = t - 1
    return 1 + _c3 * _u * _u * _u + _c1 * _u * _u
end
anim.outElastic = function(t)
    if t <= 0 then
        return 0
    end
    if t >= 1 then
        return 1
    end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end

-- A 0 -> 1 tween. Its first frame is applied immediately, so a DELAYED tween holds its start
-- state (usually hidden) instead of flashing its end state until the delay runs out.
function anim.run(duration: number, easing, onUpdate, onComplete, delay: number?)
    local _tween = Tween:new(0, 1, duration, false, false, easing or Easing.linear, onUpdate, onComplete)
    if onUpdate then
        onUpdate(0)
    end
    if delay and delay > 0 then
        Timer.After(delay, function()
            if not _tween.cancelled then
                _tween:start()
            end
        end)
    else
        _tween:start()
    end
    return _tween
end

-- Stop a tween without running its completion, including one still waiting on its delay.
function anim.cancel(tween)
    if tween then
        tween.cancelled = true
        tween:stop()
    end
end

-- An endless tween, registered in `bucket` so it can be stopped with the rest of its group.
function anim.loop(duration: number, pingPong: boolean, easing, onUpdate, bucket)
    local _tween = Tween:new(0, 1, duration, true, pingPong, easing or Easing.linear, onUpdate, nil)
    _tween:start()
    table.insert(bucket, _tween)
    return _tween
end

function anim.stopAll(bucket)
    for i = #bucket, 1, -1 do
        anim.cancel(bucket[i])
        bucket[i] = nil
    end
end

function anim.scale(element: VisualElement, value: number)
    element.style.scale = StyleScale.new(Scale.new(Vector2.new(value, value)))
end

function anim.scaleXY(element: VisualElement, x: number, y: number)
    element.style.scale = StyleScale.new(Scale.new(Vector2.new(x, y)))
end

function anim.move(element: VisualElement, x: number, y: number)
    element.style.translate = StyleTranslate.new(Translate.new(Length.new(x), Length.new(y)))
end

function anim.rotate(element: VisualElement, degrees: number)
    element.style.rotate = StyleRotate.new(Rotate.new(Angle.new(degrees)))
end

function anim.fade(element: VisualElement, opacity: number)
    element.style.opacity = StyleFloat.new(opacity)
end

-- Layout position. Used for anything a hit test or a later tween reads back.
function anim.place(element: VisualElement, x: number, y: number)
    element.style.left = Length.new(x)
    element.style.top = Length.new(y)
end

function anim.show(element: VisualElement, visible: boolean)
    element.style.display = if visible then DisplayStyle.Flex else DisplayStyle.None
end

-- Decaying side-to-side shake, e.g. "you can't do that" or the board rumbling open.
function anim.shake(element: VisualElement, amplitude: number, duration: number)
    return anim.run(duration, Easing.linear, function(t)
        anim.move(element, math.sin(t * math.pi * 8) * amplitude * (1 - t), 0)
    end, function()
        anim.move(element, 0, 0)
    end)
end

-- A quick "no" / "look at me" rotation wiggle.
function anim.wiggle(element: VisualElement, degrees: number)
    return anim.run(0.6, Easing.linear, function(t)
        anim.rotate(element, math.sin(t * math.pi * 5) * degrees * (1 - t))
    end, function()
        anim.rotate(element, 0)
    end)
end

-- Overshooting scale pop from `from` to 1.
function anim.pop(element: VisualElement, from: number, duration: number, delay: number?)
    return anim.run(duration, anim.outElastic, function(t)
        anim.scale(element, lerp(from, 1, t))
    end, function()
        anim.scale(element, 1)
    end, delay)
end

-- Squash-and-stretch landing: wide and flat, then springs back.
function anim.squash(element: VisualElement)
    return anim.run(0.42, anim.outElastic, function(t)
        anim.scaleXY(element, lerp(1.28, 1, t), lerp(0.76, 1, t))
    end, function()
        anim.scale(element, 1)
    end)
end

-- Slide + fade in from an offset, for staggered entrances.
function anim.enter(element: VisualElement, dx: number, dy: number, duration: number, delay: number)
    return anim.run(duration, anim.outBack, function(t)
        anim.move(element, dx * (1 - t), dy * (1 - t))
        anim.fade(element, clamp(t * 2.5, 0, 1))
    end, function()
        anim.move(element, 0, 0)
        anim.fade(element, 1)
    end, delay)
end

---------------- fx: particles and flourishes ----------------
local fx = {}

-- Centre of `element`, in `layer`'s local space.
function fx.point(layer: VisualElement, element: VisualElement): Vector2
    local _bound = element.worldBound
    return layer:WorldToLocal(Vector2.new(_bound.center.x, _bound.center.y))
end

function fx.round(element: VisualElement, radius: number)
    local _r = Length.new(radius)
    element.style.borderTopLeftRadius = _r
    element.style.borderTopRightRadius = _r
    element.style.borderBottomLeftRadius = _r
    element.style.borderBottomRightRadius = _r
end

-- A particle element of `size`, centred on `point` in `layer` (default: the fx layer).
function fx.particle(className: string, point: Vector2, size: number, layer: VisualElement?): VisualElement
    local _layer = layer or _fxLayer
    local _element = VisualElement.new()
    _element:AddToClassList(CLASSES.particle)
    _element:AddToClassList(className)
    _element.pickingMode = PickingMode.Ignore
    _element.style.width = Length.new(size)
    _element.style.height = Length.new(size)
    anim.place(_element, point.x - size / 2, point.y - size / 2)
    _layer:Add(_element)
    return _element
end

-- Particles thrown outward from `point`, spinning, shrinking and fading.
function fx.burst(point: Vector2, count: number, radius: number, className: string, size: number,
                  duration: number, layer: VisualElement?, round: boolean?)
    for i = 1, count do
        local _angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.7
        local _dist = radius * (0.65 + math.random() * 0.55)
        local _size = size * (0.7 + math.random() * 0.6)
        local _element = fx.particle(className, point, _size, layer)
        if round then
            fx.round(_element, _size / 2)
        end
        local _dx = math.cos(_angle) * _dist
        local _dy = math.sin(_angle) * _dist
        local _spin = math.random(-220, 220)
        anim.run(duration * (0.8 + math.random() * 0.4), anim.outCubic, function(t)
            anim.move(_element, _dx * t, _dy * t)
            anim.scale(_element, 1.15 - t)
            anim.fade(_element, 1 - t * t)
            anim.rotate(_element, _spin * t)
        end, function()
            _element:RemoveFromHierarchy()
        end)
    end
end

-- An expanding ring shockwave.
function fx.ring(point: Vector2, size: number, duration: number, gold: boolean, layer: VisualElement?)
    local _element = fx.particle(CLASSES.ring, point, size, layer)
    if gold then
        _element:AddToClassList(CLASSES.ringGold)
    end
    fx.round(_element, size / 2)
    anim.run(duration, anim.outCubic, function(t)
        anim.scale(_element, 0.3 + t * 1.0)
        anim.fade(_element, 1 - t)
    end, function()
        _element:RemoveFromHierarchy()
    end)
end

-- A soft bloom of light that swells and fades.
function fx.flash(point: Vector2, size: number, layer: VisualElement?)
    local _element = fx.particle(CLASSES.glow, point, size, layer)
    anim.run(0.45, anim.outCubic, function(t)
        anim.scale(_element, 0.4 + t)
        anim.fade(_element, 1 - t)
    end, function()
        _element:RemoveFromHierarchy()
    end)
end

-- Rising "+3 Gold" style text that pops in, drifts up and fades.
function fx.floatText(point: Vector2, text: string, extraClass: string?, layer: VisualElement?)
    local _layer = layer or _fxLayer
    local _label = Label.new()
    _label:AddToClassList(CLASSES.floatText)
    if extraClass then
        _label:AddToClassList(extraClass)
    end
    _label.pickingMode = PickingMode.Ignore
    _label.text = text
    anim.place(_label, point.x - 80, point.y - 15)
    _layer:Add(_label)
    anim.run(1.1, Easing.linear, function(t)
        anim.move(_label, 0, -52 * anim.outCubic(t))
        anim.scale(_label, if t < 0.2 then lerp(0.3, 1, anim.outBackStrong(t / 0.2)) else 1)
        anim.fade(_label, if t < 0.65 then 1 else 1 - (t - 0.65) / 0.35)
    end, function()
        _label:RemoveFromHierarchy()
    end)
end

-- The "Lucky!" / "Legendary!" stamp over a lucky spawn: slams in tilted and oversized, wobbles
-- upright-ish, drifts up and fades, with a gold ring and a spray of stars behind it. Legendary
-- (+2 tiers) gets a bigger ring and burst and its own colours.
function fx.luck(point: Vector2, luck: string)
    local _legendary = luck == config.LUCK_LEGENDARY
    fx.ring(point, if _legendary then 84 else 64, 0.45, true)
    fx.burst(point, if _legendary then 14 else 8, if _legendary then 60 else 44, CLASSES.star, 14, 0.6)

    local _label = Label.new()
    _label:AddToClassList(CLASSES.luckyText)
    if _legendary then
        _label:AddToClassList(CLASSES.legendaryText)
    end
    _label.pickingMode = PickingMode.Ignore
    _label.text = if _legendary then "Legendary!" else "Lucky!"
    -- Centred on the item, lifted so it sits over the item's top edge like a stamp.
    anim.place(_label, point.x - 75, point.y - 22 - 30)
    _fxLayer:Add(_label)
    _label:BringToFront()
    anim.run(TIMING.luck, Easing.linear, function(t)
        local _in = clamp(t / 0.22, 0, 1)
        anim.scale(_label, lerp(0.2, 1, anim.outBackStrong(_in)))
        anim.rotate(_label, -14 + math.sin(_in * math.pi * 2) * 8 * (1 - _in))
        anim.move(_label, 0, if t < 0.6 then 0 else -18 * anim.outCubic((t - 0.6) / 0.4))
        anim.fade(_label, if t < 0.7 then 1 else 1 - (t - 0.7) / 0.3)
    end, function()
        _label:RemoveFromHierarchy()
    end)
end

-- A fountain of coins that leaps out of `point` and tumbles away.
function fx.coins(point: Vector2, count: number, className: string, layer: VisualElement?)
    for i = 1, count do
        local _element = fx.particle(className, point, 22 + math.random() * 10, layer)
        local _vx = (math.random() - 0.5) * 170
        local _up = 80 + math.random() * 80
        local _spin = math.random(-360, 360)
        anim.run(0.8 + math.random() * 0.35, Easing.linear, function(t)
            -- Ballistic: up and over, finishing a little below where it started.
            anim.move(_element, _vx * t, -_up * 4 * t * (1 - t) + 40 * t * t)
            anim.rotate(_element, _spin * t)
            anim.scale(_element, if t < 0.12 then t / 0.12 else 1)
            anim.fade(_element, if t < 0.7 then 1 else 1 - (t - 0.7) / 0.3)
        end, function()
            _element:RemoveFromHierarchy()
        end, (i - 1) * 0.03)
    end
end

-- One twinkle of a trail: a small star left behind a flying item.
function fx.trail(point: Vector2, layer: VisualElement)
    local _element = fx.particle(CLASSES.star, point, 14 + math.random() * 10, layer)
    local _spin = math.random(-120, 120)
    anim.run(0.45, anim.outCubic, function(t)
        anim.scale(_element, 1 - t)
        anim.fade(_element, 1 - t)
        anim.rotate(_element, _spin * t)
    end, function()
        _element:RemoveFromHierarchy()
    end)
end

-- Paper confetti falling across `layer`, swaying and spinning.
function fx.confetti(layer: VisualElement, count: number)
    local _bound = layer.worldBound
    local _width = if _bound.width > 0 then _bound.width else 400
    local _height = if _bound.height > 0 then _bound.height else 800
    for _ = 1, count do
        local _className = CLASSES.confettiPrefix .. tostring(math.random(0, 5))
        local _element = fx.particle(_className, Vector2.new(math.random() * _width, -24), 10, layer)
        _element.style.width = Length.new(7 + math.random() * 6)
        _element.style.height = Length.new(11 + math.random() * 8)
        local _sway = 18 + math.random() * 34
        local _phase = math.random() * math.pi * 2
        local _spin = math.random(-720, 720)
        local _fall = _height + 60
        anim.run(2.2 + math.random() * 1.4, Easing.linear, function(t)
            anim.move(_element, math.sin(t * 7 + _phase) * _sway, _fall * t)
            anim.rotate(_element, _spin * t)
            -- A flutter: the piece turns edge-on and back as it falls.
            anim.scaleXY(_element, math.max(0.15, math.abs(math.cos(t * 11 + _phase))), 1)
        end, function()
            _element:RemoveFromHierarchy()
        end, math.random() * 0.9)
    end
end

-- Feature groups. Tables rather than top-level locals, to stay clear of Luau's locals limit.
local track = {}
local drag = {}
local spawn = {}
local popup = {}

---------------- art ----------------
-- The assigned sprite's texture for a tier, or nil. Only the world-top button uses this now
-- (it lives outside this HUD's stylesheet, so it cannot use the USS art classes).
local function tierTexture(tier: number?)
    -- `tier or 0` keeps the index a plain number for the type checker; index 0 never exists, so
    -- a nil tier falls through to the no-art path just the same.
    local _sprite = tierSprites[tier or 0]
    if not _sprite then
        return nil
    end
    return _sprite.texture
end

-- Paint a tier's art onto any element via its USS class (.item-tier-N carries the image).
-- Returns the class applied so the caller can remove it on the next repaint.
--
-- Art is NEVER set inline (style.backgroundImage): in this runtime, assigning nil to clear an
-- inline image leaves an inline "none" that hides the class image for good, so an element that
-- ever held an inline sprite could never show class art again.
local function paintTier(element: VisualElement, tier: number, previousClass: string?): string?
    if previousClass then
        element:RemoveFromClassList(previousClass)
    end
    local _info = config.TierInfo(tier)
    if _info then
        element:AddToClassList(_info.class)
        return _info.class
    end
    return nil
end

-- The icon class for a reward: its own `icon` override, else one per reward kind.
local function rewardIconClass(reward): string
    if reward.icon then
        return reward.icon
    end
    if reward.kind == config.REWARD_TOKENS then
        return CLASSES.rewardToken
    end
    if reward.kind == config.REWARD_TICKETS then
        return CLASSES.rewardTicket
    end
    return CLASSES.rewardItem
end

local function setRewardIcon(element: VisualElement, className: string)
    for _, name in ipairs(CLASSES.rewardIcons) do
        element:RemoveFromClassList(name)
    end
    element:AddToClassList(className)
end

-- A particle class matching a reward, for the shower on collect.
local function rewardParticleClass(reward): string
    if reward and reward.kind == config.REWARD_TOKENS then
        return CLASSES.token
    end
    if reward and reward.kind == config.REWARD_TICKETS then
        return CLASSES.ticket
    end
    return CLASSES.chest
end

---------------- toast ----------------
local function applyToast(opacity: number, risePx: number, scale: number)
    anim.fade(_toastLabel, opacity)
    anim.move(_toastLabel, 0, risePx)
    anim.scale(_toastLabel, scale)
end

-- Pop a transient message above the generator: fade in while sliding up from below, hold, then
-- fade out. Re-triggering restarts it, and the generation guard stops a superseded toast's
-- deferred fade-out from hiding the newer one.
local function showToast(text: string)
    toastGeneration = toastGeneration + 1
    local _generation = toastGeneration
    anim.cancel(toastTween)
    toastTween = nil

    _toastLabel.text = text
    _toastLabel.style.display = DisplayStyle.Flex
    toastTween = anim.run(TIMING.toastIn, anim.outBack, function(t)
        applyToast(clamp(t, 0, 1), TOAST_RISE_PX * (1 - t), lerp(0.8, 1, t))
    end, function()
        applyToast(1, 0, 1)
        Timer.After(TIMING.toastHold, function()
            if _generation ~= toastGeneration then
                return
            end
            toastTween = anim.run(TIMING.toastOut, Easing.easeInQuad, function(t)
                applyToast(1 - t, 0, 1)
            end, function()
                if _generation ~= toastGeneration then
                    return
                end
                applyToast(0, TOAST_RISE_PX, 1)
                _toastLabel.style.display = DisplayStyle.None
                toastTween = nil
            end)
        end)
    end)
end

local function hideToast()
    toastGeneration = toastGeneration + 1
    anim.cancel(toastTween)
    toastTween = nil
    _toastLabel.style.display = DisplayStyle.None
    applyToast(0, TOAST_RISE_PX, 1)
end

---------------- input helpers ----------------
-- Convert a gesture event into a panel-space point.
--
-- IF DROPS LAND ON THE WRONG CELL, THIS IS THE FUNCTION TO FIX. The docs do not state whether
-- gesture `position` is panel space (what worldBound uses) or raw screen space, and the two
-- differ by the panel scale and possibly a flipped Y. Every hit-test goes through here, so a
-- correction is one place. Set DEBUG_DRAG to print the gesture point next to the grid's
-- worldBound and the answer is immediately obvious.
local function gesturePoint(evt): Vector2
    local _point = Vector2.new(evt.position.x, evt.position.y)
    if DEBUG_DRAG then
        local _grid = _boardGrid.worldBound
        print("[MergeIslandHUD] gesture=(" .. tostring(_point.x) .. "," .. tostring(_point.y)
            .. ") screen=(" .. tostring(evt.screenPosition.x) .. "," .. tostring(evt.screenPosition.y)
            .. ") gridWorld=(" .. tostring(_grid.x) .. "," .. tostring(_grid.y)
            .. " " .. tostring(_grid.width) .. "x" .. tostring(_grid.height) .. ")")
    end
    return _point
end

-- Which cell is under a panel-space point, or nil. WorldToLocal handles the panel scale for
-- us, which is why this does not need the manual scale-factor math the Drop Four board uses.
local function cellIndexAt(point: Vector2): number | nil
    -- Cheap rejection first, so a drag outside the board does not test 49 cells per move.
    local _gridLocal = _boardGrid:WorldToLocal(point)
    if not _boardGrid:ContainsPoint(_gridLocal) then
        return nil
    end
    for i = 1, config.CELL_COUNT do
        local _ui = cellElements[i]
        if _ui then
            if _ui.root:ContainsPoint(_ui.root:WorldToLocal(point)) then
                return i
            end
        end
    end
    return nil
end

-- Any input pushes the idle hint back.
local function markInteraction()
    lastInteraction = ambientTime
    nextHintAt = ambientTime + TIMING.hintIdle
end

-- Top-left of a cell's item, in `layer` space: where a flying item must sit to land flush.
local function itemOriginIn(layer: VisualElement, index: number): Vector2
    local _center = fx.point(layer, cellElements[index].root)
    return Vector2.new(_center.x - SIZES.item / 2, _center.y - SIZES.item / 2 + SIZES.itemTopOffset)
end

-- A free-floating copy of a tier's art, used for drags and spawn flights.
local function makeFlyingItem(tier: number): VisualElement
    local _element = VisualElement.new()
    _element:AddToClassList(CLASSES.flyingItem)
    _element.pickingMode = PickingMode.Ignore
    local _tierLabel = Label.new()
    _tierLabel:AddToClassList(CLASSES.tier)
    _tierLabel.pickingMode = PickingMode.Ignore
    -- Same art rule as a cell: the tier's sprite if it has one, otherwise its class art.
    paintTier(_element, tier, nil)
    _tierLabel.text = ""
    _element:Add(_tierLabel)
    _flightLayer:Add(_element)
    _element:BringToFront()
    return _element
end

---------------- board rendering ----------------
local function hideItemVisual(ui)
    ui.item:RemoveFromClassList(CLASSES.itemVisible)
    ui.shadow:RemoveFromClassList(CLASSES.shadowVisible)
    ui.tier.text = ""
end

-- Paint one cell's item element for an item (or a ghost's silhouette). Passing nil tier hides
-- it. Art comes from the tier's USS class (see paintTier).
local function applyItemVisual(ui, tier: number?, isGhost: boolean)
    if ui.itemClass then
        ui.item:RemoveFromClassList(ui.itemClass)
        ui.itemClass = nil
    end
    ui.item:RemoveFromClassList(CLASSES.itemGhost)

    if tier == nil or not config.TierInfo(tier) then
        hideItemVisual(ui)
        return
    end

    ui.itemClass = paintTier(ui.item, tier, nil)
    ui.tier.text = ""

    ui.item:AddToClassList(CLASSES.itemVisible)
    setClass(ui.item, CLASSES.itemGhost, isGhost)
    setClass(ui.shadow, CLASSES.shadowVisible, not isGhost)
end

local function renderCell(index: number)
    local _ui = cellElements[index]
    if not _ui then
        return
    end
    local _cell = config.CellAt(manager.GetCells(), index)
    local _wasGhost = ghostIndices[index] == true

    _ui.tile:RemoveFromClassList(CLASSES.tileHidden)
    _ui.tile:RemoveFromClassList(CLASSES.tileGhost)
    _ui.tile:RemoveFromClassList(CLASSES.tileOpenA)
    _ui.tile:RemoveFromClassList(CLASSES.tileOpenB)

    if _cell.state == config.STATE_GHOST then
        _ui.tile:AddToClassList(CLASSES.tileGhost)
        applyItemVisual(_ui, _cell.tier, true)
        ghostIndices[index] = true
    elseif _cell.state == config.STATE_OPEN then
        -- Parity is fixed per cell and cached at build time, so the checkerboard stays stable as
        -- tiles change state.
        _ui.tile:AddToClassList(if _ui.isEven then CLASSES.tileOpenA else CLASSES.tileOpenB)
        applyItemVisual(_ui, _cell.tier, false)
        ghostIndices[index] = nil
    else
        _ui.tile:AddToClassList(CLASSES.tileHidden)
        applyItemVisual(_ui, nil, false)
        ghostIndices[index] = nil
    end
    -- The ghost breathing drives scale inline; a cell that stops being a ghost must not keep it.
    if _wasGhost and not ghostIndices[index] then
        anim.scale(_ui.item, 1)
    end

    -- A cell whose item is lifted, committed-but-unconfirmed, or awaiting a spawn flight keeps
    -- its layout but hides the item, so the grid never reflows mid-drag -- a reflow would move
    -- every worldBound the drop test reads.
    local _held = (dragState and dragState.fromIndex == index)
        or (commit and commit.from == index)
        or spawnHolds[index] == true
    setClass(_ui.item, CLASSES.itemLifted, _held)
    setClass(_ui.shadow, CLASSES.itemLifted, _held)
end

-- Tokens as SHOWN: the server's count, less what the taps still awaiting their snapshot cost,
-- less the discovery rewards not yet collected (they land in the wallet on "Tap to Collect").
local function displayedEnergy(): number
    local _unconfirmed = 0
    for _, entry in ipairs(pendingSpawns) do
        if not entry.confirmed then
            _unconfirmed = _unconfirmed + (entry.cost or config.SPAWN_COST)
        end
    end
    if trackSeeded then
        _unconfirmed = _unconfirmed
            + config.DiscoveryTokensBetween(shownHighestTier + 1, manager.GetHighestTier())
    end
    return math.max(0, manager.GetTokens() - _unconfirmed)
end

-- The multipliers unlocked by what the player has been SHOWN discovering, so x2 arrives with
-- the item 8 reveal rather than a frame before it. The server's own count is never behind this,
-- so it always accepts what the button offers.
function spawn.unlocked(): {number}
    return config.UnlockedMultipliers(shownHighestTier)
end

-- The selected spawn multiplier, and what one generator tap costs at it.
function spawn.multiplier(): number
    return spawn.unlocked()[ui.multiplierIndex] or 1
end

function spawn.cost(): number
    return config.SpawnCost(spawn.multiplier())
end

-- Is there somewhere for one more tap to land? Counts empty open cells not already held by a
-- landing flight or claimed by a parked move, less the taps not yet placed by the server.
local function hasSpawnRoom(): boolean
    local _cells = manager.GetCells()
    local _free = 0
    for _, i in ipairs(config.EmptyOpenCells(_cells)) do
        local _claimedByMove = commit ~= nil and commit.kind == config.KIND_MOVE and commit.to == i
        if not spawnHolds[i] and not _claimedByMove then
            _free = _free + 1
        end
    end
    for _, entry in ipairs(pendingSpawns) do
        if not entry.target then
            _free = _free - 1
        end
    end
    return _free > 0
end

local function canSpawnNow(): boolean
    return manager.IsLoaded() and displayedEnergy() >= spawn.cost() and hasSpawnRoom()
end

-- The button always stays green; only the idle "tap me" pulse stops while a spawn is impossible.
local function refreshGenerator()
    generatorEnabled = canSpawnNow()
    if not generatorEnabled and not generatorBusy then
        anim.scale(_generatorButton, 1)
    end
end

-- Repaint the multiplier button and the generator's badge (the item one tap will dig up). A
-- multiplier the wallet no longer covers steps down to the largest one it does, so a tap never
-- asks for more than the player has.
function spawn.refreshMultiplier()
    -- A new event (or a QA reset) can take unlocks away again.
    ui.multiplierIndex = clamp(ui.multiplierIndex, 1, #spawn.unlocked())
    local _energy = displayedEnergy()
    while ui.multiplierIndex > 1 and _energy < spawn.cost() do
        ui.multiplierIndex = ui.multiplierIndex - 1
    end
    local _mult = spawn.multiplier()
    ui.multiplierLabel.text = "x" .. tostring(_mult)
    ui.generatorShellClass = paintTier(ui.generatorShell, config.SpawnTierFor(_mult),
        ui.generatorShellClass)
end

-- "MAX X<n>" pops off the button: the player is on (or only has) the highest multiplier.
function spawn.flashMax(mult: number)
    fx.floatText(fx.point(_fxLayer, ui.multiplierButton), "MAX X" .. tostring(mult), CLASSES.floatTextMax)
    playSound("HapticsLight")
end

-- The multiplier button: step to the next unlocked multiplier the wallet can afford, wrapping
-- to x1. With only x1 unlocked it just flashes "MAX X1".
function spawn.cycleMultiplier()
    markInteraction()
    if not isOpen or not manager.IsLoaded() or phase ~= PHASE_IDLE then
        return
    end
    spawn.hideBoost()
    local _unlocked = spawn.unlocked()
    local _max = _unlocked[#_unlocked] or 1
    if #_unlocked <= 1 then
        anim.pop(ui.multiplierLabel, 1.25, 0.3)
        spawn.flashMax(_max)
        return
    end
    local _next = (ui.multiplierIndex % #_unlocked) + 1
    local _nextMult = _unlocked[_next]
    if displayedEnergy() < config.SpawnCost(_nextMult) then
        if ui.multiplierIndex == 1 then
            -- Nothing above x1 is affordable: say why the tap did nothing.
            showToast("Need " .. tostring(config.SpawnCost(_nextMult)) .. " Merge Tokens for x"
                .. tostring(_nextMult))
            anim.shake(ui.multiplierButton, 5, 0.35)
            playSound("HapticsLight")
            return
        end
        _next = 1
    end
    ui.multiplierIndex = _next
    spawn.refreshMultiplier()
    anim.pop(ui.multiplierLabel, 1.4, 0.35)
    anim.pop(ui.generatorShell, 1.5, 0.4)
    playSound("ButtonClick")
    playSound("HapticsLight")
    if spawn.multiplier() == _max then
        spawn.flashMax(_max)
    end
end

-- "Higher Power Boost Available!": pops up over the multiplier button when a reveal that unlocks
-- a higher multiplier is collected, and stays until the button is next tapped. It is held while
-- the HUD is closed and shown on the next open.
function spawn.showBoost()
    ui.boostPending = true
    if not isOpen then
        return
    end
    anim.show(ui.boostBubble, true)
    anim.pop(ui.boostBubble, 0, 0.55)
    playSound("TilePop")
end

function spawn.hideBoost()
    ui.boostPending = false
    anim.show(ui.boostBubble, false)
end

-- The shown track just moved forward: announce a newly unlocked multiplier.
function spawn.checkUnlock()
    local _max = config.MaxMultiplier(shownHighestTier)
    if ui.knownMaxMult and _max > ui.knownMaxMult then
        spawn.showBoost()
    end
    ui.knownMaxMult = _max
    spawn.refreshMultiplier()
end

local function refreshEnergy(bump: boolean)
    _energyLabel.text = tostring(displayedEnergy())
    spawn.refreshMultiplier()
    if bump then
        anim.pop(_energyBolt, 1.5, 0.55)
        anim.pop(_energyLabel, 1.35, 0.45)
    end
end

local function setBrackets(index: number | nil)
    if bracketIndex and cellElements[bracketIndex] then
        cellElements[bracketIndex].brackets:RemoveFromClassList(CLASSES.bracketsVisible)
    end
    bracketIndex = index
    if index and cellElements[index] then
        local _brackets = cellElements[index].brackets
        _brackets:AddToClassList(CLASSES.bracketsVisible)
        anim.pop(_brackets, 1.6, 0.6)
    end
end

---------------- track ----------------
-- The top of the screen is the discovery track (one slot per item tier, the crown last) and,
-- above it, the "Find all items to win" panel holding the jackpot set. Both are drawn from
-- shownHighestTier, which trails the server while a reveal is pending, so a slot fills -- and
-- the jackpot cards get their checks -- when the player collects, not when the server decides.

-- Place the discovery fill and the tooltip. Needs real geometry, so it retries briefly while
-- the HUD is still being laid out (worldBound is empty on the frame it is first shown).
function track.layoutTrack(animate: boolean)
    local _lineBound = _trackLine.worldBound
    if not isOpen or _lineBound.width ~= _lineBound.width or _lineBound.width <= 0 then
        if isOpen and layoutRetries < 20 then
            layoutRetries = layoutRetries + 1
            Timer.After(0.05, function()
                track.layoutTrack(animate)
            end)
        end
        return
    end
    layoutRetries = 0

    -- Fill runs to the last found slot.
    local _anchor = slotElements[math.min(shownHighestTier, config.MAX_TIER)]
    if _anchor then
        local _target = clamp(fx.point(_trackLine, _anchor.root).x, 0, _lineBound.width)
        anim.cancel(fillTween)
        if animate then
            local _from = fillWidth
            fillTween = anim.run(0.5, anim.outCubic, function(t)
                fillWidth = lerp(_from, _target, t)
                _trackFill.style.width = Length.new(fillWidth)
            end)
        else
            fillWidth = _target
            _trackFill.style.width = Length.new(fillWidth)
        end
    end

    local _next = ui.tooltipTier and slotElements[ui.tooltipTier]
    if _next then
        local _x = fx.point(_trackPanel, _next.root).x - SIZES.tooltipWidth / 2
        _trackTooltip.style.left = Length.new(_x)
    end
end

-- Fill `container` with one icon + amount per reward: the track bubble's compact column chips,
-- or the reveal overlay's wider row chips ("+20").
function track.fillRewards(container: VisualElement, rewards: {any}, big: boolean)
    container:Clear()
    for _, reward in ipairs(rewards) do
        local _chip = VisualElement.new()
        _chip.pickingMode = PickingMode.Ignore
        _chip:AddToClassList(if big then CLASSES.revealChip else CLASSES.tooltipReward)
        local _icon = VisualElement.new()
        _icon.pickingMode = PickingMode.Ignore
        _icon:AddToClassList(if big then CLASSES.revealChipIcon else CLASSES.tooltipIcon)
        _icon:AddToClassList(rewardIconClass(reward))
        local _amount = Label.new()
        _amount.pickingMode = PickingMode.Ignore
        _amount:AddToClassList(if big then CLASSES.revealChipLabel else CLASSES.tooltipAmount)
        _amount.text = (if big then "+" else "") .. tostring(reward.amount)
        _chip:Add(_icon)
        _chip:Add(_amount)
        container:Add(_chip)
    end
end

-- The bubble advertises the NEXT tier that pays a discovery reward (tiers without one are
-- skipped), and only that one. Returns false when no reward is left on the track.
function track.paintTooltip(): boolean
    local _tier = config.NextRewardTier(shownHighestTier)
    ui.tooltipTier = _tier
    if not _tier then
        _tooltipRewards:Clear()
        return false
    end
    track.fillRewards(_tooltipRewards, config.DiscoveryRewards(_tier), false)
    return true
end

-- Repaint the discovery row and the jackpot panel from shownHighestTier. `animate` plays the
-- transitions a collect earns: the fill sweeps and, when the reward it pointed at was just
-- collected, the bubble hops to the next one. (When animating, the jackpot cards' checks are
-- left to collectWin, so they land with the prize.)
function track.refreshTrack(animate: boolean)
    _hintLabel.text = if shownHighestTier >= config.MAX_TIER then JACKPOT_HINT else DEFAULT_HINT
    for tier, slot in pairs(slotElements) do
        setClass(slot.root, CLASSES.slotFound, tier <= shownHighestTier)
        setClass(slot.root, CLASSES.slotNext, tier == shownHighestTier + 1)
        anim.scale(slot.art, 1)
    end

    if not animate then
        setClass(_prizePanel, CLASSES.prizeWon, shownHighestTier >= config.MAX_TIER)
    end

    local _oldTier = ui.tooltipTier
    local _newTier = config.NextRewardTier(shownHighestTier)
    if animate and _oldTier and _newTier ~= _oldTier then
        -- Hop: shrink away, repaint for (and jump to) the next reward, bounce back in. The
        -- repaint reads shownHighestTier again, in case another collect landed mid-hop.
        anim.run(0.16, anim.inCubic, function(t)
            anim.scale(_trackTooltip, 1 - t)
        end, function()
            local _hasTooltip = track.paintTooltip()
            anim.show(_trackTooltip, _hasTooltip)
            track.layoutTrack(true)
            if _hasTooltip then
                anim.run(0.5, anim.outBackStrong, function(t)
                    anim.scale(_trackTooltip, t)
                end, nil, 0.25)
            end
        end)
    else
        local _hasTooltip = track.paintTooltip()
        anim.show(_trackTooltip, _hasTooltip)
        anim.scale(_trackTooltip, 1)
        track.layoutTrack(animate)
    end
end

function track.buildTrack()
    _trackSlots:Clear()
    slotElements = {}
    for tier = 1, config.MAX_TIER do
        local _root = VisualElement.new()
        _root:AddToClassList(CLASSES.slot)
        _root.pickingMode = PickingMode.Ignore
        local _art = VisualElement.new()
        _art:AddToClassList(CLASSES.slotArt)
        _art.pickingMode = PickingMode.Ignore
        paintTier(_art, tier, nil)
        -- The flat silhouette shown until the tier is found. A child of the art so it scales
        -- with the next-slot pulse.
        local _sil = VisualElement.new()
        _sil:AddToClassList(CLASSES.slotSil)
        _sil:AddToClassList(CLASSES.silPrefix .. tostring(tier))
        _sil.pickingMode = PickingMode.Ignore
        _art:Add(_sil)
        if tier == config.MAX_TIER then
            _root:AddToClassList(CLASSES.slotCrown)
        end
        _root:Add(_art)
        _trackSlots:Add(_root)
        slotElements[tier] = { root = _root, art = _art }
    end
end

-- One card per jackpot item: the small cards in the "Find all items to win" panel, or the big
-- ones in the win popup. Returns the cards, in order, so the caller can animate them.
function track.buildPrizeCards(row: VisualElement, big: boolean): {VisualElement}
    row:Clear()
    local _cards = {}
    if not big then
        ui.prizeChecks = {}
    end
    for _, reward in ipairs(config.JACKPOT) do
        local _card = VisualElement.new()
        _card.pickingMode = PickingMode.Ignore
        local _icon = VisualElement.new()
        _icon.pickingMode = PickingMode.Ignore
        _icon:AddToClassList(rewardIconClass(reward))
        if big then
            _card:AddToClassList(CLASSES.winPrizeCard)
            local _face = VisualElement.new()
            _face:AddToClassList(CLASSES.winPrizeFace)
            _face.pickingMode = PickingMode.Ignore
            _icon:AddToClassList(CLASSES.winPrizeIcon)
            local _label = Label.new()
            _label.pickingMode = PickingMode.Ignore
            _label:AddToClassList(CLASSES.winPrizeLabel)
            _label.text = config.RewardText(reward)
            _face:Add(_icon)
            _face:Add(_label)
            _card:Add(_face)
        else
            -- The small card is the item's art alone, like the comp; its check shows once won.
            _card:AddToClassList(CLASSES.prizeCard)
            _icon:AddToClassList(CLASSES.prizeCardIcon)
            local _check = VisualElement.new()
            _check:AddToClassList(CLASSES.prizeCardCheck)
            _check.pickingMode = PickingMode.Ignore
            _card:Add(_icon)
            _card:Add(_check)
            table.insert(ui.prizeChecks, _check)
        end
        row:Add(_card)
        table.insert(_cards, _card)
    end
    return _cards
end

---------------- board animations ----------------
-- Merge / spawn pop: the item springs up from small with a slight twist.
local function popItem(index: number, from: number)
    local _ui = cellElements[index]
    if not _ui then
        return
    end
    anim.run(0.55, anim.outElastic, function(t)
        anim.scale(_ui.item, lerp(from, 1, t))
        anim.rotate(_ui.item, (1 - t) * -14)
    end, function()
        anim.scale(_ui.item, 1)
        anim.rotate(_ui.item, 0)
    end)
end

local function cellPoint(index: number, layer: VisualElement?): Vector2
    return fx.point(layer or _fxLayer, cellElements[index].root)
end

-- Cells that just broke open burst up out of the sand, rippling outward from the unlock.
local function playBreak(indices: {number})
    for k, index in ipairs(indices) do
        local _ui = cellElements[index]
        if _ui then
            local _delay = TIMING.breakStagger * k
            anim.run(0.5, anim.outBackStrong, function(t)
                anim.scale(_ui.tile, lerp(0.15, 1, t))
                anim.rotate(_ui.tile, (1 - t) * 25)
            end, function()
                anim.scale(_ui.tile, 1)
                anim.rotate(_ui.tile, 0)
            end, _delay)
            Timer.After(_delay, function()
                if isOpen and cellElements[index] then
                    fx.burst(cellPoint(index), 6, 30, CLASSES.sand, 7, 0.45, nil, true)
                    fx.burst(cellPoint(index), 4, 22, CLASSES.bubble, 6, 0.5, nil, true)
                end
            end)
        end
    end
    anim.shake(_boardFrame, 5, 0.35)
    playSound("CardFlip")
end

-- What a confirmed drop looks like once the server's board is painted.
local function playLanding(landed)
    local _ui = cellElements[landed.to]
    if not _ui then
        return
    end
    if landed.rejected then
        -- The server said no after all: the item is back at its origin; shake it.
        anim.wiggle(cellElements[landed.from].item, 16)
        return
    end
    lastLandingIndex = landed.to
    if landed.kind == config.KIND_MOVE then
        anim.squash(_ui.item)
        playSound("HapticsLight")
        return
    end

    local _point = cellPoint(landed.to)
    local _unlock = landed.kind == config.KIND_UNLOCK
    popItem(landed.to, 0.2)
    fx.flash(_point, if _unlock then 130 else 96)
    fx.ring(_point, if _unlock then 76 else 58, 0.45, _unlock)
    fx.burst(_point, if _unlock then 12 else 8, if _unlock then 60 else 44, CLASSES.star, 15, 0.55)
    if _unlock then
        -- The ghost tile flips over into water.
        anim.run(0.4, anim.outBack, function(t)
            anim.scaleXY(_ui.tile, math.abs(math.cos(t * math.pi)), 1)
        end, function()
            anim.scale(_ui.tile, 1)
        end)
    end
    playSound("TilePop")
    playSound("HapticsLight")
end

---------------- drag ----------------
function drag.clearHover()
    if dragState and dragState.hoverIndex then
        local _ui = cellElements[dragState.hoverIndex]
        anim.cancel(dragState.hoverTween)
        dragState.hoverTween = nil
        if _ui then
            _ui.highlight:RemoveFromClassList(CLASSES.highlightVisible)
            _ui.highlight:RemoveFromClassList(CLASSES.highlightMove)
            anim.scale(_ui.item, 1)
        end
        dragState.hoverIndex = nil
    end
end

-- Move the lifted element so it is centred on a panel-space point. Layout left/top, never
-- percent translate -- percent translate is not reflected in worldBound.
function drag.moveFlying(point: Vector2)
    local _local = _flightLayer:WorldToLocal(point)
    dragState.x = _local.x - SIZES.item / 2
    dragState.y = _local.y - SIZES.item / 2
    anim.place(dragState.element, dragState.x, dragState.y)
end

-- Tear the drag down. `unhideSource` is false when a move has been committed to the server:
-- the source item stays hidden until the confirming snapshot, so it does not flicker back.
function drag.teardownDrag(unhideSource: boolean)
    if not dragState then
        return
    end
    drag.clearHover()
    local _from = dragState.fromIndex
    dragState.element:RemoveFromHierarchy()
    dragState = nil
    if unhideSource then
        renderCell(_from)
    end
end

-- Spring the lifted item back to its origin cell, then tear the drag down. Used for every
-- illegal drop, which costs no network traffic at all.
function drag.snapBack()
    if not dragState then
        return
    end
    drag.clearHover()
    local _element = dragState.element
    local _startX = dragState.x
    local _startY = dragState.y
    local _endX = dragState.originX
    local _endY = dragState.originY
    local _tilt = dragState.tilt
    local _from = dragState.fromIndex

    -- Detach state now so a new drag can start even while this tween is still running. The
    -- source cell stays hidden (via this flag) until the item is back.
    dragState = nil
    local _ui = cellElements[_from]

    anim.run(TIMING.snapBack, anim.outBack, function(t)
        anim.place(_element, lerp(_startX, _endX, t), lerp(_startY, _endY, t))
        anim.scale(_element, lerp(LIFT_SCALE, 1, clamp(t, 0, 1)))
        anim.rotate(_element, _tilt * (1 - t))
    end, function()
        _element:RemoveFromHierarchy()
        renderCell(_from)
        if _ui then
            anim.squash(_ui.item)
        end
    end)
end

function drag.beginDrag(index: number, point: Vector2)
    local _cells = manager.GetCells()
    if not config.HasItem(_cells, index) or spawnHolds[index] then
        return
    end
    local _cell = config.CellAt(_cells, index)
    if not config.TierInfo(_cell.tier) then
        return
    end

    local _sourceUi = cellElements[index]
    local _sourceWorld = _sourceUi.item.worldBound
    -- Not laid out yet (HUD hidden, or first frame): a drag would have nowhere to snap back to.
    if _sourceWorld.width <= 0 then
        return
    end
    local _origin = itemOriginIn(_flightLayer, index)
    local _element = makeFlyingItem(_cell.tier)

    local _local = _flightLayer:WorldToLocal(point)
    dragState = {
        fromIndex = index,
        element = _element,
        hoverIndex = nil,
        hoverTween = nil,
        originX = _origin.x,
        originY = _origin.y,
        lastX = _local.x,
        tilt = 0,
    }

    renderCell(index)
    drag.moveFlying(point)
    anim.run(TIMING.lift, anim.outBack, function(t)
        anim.scale(_element, lerp(1, LIFT_SCALE, t))
    end)
    markInteraction()
    playSound("HapticsLight")
end

-- Park the dropped item on its target until the server answers.
function drag.commitDrop(from: number, to: number, kind: string)
    local _element = dragState.element
    local _startX = dragState.x
    local _startY = dragState.y
    local _tilt = dragState.tilt
    drag.clearHover()
    dragState = nil

    local _target = itemOriginIn(_flightLayer, to)
    local _endScale = if kind == config.KIND_MOVE then 1 else 0.8
    anim.run(TIMING.glide, anim.outCubic, function(t)
        anim.place(_element, lerp(_startX, _target.x, t), lerp(_startY, _target.y, t))
        anim.scale(_element, lerp(LIFT_SCALE, _endScale, t))
        anim.rotate(_element, _tilt * (1 - t))
    end)

    local _commit = {
        from = from,
        to = to,
        kind = kind,
        element = _element,
        rejected = false,
        timeout = nil,
    }
    -- Safety net: if the answer never comes, stop holding the source cell hostage.
    _commit.timeout = Timer.After(TIMING.commitTimeout, function()
        if commit == _commit then
            commit = nil
            _element:RemoveFromHierarchy()
            renderCell(from)
        end
    end)
    commit = _commit
    renderCell(from)
    manager.RequestMove(from, to)
end

-- Release the parked drop, if this snapshot is its answer. Returns it for playLanding.
function drag.settleCommit(isMoveAnswer: boolean, rejected: boolean)
    if not commit or not isMoveAnswer then
        return nil
    end
    local _settled = commit
    _settled.rejected = rejected
    commit = nil
    if _settled.timeout then
        _settled.timeout:Stop()
    end
    _settled.element:RemoveFromHierarchy()
    return _settled
end

function drag.dropCommitNow()
    if not commit then
        return
    end
    if commit.timeout then
        commit.timeout:Stop()
    end
    commit.element:RemoveFromHierarchy()
    commit = nil
end

---------------- spawn ----------------
-- Every live flight (pending or confirmed), so closing the HUD can tidy them all up.
spawn.flights = {}
spawn.lastTapAt = -1

function spawn.removeFlight(entry)
    for i, flight in ipairs(spawn.flights) do
        if flight == entry then
            table.remove(spawn.flights, i)
            return
        end
    end
end

function spawn.finishSpawn(entry)
    if entry.timeout then
        entry.timeout:Stop()
        entry.timeout = nil
    end
    anim.cancel(entry.tween)
    if entry.element then
        entry.element:RemoveFromHierarchy()
        entry.element = nil
    end
    spawn.removeFlight(entry)
    if not entry.target then
        return
    end
    spawnHolds[entry.target] = nil
    renderCell(entry.target)
    refreshGenerator()
    if not isOpen then
        return
    end
    local _ui = cellElements[entry.target]
    if _ui then
        anim.squash(_ui.item)
        local _point = cellPoint(entry.target)
        fx.burst(_point, 6, 30, CLASSES.bubble, 8, 0.45, nil, true)
        fx.ring(_point, 48, 0.35, false)
        if entry.luck and entry.luck ~= config.LUCK_NONE then
            fx.luck(_point, entry.luck)
            playSound("TilePop")
        end
    end
    playSound("ItemLand")
end

function spawn.cancelSpawn(entry)
    if entry.timeout then
        entry.timeout:Stop()
        entry.timeout = nil
    end
    anim.cancel(entry.tween)
    spawn.removeFlight(entry)
    if entry.target then
        spawnHolds[entry.target] = nil
        renderCell(entry.target)
    end
    local _element = entry.element
    entry.element = nil
    if _element then
        anim.run(0.2, Easing.linear, function(t)
            anim.fade(_element, 1 - t)
        end, function()
            _element:RemoveFromHierarchy()
        end)
    end
    refreshGenerator()
    refreshEnergy(false)
end

-- Where a flight is heading: its cell once the server has named one, else the board's middle.
function spawn.flightEnd(target: number?): Vector2
    if target and cellElements[target] then
        return itemOriginIn(_flightLayer, target)
    end
    local _center = fx.point(_flightLayer, _boardGrid)
    return Vector2.new(_center.x - SIZES.item / 2, _center.y - SIZES.item / 2)
end

-- Launch an item from the generator. The destination is re-read every frame, so the server
-- naming the cell mid-flight simply bends the arc onto it.
function spawn.launchSpawnFlight(entry, delay: number?)
    local _start = fx.point(_flightLayer, _generatorButton)
    local _element = makeFlyingItem(entry.tier)
    anim.place(_element, _start.x - SIZES.item / 2, _start.y - SIZES.item / 2)
    entry.element = _element
    table.insert(spawn.flights, entry)
    entry.tween = anim.run(TIMING.spawnFlight, Easing.linear, function(t)
        local _end = spawn.flightEnd(entry.target)
        local _e = anim.inOutSine(t)
        local _x = lerp(_start.x - SIZES.item / 2, _end.x, _e)
        local _y = lerp(_start.y - SIZES.item / 2, _end.y, _e) - math.sin(math.pi * t) * 90
        anim.place(_element, _x, _y)
        anim.scale(_element, lerp(0.35, 1, anim.outCubic(t)) * (1 + 0.25 * math.sin(math.pi * t)))
        anim.rotate(_element, (1 - t) * -300)
    end, function()
        entry.landed = true
        if entry.confirmed then
            spawn.finishSpawn(entry)
        end
    end, delay)
end

-- The server named this flight's cell. A flight still in the air bends onto it; one that has
-- already arrived (at the board's middle) glides the short way over. A flight whose real tier
-- differs from the one it launched as (a lucky roll) swaps its art for the real one.
function spawn.confirmSpawn(entry, index: number, luck: string, tier: number?)
    entry.target = index
    entry.confirmed = true
    entry.luck = luck
    spawnHolds[index] = true
    renderCell(index)
    if tier and tier ~= entry.tier and entry.element then
        local _launchInfo = config.TierInfo(entry.tier)
        paintTier(entry.element, tier, _launchInfo and _launchInfo.class)
        entry.tier = tier
    end
    if not entry.landed then
        return
    end
    local _element = entry.element
    if not isOpen or not _element then
        spawn.finishSpawn(entry)
        return
    end
    local _from = spawn.flightEnd(nil)
    local _to = itemOriginIn(_flightLayer, index)
    entry.tween = anim.run(TIMING.spawnGlide, anim.outCubic, function(t)
        anim.place(_element, lerp(_from.x, _to.x, t), lerp(_from.y, _to.y, t))
    end, function()
        spawn.finishSpawn(entry)
    end)
end

function spawn.pressGenerator()
    generatorBusy = true
    anim.run(0.3, Easing.linear, function(t)
        local _s = if t < 0.3 then lerp(1, 0.86, t / 0.3) else lerp(0.86, 1, anim.outBackStrong((t - 0.3) / 0.7))
        anim.scale(_generatorButton, _s)
    end, function()
        anim.scale(_generatorButton, 1)
        generatorBusy = false
    end)
end

-- `cost` is what the tap spent (held off the shown wallet until its snapshot lands) and `tier`
-- is what the flight launches as.
function spawn.newEntry(cost: number, tier: number)
    return {
        cost = cost,
        tier = tier,
        target = nil,
        element = nil,
        tween = nil,
        landed = false,
        confirmed = false,
        timeout = nil,
    }
end

function spawn.requestSpawn()
    markInteraction()
    if not isOpen or not manager.IsLoaded() or phase ~= PHASE_IDLE then
        return
    end
    if ambientTime - spawn.lastTapAt < TIMING.spawnTapGap then
        return
    end
    spawn.lastTapAt = ambientTime
    spawn.pressGenerator()

    -- Step the multiplier down first if the wallet no longer covers it, so the only refusal
    -- left is an empty wallet.
    spawn.refreshMultiplier()
    local _mult = spawn.multiplier()
    local _cost = config.SpawnCost(_mult)
    if displayedEnergy() < _cost then
        -- Nothing is sent: the server would only refuse it. While an offer is still for sale the
        -- tap opens the offers; once every one is bought it just says no.
        if manager.HasOffersLeft() then
            popup.enqueue({ kind = "topup" }, 0)
        else
            showToast(REJECT_MESSAGES.no_energy)
            anim.shake(_energyChip, 7, 0.4)
            anim.wiggle(_generatorButton, 6)
            playSound("HapticsLight")
        end
        return
    end
    if not hasSpawnRoom() then
        showToast(REJECT_MESSAGES.board_full)
        anim.shake(_boardFrame, 4, 0.35)
        playSound("HapticsLight")
        return
    end

    local _entry = spawn.newEntry(_cost, config.SpawnTierFor(_mult))
    table.insert(pendingSpawns, _entry)
    -- Safety net: an answer that never comes must not hold the flight or the tokens forever.
    _entry.timeout = Timer.After(TIMING.spawnTimeout, function()
        _entry.timeout = nil
        for i, pending in ipairs(pendingSpawns) do
            if pending == _entry then
                table.remove(pendingSpawns, i)
                spawn.cancelSpawn(_entry)
                return
            end
        end
    end)

    refreshEnergy(true)
    fx.floatText(fx.point(_fxLayer, _energyChip), "-" .. tostring(_cost), CLASSES.floatTextEnergy)
    spawn.launchSpawnFlight(_entry)
    refreshGenerator()
    playSound("ItemWhoosh")
    playSound("HapticsLight")
    manager.RequestSpawn(_mult)
end

-- The server's answer to one tap: `indices` holds the cell it landed on, `tier` what landed
-- there; `luck` is the Config.LUCK_* it rolled.
function spawn.onSpawned(indices, luck: string, tier: number?)
    local _first = indices and indices[1]
    if not _first then
        return
    end
    -- The oldest tap still waiting for a cell. Taps are answered in order.
    local _entry = nil
    for i, pending in ipairs(pendingSpawns) do
        if not pending.confirmed then
            _entry = table.remove(pendingSpawns, i)
            break
        end
    end
    if not _entry then
        -- A spawn we did not launch (e.g. the HUD reopened mid-flight): just pop the items once
        -- the board is painted.
        Timer.After(0, function()
            if isOpen then
                popItem(_first, 0.3)
                if luck ~= config.LUCK_NONE then
                    fx.luck(cellPoint(_first), luck)
                end
            end
        end)
        return
    end
    if _entry.timeout then
        _entry.timeout:Stop()
        _entry.timeout = nil
    end
    spawn.confirmSpawn(_entry, _first, luck, tier)
end

-- Closing the HUD mid-flight: every flight loses its visuals. Pending taps stay in the queue
-- (their snapshots are still coming) but are marked landed, so their answer settles at once.
function spawn.dropFlights()
    for i = #spawn.flights, 1, -1 do
        local _entry = spawn.flights[i]
        anim.cancel(_entry.tween)
        if _entry.element then
            _entry.element:RemoveFromHierarchy()
            _entry.element = nil
        end
        _entry.landed = true
        if _entry.confirmed then
            spawn.finishSpawn(_entry)
        end
    end
end

---------------- board ----------------
local function renderBoard()
    if not manager.IsLoaded() then
        _loadingLabel.style.display = DisplayStyle.Flex
        return
    end
    _loadingLabel.style.display = DisplayStyle.None

    for i = 1, config.CELL_COUNT do
        renderCell(i)
    end
    refreshEnergy(false)
    refreshGenerator()

    -- The track is seeded from the first snapshot. After that it only moves forward through a
    -- collect -- except for a NEW EVENT, which resets the server's value below what we show.
    local _actual = manager.GetHighestTier()
    if not trackSeeded or _actual < shownHighestTier then
        trackSeeded = true
        shownHighestTier = _actual
        track.refreshTrack(false)
        -- Unlocks already earned are not news.
        ui.knownMaxMult = config.MaxMultiplier(shownHighestTier)
        spawn.hideBoost()
        spawn.refreshMultiplier()
    end
    anim.show(ui.resetButton, manager.CanReset())
end

local function playHint()
    local _cells = manager.GetCells()
    local _seen = {}
    local _a, _b = nil, nil
    for i = 1, config.CELL_COUNT do
        local _cell = config.CellAt(_cells, i)
        if _cell.state == config.STATE_OPEN and _cell.tier and _cell.tier < config.MAX_TIER
            and not spawnHolds[i] then
            if _seen[_cell.tier] then
                _a, _b = _seen[_cell.tier], i
                break
            end
            _seen[_cell.tier] = i
        end
    end
    if not _a then
        -- No pair on the board: point at a ghost the player could satisfy instead.
        for i = 1, config.CELL_COUNT do
            local _cell = config.CellAt(_cells, i)
            if _cell.state == config.STATE_GHOST and _cell.tier and _seen[_cell.tier] then
                _a, _b = _seen[_cell.tier], i
                break
            end
        end
    end
    if _a and _b then
        anim.wiggle(cellElements[_a].item, 13)
        anim.wiggle(cellElements[_b].item, 13)
    end
end

-- One frame of every always-on flourish. A single ticker is cheaper than a dozen loop tweens,
-- and stops with one call.
local function ambientTick()
    ambientTime = ambientTime + Time.deltaTime
    local _t = ambientTime

    if not generatorBusy and generatorEnabled then
        anim.scale(_generatorButton, 1 + 0.035 * math.sin(_t * 4.2))
    end
    anim.move(_tooltipBob, 0, -3 * (1 + math.sin(_t * 3.4)))
    if ui.boostPending then
        anim.move(ui.boostBob, 0, -3 * (1 + math.sin(_t * 4)))
    end
    anim.rotate(_energyBolt, 7 * math.sin(_t * 2.2))

    local _hover = dragState and dragState.hoverIndex
    local _ghostScale = 0.9 + 0.06 * math.sin(_t * 2.6)
    for index in pairs(ghostIndices) do
        if index ~= _hover then
            anim.scale(cellElements[index].item, _ghostScale)
        end
    end

    if shownHighestTier < config.MAX_TIER then
        local _next = slotElements[shownHighestTier + 1]
        if _next then
            anim.scale(_next.art, 1 + 0.1 * math.sin(_t * 3.2))
        end
    end

    -- A light sweep across the prize row: 0.9s of movement every 3.2s.
    local _sweep = (_t % 3.2) / 0.9
    if _sweep <= 1 then
        anim.move(_prizeShine, lerp(-60, 320, _sweep), -12)
    end

    -- Let a held drag's tilt relax when the finger stops moving.
    if dragState then
        dragState.tilt = dragState.tilt * 0.86
        anim.rotate(dragState.element, dragState.tilt)
    end

    if phase == PHASE_IDLE and not dragState and not commit and manager.IsLoaded()
        and _t - lastInteraction > TIMING.hintIdle and _t >= nextHintAt then
        nextHintAt = _t + TIMING.hintRepeat
        playHint()
    end
end

-- Two stacked 7x7 layouts share the grid: the CELLS (hit targets, each holding its tile) and,
-- above them, an ITEM LAYER holding each cell's item, shadow, highlight and brackets. Items live
-- on their own layer so a pop or a throb that grows past its cell draws over the neighbouring
-- tiles instead of being clipped underneath the next tile in document order.
local function buildGrid()
    _boardGrid:Clear()
    cellElements = {}

    local _itemLayer = VisualElement.new()
    _itemLayer:AddToClassList(CLASSES.itemLayer)
    _itemLayer.pickingMode = PickingMode.Ignore
    local _itemRows = {}
    for _row = 1, config.ROWS do
        local _itemRow = VisualElement.new()
        _itemRow:AddToClassList(CLASSES.boardRow)
        _itemRow.pickingMode = PickingMode.Ignore
        _itemLayer:Add(_itemRow)
        _itemRows[_row] = _itemRow
    end

    for _row = 1, config.ROWS do
        local _rowElement = VisualElement.new()
        _rowElement:AddToClassList(CLASSES.boardRow)
        _rowElement.pickingMode = PickingMode.Ignore
        _boardGrid:Add(_rowElement)

        for _col = 1, config.COLS do
            local _index = config.CellIndex(_row, _col)

            local _cellElement = VisualElement.new()
            _cellElement:AddToClassList(CLASSES.cell)
            -- Dynamically created elements are not reliably tappable unless pickingMode is set
            -- explicitly in Lua, even with a USS rule.
            _cellElement.pickingMode = PickingMode.Position
            _rowElement:Add(_cellElement)

            local _tile = VisualElement.new()
            _tile:AddToClassList(CLASSES.tile)
            _tile.pickingMode = PickingMode.Ignore
            local _face = VisualElement.new()
            _face:AddToClassList(CLASSES.tileFace)
            _face.pickingMode = PickingMode.Ignore
            _tile:Add(_face)
            _cellElement:Add(_tile)

            local _slot = VisualElement.new()
            _slot:AddToClassList(CLASSES.itemSlot)
            _slot.pickingMode = PickingMode.Ignore
            _itemRows[_row]:Add(_slot)

            local _shadow = VisualElement.new()
            _shadow:AddToClassList(CLASSES.shadow)
            _shadow.pickingMode = PickingMode.Ignore
            _slot:Add(_shadow)

            local _itemElement = VisualElement.new()
            _itemElement:AddToClassList(CLASSES.item)
            _itemElement.pickingMode = PickingMode.Ignore
            _slot:Add(_itemElement)

            local _tierLabel = Label.new()
            _tierLabel:AddToClassList(CLASSES.tier)
            _tierLabel.pickingMode = PickingMode.Ignore
            _itemElement:Add(_tierLabel)

            -- Drop-target ring. An overlay child rather than a border on the cell, because
            -- borders draw outside the content box.
            local _highlight = VisualElement.new()
            _highlight:AddToClassList(CLASSES.highlight)
            _highlight.pickingMode = PickingMode.Ignore
            _slot:Add(_highlight)

            local _brackets = VisualElement.new()
            _brackets:AddToClassList(CLASSES.brackets)
            _brackets.pickingMode = PickingMode.Ignore
            for _, corner in ipairs(CLASSES.bracketCorners) do
                local _bracket = VisualElement.new()
                _bracket:AddToClassList(CLASSES.bracket)
                _bracket:AddToClassList(corner)
                _bracket.pickingMode = PickingMode.Ignore
                _brackets:Add(_bracket)
            end
            _slot:Add(_brackets)

            cellElements[_index] = {
                root = _cellElement,
                tile = _tile,
                item = _itemElement,
                tier = _tierLabel,
                shadow = _shadow,
                highlight = _highlight,
                brackets = _brackets,
                itemClass = nil,
                -- Cached so the checkerboard never has to be recomputed per repaint.
                isEven = (_row + _col) % 2 == 0,
            }

            -- Pickup identity comes from the event target, not from coordinates, so grabbing
            -- the right item never depends on the gesture coordinate space.
            _cellElement:RegisterCallback(PointerDownEvent, function()
                pressedIndex = _index
            end)
        end
    end

    -- Added last so it draws above every tile.
    _boardGrid:Add(_itemLayer)
end

---------------- reveal: NEW ITEM ----------------
-- Stars that twinkle around the revealed item for as long as it is on screen.
function popup.spawnRevealSparkles(layer: VisualElement)
    layer:Clear()
    for i = 1, REVEAL_SPARKLE_COUNT do
        local _angle = (i / REVEAL_SPARKLE_COUNT) * math.pi * 2 + math.random() * 0.5
        local _dist = 70 + math.random() * 30
        local _point = Vector2.new(SIZES.stage / 2 + math.cos(_angle) * _dist,
            SIZES.stage / 2 + math.sin(_angle) * _dist)
        local _size = 16 + math.random() * 14
        local _element = fx.particle(CLASSES.star, _point, _size, layer)
        local _speed = 0.7 + math.random() * 0.6
        local _offset = math.random()
        anim.loop(_speed, true, anim.inOutSine, function(t)
            local _v = (t + _offset) % 1
            anim.scale(_element, 0.15 + 0.85 * _v)
            anim.fade(_element, _v)
            anim.rotate(_element, 90 * _v)
        end, overlayLoops)
    end
end

-- Sunburst + glow behind a showcased item, spinning for as long as the overlay is up.
function popup.startShowcaseLoops(rays: VisualElement, raysBack: VisualElement?, glow: VisualElement)
    anim.loop(10, false, Easing.linear, function(t)
        anim.rotate(rays, 360 * t)
    end, overlayLoops)
    if raysBack then
        anim.loop(16, false, Easing.linear, function(t)
            anim.rotate(raysBack, -360 * t)
        end, overlayLoops)
    end
    anim.loop(1.2, true, anim.inOutSine, function(t)
        anim.scale(glow, lerp(0.92, 1.1, t))
    end, overlayLoops)
end

-- Paint the reveal overlay's art and copy for a discovered item. The line under the name says
-- what the item is good for: the jackpot for the top tier, its first-discovery reward, otherwise
-- how far the player still is from the jackpot. Returns false when there is nothing to show.
function popup.paintReveal(entry): boolean
    local _info = config.TierInfo(entry.tier)
    if not _info then
        return false
    end
    revealItemClass = paintTier(_revealItem, entry.tier, revealItemClass)
    _revealTitle.text = "NEW ITEM REVEALED!"
    _revealName.text = _info.label
    -- Everything this collect pays: this tier's rewards plus any a jump skipped past.
    local _rewards = config.DiscoveryRewardsBetween(shownHighestTier + 1, entry.tier)
    ui.revealRewardChips:Clear()
    anim.show(_revealRewardIcon, true)
    if entry.tier >= config.MAX_TIER then
        setRewardIcon(_revealRewardIcon, CLASSES.rewardCrown)
        _revealRewardLabel.text = "Jackpot unlocked!"
    elseif #_rewards > 0 then
        anim.show(_revealRewardIcon, false)
        _revealRewardLabel.text = "Reward:"
        track.fillRewards(ui.revealRewardChips, _rewards, true)
    else
        local _left = config.MAX_TIER - entry.tier
        setRewardIcon(_revealRewardIcon, CLASSES.rewardCrown)
        _revealRewardLabel.text = tostring(_left) .. " more to the Jackpot!"
    end
    anim.show(_revealReward, true)
    return true
end

function popup.showReveal(entry)
    if not popup.paintReveal(entry) then
        phase = PHASE_IDLE
        popup.startNextReveal()
        return
    end
    revealEntry = entry
    phase = PHASE_REVEAL_IN

    anim.fade(_revealContent, 1)
    anim.fade(_revealItem, 1)
    anim.show(_revealOverlay, true)
    _revealOverlay:BringToFront()
    _topLayer:BringToFront()

    playSound("RewardsCardFlip")
    playSound("HapticsLight")

    anim.run(0.3, Easing.linear, function(t)
        anim.fade(_revealScrim, t)
    end)
    anim.run(0.6, anim.outBack, function(t)
        anim.move(_revealBanner, 0, -180 * (1 - t))
        anim.fade(_revealBanner, clamp(t * 3, 0, 1))
    end, nil, 0.05)
    anim.run(0.45, anim.outBackStrong, function(t)
        anim.scale(_revealTitle, t)
        anim.fade(_revealTitle, clamp(t * 2, 0, 1))
    end, nil, 0.25)
    anim.run(0.6, anim.outCubic, function(t)
        anim.scale(_revealRays, lerp(0.3, 1.45, t))
        anim.scale(_revealRaysBack, lerp(0.3, 1.7, t))
        anim.fade(_revealRays, t)
        anim.fade(_revealGlow, t)
    end, nil, 0.3)
    anim.run(0.8, anim.outElastic, function(t)
        anim.scale(_revealItem, t)
        anim.rotate(_revealItem, (1 - t) * -30)
    end, nil, 0.4)
    Timer.After(0.45, function()
        if phase == PHASE_REVEAL_IN and revealEntry == entry then
            local _center = Vector2.new(SIZES.stage / 2, SIZES.stage / 2)
            fx.ring(_center, 150, 0.55, true, _revealSparkles)
            fx.burst(_center, 12, 110, CLASSES.star, 20, 0.7, _revealSparkles)
            playSound("TilePop")
        end
    end)
    anim.enter(_revealName, 0, 24, 0.4, 0.7)
    anim.enter(_revealReward, 0, 24, 0.4, 0.8)
    anim.run(0.35, Easing.linear, function(t)
        anim.fade(_revealTap, t)
    end, nil, 1.0)

    popup.spawnRevealSparkles(_revealSparkles)
    popup.startShowcaseLoops(_revealRays, _revealRaysBack, _revealGlow)
    anim.loop(1.5, true, anim.inOutSine, function(t)
        anim.move(_revealItem, 0, lerp(-6, 6, t))
    end, overlayLoops)
    Timer.After(1.0, function()
        if phase ~= PHASE_REVEAL_IN or revealEntry ~= entry then
            return
        end
        anim.loop(0.8, true, anim.inOutSine, function(t)
            anim.scale(_revealTap, lerp(0.96, 1.06, t))
        end, overlayLoops)
    end)

    Timer.After(TIMING.revealArm, function()
        if phase == PHASE_REVEAL_IN and revealEntry == entry then
            phase = PHASE_REVEAL_READY
        end
    end)
end

function popup.closeOverlay(overlay: VisualElement, scrim: VisualElement, content: VisualElement,
                            duration: number, onDone)
    anim.run(duration, Easing.linear, function(t)
        anim.fade(scrim, 1 - t)
        anim.fade(content, clamp(1 - t * 1.6, 0, 1))
    end, function()
        anim.show(overlay, false)
        if onDone then
            onDone()
        end
    end)
end

-- Back to the board, then the next queued moment (if any).
function popup.finishMoment()
    phase = PHASE_IDLE
    markInteraction()
    popup.startNextReveal()
end

---------------- win: every item found, the jackpot ----------------
function popup.showWin()
    phase = PHASE_WIN
    local _cards = track.buildPrizeCards(_winPrizeRow, true)
    _winTitle.text = "You found every item!"
    anim.fade(_winContent, 1)
    anim.show(_winOverlay, true)
    _winOverlay:BringToFront()
    _topLayer:BringToFront()

    playSound("CurrencyBurst")
    playSound("HapticsLight")

    anim.run(0.3, Easing.linear, function(t)
        anim.fade(_winScrim, t)
    end)
    anim.run(0.6, anim.outBack, function(t)
        anim.move(_winBanner, 0, -180 * (1 - t))
        anim.fade(_winBanner, clamp(t * 3, 0, 1))
    end, nil, 0.05)
    anim.run(0.6, anim.outCubic, function(t)
        anim.scale(_winRays, lerp(0.3, 1.5, t))
        anim.fade(_winRays, t)
        anim.fade(_winGlow, t)
    end, nil, 0.2)
    anim.run(0.9, anim.outElastic, function(t)
        anim.scale(_winCrown, t)
        anim.rotate(_winCrown, (1 - t) * 40)
    end, nil, 0.3)
    anim.enter(_winTitle, 0, 24, 0.45, 0.55)

    for i, card in ipairs(_cards) do
        anim.pop(card, 0, 0.6, 0.75 + (i - 1) * 0.12)
    end
    anim.pop(_winButton, 0, 0.6, 1.0 + #_cards * 0.12)

    fx.confetti(_confettiLayer, CONFETTI_COUNT)
    Timer.After(1.2, function()
        if phase == PHASE_WIN then
            fx.confetti(_confettiLayer, CONFETTI_COUNT / 2)
        end
    end)
    popup.startShowcaseLoops(_winRays, nil, _winGlow)
    anim.loop(1.6, true, anim.inOutSine, function(t)
        anim.move(_winCrown, 0, lerp(-5, 5, t))
    end, overlayLoops)
    Timer.After(TIMING.winArm + 0.6, function()
        if phase == PHASE_WIN then
            anim.loop(0.7, true, anim.inOutSine, function(t)
                anim.scale(_winButton, lerp(1, 1.06, t))
            end, overlayLoops)
        end
    end)
end

function popup.collectWin()
    if phase ~= PHASE_WIN then
        return
    end
    phase = PHASE_COLLECTING
    anim.stopAll(overlayLoops)
    playSound("HapticsLight")
    popup.closeOverlay(_winOverlay, _winScrim, _winContent, 0.3, function()
        _confettiLayer:Clear()
        popup.finishMoment()
    end)

    -- Check off every jackpot card, one after another, then shower the panel with the prize.
    setClass(_prizePanel, CLASSES.prizeWon, true)
    for i, check in ipairs(ui.prizeChecks) do
        anim.run(0.45, anim.outBackStrong, function(t)
            anim.scale(check, lerp(2.2, 1, t))
            anim.fade(check, clamp(t * 2, 0, 1))
        end, nil, 0.2 + (i - 1) * 0.12)
    end
    Timer.After(0.2 + #ui.prizeChecks * 0.12 + 0.2, function()
        if not isOpen then
            return
        end
        anim.shake(_prizePanel, 5, 0.3)
        local _point = fx.point(_fxLayer, _prizePanel)
        fx.ring(_point, 150, 0.5, true)
        fx.burst(_point, 12, 120, CLASSES.star, 18, 0.6)
        fx.coins(_point, 12, CLASSES.chest)
        fx.floatText(_point, "JACKPOT!")
        playSound("CoinLandGold")
    end)
end

-- Show a collected discovery's rewards landing: tokens shower the wallet (whose count was held
-- back until now, see displayedEnergy), everything else floats up off the item's track slot.
function popup.payDiscovery(rewards: {any}, slot: VisualElement?)
    if #rewards == 0 or not isOpen then
        refreshEnergy(false)
        return
    end
    local _slotPoint = if slot then fx.point(_fxLayer, slot) else fx.point(_fxLayer, _trackPanel)
    local _lift = 0
    for _, reward in ipairs(rewards) do
        if reward.kind == config.REWARD_TOKENS then
            local _chip = fx.point(_fxLayer, _energyChip)
            fx.coins(_chip, 6, CLASSES.token)
            fx.floatText(_chip, "+" .. tostring(reward.amount), CLASSES.floatTextEnergy)
        else
            -- Stacked so two float-ups off the same slot do not overprint.
            local _point = Vector2.new(_slotPoint.x, _slotPoint.y + 30 + _lift)
            fx.coins(_point, 5, rewardParticleClass(reward))
            fx.floatText(_point, "+" .. config.RewardText(reward))
            _lift = _lift + 26
        end
    end
    refreshEnergy(true)
    playSound("CoinLandGold")
end

-- The collected item has reached its slot: fill it, advance the track, and pay out the fx. The
-- top tier then plays the jackpot screen, if this snapshot won it.
function popup.onCollected(entry)
    -- Read before the track advances: shownHighestTier is what bounds the uncollected rewards.
    local _rewards = config.DiscoveryRewardsBetween(shownHighestTier + 1, entry.tier)
    shownHighestTier = math.max(shownHighestTier, entry.tier)
    track.refreshTrack(true)
    spawn.checkUnlock()
    setBrackets(nil)
    local _slot = slotElements[entry.tier]
    local _target: VisualElement = _slot and _slot.root

    if _target then
        anim.run(0.65, anim.outElastic, function(t)
            anim.scale(_target, lerp(1.6, 1, t))
        end, function()
            anim.scale(_target, 1)
        end)
        local _point = fx.point(_topLayer, _target)
        fx.flash(_point, 90, _topLayer)
        fx.ring(_point, 64, 0.5, true, _topLayer)
        fx.burst(_point, 10, 60, CLASSES.star, 15, 0.6, _topLayer)
    end
    playSound("TilePop")
    playSound("HapticsLight")
    popup.payDiscovery(_rewards, _target)

    if entry.tier >= config.MAX_TIER and not ui.jackpotPending then
        -- The top tier without a win screen (the jackpot was already paid): just check it off.
        setClass(_prizePanel, CLASSES.prizeWon, true)
    end
    if entry.tier >= config.MAX_TIER and ui.jackpotPending then
        ui.jackpotPending = false
        Timer.After(0.8, function()
            if isOpen then
                popup.showWin()
            else
                phase = PHASE_IDLE
            end
        end)
    else
        Timer.After(0.35, popup.finishMoment)
    end
end

-- "Tap to Collect": the item flies out of the popup and into its slot on the track.
function popup.collectReveal()
    if phase ~= PHASE_REVEAL_READY or not revealEntry then
        return
    end
    phase = PHASE_COLLECTING
    local _entry = revealEntry
    revealEntry = nil
    anim.stopAll(overlayLoops)

    local _start = fx.point(_topLayer, _revealItem)
    local _flyer = VisualElement.new()
    _flyer:AddToClassList(CLASSES.particle)
    _flyer.pickingMode = PickingMode.Ignore
    _flyer.style.width = Length.new(SIZES.revealItem)
    _flyer.style.height = Length.new(SIZES.revealItem)
    paintTier(_flyer, _entry.tier, nil)
    local _slot = slotElements[_entry.tier]
    local _destination: VisualElement = _slot and _slot.art
    anim.place(_flyer, _start.x - SIZES.revealItem / 2, _start.y - SIZES.revealItem / 2)
    _topLayer:Add(_flyer)
    anim.fade(_revealItem, 0)

    popup.closeOverlay(_revealOverlay, _revealScrim, _revealContent, 0.35, nil)
    anim.run(0.2, Easing.linear, function(t)
        anim.fade(_revealTap, 1 - t)
    end)
    playSound("ItemWhoosh")
    playSound("HapticsLight")

    local _endScale = SIZES.slotArt / SIZES.revealItem
    local _lastTrail = 0
    anim.run(TIMING.collectFlight, Easing.linear, function(t)
        local _end = if _destination then fx.point(_topLayer, _destination) else _start
        local _e = anim.inOutSine(t)
        local _arc = math.sin(math.pi * t)
        local _x = lerp(_start.x, _end.x, _e) + _arc * 70
        local _y = lerp(_start.y, _end.y, _e) - _arc * 30
        anim.move(_flyer, _x - _start.x, _y - _start.y)
        anim.scale(_flyer, lerp(1, _endScale, _e) * (1 + 0.2 * _arc))
        anim.rotate(_flyer, _arc * 25)
        if t - _lastTrail > 0.05 and t < 0.95 then
            _lastTrail = t
            fx.trail(Vector2.new(_x, _y), _topLayer)
        end
    end, function()
        _flyer:RemoveFromHierarchy()
        popup.onCollected(_entry)
    end)
end

---------------- top-up: out of Merge Tokens ----------------
-- One card per config.TOPUP_OFFERS entry: the pack, its amount and its Buy button. Built once;
-- popup.refreshOffers repaints which ones are already bought.
function popup.buildOffers()
    ui.topupOffers:Clear()
    ui.offerCards = {}
    for k, offer in ipairs(config.TOPUP_OFFERS) do
        local _card = VisualElement.new()
        _card:AddToClassList(CLASSES.offer)
        _card.pickingMode = PickingMode.Ignore
        local _icon = VisualElement.new()
        _icon:AddToClassList(CLASSES.offerIcon)
        _icon.pickingMode = PickingMode.Ignore
        local _amount = Label.new()
        _amount:AddToClassList(CLASSES.offerAmount)
        _amount.pickingMode = PickingMode.Ignore
        _amount.text = "+" .. tostring(offer.amount)
        -- Dynamically created elements are only reliably tappable with pickingMode set in Lua.
        local _buy = VisualElement.new()
        _buy:AddToClassList(CLASSES.ctaButton)
        _buy:AddToClassList(CLASSES.offerBuy)
        _buy.pickingMode = PickingMode.Position
        local _face = VisualElement.new()
        _face:AddToClassList(CLASSES.ctaFace)
        _face.pickingMode = PickingMode.Ignore
        local _price = Label.new()
        _price:AddToClassList(CLASSES.ctaLabel)
        _price:AddToClassList(CLASSES.offerPrice)
        _price.pickingMode = PickingMode.Ignore
        _face:Add(_price)
        _buy:Add(_face)
        _card:Add(_icon)
        _card:Add(_amount)
        _card:Add(_buy)
        _buy:RegisterPressCallback(function()
            popup.buyOffer(k)
        end)
        ui.topupOffers:Add(_card)
        ui.offerCards[k] = { root = _card, buy = _buy, price = _price }
    end
end

function popup.refreshOffers()
    for k, card in pairs(ui.offerCards) do
        local _bought = manager.IsOfferBought(k)
        setClass(card.root, CLASSES.offerBought, _bought)
        card.price.text = if _bought then "Bought" else config.TOPUP_OFFERS[k].priceLabel
    end
end

function popup.buyOffer(offerIndex: number)
    if phase ~= PHASE_TOPUP or manager.IsOfferBought(offerIndex) then
        return
    end
    anim.pop(ui.offerCards[offerIndex].buy, 0.8, 0.35)
    manager.RequestTopUp(offerIndex)
    popup.closeTopUp()
end

function popup.showTopUp()
    phase = PHASE_TOPUP
    popup.refreshOffers()
    anim.fade(ui.topupContent, 1)
    anim.show(ui.topupOverlay, true)
    ui.topupOverlay:BringToFront()
    playSound("ButtonClick")
    anim.run(0.2, Easing.linear, function(t)
        anim.fade(ui.topupScrim, t)
    end)
    anim.run(0.45, anim.outBackStrong, function(t)
        anim.scale(ui.topupPanel, lerp(0.6, 1, t))
        anim.fade(ui.topupPanel, clamp(t * 2, 0, 1))
    end)
    for k, card in pairs(ui.offerCards) do
        if not manager.IsOfferBought(k) then
            local _buy = card.buy
            anim.loop(0.8, true, anim.inOutSine, function(t)
                anim.scale(_buy, lerp(1, 1.05, t))
            end, overlayLoops)
        end
    end
end

function popup.closeTopUp()
    if phase ~= PHASE_TOPUP then
        return
    end
    phase = PHASE_COLLECTING
    anim.stopAll(overlayLoops)
    anim.run(0.18, anim.inCubic, function(t)
        anim.scale(ui.topupPanel, lerp(1, 0.85, t))
    end)
    popup.closeOverlay(ui.topupOverlay, ui.topupScrim, ui.topupContent, 0.18, popup.finishMoment)
end

---------------- queue ----------------
function popup.startNextReveal()
    if phase ~= PHASE_IDLE or #revealQueue == 0 or not isOpen then
        return
    end
    -- A drag in progress cannot survive the popup taking the screen.
    if dragState then
        drag.snapBack()
    end
    local _entry = table.remove(revealQueue, 1)
    if _entry.kind == "topup" then
        popup.showTopUp()
    else
        popup.showReveal(_entry)
    end
end

-- Queue a moment and start it after `delay` (lets a merge pop play first).
function popup.enqueue(entry, delay: number)
    table.insert(revealQueue, entry)
    Timer.After(delay, function()
        popup.startNextReveal()
    end)
end

---------------- info ----------------
function popup.openInfo()
    if phase ~= PHASE_IDLE then
        return
    end
    phase = PHASE_INFO
    if dragState then
        drag.snapBack()
    end
    anim.fade(_infoContent, 1)
    anim.show(_infoOverlay, true)
    _infoOverlay:BringToFront()
    playSound("ButtonClick")
    anim.run(0.2, Easing.linear, function(t)
        anim.fade(_infoScrim, t)
    end)
    anim.run(0.45, anim.outBackStrong, function(t)
        anim.scale(_infoPanel, lerp(0.6, 1, t))
        anim.fade(_infoPanel, clamp(t * 2, 0, 1))
    end)
end

function popup.closeInfo()
    if phase ~= PHASE_INFO then
        return
    end
    phase = PHASE_COLLECTING
    anim.run(0.18, anim.inCubic, function(t)
        anim.scale(_infoPanel, lerp(1, 0.85, t))
    end)
    popup.closeOverlay(_infoOverlay, _infoScrim, _infoContent, 0.18, popup.finishMoment)
end

-- Tear down every overlay instantly (used when the HUD closes mid-sequence). The displays jump
-- to the truth: the rewards were paid by the server regardless of the animation.
function popup.abortOverlays()
    anim.stopAll(overlayLoops)
    revealQueue = {}
    revealEntry = nil
    ui.jackpotPending = false
    anim.show(_revealOverlay, false)
    anim.show(_winOverlay, false)
    anim.show(_infoOverlay, false)
    anim.show(ui.topupOverlay, false)
    _confettiLayer:Clear()
    _topLayer:Clear()
    _revealSparkles:Clear()
    phase = PHASE_IDLE
    setBrackets(nil)
    if trackSeeded then
        shownHighestTier = manager.GetHighestTier()
        track.refreshTrack(false)
        spawn.checkUnlock()
        -- Discovery tokens held back for an uncollected reveal are shown now.
        refreshEnergy(false)
    end
end

---------------- reset (QA) ----------------
function popup.disarmReset()
    ui.resetArmed = false
    if ui.resetTimer then
        ui.resetTimer:Stop()
        ui.resetTimer = nil
    end
    setClass(ui.resetButton, CLASSES.resetArmed, false)
    ui.resetLabel.text = "RESET"
end

-- First tap arms the button; a second tap within TIMING.resetArm asks the server to wipe.
function popup.pressReset()
    if not isOpen or not manager.CanReset() then
        return
    end
    anim.pop(ui.resetButton, 0.8, 0.35)
    if not ui.resetArmed then
        ui.resetArmed = true
        setClass(ui.resetButton, CLASSES.resetArmed, true)
        ui.resetLabel.text = "SURE?"
        playSound("HapticsLight")
        ui.resetTimer = Timer.After(TIMING.resetArm, function()
            ui.resetTimer = nil
            popup.disarmReset()
        end)
        return
    end
    popup.disarmReset()
    manager.RequestReset()
end

-- The server wiped the island. Runs BEFORE the fresh board is painted: drop every drag, flight
-- and overlay, and forget what the tracks were showing so they re-seed from zero.
function popup.onReset()
    drag.teardownDrag(false)
    drag.dropCommitNow()
    for _, entry in ipairs(pendingSpawns) do
        if entry.timeout then
            entry.timeout:Stop()
            entry.timeout = nil
        end
    end
    pendingSpawns = {}
    spawn.dropFlights()
    for i = #spawn.flights, 1, -1 do
        spawn.cancelSpawn(spawn.flights[i])
    end
    spawnHolds = {}
    popup.abortOverlays()
    trackSeeded = false
    shownHighestTier = 1
    if not isOpen then
        return
    end
    -- Once the fresh board is painted: the start area springs up out of the sand.
    Timer.After(0, function()
        if not isOpen then
            return
        end
        local _cells = manager.GetCells()
        local _open = {}
        for i = 1, config.CELL_COUNT do
            if config.CellAt(_cells, i).state == config.STATE_OPEN then
                table.insert(_open, i)
            end
        end
        playBreak(_open)
        showToast("Fresh island!")
        refreshEnergy(true)
    end)
end

-- Staggered entrance: panels drop in from the top, the board springs up, the controls rise.
function popup.playEntrance()
    anim.run(0.25, Easing.linear, function(t)
        anim.fade(_hudRoot, t)
    end)
    anim.enter(_prizePanel, 0, -50, 0.5, 0.05)
    anim.enter(_trackPanel, 0, -50, 0.5, 0.12)
    anim.run(0.5, anim.outBack, function(t)
        anim.scale(_boardFrame, lerp(0.85, 1, t))
        anim.fade(_boardFrame, clamp(t * 2.5, 0, 1))
    end, nil, 0.16)
    anim.enter(_bottomBar, 0, 24, 0.5, 0.24)
    anim.enter(ui.hintArea or _hintLabel, 0, 20, 0.4, 0.34)
    anim.pop(_infoButton, 0, 0.5, 0.3)
    anim.pop(_closeButton, 0, 0.5, 0.36)
end

-- Look up the elements added after the original build into `ui` (by UXML name, minus the
-- leading underscore). A missing name is reported once, here, rather than as a nil error later.
local function bindExtraUi()
    local _names = {
        "hintArea",
        "topupOverlay", "topupScrim", "topupContent", "topupPanel",
        "topupOffers", "topupLater", "boostBubble", "boostBob",
        "resetButton", "resetLabel",
        "multiplierButton", "multiplierLabel", "generatorShell",
        "revealRewardChips",
    }
    for _, name in ipairs(_names) do
        local _element = _hudRoot:Q("_" .. name)
        if not _element then
            print("[MergeIslandHUD] ERROR: MergeIslandHUD.uxml has no element named _" .. name)
        end
        ui[name] = _element
    end
end

-- Entry point. Building the button here keeps Merge Island drop-in: nothing else in the scene
-- needs to know it exists.
--
-- It is styled INLINE rather than from MergeIslandHUD.uss: the button is hosted in Highrise's
-- world-top bar, a different part of the UI tree that this HUD's stylesheet does not reach, so
-- a class-only element there has no size and renders as nothing. The icon is the tier-1 sprite;
-- without one it falls back to an "M" glyph, which a Label draws even completely unstyled.
local function buildWorldTopButton()
    worldTopButton = VisualElement.new()
    worldTopButton:AddToClassList(CLASSES.worldTopButton)
    worldTopButton.pickingMode = PickingMode.Position
    worldTopButton.style.width = Length.new(38)
    worldTopButton.style.height = Length.new(38)
    worldTopButton.style.backgroundColor = StyleColor.new(Color.new(0.97, 0.66, 0.16, 1))
    fx.round(worldTopButton, 12)

    local _texture = tierTexture(1)
    if _texture then
        local _icon = VisualElement.new()
        _icon:AddToClassList(CLASSES.worldTopIcon)
        _icon.pickingMode = PickingMode.Ignore
        _icon.style.width = Length.new(28)
        _icon.style.height = Length.new(28)
        -- Centred by margins (38 = 5 + 28 + 5) so it needs nothing but plain lengths.
        _icon.style.marginLeft = Length.new(5)
        _icon.style.marginTop = Length.new(5)
        _icon.style.backgroundImage = _texture
        worldTopButton:Add(_icon)
    else
        local _glyph = Label.new()
        _glyph.text = "M"
        _glyph.pickingMode = PickingMode.Ignore
        _glyph.style.marginLeft = Length.new(12)
        _glyph.style.marginTop = Length.new(8)
        worldTopButton:Add(_glyph)
    end

    worldTopButton:RegisterPressCallback(function() Toggle() end)
    UI:AddWorldTopButton(worldTopButton, WORLD_TOP_BUTTON_INDEX)
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function Show()
    if isOpen then
        return
    end
    isOpen = true
    openGeneration = openGeneration + 1
    _hudRoot.style.display = DisplayStyle.Flex
    -- Full-screen HUD: the world controls underneath would be unreachable anyway, and leaving
    -- them up lets a drag double as a camera pan.
    UI:HideWorldControls()
    renderBoard()
    track.refreshTrack(false)
    if ui.boostPending then
        spawn.showBoost()
    end
    popup.playEntrance()
    playSound("ButtonClick")
    anim.loop(1, false, Easing.linear, function()
        ambientTick()
    end, loopTweens)
    markInteraction()
    manager.ReportSession(true)
end

function Hide()
    if not isOpen then
        return
    end
    isOpen = false
    openGeneration = openGeneration + 1
    local _generation = openGeneration

    -- A drag, a parked drop or a spawn flight in flight must not survive the HUD closing, or
    -- their elements would be orphaned in a hidden layer. Pending spawns keep their entries
    -- (their snapshots are still coming) but lose their visuals.
    drag.teardownDrag(true)
    drag.dropCommitNow()
    spawn.dropFlights()
    popup.disarmReset()
    popup.abortOverlays()
    hideToast()
    anim.stopAll(loopTweens)
    _fxLayer:Clear()
    renderBoard()
    UI:ShowWorldControls()
    manager.ReportSession(false)

    anim.run(TIMING.hudOut, Easing.linear, function(t)
        anim.fade(_hudRoot, 1 - t)
    end, function()
        if _generation == openGeneration and not isOpen then
            _hudRoot.style.display = DisplayStyle.None
        end
    end)
end

function Toggle()
    if isOpen then
        Hide()
    else
        Show()
    end
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    -- The entry point goes in FIRST, so nothing that fails later in Start can take away the only
    -- way into the game.
    buildWorldTopButton()

    bindExtraUi()
    buildGrid()
    track.buildTrack()
    track.buildPrizeCards(_prizeRow, false)
    popup.buildOffers()
    anim.show(ui.boostBubble, false)
    -- Tier-1 art for the "faded twin" row of the how-to-play panel comes from the USS; nothing
    -- else in the panel is dynamic.

    -- Start closed; the world-top button is the way in.
    isOpen = false
    _hudRoot.style.display = DisplayStyle.None
    _hintLabel.text = DEFAULT_HINT

    -- Overlays cover the close button, so it can only be pressed from the board itself.
    _closeButton:RegisterPressCallback(function()
        Hide()
    end)
    _infoButton:RegisterPressCallback(function()
        anim.pop(_infoButton, 0.7, 0.4)
        popup.openInfo()
    end)
    _infoOk:RegisterPressCallback(function()
        popup.closeInfo()
    end)
    _infoOverlay:RegisterPressCallback(function()
        popup.closeInfo()
    end)
    _revealOverlay:RegisterPressCallback(function()
        popup.collectReveal()
    end)
    _winButton:RegisterPressCallback(function()
        popup.collectWin()
    end)
    _generatorButton:RegisterPressCallback(function()
        spawn.requestSpawn()
    end)
    ui.multiplierButton:RegisterPressCallback(function()
        spawn.cycleMultiplier()
    end)
    ui.topupLater:RegisterPressCallback(function()
        popup.closeTopUp()
    end)
    ui.resetButton:RegisterPressCallback(function()
        popup.pressReset()
    end)
    -- Tapping the wallet while it is empty brings the offers back on demand, while any is left.
    _energyChip:RegisterPressCallback(function()
        if phase == PHASE_IDLE and isOpen and displayedEnergy() < config.SPAWN_COST
            and manager.HasOffersLeft() then
            popup.enqueue({ kind = "topup" }, 0)
        end
    end)

    -- Clear the pending pickup on the way DOWN the hierarchy, so a cell's own handler (which
    -- runs later, on the way back up) is the only thing that can set it. A press that misses
    -- every cell therefore leaves it nil instead of leaving the previous cell armed.
    _boardGrid:RegisterCallback(PointerDownEvent, function()
        pressedIndex = nil
        markInteraction()
    end, TrickleDown.TrickleDown)

    -- Drag lives on the grid container, so the gesture keeps reporting after the finger leaves
    -- the cell it started on.
    _boardGrid:RegisterGesture(DragGesture.new(DRAG_MIN_DISTANCE))

    _boardGrid:RegisterCallback(DragGestureBegan, function(evt)
        if not isOpen or not manager.IsLoaded() or phase ~= PHASE_IDLE then
            return
        end
        -- A drag already in flight, a drop still awaiting its answer, or a press that never
        -- landed on a cell is not a pickup.
        if dragState or commit or not pressedIndex then
            return
        end
        -- Consume it, so one press can only ever start one drag.
        local _index = pressedIndex
        pressedIndex = nil
        drag.beginDrag(_index, gesturePoint(evt))
    end)

    _boardGrid:RegisterCallback(DragGestureChanged, function(evt)
        if not dragState then
            return
        end
        local _point = gesturePoint(evt)
        drag.moveFlying(_point)
        markInteraction()

        -- Swing the item toward the direction of travel.
        local _localX = _flightLayer:WorldToLocal(_point).x
        local _dx = _localX - dragState.lastX
        dragState.lastX = _localX
        dragState.tilt = clamp(lerp(dragState.tilt, _dx * TILT_PER_PX, 0.35), -TILT_MAX, TILT_MAX)
        anim.rotate(dragState.element, dragState.tilt)

        local _over = cellIndexAt(_point)
        if _over == dragState.hoverIndex then
            return
        end
        drag.clearHover()
        -- Highlight only a drop that would actually be legal, using the same rules the server
        -- will apply. A merge target also throbs, so it is obvious what will combine.
        if _over and manager.CanDrop(dragState.fromIndex, _over) then
            local _ui = cellElements[_over]
            if _ui then
                local _kind = manager.ResolveLocalDrop(dragState.fromIndex, _over).kind
                setClass(_ui.highlight, CLASSES.highlightMove, _kind == config.KIND_MOVE)
                _ui.highlight:AddToClassList(CLASSES.highlightVisible)
                dragState.hoverIndex = _over
                if _kind ~= config.KIND_MOVE then
                    local _item = _ui.item
                    -- Its own throwaway bucket: clearHover cancels it, and so does any
                    -- teardown, so it never needs Hide's sweep.
                    dragState.hoverTween = anim.loop(0.32, true, anim.inOutSine, function(t)
                        anim.scale(_item, lerp(1, 1.14, t))
                    end, {})
                end
                playSound("HapticsSlider")
            end
        end
    end)

    _boardGrid:RegisterCallback(DragGestureEnded, function(evt)
        if not dragState then
            return
        end
        -- A cancelled gesture (interrupted by the system, another pointer, etc.) is not a drop.
        if evt.cancelled then
            drag.snapBack()
            return
        end
        local _from = dragState.fromIndex
        local _over = cellIndexAt(gesturePoint(evt))

        if not _over or not manager.CanDrop(_from, _over) then
            -- Illegal: resolved entirely locally, no network traffic. A mismatched item says
            -- "no" with a shake.
            drag.snapBack()
            if _over and _over ~= _from then
                local _reason = manager.ResolveLocalDrop(_from, _over).reason
                if _reason == config.REJECT_MISMATCH or _reason == config.REJECT_MAX_TIER then
                    anim.wiggle(cellElements[_over].item, 14)
                    playSound("HapticsLight")
                end
            end
            return
        end

        drag.commitDrop(_from, _over, manager.ResolveLocalDrop(_from, _over).kind)
    end)

    -- Spawn and reject listeners fire BEFORE the repaint for the same snapshot, so pending
    -- spawns are settled against the new board.
    manager.OnReset(function()
        popup.onReset()
    end)

    manager.OnSpawned(function(indices, luck, tier)
        spawn.onSpawned(indices, luck or config.LUCK_NONE, tier)
    end)

    manager.OnRejected(function(reason)
        if reason == config.REJECT_NO_ENERGY or reason == config.REJECT_BOARD_FULL then
            -- The oldest tap still waiting for a cell was refused.
            for i, pending in ipairs(pendingSpawns) do
                if not pending.confirmed then
                    table.remove(pendingSpawns, i)
                    spawn.cancelSpawn(pending)
                    break
                end
            end
        end
        local _message = REJECT_MESSAGES[reason]
        if _message and isOpen then
            showToast(_message)
        end
    end)

    manager.OnBoardChanged(function(isMoveAnswer, rejected)
        -- Release the parked drop BEFORE painting, so its source cell unhides into the new
        -- board, then animate the result on top of the authoritative repaint.
        local _settled = drag.settleCommit(isMoveAnswer, rejected)
        renderBoard()
        if _settled and isOpen then
            playLanding(_settled)
        end
    end)

    manager.OnUnlocked(function(_index, openedIndices)
        if isOpen then
            playBreak(openedIndices)
        end
    end)

    manager.OnDiscovered(function(tier)
        if not isOpen then
            shownHighestTier = math.max(shownHighestTier, tier)
            track.refreshTrack(false)
            spawn.checkUnlock()
            refreshEnergy(false)
            return
        end
        setBrackets(lastLandingIndex)
        popup.enqueue({ kind = "item", tier = tier }, TIMING.revealDelay)
    end)

    -- Fires right after the top tier's OnDiscovered: its reveal plays the win screen once it is
    -- collected. With the HUD closed there is nothing to celebrate; the panel just shows won.
    manager.OnJackpot(function()
        if isOpen then
            ui.jackpotPending = true
        end
    end)

    manager.OnTopUp(function(toppedUp)
        if toppedUp > 0 and isOpen then
            local _chip = fx.point(_fxLayer, _energyChip)
            fx.coins(_chip, 8, CLASSES.token)
            fx.floatText(_chip, "+" .. tostring(toppedUp), CLASSES.floatTextEnergy)
            refreshEnergy(true)
            playSound("CoinLandGold")
        end
    end)

    renderBoard()
end
