--!Type(UI)

--!Bind
local tablet_button : VisualElement = nil

local sceneID = 0
local uiManager = require("UIManager")


tablet_button:RegisterPressCallback(function()
    --uiManager.SwitchSceneRequest("home")
    uiManager.OpenGeneralInventoryUI()
end)

scene.PlayerJoined:Connect(function(scene, player)
    print(typeof(scene), typeof(player))
    print(scene.id)
end)