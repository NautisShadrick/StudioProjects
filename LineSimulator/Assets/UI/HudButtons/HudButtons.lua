--!Type(UI)

--!SerializeField
local buttonIcons : {Texture} = nil

--!SerializeField
local fartCloudData: ItemUITemplate = nil
--!SerializeField
local fartBombData: ItemUITemplate = nil
--!SerializeField
local fireAlarmData: ItemUITemplate = nil
--!SerializeField
local toiletPartyData: ItemUITemplate = nil
--!SerializeField
local poopHeadData: ItemUITemplate = nil

--!Bind
local hud_buttons: UILuaView = nil
--!Bind
local left_container: VisualElement = nil
--!Bind
local right_container: VisualElement = nil

local uiManager = require("UIManager")

function self:Start()
    
    function CreateHudButton(actionData: ItemUITemplate, side: string)

        local iconID = actionData.GetIconID()
        local cost = actionData.GetPrice()

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
    
        _buttonContainer:RegisterPressCallback(function()
            uiManager.ShowConfirmationPopup(actionData.GetTitle(), actionData.GetDescription(), actionData.GetPrice(), actionData.GetIconID(), actionData.GetActionID())
        end)
    
        return _buttonContainer
    end

    CreateHudButton(fartCloudData, "right")
    CreateHudButton(fartBombData, "right")
    --CreateHudButton(poopHeadData, "right")
    --CreateHudButton(fireAlarmData, "right")
    CreateHudButton(toiletPartyData, "right")
end