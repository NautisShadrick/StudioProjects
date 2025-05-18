--!Type(UI)

--!SerializeField
local buttonIcons : {Texture} = nil

--!Bind
local hud_buttons: UILuaView = nil
--!Bind
local left_container: VisualElement = nil
--!Bind
local right_container: VisualElement = nil

local uiManager = require("UIManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

function self:Start()
    
    function CreateHudButton(text: string, icon: Texture, side: string, cb)
        local _buttonContainer = VisualElement.new()
        _buttonContainer:AddToClassList("button-container")
    
        local _buttonIcon = VisualElement.new()
        _buttonIcon:AddToClassList("button-icon")
        _buttonIcon.style.backgroundImage = icon
    
        local _butonLabel = Label.new()
        _butonLabel:AddToClassList("button-label")
    
        _butonLabel.text = text
    
        _buttonContainer:Add(_buttonIcon)
        _buttonContainer:Add(_butonLabel)
    
        if side == "left" then
            left_container:Add(_buttonContainer)
        else
            right_container:Add(_buttonContainer)
        end
    
        _buttonContainer:AddToClassList(side .. "-side")
        _buttonContainer:RegisterPressCallback(cb)
    
        return _buttonContainer
    end

    inventoryButton = CreateHudButton("Inventory", buttonIcons[1], "right", function()
        uiManager.OpenGeneralInventoryUI()
    end)
    inventoryButton.name = "inv_button"

    collectionButton = CreateHudButton("Collection", buttonIcons[2], "right", function()
        uiManager.OpenTeamManagerUI()
    end)
    collectionButton.name = "coll_button"
end