--!Type(UI)

--!Bind
local _content : VisualElement = nil -- Do not touch this line
--!Bind
local _ranklist : UIScrollView = nil -- Do not touch this line

--!Bind
local _closeButton : VisualElement = nil -- Do not touch this line

--!Bind
local local_rewards_container : VisualElement = nil -- Do not touch this line
--!Bind
local local_rewards_label : Label = nil -- Do not touch this line

local uiManager = require("UIManager")
local playerTracker = require("PlayerTracker")

local testEntries = {
  {id = "player.user.id", name = "Player 1" , },
  {id = "player.user.id", name = "Player 2" , },
  {id = "player.user.id", name = "Player 3" , },
  {id = "player.user.id", name = "Player 4" , },
  {id = "player.user.id", name = "Player 5" , },
  {id = "player.user.id", name = "Player 6" , },
  {id = "player.user.id", name = "Player 7" , },
  {id = "player.user.id", name = "Player 8" , },
  {id = "player.user.id", name = "Player 9" , },
  {id = "player.user.id", name = "Player 10", },
}

-- Register a callback to close the ranking UI
_closeButton:RegisterPressCallback(function()
  uiManager.HideLeaderboard()
end, true, true, true)

-- Function to get the suffix of a position
function GetPositionSuffix(position)
  if position == 1 then
    return "1st"
  elseif position == 2 then
    return "2nd"
  elseif position == 3 then
    return "3rd"
  else
    return position .. "th"
  end
end

-- Function to update the leaderboard
function UpdateLeaderboard()

  local entries = {}

  for id, matchData in playerTracker.players[client.localPlayer].matches.value do
    print("Match Data: " .. id)
    local entry = {
      id = id,
      name = matchData.name,
    }
    table.insert(entries, entry)
  end

  print("Updating leaderboard..." .. #entries)
  -- Clear the previous leaderboard entries
  _ranklist:Clear()
  
  -- Loop through the entries and add them to the leaderboard
  for i, entry in ipairs(entries) do
    -- Create a new rank item
    local _rankItem = VisualElement.new()
    _rankItem:AddToClassList("rank-item")

    -- Get the player entry
    local entry = entries[i]

    -- Create the player user thumbnail
    local userthumbnail = UIUserThumbnail.new()
    userthumbnail:Load(entry.id)
    userthumbnail:AddToClassList("user_thumb")

    local name = entry.name -- Get the name of the player

    -- Set the name and score of the player
    local _nameLabel = Label.new()
    _nameLabel.text = entry.name
    _nameLabel:AddToClassList("name-label")

    -- Add the user thumbnail to the rank item
    _rankItem:Add(userthumbnail)

    -- Add the rank, name, and score labels to the rank item
    _rankItem:Add(_nameLabel)

    -- Add the rank item to the leaderboard
    _ranklist:Add(_rankItem)

    _rankItem:RegisterPressCallback(function()
      UI:OpenMiniProfile(entry.id)
    end, true, true, true)
    
  end
end