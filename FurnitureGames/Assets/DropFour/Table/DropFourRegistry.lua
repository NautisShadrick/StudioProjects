--!Type(Module)

-- DropFourRegistry -- client-side router from in-world Drop Four tables to the launcher UI,
-- plus a small world-controls suppressor.
--
-- The single DropFourLauncherUI registers its handlers on Start; each placed
-- DropFourTable prefab calls OpenTable(tableId) on tap. Placed tables need zero scene
-- wiring beyond their tableId.
--
-- Seat exclusivity across tables is enforced by DropFourManager on the server (it owns
-- every table's seats); this module is client-only glue.
--
-- NOTE: this module must be attached to a GameObject to be require-able. It ships on the
-- Registry child of DropFourGame.prefab, which is what keeps the package drop-in.

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- The launcher's open function, called with the tapped tableId
local _openLauncher = nil
-- The launcher's minimize/leave handlers, called by the lobby and board chrome. They live
-- in the launcher (it owns isOpen + the anti-flash suppressor); the views are separate UI
-- components and cannot require the launcher directly.
local _minimizeFn = nil
local _leaveFn = nil
-- The launcher's quit-confirm opener, called by the in-game Quit button (the destructive
-- in-game quit confirms first; the lobby's Leave Queue uses Leave directly).
local _quitConfirmFn = nil

-- Ref-counted world-controls suppression. Several bits of UI (the rules drawer, the
-- quit-confirm popup) want the world controls hidden while they are up, and whichever one
-- closes last must be the one that restores them -- a plain hide/show pair would let the
-- first closer un-hide the controls under the second. Keyed by a stable string id so
-- Suppress/Release are both idempotent.
local _suppressors: {[string]: boolean} = {}
local _controlsHidden: boolean = false

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function applyWorldControlsState()
    local _shouldHide = false
    for _, _ in pairs(_suppressors) do
        _shouldHide = true
        break
    end
    if _shouldHide == _controlsHidden then
        return
    end
    _controlsHidden = _shouldHide
    if _shouldHide then
        UI:HideWorldControls()
    else
        UI:ShowWorldControls()
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function RegisterLauncher(openFn)
    if not openFn then
        print("[DropFourRegistry] RegisterLauncher called with nil")
        return
    end
    _openLauncher = openFn
end

-- The launcher registers its window controls so the lobby panel's chevron, its Leave Queue
-- button, and the board's in-game chrome can all drive them.
function RegisterControls(minimizeFn, leaveFn, quitConfirmFn)
    _minimizeFn = minimizeFn
    _leaveFn = leaveFn
    _quitConfirmFn = quitConfirmFn
end

function OpenTable(tableId: number)
    if not _openLauncher then
        print("[DropFourRegistry] No launcher registered; cannot open Drop Four")
        return
    end
    _openLauncher(tableId)
end

function Minimize()
    if _minimizeFn then
        _minimizeFn()
    end
end

function Leave()
    if _leaveFn then
        _leaveFn()
    end
end

-- In-game Quit: route to the launcher's quit-confirm popup (destructive, so it confirms).
function RequestQuit()
    if _quitConfirmFn then
        _quitConfirmFn()
    end
end

-- Hide the world controls while `id` is active.
function SuppressWorldControls(id: string)
    if not id or id == "" then
        print("[DropFourRegistry] SuppressWorldControls: ignoring empty id")
        return
    end
    if _suppressors[id] then
        return
    end
    _suppressors[id] = true
    applyWorldControlsState()
end

-- Stop suppressing for `id`. No-op if it was not active, so callers can release freely
-- from cleanup paths (OnDisable, popup close) without tracking whether they suppressed.
function ReleaseWorldControls(id: string)
    if not id or id == "" then
        return
    end
    if not _suppressors[id] then
        return
    end
    _suppressors[id] = nil
    applyWorldControlsState()
end
