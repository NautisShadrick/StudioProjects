--!Type(UI)

--!Bind
local _localrank : UILabel = nil -- Do not touch this line
--!Bind
local _localname : UILabel = nil -- Do not touch this line
--!Bind
local _localscore : UILabel = nil -- Do not touch this line

--!Bind
local _content : VisualElement = nil -- Do not touch this line
--!Bind
local _ranklist : UIScrollView = nil -- Do not touch this line

--!Bind
local _closeButton : VisualElement = nil -- Do not touch this line

local uiManager = require("UIManager")

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

-- Function to update the local player
function UpdateLocalPlayer(place: number, name: string, score: number)

  _localrank:SetPrelocalizedText(GetPositionSuffix(place+1)) -- Set the name of the local player
  _localname:SetPrelocalizedText(name) -- Set the name of the local player
  _localscore:SetPrelocalizedText(tostring(score)) -- Set the score of the local player

  -- Note: When passing the "score" make sure you convert it to a string
end

-- Function to update the leaderboard
function UpdateLeaderboard(entries)
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

    local name = entry.name -- Get the name of the player
    local score = entry.score -- Get the score of the player
    local rank = GetPositionSuffix(entry.rank) -- Get the rank of the player

    -- Create the rank, name, and score labels
    local _rankLabel = UILabel.new()
    _rankLabel:SetPrelocalizedText(rank)
    _rankLabel:AddToClassList("rank-label")

    -- Set the name and score of the player
    local _nameLabel = UILabel.new()
    _nameLabel:SetPrelocalizedText(name)
    _nameLabel:AddToClassList("name-label")

    -- Set the score of the player
    local _scoreLabel = UILabel.new()
    _scoreLabel:SetPrelocalizedText(tostring(score))
    _scoreLabel:AddToClassList("score-label")

    -- Add the rank, name, and score labels to the rank item
    _rankItem:Add(_rankLabel)
    _rankItem:Add(_nameLabel)
    _rankItem:Add(_scoreLabel)

    -- Add the rank item to the leaderboard
    _ranklist:Add(_rankItem)
  end
end
