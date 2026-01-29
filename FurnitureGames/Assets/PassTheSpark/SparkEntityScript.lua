--!Type(ClientAndServer)
local HAPPYEMOTE = "emote-happy"
local SADEMOTE = "emoji-scared"

local spawnerScript = require("PassTheSparkSpawner")

local myTapHandler : TapHandler = nil

function SetParentScript(spawner : PassTheSparkSpawner)
    spawnerScript = spawner
end

function UpdatePlayer(activeID : string, oldID : string)
    local myPlayer = spawnerScript.GetPlayerByID(activeID)
    
    print("Updating player to ID: " .. activeID)
    print("My Player Name: " .. (myPlayer and myPlayer.name or "nil"))
    -- parent to myPlayer's characters
    if myPlayer then
        -- Do something with myPlayer
        myPlayer.character:PlayEmote(HAPPYEMOTE, 1, false)
        self.transform.parent = myPlayer.character.transform
        self.transform.localPosition = Vector3.new(0, 0, 0)
    end
    myTapHandler.enabled = true

    if oldID then
        local oldPlayer = spawnerScript.GetPlayerByID(oldID)
        if oldPlayer then
            oldPlayer.character:PlayEmote(SADEMOTE, 1, false)
        end
    end

end

function self:ClientStart()
    
    myTapHandler = self.gameObject:GetComponent(TapHandler)
    myTapHandler.Tapped:Connect(function()
        print("Spark entity tapped, requesting to steal spark.")
        spawnerScript.stealSparkRequest:FireServer()
    end)
    
    UpdatePlayer(spawnerScript.activeHolderID.value)
    spawnerScript.activeHolderID.Changed:Connect(function(newID, oldID)
        print("Active holder changed from " .. oldID .. " to " .. newID)
        -- Update client-side UI or effects based on active holder change
        UpdatePlayer(newID, oldID)
    end)
end