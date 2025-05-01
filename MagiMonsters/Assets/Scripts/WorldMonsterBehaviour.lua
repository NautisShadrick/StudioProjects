--!Type(Client)

--!SerializeField
local followDistance : number = 5
--!SerializeField
local teleportDistance : number = 10
--!SerializeField
local anim : Animator = nil

--!SerializeField
local FairyBody : GameObject = nil
--!SerializeField
local ExplodeParticle : ParticleSystem = nil
--!SerializeField
local CreatureSprite : GameObject = nil

local monsterLibrary = require("MonsterLibrary")


local navAgent = nil
local mainCamera = nil
myCharacter = nil

local isFairy = true

function self:Start()
    navAgent = self.gameObject:GetComponent(NavMeshAgent)
    mainCamera = Camera.main
end

function self:Update()
    if myCharacter == nil or navAgent == nil then
        return
    end

    if Vector3.Distance(myCharacter.transform.position, self.transform.position) > followDistance then
        if isFairy == false then
            FollowPlayer()
        end
        if Vector3.Distance(myCharacter.transform.position, self.transform.position) > teleportDistance or isFairy then
            SetFairy(true)
            navAgent.enabled = false
            -- Move Towards the player
            self.transform.position = Vector3.MoveTowards(self.transform.position, myCharacter.transform.position, 5 * Time.deltaTime)
        end
    else
        navAgent.enabled = true
        SetFairy(false)
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

function SetFairy(state)
    if isFairy == state then
        return
    end
    isFairy = state

    if state then Timer.After(.1, function() CreatureSprite:SetActive(false) end) else CreatureSprite:SetActive(true) end
    FairyBody:SetActive(state)

    ExplodeParticle:Play()

    if state then
        anim:SetTrigger("shrink")
    else
        anim:SetTrigger("pop")
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

function SetSprite(type)
    CreatureSprite:GetComponent(Renderer).material.mainTexture = monsterLibrary.monsters[type].GetSprite()
end