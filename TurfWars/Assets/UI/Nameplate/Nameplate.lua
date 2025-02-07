--!Type(UI)

--!Bind
local nameLabel : UILabel = nil

local playerTracker = require("PlayerTrackerTemplate")


function ChangeTeamColor(team)
    nameLabel:EnableInClassList("teamRed", true)
    --nameLabel:EnableInClassList("teamBlue", team == 2)
    print("Added to class " .. team)
end

function self:Start()
    local myCharacter = self.transform.parent.gameObject:GetComponent(Character)
    local myPlayer = myCharacter.player
    nameLabel:SetPrelocalizedText(myPlayer.name, true)

    playerTracker.setPlayerTeamEvent:Connect(function(player, team)
        --print("Changing team color for player: "..player.name .. " to team: "..team)
        local namePlateUI = player.character.gameObject.transform:GetChild(1).gameObject:GetComponent(Nameplate)
        if namePlateUI then
            namePlateUI.ChangeTeamColor(team)
        else
            print("No nameplate found for player: "..player.name)
        end
    end)
end