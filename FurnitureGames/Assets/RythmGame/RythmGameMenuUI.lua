--!Type(UI)

--!SerializeField
local SongDataList : {SongEntry} = {}

--!Bind
local open_button : Label = nil
--!Bind
local menu_container : VisualElement = nil
--!Bind
local _closeButton : VisualElement = nil
--!Bind
local _songlist : UIScrollView = nil

local rythmGameController : RythmGameController = nil

function CreateSongEntry(songData)
    local _SongEntryElement = VisualElement.new()
    _SongEntryElement:AddToClassList("song-entry")

    local _SongTitleLabel = Label.new()
    _SongTitleLabel:AddToClassList("song-title-label")
    _SongTitleLabel.text = songData.GetName()

    local _SongBPMLabel = Label.new()
    _SongBPMLabel:AddToClassList("song-bpm-label")
    _SongBPMLabel.text = tostring(songData.GetBPM()).."bpm"

    local _SongDurationLabel = Label.new()
    _SongDurationLabel:AddToClassList("song-duration-label")
    _SongDurationLabel.text = tostring(songData.GetDuration()) .. "s"

    local playLabel = Label.new()
    playLabel:AddToClassList("play-label")
    playLabel.text = "Play"

    _SongEntryElement:Add(_SongTitleLabel)
    _SongEntryElement:Add(_SongBPMLabel)
    --_SongEntryElement:Add(_SongDurationLabel)
    _SongEntryElement:Add(playLabel)

    _SongEntryElement:RegisterPressCallback(function()
        rythmGameController.StartGameWithSong(songData)
    end)

    _songlist:Add(_SongEntryElement)
end

function PlayerEntered()
    menu_container.style.display = DisplayStyle.None
    open_button.style.display = DisplayStyle.Flex
end

open_button:RegisterPressCallback(function()
    menu_container.style.display = DisplayStyle.Flex
    open_button.style.display = DisplayStyle.None
end)

_closeButton:RegisterPressCallback(function()
    menu_container.style.display = DisplayStyle.None
    open_button.style.display = DisplayStyle.Flex
end)

function Initialize()
    for _, songData in ipairs(SongDataList) do
        CreateSongEntry(songData)
    end
end

function self:Start()
    PlayerEntered()
    rythmGameController = self.transform.parent:GetComponent(RythmGameController)
    Initialize()
end