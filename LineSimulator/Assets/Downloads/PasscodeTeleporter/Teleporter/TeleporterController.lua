--!SerializeField
local Destination : Transform = nil
--!SerializeField
local passCodeObject : GameObject = nil

local canTeleport = false

local teleportRequest = Event.new("TeleportRequest")
local teleportEvent = Event.new("TeleportEvent")

local TeleportUIScript = nil
local PassCodeUIScript = nil

function self:ClientAwake()
    TeleportUIScript = self.transform.parent.gameObject:GetComponent(TeleporterUi)
    PassCodeUIScript = self.transform.parent:GetChild(0).gameObject:GetComponent(PassCodeUI)


    function ToggleTeleporterUI(canTeleport)
        TeleportUIScript.SetVisible(canTeleport, self.gameObject)
    end

    function Teleport(passed)
        if PassCodeUIScript and not passed then ----- PopUp Passcode UI
            PassCodeUIScript.SetVsible(true, self)
        else
            teleportRequest:FireServer(Destination.position)
        end
    end

    function self:OnTriggerEnter(other : Collider)
        local playerCharacter = other.gameObject:GetComponent(Character)
        if playerCharacter == nil then return end  -- Exit if no Character component

        local player = playerCharacter.player
        if client.localPlayer == player then
            canTeleport = true
            ToggleTeleporterUI(canTeleport)
        end
    end 
    function self:OnTriggerExit(other : Collider)
        local playerCharacter = other.gameObject:GetComponent(Character)
        if playerCharacter == nil then return end  -- Exit if no Character component

        local player = playerCharacter.player
        if client.localPlayer == player then
            canTeleport = false
            ToggleTeleporterUI(canTeleport)
        end
    end

    teleportEvent:Connect(function(player, pos)
        Destination.gameObject:GetComponent(ParticleSystem):Play()
        player.character:Teleport(Destination.position)
    end)
end

------------ Server ------------

function self:ServerAwake()
    teleportRequest:Connect(function(player, pos)
        player.character.transform.position = pos
        teleportEvent:FireAllClients(player)
    end)
end