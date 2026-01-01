--!Type(Module)

local _cachedLocalPlayerPosition: Vector3 = Vector3.zero
local _cachedCameraRotation: Quaternion = Quaternion.identity

local _landAreaMask = 0
if client then
    _landAreaMask = bit32.bor(bit32.lshift(1, NavMesh.GetAreaFromName("Walkable")))
end
LandAreaMask = _landAreaMask

function GetLocalPlayerPosition(): Vector3
    return _cachedLocalPlayerPosition
end

function GetCachedCameraRotation(): Quaternion
    return _cachedCameraRotation
end

local function CacheValues()
    if client.localPlayer and client.localPlayer.character then
        _cachedLocalPlayerPosition = client.localPlayer.character.transform.position
    else
        _cachedLocalPlayerPosition = Vector3.zero
    end
end

function self:ClientUpdate()
    CacheValues()
end