--!Type(Client)

--!SerializeField
local followDistance : number = 5
--!SerializeField
local anim : Animator = nil

local navAgent = nil
local mainCamera = nil
myCharacter = nil


function self:Start()
    navAgent = self.gameObject:GetComponent(NavMeshAgent)
    mainCamera = Camera.main
end

function self:Update()
    if myCharacter == nil or navAgent == nil then
        return
    end

    if Vector3.Distance(myCharacter.transform.position, self.transform.position) > followDistance then
        FollowPlayer()
    end

    if navAgent.velocity.magnitude > .5 then
        anim:SetBool("moving", true)
    else
        anim:SetBool("moving", false)
    end

    -- Set the X Scale depending on the direction we're moving
    if mainCamera then
        local playerScreenPos = mainCamera:WorldToScreenPoint(myCharacter.transform.position)
        local monsterScreenPos = mainCamera:WorldToScreenPoint(self.transform.position)
        if playerScreenPos.x < monsterScreenPos.x then
            self.transform.localScale = Vector3.new(1, 1, 1)
        else
            self.transform.localScale = Vector3.new(-1, 1, 1)
        end
    end
    

end

function FollowPlayer()
    if myCharacter == nil or navAgent == nil then
        return
    end
    -- Pick a random spot within X distance of the player
    local newDestination = myCharacter.transform.position + Random.insideUnitSphere * 2
    navAgent.destination = newDestination
end

function SetCharacter(character)
    myCharacter = character
end