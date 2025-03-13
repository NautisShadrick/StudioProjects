--!Type(Module)

--!SerializeField
local mainCamera: GameObject = nil
--!SerializeField
local battleCamera: GameObject = nil

function SwitchCamera(mode: number)
    if mode == 0 then
        mainCamera:SetActive(true)
        if battleCamera then battleCamera:SetActive(false) end
    elseif mode == 1 then
        if battleCamera then battleCamera:SetActive(true) end
        mainCamera:SetActive(false)
    end
end

function GetBattleCam()
    return battleCamera
end
function GetMainCam()
    return mainCamera
end