--!Type(Client)

--!SerializeField
local offset: Vector3 = Vector3.new(0, 0, 0)

--!SerializeField
local pointA : Transform = nil
--!SerializeField
local pointB : Transform = nil

function GetPoints()
    return pointA, pointB
end

--!SerializeField
local moveSpeed : number = 1
--!SerializeField
local radius : number = 5

local angle : number = 0 -- Current angle from radius

function self:Start()
    math.randomseed(os.time())

    -- Slightly Randomize the radius
    radius = radius * Random.Range(6,10)/10

    -- Start with a random angle
    angle = Random.Range(0, 360)
    -- Calculate the new position on the circle assuming XZ plane
    local x = Mathf.Cos(angle) * radius
    local z = Mathf.Sin(angle) * radius
    -- Set the new position
    self.transform.position = Vector3.new(x, 0, z) + offset
    --Rotate the boat to face to moving direction
    self.transform.rotation = Quaternion.LookRotation(Vector3.new(-x, 0, -z))
end

function self:Update()

    -- Increment the angle based on speed and frametime
    angle = angle + moveSpeed * Time.deltaTime

    -- Calculate the new position on the circle assuming XZ plane
    local x = Mathf.Cos(angle) * radius
    local z = Mathf.Sin(angle) * radius

    -- Set the new position
    self.transform.position = Vector3.new(x, 0, z) + offset

    --Rotate the boat to face to moving direction
    self.transform.rotation = Quaternion.LookRotation(Vector3.new(-x, 0, -z))
end