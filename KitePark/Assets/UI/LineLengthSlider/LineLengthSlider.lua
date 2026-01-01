--!Type(UI)

--------------------------------
------  REQUIRED MODULES  ------
--------------------------------
local playerTracker = require("playerTracker")

--------------------------------
---- UXML ELEMENT BINDINGS -----
--------------------------------
--!Bind
local _lengthSlider: UISlider = nil
--!Bind
local _valueLabel: Label = nil

--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function onSliderChanged(event)
    local _value = _lengthSlider.value
    _valueLabel.text = string.format("%.0f", _value)
    playerTracker.ChangeLengthRequest:FireServer(_value)
end

--------------------------------
------  LIFECYCLE HOOKS   ------
--------------------------------
function self:Awake()
    _lengthSlider:RegisterCallback(IntChangeEvent, onSliderChanged)
end

function self:OnEnable()
    _lengthSlider.lowValue = playerTracker.GetMinLineLength()
    _lengthSlider.highValue = playerTracker.GetMaxLineLength()
    _lengthSlider.value = playerTracker.GetDefaultLineLength()
    _valueLabel.text = string.format("%.0f", _lengthSlider.value)
end
