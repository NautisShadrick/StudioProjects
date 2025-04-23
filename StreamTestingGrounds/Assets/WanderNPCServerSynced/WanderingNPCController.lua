--!Type(ClientAndServer)

local npcMoveEvent = Event.new("WanderingNPCMoveEvent")

local character = nil

----- Client side -----

function handleMove(destination : Vector3)
    -- Move to a points TODO
    character:MoveTo(destination)
end

function self:ClientStart()
    character = self.gameObject:GetComponent(Character)
    npcMoveEvent:Connect(handleMove)
end

----- Server side -----

function MoveToRandomPoint()
    local randomPoint = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
    self.gameObject.transform.position = randomPoint
    npcMoveEvent:FireAllClients(randomPoint)
end

function MoveToPoint(point: Vector3)
    self.gameObject.transform.position = point
    npcMoveEvent:FireAllClients(point)
end

function self:ServerStart()
    Timer.Every(2, MoveToRandomPoint)
end