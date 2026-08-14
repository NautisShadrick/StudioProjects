--!Type(Client)

--------------------------------
------     REQUIRES       ------
--------------------------------
local Environment = require("EnvironmentManager")

--------------------------------
------  SERIALIZED FIELDS  ------
--------------------------------
--!SerializeField
local lineLength: number = 10
--!SerializeField
local dropShadow: Transform = nil
--!SerializeField
local kiteRenderer: Transform = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
local GRAVITY: number = 6
local PLAYER_MOVE_LIFT: number = 32
local DRAG: number = 0.98
local LINE_PULL_STRENGTH: number = 15
local WIND_RESPONSIVENESS: number = 1.5

--------------------------------
------     LOCAL STATE    ------
--------------------------------
local kiteVelocity: Vector3 = Vector3.zero
local lastPlayerPos: Vector3 = Vector3.zero
local playerVelocity: Vector3 = Vector3.zero
local isInitialized: boolean = false
local lineRenderer: LineRenderer = nil
local assignedPlayer: Player = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function getPlayer(): Player
    return assignedPlayer or client.localPlayer
end

local function getLineLength(): number
    return lineLength
end

local function getPlayerPosition(): Vector3
    local _player = getPlayer()
    if not _player or not _player.character then
        return Vector3.zero
    end
    return _player.character.transform.position
end

local function getAnchorPoint(): Vector3
    local _playerPos = getPlayerPosition()
    return _playerPos + Vector3.new(0, 1.5, 0)
end

local function constrainToLineLength(kitePos: Vector3, anchorPos: Vector3, currentLineLength: number): Vector3
    local _toKite = kitePos - anchorPos
    local _distance = _toKite.magnitude

    if _distance > currentLineLength then
        local _direction = _toKite.normalized
        return anchorPos + _direction * currentLineLength
    end

    return kitePos
end

local function isPlayerMoving(): boolean
    local _player = getPlayer()
    if not _player or not _player.character then
        return false
    end
    return _player.character.isMoving
end

local function getPlayerHandPosition(): Vector3
    local _player = getPlayer()
    if not _player or not _player.character then
        return Vector3.zero
    end
    local _charPos = _player.character.transform.position
    return _charPos + Vector3.new(0.3, 1.2, 0)
end

local LINE_SEGMENTS: number = 20

local function updateLineRenderer(kitePos: Vector3, currentLineLength: number)
    if not lineRenderer then
        return
    end
    local _handPos = getPlayerHandPosition()
    local _directDistance = Vector3.Distance(_handPos, kitePos)
    local _slack = currentLineLength - _directDistance

    if _slack <= 0 then
        -- Line is taut - straight line
        for i = 0, LINE_SEGMENTS do
            local _t = i / LINE_SEGMENTS
            local _pos = Vector3.Lerp(_handPos, kitePos, _t)
            lineRenderer:SetPosition(i, _pos)
        end
    else
        -- Line has slack - make it droop
        local _sagAmount = _slack * 0.5

        for i = 0, LINE_SEGMENTS do
            local _t = i / LINE_SEGMENTS
            local _basePos = Vector3.Lerp(_handPos, kitePos, _t)

            -- Parabola sag: maximum at middle, zero at ends
            local _sagFactor = 4 * _t * (1 - _t)
            local _sag = _sagAmount * _sagFactor

            -- Also add some extra droop near the ground for realism
            local _groundSag = _slack * _sagFactor * 0.3

            local _pos = _basePos - Vector3.new(0, _sag + _groundSag, 0)

            -- Don't let line go below ground
            if _pos.y < 0.05 then
                _pos = Vector3.new(_pos.x, 0.05, _pos.z)
            end

            lineRenderer:SetPosition(i, _pos)
        end
    end
end

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function SetPlayer(player: Player)
    assignedPlayer = player
    isInitialized = false
end

function SetLineLength(length: number)
    lineLength = length
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Awake()
    lineRenderer = self.gameObject:GetComponent(LineRenderer)
    if lineRenderer then
        lineRenderer.positionCount = LINE_SEGMENTS + 1
        lineRenderer.useWorldSpace = true
        lineRenderer.startWidth = 0.02
        lineRenderer.endWidth = 0.02
    end

    local _player = getPlayer()
    if _player and _player.character then
        lastPlayerPos = getPlayerPosition()
        local _anchor = getAnchorPoint()
        local _lineLen = getLineLength()
        self.transform.position = _anchor + Vector3.new(0, _lineLen * 0.5, _lineLen * 0.5)
        isInitialized = true
        updateLineRenderer(self.transform.position, _lineLen)
    end
end

function self:Update()
    local _player = getPlayer()
    if not _player or not _player.character then
        return
    end

    if not isInitialized then
        lastPlayerPos = getPlayerPosition()
        local _anchor = getAnchorPoint()
        self.transform.position = _anchor + Vector3.new(0, 2, 0)
        isInitialized = true
        return
    end

    local _dt = Time.deltaTime
    local _lineLen = getLineLength()
    local _currentPlayerPos = getPlayerPosition()
    local _anchorPoint = getAnchorPoint()
    local _kitePos = self.transform.position

    -- Calculate player velocity
    playerVelocity = (_currentPlayerPos - lastPlayerPos) / _dt
    lastPlayerPos = _currentPlayerPos

    -- Direction from kite to player (anchor)
    local _toAnchor = _anchorPoint - _kitePos
    local _distanceToAnchor = _toAnchor.magnitude
    local _dirToAnchor = _toAnchor.normalized

    -- Check player speed
    local _playerSpeed = playerVelocity.magnitude
    local _isMoving = isPlayerMoving() and _playerSpeed > 0.5

    -- Get current wind from environment (amplified for more movement)
    local _windForce = Environment.GetCurrentWind() * WIND_RESPONSIVENESS

    -- Apply gravity
    local _gravityForce = Vector3.new(0, -GRAVITY, 0)

    -- Calculate line tension and lift
    local _linePullForce = Vector3.zero
    local _liftForce = Vector3.zero

    -- How taut is the line (0 = slack, 1 = fully taut)
    local _tension = math.max(0, (_distanceToAnchor - _lineLen * 0.7) / (_lineLen * 0.3))
    _tension = math.min(1, _tension)

    if _distanceToAnchor >= _lineLen * 0.95 then
        -- Line is taut - pull kite toward player
        _linePullForce = _dirToAnchor * LINE_PULL_STRENGTH
    end

    -- Apply lift when line has tension and player is moving
    if _isMoving and _tension > 0 then
        -- Lift scales with tension and player speed
        local _speedFactor = math.min(1, _playerSpeed / 5)
        _liftForce = Vector3.new(0, PLAYER_MOVE_LIFT * _tension * _speedFactor, 0)
    end

    -- Combine forces
    local _totalForce = _windForce + _gravityForce + _liftForce + _linePullForce

    -- Update velocity
    kiteVelocity = kiteVelocity + _totalForce * _dt
    kiteVelocity = kiteVelocity * DRAG

    -- Update position
    local _newPos = _kitePos + kiteVelocity * _dt

    -- Constrain to line length (hard constraint)
    _newPos = constrainToLineLength(_newPos, _anchorPoint, _lineLen)

    -- Apply tension from line constraint - remove outward velocity when taut
    local _toKite = _newPos - _anchorPoint
    local _distance = _toKite.magnitude
    if _distance >= _lineLen * 0.99 then
        local _lineDir = _toKite.normalized
        local _velocityAlongLine = Vector3.Dot(kiteVelocity, _lineDir)
        if _velocityAlongLine > 0 then
            kiteVelocity = kiteVelocity - _lineDir * _velocityAlongLine
        end
    end

    -- Keep kite above ground
    if _newPos.y < 0.5 then
        _newPos = Vector3.new(_newPos.x, 0.5, _newPos.z)
        kiteVelocity = Vector3.new(kiteVelocity.x, 0, kiteVelocity.z)
    end

    self.transform.position = _newPos

    -- Tilt kite renderer on Z based on horizontal movement relative to camera
    if kiteRenderer then
        local _cam = Camera.main
        if _cam then
            local _camRight = _cam.transform.right
            local _horizontalSpeed = Vector3.Dot(kiteVelocity, _camRight)
            local _tiltAngle = math.max(-45, math.min(45, _horizontalSpeed * -5))
            local _currentRot = kiteRenderer.localEulerAngles
            kiteRenderer.localEulerAngles = Vector3.new(_currentRot.x, _currentRot.y, _tiltAngle)
        end
    end

    -- Update the line renderer
    updateLineRenderer(_newPos, _lineLen)

    -- Update drop shadow position
    if dropShadow then
        local _hit, _hitInfo = Physics.Raycast(_newPos, Vector3.new(0, -1, 0), 100)
        if _hit then
            dropShadow.position = _hitInfo.point + Vector3.new(0, 0.05, 0)
        end
    end
end
