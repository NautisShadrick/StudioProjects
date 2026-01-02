--!Type(Client)

local playerTracker = require("playerTracker")
local KitePartsManager = require("KitePartsManager")

--!SerializeField
local canvas: Transform = nil
--!SerializeField
local basePartRatio: number = 0.172 -- 50px / 290px from UI (adjust to tune)

local spawnedParts: {GameObject} = {}
local kiteParts: {KitePart} = {}
local partSpriteMap: {[string]: Sprite} = {}
local owner: Player = nil
local buildConnection = nil

local function hexToColor(hex: string): Color
    local _hex = hex:gsub("#", "")
    local _r = tonumber(_hex:sub(1, 2), 16) / 255
    local _g = tonumber(_hex:sub(3, 4), 16) / 255
    local _b = tonumber(_hex:sub(5, 6), 16) / 255
    return Color.new(_r, _g, _b, 1)
end

local function buildSpriteMap()
    kiteParts = KitePartsManager.GetKiteParts()
    for _, part in ipairs(kiteParts) do
        local _partID = part.GetPartId()
        local _sprite = part.GetSprite()
        partSpriteMap[_partID] = _sprite
    end
end

local function clearParts()
    for _, part in ipairs(spawnedParts) do
        if part then
            GameObject.Destroy(part)
        end
    end
    spawnedParts = {}
end

local function buildKite(buildData)
    clearParts()

    if not canvas then
        print("KiteConstructor: No canvas assigned")
        return
    end

    if not buildData or #buildData == 0 then
        return
    end

    local _canvasScale = canvas.localScale
    local _canvasWidth = _canvasScale.x
    local _canvasHeight = _canvasScale.y

    for i, partData in ipairs(buildData) do
        local _partID = partData.partID
        local _x = partData.x
        local _y = partData.y
        local _colorHex = partData.color or "#FFFFFF"
        local _rotation = partData.rotation or 0
        local _flip = partData.flip or 1
        local _scale = partData.scale or 1

        local _sprite = partSpriteMap[_partID]
        if not _sprite then
            print("KiteConstructor: No sprite found for partID: " .. _partID)
        end

        local _partObj = GameObject.new("KitePart_" .. i .. "_" .. _partID)
        _partObj.transform:SetParent(canvas, false)

        local _spriteRenderer = _partObj:AddComponent(SpriteRenderer)
        if _sprite then
            _spriteRenderer.sprite = _sprite
        end

        local _color = hexToColor(_colorHex)
        _spriteRenderer.color = _color

        local _localX = (_x - 0.5) * _canvasWidth
        local _localY = (_y - 0.5) * _canvasHeight
        _partObj.transform.localPosition = Vector3.new(_localX, _localY, -0.01 * i)

        local _baseSize = basePartRatio * math.min(_canvasWidth, _canvasHeight)
        _partObj.transform.localScale = Vector3.new(_baseSize * _flip * _scale, _baseSize * _scale, 1)
        _partObj.transform.localRotation = Quaternion.Euler(0, 0, -_rotation)

        table.insert(spawnedParts, _partObj)
    end

    print("KiteConstructor: Built kite with " .. #spawnedParts .. " parts")
end

function SetPlayer(player: Player)
    owner = player

    if buildConnection then
        buildConnection:Disconnect()
        buildConnection = nil
    end

    local _playerInfo = playerTracker.players[owner]
    if _playerInfo and _playerInfo.myBuild then
        buildKite(_playerInfo.myBuild.value)

        buildConnection = _playerInfo.myBuild.Changed:Connect(function(newBuild, oldBuild)
            buildKite(newBuild)
        end)
    end
end

function GetPlayer(): Player
    return owner
end

function self:Start()
    buildSpriteMap()
end
