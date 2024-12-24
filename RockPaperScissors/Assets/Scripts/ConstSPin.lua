--!Type(Client)

--!SerializeField
local rotationSpeed: number = 25

function self:Update()
    self.gameObject.transform:Rotate(Vector3.new(0, rotationSpeed * Time.deltaTime, 0))
end