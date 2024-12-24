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

local enabled = true

local gameManager = require("GameManager")

function self:Awake()
end

function DisableOptions()
    enabled = false
    buttons_container:EnableInClassList("disabled", true)
end

function EnableOptions()
    enabled = true
    buttons_container:EnableInClassList("disabled", false)
end

function HideButtons()
    buttons_container:EnableInClassList("hidden", true)
    response_button:EnableInClassList("hidden", true)
end

function SetState(state:number)
    if state == 1 then
        EnableOptions()
        print("Setting state to options")
        buttons_container:EnableInClassList("hidden", false)
        response_button:EnableInClassList("hidden", true)
        gameManager.localPlayerIsResponding = false
    elseif state == 2 then
        EnableOptions()
        gameManager.UpdateBusy(true)
        gameManager.localPlayerIsResponding = true
        buttons_container:EnableInClassList("hidden", false)
        response_button:EnableInClassList("hidden", true)
    else
        buttons_container:EnableInClassList("hidden", true)
        response_button:EnableInClassList("hidden", true)
    end
end

button1:RegisterPressCallback(function()
    if not enabled then return end

    if not gameManager.localPlayerIsResponding then
        gameManager.SendChallenge(1)
    else
        gameManager.SendResponse(1)
    end
end)

button2:RegisterPressCallback(function()
    if not enabled then return end
    if not gameManager.localPlayerIsResponding then
        gameManager.SendChallenge(2)
    else
        gameManager.SendResponse(2)
    end
end)

button3:RegisterPressCallback(function()
    if not enabled then return end
    if not gameManager.localPlayerIsResponding then
        gameManager.SendChallenge(3)
    else
        gameManager.SendResponse(3)
    end
end)