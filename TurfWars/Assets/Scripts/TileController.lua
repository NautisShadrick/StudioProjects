--!Type(ClientAndServer)

--!SerializeField
local teamObjs: {GameObject} = nil

tileID = NumberValue.new("TileID", 0)
local changeTileRequestEvent = Event.new("ChangeTileRequest")

local danceGameManager = require("DanceGameManager")
local playerTracker = require("PlayerTrackerTemplate")

function GetTileID()
    return tileID.value
end

--------- CLIENT ---------



function self:ClientStart()
    for i, teamObj in ipairs(teamObjs) do
        teamObj:SetActive(false)
    end

    function UpdateTile(newValue)
        for i, teamObj in ipairs(teamObjs) do
            teamObj:SetActive(false)
        end
        if newValue > 0 then teamObjs[newValue]:SetActive(true) end
    end

    UpdateTile(tileID.value)
    tileID.Changed:Connect(function(newValue)
        UpdateTile(newValue)
    end)
end

function self:OnTriggerEnter(collider: Collider)
    local character
    if collider.gameObject:GetComponent(Character) then character = collider.gameObject:GetComponent(Character) end
    if not character then return end
    if character.player ~= client.localPlayer then return end
    ChangeTileRequest()
end


function ChangeTileRequest()
    changeTileRequestEvent:FireServer()
end


--------- SERVER ---------

function self:ServerStart()

    danceGameManager.AddTileToFloor(self)

    changeTileRequestEvent:Connect(function(player)
        local TeamID = playerTracker.GetTeam(player)
        if TeamID == 0 then return end
        tileID.value = TeamID
        danceGameManager.ChangeTileID(self, TeamID)
        print(player.name .. " changed tile to " .. playerTracker.GetTeam(player))

    end)
end