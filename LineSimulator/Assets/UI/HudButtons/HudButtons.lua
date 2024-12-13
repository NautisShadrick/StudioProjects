--!Type(UI)

--!SerializeField
local buttonIcons : {Texture} = nil

--!SerializeField
local fartCloudData: ItemUITemplate = nil

--!Bind
local hud_buttons: UILuaView = nil
--!Bind
local left_container: VisualElement = nil
--!Bind
local right_container: VisualElement = nil

local uiManager = require("UIManager")

function self:Start()
    
    function CreateHudButton(iconID:string, cost:number, side: string, callback: () -> ())
        local _buttonContainer = VisualElement.new()
        _buttonContainer:AddToClassList("button-container")
    
        local _buttonIcon = VisualElement.new()
        _buttonIcon:AddToClassList("button-icon")
        _buttonIcon:AddToClassList(iconID)
    
        local _butonLabel = Label.new()
        _butonLabel:AddToClassList("button-label")
    
        _butonLabel.text = "$" .. tostring(cost)
    
        _buttonContainer:Add(_buttonIcon)
        _buttonContainer:Add(_butonLabel)
    
        if side == "left" then
            left_container:Add(_buttonContainer)
        else
            right_container:Add(_buttonContainer)
        end
    
        _buttonContainer:AddToClassList(side .. "-side")
    
        _buttonContainer:RegisterPressCallback(callback)
    
        return _buttonContainer
    end

    CreateHudButton(fartCloudData.GetIconID(), fartCloudData.GetPrice(), "right", function()
        uiManager.ShowConfirmationPopup(fartCloudData.GetTitle(), fartCloudData.GetDescription(), fartCloudData.GetPrice(), fartCloudData.GetIconID(), fartCloudData.GetActionID())
    end)

    --CreateHudButton("", 200, "right", function() print("Two") end)
    --CreateHudButton("", 350, "right", function() print("Three") end)
    --CreateHudButton("", 500, "right", function() print("Four") end)
end