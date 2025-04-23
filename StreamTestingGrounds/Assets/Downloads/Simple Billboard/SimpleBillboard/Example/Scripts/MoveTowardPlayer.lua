--!Type(Client)

--!SerializeField
local speed:number = 1
--!SerializeField
local range:number = 5

function self:LateUpdate()

    if client.localPlayer ~= nil then

        local playerPosition = client.localPlayer.character.transform.position
        local vectorToPlayer = playerPosition - self.transform.position

        if range > 0 then
            local distance = vectorToPlayer.sqrMagnitude
            if distance > Mathf.Pow(range, 2) then return nil end
        end

        local newPosition = self.transform.position + (vectorToPlayer.normalized * Time.deltaTime * speed)
        self.transform.position = newPosition
        --self.transform:LookAt(newPosition - vectorToPlayer)

    end

end