--!Type(Client)

local mainCam = Camera.main
local player = client.localPlayer

local meshRender = self.gameObject:GetComponent(MeshRenderer)

function self:Update()
    -- Hide self when between Cam an player
    local ray = Ray.new(mainCam.transform.position, mainCam.transform.forward)
    local success, hit = Physics.Raycast(ray, 100, 1)

    if success and hit.transform then
        if hit.transform.gameObject == self.gameObject then
            if meshRender.enabled then
                meshRender.enabled = false
            end
        else
            if meshRender.enabled == false then
                meshRender.enabled = true
            end
        end
    else
        if meshRender.enabled == false then
            meshRender.enabled = true
        end
    end
end