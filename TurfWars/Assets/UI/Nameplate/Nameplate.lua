--!Type(UI)

--!Bind
local nameLabel : UILabel = nil

local playerTracker = require("PlayerTrackerTemplate")


function ChangeTeamColor(team)
    nameLabel:EnableInClassList("teamRed", team == 1)
    nameLabel:EnableInClassList("teamBlue", team == 2)
end

function self:Start()
    local myCharacter = self.transform.parent.gameObject:GetComponent(Character)
    local myPlayer = myCharacter.player
    nameLabel:SetPrelocalizedText(myPlayer.name, true)
end