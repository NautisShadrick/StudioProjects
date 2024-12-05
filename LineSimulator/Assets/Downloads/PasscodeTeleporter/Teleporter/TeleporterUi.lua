--!Type(UI)

--!Bind
local interact : UIButton = nil

local canTeleport = false

local teleporterScript = nil

function SetVisible(state, teleporter)
    if teleporter then teleporterScript = teleporter:GetComponent(TeleporterController) end
    interact:EnableInClassList("hide", not state)
    canTeleport = state
end

SetVisible(false)

interact:RegisterPressCallback(function()
    if teleporterScript then
        teleporterScript.Teleport(false)
        SetVisible(false, nil)
    end
end, true, true, true)
