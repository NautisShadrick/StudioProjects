--!Type(UI)

--!Bind
local items_container : VisualElement = nil

local playerTracker = require("PlayerTracker")
local inventoryManager = require("PlayerInventoryManager")
local itemLibrary = require("ItemLibrary")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

function CreateItemNotifaction(item, amount)
    
    local itemData = itemLibrary.GetItemByID(item)
    if itemData == nil then
        itemData = itemLibrary.GetConsumableByID(item)
    end
    if itemData == nil then
        return -- item not found as a material or consumable
    end

    local item_displayName = itemData.GetDisplayName()
    local item_sprite = itemData.GetSprite()

    local _Notification = VisualElement.new()
    _Notification:AddToClassList("item-notification")

    local _amount_gained = Label.new()
    _amount_gained:AddToClassList("item-notification-amount-gained")
    _amount_gained.text = "+" .. amount
    _Notification:Add(_amount_gained)

    local _display_name = Label.new()
    _display_name:AddToClassList("item-notification-display-name")
    _display_name.text = item_displayName
    _Notification:Add(_display_name)

    local _item_icon = Image.new()
    _item_icon:AddToClassList("item-notification-icon")
    _item_icon.image = item_sprite
    _Notification:Add(_item_icon)

    local amountOwned = playerTracker.GetItemAmountFromInv(client.localPlayer, item)
    local _amount_total = Label.new()
    _amount_total:AddToClassList("item-notification-amount-total")
    _amount_total.text = "(" .. amountOwned .. ")"
    _Notification:Add(_amount_total)

    items_container:Add(_Notification)

    _Notification.pickingMode = PickingMode.Ignore
    _amount_gained.pickingMode = PickingMode.Ignore
    _display_name.pickingMode = PickingMode.Ignore
    _item_icon.pickingMode = PickingMode.Ignore
    _amount_total.pickingMode = PickingMode.Ignore


    local fadeOutTween = Tween:new(
        1,
        0,
        0.5,
        false,
        false,
        TweenModule.Easing.easeInBack,
        function(value)
            _Notification.style.opacity = value
        end,
        function()
            _Notification:RemoveFromHierarchy()
        end
    )

    local slideUpTween = Tween:new(
        32,
        0,
        0.5,
        false,
        false,
        TweenModule.Easing.easeOutBack,
        function(value, t)
            _Notification.style.translate = StyleTranslate.new(Translate.new(Length.new(0), Length.new(value)))
            _Notification.style.opacity = t
        end,
        function()
            Timer.After(2, function()
                fadeOutTween:start()
            end)
        end
    )

    slideUpTween:start()

    return _Notification

end

function DisplayItems(items)

    local stackedItems = {}
    local stackSize = 0
    for i, itemInfo in items do
        local itemId = itemInfo.id
        if stackedItems[itemId] == nil then
            stackedItems[itemId] = { id = itemId, amount = 0 }
            stackSize = stackSize + 1
        end
        stackedItems[itemId].amount = stackedItems[itemId].amount + itemInfo.amount
    end


    local currentitem = 0
    for id, itemInfo in stackedItems do
        currentitem = currentitem + 1
        Timer.After(currentitem * .5, function()
            CreateItemNotifaction(id, itemInfo.amount)
        end)
    end
end