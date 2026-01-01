--!Type(Client)

-- This script makes the gameObject's transform move up and down using a sine wave over time
local time = 0
local amplitude = .1 -- Adjust the amplitude of the sine wave
local frequency = 2 -- Adjust the frequency of the sine wave

-- Add rotation logic to make the gameObject rotate clockwise over time
local rotationSpeed = 15 -- Degrees per second

-- Offset the vertical timing by the start rotation to create a wave effect
local startRotationY = self.gameObject.transform.rotation.eulerAngles.y

function self:Update()
    time = time + Time.deltaTime
    local offsetTime = time + startRotationY / 360 -- Normalize rotation to a 0-1 range
    local newY = amplitude * math.sin(frequency * offsetTime) + .2
    self.gameObject.transform.position = Vector3.new(self.gameObject.transform.position.x, newY, self.gameObject.transform.position.z)
    
    local rotation = self.gameObject.transform.rotation.eulerAngles
    rotation.y = rotation.y - rotationSpeed * Time.deltaTime
    self.gameObject.transform.rotation = Quaternion.Euler(rotation)
end

