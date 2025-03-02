--!Type(UI)

--!Bind
local no_button: VisualElement = nil
--!Bind
local yes_button: VisualElement = nil

local gameManger = require("GameStateManager")
local uiManager = require("UIManager")

no_button:RegisterPressCallback(function()
    print("No button pressed")
    gameManger.makeChoiceRequest:FireServer(0)
    self.gameObject:SetActive(false)

    uiManager.resultsUI.ShowHeartStart()
end)

yes_button:RegisterPressCallback(function()
    print("Yes button pressed")
    gameManger.makeChoiceRequest:FireServer(1)
    self.gameObject:SetActive(false)
    
    uiManager.resultsUI.ShowHeartStart()
end)