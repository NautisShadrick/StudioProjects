--!Type(Client)

-- DropFourTableTap -- in-world entry point for one Drop Four table.
--
-- Lives on the DropFourTable prefab next to a TapHandler and a Collider (moveTo enabled so
-- the avatar walks over first). Opens that table's window via DropFourRegistry, so the
-- prefab can be dropped anywhere; the only per-placement setting is tableId, which must be
-- within the manager's tableCount.
--
-- It also drives the floating "Indicator" billboard above the table, swapping its surface
-- texture to show this table's seated count. Read-only client-side display -- the server
-- stays the single source of truth, and because every client runs this and reacts to the
-- replicated seats.Changed, all players see the same count.

--------------------------------
------ SERIALIZED FIELDS  ------
--------------------------------
--!Tooltip("Which table this is. Must be between 1 and the manager's tableCount.")
--!SerializeField
local tableId : number = 1
--!Tooltip("The DropFourManager (same instance the lobby and launcher reference); supplies this table's seat count. It is a ClientAndServer script, not a Module, so it must be referenced here rather than required.")
--!SerializeField
local manager : DropFourManager = nil
--!Tooltip("Optional indicator art for 1 seated player. Leave empty to keep the prefab's default texture.")
--!SerializeField
local icon1Player : Texture2D = nil
--!Tooltip("Optional indicator art for 2 seated players.")
--!SerializeField
local icon2Players : Texture2D = nil
--!Tooltip("Optional indicator art for 3 seated players.")
--!SerializeField
local icon3Players : Texture2D = nil
--!Tooltip("Optional indicator art for 4 seated players.")
--!SerializeField
local icon4Players : Texture2D = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
-- The Indicator's renderer is built at runtime AND the seats value replicates
-- asynchronously, and TableValue.Changed never fires for a value that existed before we
-- subscribed. So re-paint a few times over the first couple of seconds to catch both the
-- renderer and the initial replicated count -- this is what makes a player entering a world
-- with already-occupied tables see the right count. Ongoing changes come from seats.Changed.
local REFRESH_SCHEDULE = { 0.25, 0.5, 1.0, 2.0 }

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local tableRegistry = require("DropFourRegistry")

--------------------------------
------     LOCAL STATE    ------
--------------------------------
-- The indicator's per-renderer material CLONE (reading renderer.material clones a
-- per-instance copy, so tables sharing one material stay independent) and its original Base
-- Map, restored when the table empties.
local indicatorMat = nil
local defaultTex = nil
-- Skip a redundant SetTexture when the count has not changed.
local lastCount: number | nil = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
-- The built-in Indicator builds its renderer at runtime, so resolve lazily. Uses the base
-- Renderer type so it catches MeshRenderer, SpriteRenderer, and friends. Returns true once
-- the material clone is cached.
local function resolveIndicatorMaterial(): boolean
    if indicatorMat then
        return true
    end
    local _indT = self.gameObject.transform:Find("Indicator")
    if not _indT then
        return false
    end
    local _renderer = _indT.gameObject:GetComponentInChildren(Renderer)
    if not _renderer then
        return false
    end
    indicatorMat = _renderer.material
    defaultTex = indicatorMat:GetTexture("_BaseMap")
    return true
end

-- Paint the indicator for a seated count. 0 (an empty table) restores the default art.
-- _BaseMap is the URP surface map; _MainTex is set too so the swap holds regardless of which
-- slot the shader samples.
local function applyIcon(count: number)
    if not resolveIndicatorMaterial() then
        return
    end
    if lastCount == count then
        return
    end
    lastCount = count
    local _tex = defaultTex
    if count >= 4 then
        _tex = icon4Players
    elseif count == 3 then
        _tex = icon3Players
    elseif count == 2 then
        _tex = icon2Players
    elseif count == 1 then
        _tex = icon1Player
    end
    -- Unassigned count art falls back to the prefab's own texture rather than blanking it.
    if _tex == nil then
        _tex = defaultTex
    end
    indicatorMat:SetTexture("_BaseMap", _tex)
    indicatorMat:SetTexture("_MainTex", _tex)
end

local function refresh()
    local _t = manager and manager.tables[tableId]
    local _count = _t and #_t.seats.value or 0
    applyIcon(_count)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Awake()
    local _tapHandler = self.gameObject:GetComponent(TapHandler)
    if not _tapHandler then
        print("[DropFourTableTap] No TapHandler on '" .. self.gameObject.name
            .. "'; this table cannot be tapped")
        return
    end
    _tapHandler.Tapped:Connect(function()
        tableRegistry.OpenTable(tableId)
    end)

    if manager == nil then
        print("[DropFourTableTap] manager is not assigned on '" .. self.gameObject.name
            .. "'; the seat-count indicator will not update")
        return
    end

    if not manager.IsTableActive(tableId) then
        print("[DropFourTableTap] tableId " .. tostring(tableId) .. " on '" .. self.gameObject.name
            .. "' is above the manager's tableCount; this table will accept no players."
            .. " Raise tableCount on DropFourManager or lower this tableId.")
    end

    -- Live seat-count indicator. Every seat change for this table replicates to all clients,
    -- so the billboard stays in sync everywhere.
    local _t = manager.tables[tableId]
    if not _t then
        print("[DropFourTableTap] tableId " .. tostring(tableId)
            .. " is outside the manager's table pool")
        return
    end
    _t.seats.Changed:Connect(function(newSeats)
        applyIcon(newSeats and #newSeats or 0)
    end)

    refresh()
    for _, delay in ipairs(REFRESH_SCHEDULE) do
        Timer.After(delay, function() refresh() end)
    end
end
