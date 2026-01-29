--!Type(UI)

--!SerializeField
local EmojiTextures : {Texture} = {}
--!SerializeField
local Stations : {TapHandler} = {}

local emojiManager = require("EmojiManager")

local EmojiEntryClass = "emoji-entry"
local EmojiEntrySelectedClass = "emoji-entry-selected"

--!Bind
local _menuContainer : VisualElement = nil
--!Bind
local _closeButton : VisualElement = nil
--!Bind
local _emojiGrid : UIScrollView = nil

local selectedIndex : number = 0
local emojiEntries : {VisualElement} = {}

local function updateSelection(newIndex: number)
    if emojiEntries[selectedIndex] then
        emojiEntries[selectedIndex]:RemoveFromClassList(EmojiEntrySelectedClass)
    end

    selectedIndex = newIndex

    if emojiEntries[selectedIndex] then
        emojiEntries[selectedIndex]:AddToClassList(EmojiEntrySelectedClass)
    end
end

local function createEmojiEntry(index: number, texture: Texture)
    local _entry = VisualElement.new()
    _entry:AddToClassList(EmojiEntryClass)

    local _image = VisualElement.new()
    _image:AddToClassList("emoji-image")
    _image.style.backgroundImage = texture

    _entry:Add(_image)

    _entry:RegisterPressCallback(function()
        updateSelection(index)
        emojiManager.changeEmojiRequest:FireServer(index)
    end)

    emojiEntries[index] = _entry
    _emojiGrid:Add(_entry)
end

local function createClearEntry()
    local _entry = VisualElement.new()
    _entry:AddToClassList(EmojiEntryClass)
    _entry:AddToClassList(EmojiEntrySelectedClass)

    local _label = Label.new()
    _label:AddToClassList("clear-label")
    _label.text = "None"

    _entry:Add(_label)

    _entry:RegisterPressCallback(function()
        updateSelection(0)
        emojiManager.changeEmojiRequest:FireServer(0)
    end)

    emojiEntries[0] = _entry
    _emojiGrid:Add(_entry)
end

local function showMenu()
    _menuContainer.style.display = DisplayStyle.Flex
end

local function hideMenu()
    _menuContainer.style.display = DisplayStyle.None
end
_closeButton:RegisterPressCallback(function()
    hideMenu()
end)

local function initialize()
    createClearEntry()

    for i, texture in ipairs(EmojiTextures) do
        createEmojiEntry(i, texture)
    end
end

function self:Start()
    hideMenu()
    initialize()

    for i, station in ipairs(Stations) do
        station.Tapped:Connect(function(player)
            showMenu()
        end)
    end
end
