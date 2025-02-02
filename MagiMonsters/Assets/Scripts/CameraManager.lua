--!Type(Module)

--!SerializeField
local mainCamera: GameObject = nil
--!SerializeField
local battleCamera: GameObject = nil

function SwitchCamera(mode: number)
    if mode == 0 then
        mainCamera:SetActive(true)
        battleCamera:SetActive(false)
    elseif mode == 1 then
        battleCamera:SetActive(true)
        mainCamera:SetActive(false)
    end
end

function GetBattleCam()
    return battleCamera
end
function GetMainCam()
    return mainCamera
end