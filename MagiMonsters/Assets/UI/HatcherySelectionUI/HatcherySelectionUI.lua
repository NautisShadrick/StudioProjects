--!Type(UI)

--!Bind
local click_off : VisualElement = nil
--!Bind
local hatchery_selection_container : VisualElement = nil

local monsterLibrary = require("MonsterLibrary")
local playerTracker = require("PlayerTracker")
local uiManager = require("UIManager")

function CreateCollectionItem(eggIndex, eggType)
    local _collectionItem = VisualElement.new()
    _collectionItem:AddToClassList("item-container")

    local _itemImage = Image.new()
    _itemImage:AddToClassList("item-image")

    _itemImage.image = monsterLibrary.eggSprites["air"]

    _collectionItem:Add(_itemImage)

    _collectionItem:RegisterPressCallback(function()
        print("Item Clicked")
        uiManager.SelectEggForHatchery(eggIndex)
    end)

    return _collectionItem
end

function GenerateCollection()
    hatchery_selection_container:Clear()

    local _playerEggCollection = playerTracker.players[client.localPlayer].eggCollection.value

    for i, _egg in ipairs(_playerEggCollection) do
        local newItem = CreateCollectionItem(i, _egg.monster)
        hatchery_selection_container:Add(newItem)
    end

end

click_off:RegisterPressCallback(function()
    self.gameObject:SetActive(false)
end)
