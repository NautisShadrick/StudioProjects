--!Type(UI)

--!Bind
local no_button: VisualElement = nil
--!Bind
local yes_button: VisualElement = nil

local gameManger = require("GameStateManager")
local uiManager = require("UIManager")
local audioManager = require("AudioManager")

no_button:RegisterPressCallback(function()
    print("No button pressed")
    gameManger.makeChoiceRequest:FireServer(0)
    self.gameObject:SetActive(false)

    uiManager.resultsUI.ShowHeartStart()

    audioManager.PlaySound("pop")
end)

yes_button:RegisterPressCallback(function()
    print("Yes button pressed")
    gameManger.makeChoiceRequest:FireServer(1)
    self.gameObject:SetActive(false)
    
    uiManager.resultsUI.ShowHeartStart()
    audioManager.PlaySound("pop")
end)