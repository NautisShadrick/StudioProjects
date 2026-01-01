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


--------------------------------
------  LOCAL FUNCTIONS   ------
--------------------------------
local function onSliderChanged(event)
    local _value = _lengthSlider.value
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
end
