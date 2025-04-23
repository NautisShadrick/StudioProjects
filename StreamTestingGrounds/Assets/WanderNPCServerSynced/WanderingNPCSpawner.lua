--!Type(Server)

--!SerializeField
local WanderingNPCPrefab : GameObject = nil

function self:Start()
    local wanderingNPC = Object.Instantiate(WanderingNPCPrefab)
    wanderingNPC.transform.position = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
end