--!Type(Client)

--------------------------------
------     REQUIRES       ------
--------------------------------
local Environment = require("EnvironmentManager")

--------------------------------
------  SERIALIZED FIELDS  ------
--------------------------------
--!SerializeField
local headTransform: Transform = nil

--------------------------------
------     CONSTANTS      ------
--------------------------------
local SEGMENT_COUNT: number = 16
local SEGMENT_LENGTH: number = 0.25
local TAIL_GRAVITY: number = 4
local SPRING_STRENGTH: number = 80
local DAMPING: number = 0.9
local WIND_INFLUENCE: number = 0.6
local WAVE_SPEED: number = 8
local WAVE_AMPLITUDE: number = 0.15
local WAVE_FREQUENCY: number = 3

--------------------------------
------     LOCAL STATE    ------
--------------------------------
local lineRenderer: LineRenderer = nil
local segmentPositions = {}
local segmentVelocities = {}
local isInitialized: boolean = false
local waveTime: number = 0
local wavePhaseOffset: number = 0

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Start()
    -- Random phase offset so each tail waves differently
    wavePhaseOffset = math.random() * math.pi * 2

    lineRenderer = self.gameObject:GetComponent(LineRenderer)
    if not lineRenderer then
        return
    end

    lineRenderer.positionCount = SEGMENT_COUNT
    lineRenderer.useWorldSpace = true
    lineRenderer.startWidth = 0.1
    lineRenderer.endWidth =   0.1

    if headTransform then
        local _headPos = headTransform.position
        for i = 1, SEGMENT_COUNT do
            segmentPositions[i] = _headPos - Vector3.up * SEGMENT_LENGTH * (i - 1)
            segmentVelocities[i] = Vector3.zero
        end
        isInitialized = true
    end
end

function self:FixedUpdate()
    if not isInitialized or not headTransform or not lineRenderer then
        return
    end

    waveTime = waveTime + Time.fixedDeltaTime * WAVE_SPEED

    -- Anchor first segment to head
    segmentPositions[1] = headTransform.position

    -- Get wind from environment
    local _wind = Environment.GetCurrentWind()

    -- Get perpendicular direction for wave (cross wind with up)
    local _windDir = _wind.normalized
    local _waveDir = Vector3.Cross(_windDir, Vector3.up).normalized
    if _waveDir.magnitude < 0.1 then
        _waveDir = Vector3.right
    end

    for i = 2, SEGMENT_COUNT do
        -- Apply gravity (downward)
        segmentVelocities[i] = segmentVelocities[i] + Vector3.new(0, -TAIL_GRAVITY, 0) * Time.fixedDeltaTime

        -- Apply wind force (stronger on segments further from head)
        local _windFactor = (i / SEGMENT_COUNT) * WIND_INFLUENCE
        segmentVelocities[i] = segmentVelocities[i] + _wind * _windFactor * Time.fixedDeltaTime

        -- Add sine wave that travels down the tail (with random offset per tail)
        local _segmentRatio = (i - 1) / SEGMENT_COUNT
        local _wavePhase = waveTime - _segmentRatio * WAVE_FREQUENCY * math.pi * 2 + wavePhaseOffset
        local _waveOffset = math.sin(_wavePhase) * WAVE_AMPLITUDE * _segmentRatio
        segmentVelocities[i] = segmentVelocities[i] + _waveDir * _waveOffset

        -- Spring force to previous segment
        local _dir = segmentPositions[i - 1] - segmentPositions[i]
        local _dist = _dir.magnitude

        -- Constrain distance
        if _dist > SEGMENT_LENGTH then
            _dir = _dir.normalized
            segmentPositions[i] = segmentPositions[i - 1] - _dir * SEGMENT_LENGTH
            _dist = SEGMENT_LENGTH
        end

        local _error = _dist - SEGMENT_LENGTH
        local _force = _dir.normalized * _error * SPRING_STRENGTH
        segmentVelocities[i] = segmentVelocities[i] + _force * Time.fixedDeltaTime

        -- Apply damping
        segmentVelocities[i] = segmentVelocities[i] * DAMPING

        -- Update position
        segmentPositions[i] = segmentPositions[i] + segmentVelocities[i] * Time.fixedDeltaTime
    end

    -- Update line renderer
    for i = 0, SEGMENT_COUNT - 1 do
        if segmentPositions[i + 1] then
            lineRenderer:SetPosition(i, segmentPositions[i + 1])
        end
    end
end
