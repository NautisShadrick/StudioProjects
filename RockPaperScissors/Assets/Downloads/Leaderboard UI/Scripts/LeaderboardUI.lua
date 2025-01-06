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

--!Bind
local local_rewards_container : VisualElement = nil -- Do not touch this line
--!Bind
local local_rewards_label : Label = nil -- Do not touch this line

local uiManager = require("UIManager")

-- 15k Total distributed among 10 players
local LeaderboardRewards = {
  3500,
  3000,
  3000,
  1500,
  1000,
  1000,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500,
  500
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

-- Function to update the local player
function UpdateLocalPlayer(place: number, name: string, score: number)
  place = place + 1

  _localrank:SetPrelocalizedText(GetPositionSuffix(place)) -- Set the name of the local player
  _localname:SetPrelocalizedText(name) -- Set the name of the local player
  _localscore:SetPrelocalizedText(tostring(score)) -- Set the score of the local player

  if score == 0 then
    _localrank:SetPrelocalizedText(GetPositionSuffix(0))
  end

  if LeaderboardRewards[place] and score > 0 then
    local_rewards_label.text = LeaderboardRewards[place]
  else
    local_rewards_container:EnableInClassList("hidden", true)
  end

  -- Note: When passing the "score" make sure you convert it to a string
end

-- 25 test entries
local testEntries 
= {
  { rank = 1, name = "Player1", score = 3500 },
  { rank = 2, name = "Player2", score = 3000 },
  { rank = 3, name = "Player3", score = 3000 },
  { rank = 4, name = "Player4", score = 1500 },
  { rank = 5, name = "Player5", score = 1000 },
  { rank = 6, name = "Player6", score = 1000 },
  { rank = 7, name = "Player7", score = 500 },
  { rank = 8, name = "Player8", score = 500 },
  { rank = 9, name = "Player9", score = 500 },
  { rank = 10, name = "Player10", score = 500 },
  { rank = 11, name = "Player11", score = 500 },
  { rank = 12, name = "Player12", score = 500 },
  { rank = 13, name = "Player13", score = 500 },
  { rank = 14, name = "Player14", score = 500 },
  { rank = 15, name = "Player15", score = 500 },
  { rank = 16, name = "Player16", score = 500 },
  { rank = 17, name = "Player17", score = 500 },
  { rank = 18, name = "Player18", score = 500 },
  { rank = 19, name = "Player19", score = 500 },
  { rank = 20, name = "Player20", score = 500 },
  { rank = 21, name = "Player21", score = 0 },
  { rank = 22, name = "Player22", score = 0 },
  { rank = 23, name = "Player23", score = 0 },
  { rank = 24, name = "Player24", score = 0 },
  { rank = 25, name = "Player25", score = 0 }
}

-- Function to update the leaderboard
function UpdateLeaderboard(entries)
  --entries = testEntries
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

    -- Create the Rewards Container
    local _rewardsContainer = VisualElement.new()
    _rewardsContainer:AddToClassList("rewards-container")

    -- Create the Rewards Icon
    local _rewardsIcon = VisualElement.new()
    _rewardsIcon:AddToClassList("rewards-icon")

    -- Create the Rewards Label
    local _rewardsLabel = Label.new()
    _rewardsLabel.text = "##k"
    _rewardsLabel:AddToClassList("rewards-label")
    _rewardsLabel.text = LeaderboardRewards[entry.rank]

    -- Set the score of the player
    local _scoreLabel = UILabel.new()
    _scoreLabel:SetPrelocalizedText(tostring(score))
    _scoreLabel:AddToClassList("score-label")

    -- Add the rewards icon and label to the rewards container
    _rewardsContainer:Add(_rewardsIcon)
    _rewardsContainer:Add(_rewardsLabel)

    -- Add the rank, name, and score labels to the rank item
    _rankItem:Add(_rankLabel)
    _rankItem:Add(_nameLabel)
    if LeaderboardRewards[entry.rank] then _rankItem:Add(_rewardsContainer) end
    _rankItem:Add(_scoreLabel)

    -- Add the rank item to the leaderboard
    _ranklist:Add(_rankItem)
  end
end
