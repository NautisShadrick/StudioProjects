--!Type(Module)

--------------------------------
------     WIND SETTINGS   ------
--------------------------------
MAIN_WIND_DIRECTION = Vector3.new(0.3, 1, 0.1).normalized
BASE_WIND_STRENGTH = 8
WIND_STRENGTH_VARIATION = 2
WIND_DIRECTION_VARIATION = 0.3

--------------------------------
------     LOCAL STATE    ------
--------------------------------
local windTime: number = 0

--------------------------------
------  PUBLIC FUNCTIONS  ------
--------------------------------
function GetCurrentWind(): Vector3
    -- Use multiple sine waves at different frequencies for smooth organic variation
    local _strengthVar = math.sin(windTime * 0.5) * 0.4
                       + math.sin(windTime * 0.23) * 0.3
                       + math.sin(windTime * 0.11) * 0.3

    local _currentStrength = BASE_WIND_STRENGTH + WIND_STRENGTH_VARIATION * _strengthVar

    -- Direction variation - small offsets to the main direction
    local _dirVarX = math.sin(windTime * 0.17) * WIND_DIRECTION_VARIATION
    local _dirVarY = math.sin(windTime * 0.13) * WIND_DIRECTION_VARIATION * 0.5
    local _dirVarZ = math.sin(windTime * 0.19) * WIND_DIRECTION_VARIATION

    local _variedDirection = Vector3.new(
        MAIN_WIND_DIRECTION.x + _dirVarX,
        MAIN_WIND_DIRECTION.y + _dirVarY,
        MAIN_WIND_DIRECTION.z + _dirVarZ
    ).normalized

    return _variedDirection * _currentStrength
end

function GetWindDirection(): Vector3
    return MAIN_WIND_DIRECTION
end

function GetWindStrength(): number
    local _strengthVar = math.sin(windTime * 0.5) * 0.4
                       + math.sin(windTime * 0.23) * 0.3
                       + math.sin(windTime * 0.11) * 0.3
    return BASE_WIND_STRENGTH + WIND_STRENGTH_VARIATION * _strengthVar
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:ClientUpdate()
    windTime = windTime + Time.deltaTime
end
