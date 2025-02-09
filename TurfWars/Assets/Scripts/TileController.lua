--!Type(ClientAndServer)

--!SerializeField
local teamObjs: {GameObject} = nil

local audioManager = require("AudioManager")
local danceGameManager = require("DanceGameManager")
local playerTracker = require("PlayerTrackerTemplate")

myIndex = 0

--------- CLIENT ---------

function UpdateTile(newValue)
    --print("UpdateTile", newValue)
    for i, teamObj in ipairs(teamObjs) do
        teamObj:SetActive(false)
    end
    if newValue > 0 then teamObjs[newValue]:SetActive(true) end
end

function self:ClientStart()
    for i, teamObj in ipairs(teamObjs) do
        teamObj:SetActive(false)
    end

    
end

function self:OnTriggerEnter(collider: Collider)
    local character
    if collider.gameObject:GetComponent(Character) then character = collider.gameObject:GetComponent(Character) end
    if not character then return end
    if character.player ~= client.localPlayer then return end
    danceGameManager.ChangeTileReq(myIndex)

    if playerTracker.GetTeam(character.player) ~= 0 then audioManager.PlaySound(1) end
end