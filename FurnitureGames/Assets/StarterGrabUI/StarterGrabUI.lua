--!Type(UI)

--!SerializeField
local shopImages : {Texture} = {}

--!Bind
local shop_card_content : VisualElement = nil

function CreateCollectionButton(id : string, title : string, image)
    local _button = VisualElement.new()
    _button:AddToClassList("collection_button")
    _button.style.backgroundImage = image
    local _name = Label.new()
    _name:AddToClassList("collection_button_name")
    _name.text = title

    _button:Add(_name)
    shop_card_content:Add(_button)

    _button:RegisterPressCallback(function()
        print("Clicked on " .. id)
    end)
end

function self:Start()
    CreateCollectionButton("goth", "GOTH STARTER BLIND BOX", shopImages[2])
    CreateCollectionButton("cute", "CUTE STARTER BLIND BOX", shopImages[1])
    CreateCollectionButton("casual", "CASUAL STARTER BLIND BOX", shopImages[3])
end