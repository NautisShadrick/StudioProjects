--!Type(UI)

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local Environment = require("EnvironmentManager")

--------------------------------
---- UXML ELEMENT BINDINGS -----
--------------------------------
--!Bind
local _arrowContainer: VisualElement = nil
--!Bind
local _strengthLabel: Label = nil

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Update()
    local _wind = Environment.GetCurrentWind()
    local _strength = Environment.GetWindStrength()

    -- Calculate angle from wind XZ direction
    -- North (+X, +Z) = 0 degrees (up), East (+X, -Z) = 90 degrees (right)
    local _angle = math.atan2(_wind.x - _wind.z, _wind.x + _wind.z) * (180 / math.pi)

    -- Update arrow rotation
    if _arrowContainer then
        _arrowContainer.style.rotate = StyleRotate.new(Rotate.new(Angle.Degrees(_angle)))
    end

    -- Update strength label
    if _strengthLabel then
        _strengthLabel.text = string.format("%.1f", _strength)
    end
end
