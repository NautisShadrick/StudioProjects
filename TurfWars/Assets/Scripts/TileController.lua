--!Type(ClientAndServer)

--!SerializeField
local teamObjs: {GameObject} = nil

local tileID = NumberValue.new("TileID", 0)
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

    tileID.Changed:Connect(function()
        for i, teamObj in ipairs(teamObjs) do
            teamObj:SetActive(false)
        end
        teamObjs[tileID.value]:SetActive(true)
    end)
end

function self:OnTriggerEnter(collider: Collider)
    local character
    if collider.gameObject:GetComponent(Character) then character = collider.gameObject:GetComponent(Character) end
    if not character then return end
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
        if TeamID == tileID.value then return end
        tileID.value = TeamID
        danceGameManager.ChangeTileID(self, TeamID)
    end)
end