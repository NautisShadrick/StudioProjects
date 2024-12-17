--!Type(Module)

local reSyncRequest = Event.new("ReSyncRequest")
local addToFloorRequest = Event.new("AddToFloorRequest")
local removeFromFloorRequest = Event.new("RemoveFromFloorRequest")
local PlayAnimationsEvent = Event.new("PlayAnimationsEvent")

local isOnFloor = false

-------------- CLIENT FUNCTIONS --------------

function self:ClientAwake()
    function self:OnTriggerEnter(collider: Collider)
        local playerCharacter = collider.gameObject:GetComponent(Character)
        if playerCharacter == nil then return end  -- Exit if no Character component

        local player = playerCharacter.player
        if player ~= client.localPlayer then return end

        print(player.name .. " entered the dance floor!")
        addToFloorRequest:FireServer()

        isOnFloor = true
    end

    function self:OnTriggerExit(collider: Collider)
        local playerCharacter = collider.gameObject:GetComponent(Character)
        if playerCharacter == nil then return end  -- Exit if no Character component

        local player = playerCharacter.player
        if player ~= client.localPlayer then return end

        print(player.name .. " left the dance floor!")
        removeFromFloorRequest:FireServer()

        isOnFloor = false
    end

    PlayAnimationsEvent:Connect(function(currentDancers)
        print("Playing animations!")
        for _, player in ipairs(currentDancers) do
            print("Playing animation for " .. player.name)
            player.character:PlayEmote("dance-macarena", 1, true, nil)

        end
    end)
end

function ReSyncRequest()
    if isOnFloor then
        reSyncRequest:FireServer()
    end
end

-------------- SERVER FUNCTIONS --------------

local animationTimer = nil
local resyncTimer = nil

function self:ServerAwake()
    local playersOnFloor = {}

    addToFloorRequest:Connect(function(player)
        table.insert(playersOnFloor, player)
        ReSyncAnimations(playersOnFloor)
    end)

    removeFromFloorRequest:Connect(function(targetPlayer)

        for i, player in ipairs(playersOnFloor) do
            if player == targetPlayer then
                table.remove(playersOnFloor, i)
                break
            end
        end
        ReSyncAnimations(playersOnFloor)
    end)

    reSyncRequest:Connect(function()
        ReSyncAnimations(playersOnFloor)
    end)

    server.PlayerDisconnected:Connect(function(player)
        for i, playerOnFloor in ipairs(playersOnFloor) do
            if playerOnFloor == player then
                table.remove(playersOnFloor, i)
                break
            end
        end
        ReSyncAnimations(playersOnFloor)
    end)
end

function ReSyncAnimations(playersOnFloor)
    if resyncTimer then resyncTimer:Stop() end
    resyncTimer = Timer.After(2, function()
        PlayAnimationsEvent:FireAllClients(playersOnFloor)
    end)
end