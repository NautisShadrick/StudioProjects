--!Type(UI)

--!Bind
local buttons_container: VisualElement = nil

--!Bind
local button1: VisualElement = nil
--!Bind
local button2: VisualElement = nil
--!Bind
local button3: VisualElement = nil

--!Bind
local response_button: VisualElement = nil

button1:RegisterPressCallback(function()
    print("button1 pressed")
end)

button2:RegisterPressCallback(function()
    print("button2 pressed")
end)

button3:RegisterPressCallback(function()
    print("button3 pressed")
end)

response_button:RegisterPressCallback(function()
    print("response_button pressed")
end)

function self:Awake()
end