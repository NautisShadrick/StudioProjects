--!Type(UI)

--!SerializeField
local buttonIcons : {Texture} = nil

--!Bind
local hud_buttons: UILuaView = nil
--!Bind
local left_container: VisualElement = nil
--!Bind
local right_container: VisualElement = nil

local uiManager = require("UiManager")

function self:Start()
    
    function CreateHudButton(text: string, iconID: string, side: string, cb)

        local iconID = iconID or 0

        local _buttonContainer = VisualElement.new()
        _buttonContainer:AddToClassList("button-container")
    
        local _buttonIcon = VisualElement.new()
        _buttonIcon:AddToClassList("button-icon")
        _buttonIcon:AddToClassList(iconID)
    
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

    CreateHudButton("Create", "create_icon", "right", function()
        uiManager.openCreateQuestionUI()
    end)
end