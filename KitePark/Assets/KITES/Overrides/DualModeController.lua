-- --[[

-- 	Copyright (c) 2024 Pocket Worlds

-- 	This software is provided 'as-is', without any express or implied
-- 	warranty.  In no event will the authors be held liable for any damages
-- 	arising from the use of this software.

-- 	Permission is granted to anyone to use this software for any purpose,
-- 	including commercial applications, and to alter it and redistribute it
-- 	freely.

-- --]]

--!Type(Module)

local GameManager: GameManager = require("GameManager")

local RunId: string = "run"
local WalkId: string = "walk"
local IdleId: string = "idle"
local JumpId: string = "jump"

-------------------------------------------------------------------------------
-- SERIALIZED
-------------------------------------------------------------------------------
--!SerializeField
local movementUpdateInterval: number = 0.1

--!SerializeField
local footstepWalkSound: AudioShader = nil

--!SerializeField
local footstepRunSound: AudioShader = nil

--!Tooltip("Keyboard and gamepad input used on Desktop clients")
--!SerializeField
local externalInputAction: InputActionReference = nil

--!SerializeField
local _startingMovementSpeed: number = 5.5

--!SerializeField
local _smoothTime: number = 0.15

--!SerializeField
local _movementSpeed: number = 5.5

--!Tooltip("The running emote will be used beyond this speed")
--!SerializeField
local runningSpeedThreshold: number = 5
--!SerializeField
local _turnAroundThreshold: number = -0.5

--!Tooltip("If checked the input to world space transform will not ignore the Y coordinate")
--!SerializeField
local is2D: boolean = false

--!Header("These properties determine if you should use an off-mesh link")
--!Tooltip("You have to be within this distance of an off-mesh link endpoint to use it")
--!SerializeField
local maxLinkDistance: number = 1
--!Tooltip("The euler angle between your movement vector and the link vector has to be within this value to use it")
--!SerializeField
local maxLinkAngle: number = 95
--!Tooltip("The difference between the requested step size and the actual step size. 0 means no change, 1 means the character couldn't move at all in that direction. If the difference is above this value and all the other criteria are met the off-mesh link will be used")
--!SerializeField
local minLinkMoveStepChange: number = 0.24

--!Header("Drag Movement Configuration")
--!Tooltip("Camera used for screen to world position conversion")
--!SerializeField
local movementCamera: Camera = nil
--!Tooltip("Maximum distance for movement target")
--!SerializeField
local maxMovementDistance: number = 50.0
--!Tooltip("How close the character needs to be to the target before stopping")
--!SerializeField
local arrivalThreshold: number = 0.5
--!SerializeField
local _tapToMoveThreshold: number = 0.05
--!SerializeField
local _rotationScreenThreshold: number = 0.6 -- portion of screen height for rotation

--!Header("Tap to Move Configuration")
--!Tooltip("Movement indicator prefab to show tap destination")
--!SerializeField
local movementIndicator: GameObject = nil
--!Tooltip("Sound to play on long press")
--!SerializeField
local longPressSound: AudioShader = nil

local _wasInputActive: boolean = false
local _lastLocalDirection: Vector3 = Vector3.forward

-------------------------------------------------------------------------------
-- OPTIONS
-------------------------------------------------------------------------------

options = {}

if client then
    -- Whether or not the PlayerController is enabled
    options.enabled = true

    -- Whether or not tap to move is enabled
    options.tapToMoveEnabled = true

    -- Whether or not tap handlers are enabled
    options.tapHandlersEnabled = true

    -- True if playing emotes through the chat UI should be enabled
    options.emotesEnabled = true

    -- True if long press for mini-profile should be enabled
    options.enableLongPress = true

    -- The mask to use for raycasting (includes Critter layer for tap interactions)
    options.tapMask = bit32.bor(
        bit32.lshift(1, LayerMask.NameToLayer("Walkable")),
        bit32.lshift(1, LayerMask.NameToLayer("Character")),
        bit32.lshift(1, LayerMask.NameToLayer("Tappable")),
        bit32.lshift(1, LayerMask.NameToLayer("Critter")),
        bit32.lshift(1, LayerMask.NameToLayer("ChristmasTree")),
        bit32.lshift(1, LayerMask.NameToLayer("Default"))
    )

    -- Long press options
    options.characterLongPress = {
        enabled = true,
        height = 0.5,
        bounceDuration = 0.3,
    }
end

-------------------------------------------------------------------------------
-- SHARED
-------------------------------------------------------------------------------

local initialPlayerDataEvent = Event.new("InitialPlayerDataEvent")
local playerInitializedEvent = Event.new("PlayerInitializedEvent")
local movementUpdateRequest = Event.new("MovementUpdateRequest")
local movementUpdateEvent = Event.new("MovementUpdateEvent")
local navMeshJumpRequest = Event.new("NavMeshJumpRequest")
local navMeshJumpEvent = Event.new("NavMeshJumpEvent")
local emoteRequest = Event.new("EmoteRequest")
local emoteEvent = Event.new("EmoteEvent")

local requestAnchor = RemoteFunction.new("RequestAnchor")
local releaseAnchor = Event.new("ReleaseAnchor")
local playerReleasedAnchor = Event.new("PlayerReleasedAnchor")
local syncAnchors = Event.new("SyncAnchors")

tapHandlerPointEvent = Event.new("TapHandlerPointEvent")

local anchors: { [Anchor]: string } = {}
local activeAnchorRequestId: number = 1

PreTap = Event.new("PreTap")
IgnoreMovementEvent = Event.new("IgnoreMovementEvent")
CancelTapToMoveEvent = Event.new("CancelTapToMoveEvent")
MoveToPositionEvent = Event.new("MoveToPositionEvent")
playerTappedOnEvent = Event.new("playerTappedOnEvent")

-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

local RequestLocalPlayerMovementUpdate: (Vector3, Vector3, boolean, boolean | nil) -> () = nil

movementEnabled = true

function SetLocalPlayerPosition(position: Vector3)
    if RequestLocalPlayerMovementUpdate then
        RequestLocalPlayerMovementUpdate(position, Vector3.zero, true, false)
    end
end

function CancelTapToMove(playerId: string, position: Vector3)
    CancelTapToMoveEvent:Fire(playerId, position)
end

function GetScreenHeightThreshold(): number
    return _rotationScreenThreshold
end

function IgnoreMovementUpdatesForPlayer(playerId: string, ignore: boolean)
    IgnoreMovementEvent:Fire(playerId, ignore)
end

function RequestLocalMoveToPosition(position: Vector3)
    MoveToPositionEvent:Fire(position)
end

function SetMoveSpeed(speed: number)
    _movementSpeed = speed or 5.5
end
-------------------------------------------------------------------------------
-- CLIENT
-------------------------------------------------------------------------------
AnchorState = {
    None = 0,
    MovingToAnchor = 1,
    Anchored = 2,
}

type NavMeshJumpInfo = {
    startTime: number,
    endTime: number,
    distance: number,
    startPosition: Vector3,
    endPosition: Vector3,
}

type EmoteInfo = {
    idleEmote: string?,
    activeEmote: {
        id: string?,
        speed: number?,
    },
}

type PlayerInfo = {
    movement: {
        position: Vector3,
        velocity: Vector3,
    },
    smoothVel: Vector3,
    tapToMove: boolean,
    character: Character?,
    navMeshAgent: NavMeshAgent?,
    navMeshJump: NavMeshJumpInfo?,
    emote: EmoteInfo,
    anchor: Anchor,
    anchorState: number,
    ignoreUpdates: boolean,
}

type PlayerMoveData = {
    position: Vector3,
    velocity: Vector3,
    anchor: Anchor,
    tapToMove: boolean,
}

type PlayerEmoteMoveData = {
    Character: Character,
    RunEmote: string,
    WalkEmote: string,
    MoveSpeedMod: number,
}

type CharacterChangedCallback = (player: Player, character: Character) -> ()

-- Create a mask that excludes the Character and Critter layers
local dragMask = nil
if client then
    dragMask = bit32.bor(bit32.lshift(1, LayerMask.NameToLayer("Walkable")))
end

-- other player data
local _clientPlayers: { [string]: PlayerInfo } = {}

-- local player data
local lastMovementUpdateTime: number = 0
local lastPlayerPosition: Vector3 = Vector3.zero
local lastPlayerVelocity: Vector3 = Vector3.zero
local localCharacter: Character = nil
local localNavMeshAgent: NavMeshAgent = nil
local localEmote: EmoteInfo = { idleEmote = nil, activeEmote = nil }
local localNavMeshJump: NavMeshJumpInfo? = nil

-- input
local currentTouchPosition: Vector2 = Vector2.zero
local isDragging: boolean = false
local targetWorldPosition: Vector3 = Vector3.zero
local hasValidTarget: boolean = false
local _chatFocused: boolean = false

-- cached plane for ground projection
local groundPlane = nil
if client then
    groundPlane = Plane.new(Vector3.up, Vector3.new(0, 0, 0))
end

-- tap to move
local movementIndicatorInstance: GameObject? = nil
local longPressCharacter: Character? = nil
local longPressTween: Tween? = nil
local pendingCallback: (() -> ())? = nil

-- movement progress tracking
local progressTimer: Timer? = nil
local progressStartPosition: Vector3 = Vector3.zero
local minimumProgressDistance: number = 0.5 -- Must move at least this far per second

-- mesh links
local meshLinks: { [number]: { [number]: { [number]: { OffMeshLink } } } } = {}
local reverseMeshLinks: { [number]: { [number]: { [number]: { OffMeshLink } } } } = {}
local nearbyMeshLink: { link: OffMeshLink, startPosition: Vector3, endPosition: Vector3 }? = nil

-- swap emotes
local _emoteMoveList: { PlayerEmoteMoveData } = {}

-- footsteps
local footstepEvent = "footstep"
--!SerializeField
local footstepInterval = 0.2
local lastFootstepTime = 0

OtherPlayerSpeedChangedEvent = Event.new("OtherPlayerSpeedChangedEvent")

RequestLocalPlayerMovementUpdate = function(position: Vector3, velocity: Vector3, tapToMove: boolean, anchor: boolean | nil)
    if position ~= lastPlayerPosition or velocity ~= lastPlayerVelocity then
        movementUpdateRequest:FireServer(position, velocity, tapToMove)
        lastPlayerPosition = position
        lastPlayerVelocity = velocity
        lastMovementUpdateTime = Time.time
    end
end

function EnableMovementForLocalPlayer(enabled: boolean)
    options.enabled = enabled
    if not enabled then
        local playerData = _clientPlayers[client.localPlayer.user.id]
        if playerData then
            playerData.emote.activeEmote = nil
            playerData.emote.idleEmote = nil
        end
    end
end

local function ListenForChatInput()
    UI.ChatInputFocusIn:Connect(function()
        _chatFocused = true
    end)

    UI.ChatInputFocusOut:Connect(function()
        _chatFocused = false
    end)
end

function self:ClientAwake()
    scene.PlayerJoined:Connect(function(scene, player: Player)
        InitializePlayerData(player)

        player.CharacterChanged:Connect(function(player, character)
            if player.isLocal then
                localCharacter = character

                playerData = _clientPlayers[player.user.id]
                playerData.character = character
                if character then
                    localNavMeshAgent = character.gameObject:GetComponent(NavMeshAgent)
                    playerData.navMeshAgent = localNavMeshAgent

                    character.AnimationEvent:Connect(function(evt)
                        if evt.name == footstepEvent then
                            PlayFootstepSound()
                        end
                    end)
                end
            else
                playerData = _clientPlayers[player.user.id]

                if not playerData then
                    return
                end

                playerData.character = character
                playerData.navMeshAgent = character.gameObject:GetComponent(NavMeshAgent)

                if character then
                    character.transform.position = playerData.movement.position
                end
            end

            if character then
                character.transform:LookAt(client.mainCamera.transform)
            end

            table.insert(
                _emoteMoveList,
                {
                    Character = character,
                    RunEmote = RunId,
                    WalkEmote = WalkId,
                    MoveSpeedMod = 1,
                } :: PlayerEmoteMoveData
            )

            PlayEmote(character, _clientPlayers[player.user.id].emote)
        end)
    end)

    scene.PlayerLeft:Connect(function(scene, player)
        local playerInfo = _clientPlayers[player.user.id]
        if not playerInfo then
            return
        end

        if server and playerInfo.anchor ~= nil then
            anchors[playerInfo.anchor] = nil
        end

        _clientPlayers[player.user.id] = nil

        for i, emoteData: PlayerEmoteMoveData in ipairs(_emoteMoveList) do
            if emoteData.Character and emoteData.Character.player == player then
                table.remove(_emoteMoveList, i)
                break
            end
        end
    end)

    playerInitializedEvent:Connect(function(player: Player, position)
        InitializePlayerData(player, HandlePlayerCharacterChanged)
        _clientPlayers[player.user.id].movement.position = position
    end)

    initialPlayerDataEvent:Connect(function(remotePlayers, anchors, serverTime)
        for playerId, remotePlayerData in pairs(remotePlayers) do
            local playerData = _clientPlayers[playerId]
            local speed = remotePlayerData.movement.velocity.magnitude
            local character = nil
            local navMeshJump = nil

            if playerData and playerData.character then
                character = playerData.character
                character.transform.position = remotePlayerData.movement.position
            end

            if remotePlayerData.navMeshJump and remotePlayerData.navMeshJump.endTime > serverTime then
                local jump = remotePlayerData.navMeshJump
                local timeDiff = Time.time - serverTime
                navMeshJump = {
                    startTime = jump.startTime + timeDiff,
                    endTime = jump.endTime + timeDiff,
                    startPosition = jump.startPosition,
                    endPosition = jump.endPosition,
                    distance = (jump.endPosition - jump.startPosition).magnitude,
                }
            end

            local foundAnchor = nil
            local anchorState = AnchorState.None
            for anchor, playerAnchorId in anchors do
                if playerId == playerAnchorId then
                    foundAnchor = anchor
                    anchorState = AnchorState.Anchored
                    break
                end
            end

            local info: PlayerInfo = {
                movement = {
                    position = remotePlayerData.movement.position,
                    velocity = remotePlayerData.movement.velocity,
                },
                smoothVel = remotePlayerData.smoothVel,
                character = character,
                navMeshAgent = character and character.gameObject:GetComponent(NavMeshAgent) or nil,
                emote = {
                    idleEmote = remotePlayerData.idleEmote,
                    activeEmote = MovementEmote(character, navMeshJump, speed),
                },
                navMeshJump = navMeshJump,
                anchor = foundAnchor,
                tapToMove = false,
                anchorState = anchorState,
            } :: PlayerInfo
            _clientPlayers[playerId] = info

            if character then
                ListenForCharacterChange(character.player, HandlePlayerCharacterChanged)

                if foundAnchor then
                    character:TeleportToAnchor(foundAnchor)
                end
            end
            PlayEmote(character, _clientPlayers[playerId].emote)
        end
    end)

    movementUpdateEvent:Connect(function(playerMovement: { [string]: PlayerMoveData })
        for playerId, movement: PlayerMoveData in pairs(playerMovement) do
            if playerId == client.localPlayer.user.id then
                continue
            end

            local playerData = _clientPlayers[playerId]

            if playerData == nil then
                continue
            end

            if movement.tapToMove then
                PlayerTappedToPosition(playerData, movement.position)
                continue
            end

            if playerData.tapToMove and not movement.tapToMove then
                CancelTapToMovePlayerData(playerData, movement.position)
            end

            if movement then
                playerData.movement.position = movement.position
                playerData.movement.velocity = movement.velocity
                MoveCharacterToAnchor(playerData, movement.anchor)
            else
                playerData.movement.position = Vector3.zero
                playerData.movement.velocity = Vector3.zero
            end
        end

        for playerId, playerData in pairs(_clientPlayers) do
            if not playerMovement[playerId] then
                playerData.movement.velocity = Vector3.zero
            end
        end
    end)

    playerReleasedAnchor:Connect(function(playerId: string)
        local playerData = _clientPlayers[playerId]
        if not playerData then
            return
        end
        playerData.anchor = nil
        if playerData.anchorState == AnchorState.MovingToAnchor then
            playerData.character:Teleport(playerData.character.transform.position)
        end
        playerData.anchorState = AnchorState.None
    end)

    UI.EmoteSelected:Connect(function(emote, loop)
        if not options.emotesEnabled then
            return
        end
        emoteRequest:FireServer(emote, loop)

        if not emote or emote == "" then
            localEmote.idleEmote = nil
        elseif loop then
            localEmote.idleEmote = emote
        else
            localEmote.idleEmote = nil
            localEmote.activeEmote = { id = emote, speed = nil }
        end
        PlayEmote(localCharacter, localEmote)
    end)

    emoteEvent:Connect(function(playerId, emote, loop)
        local player = _clientPlayers[playerId]
        if not player or not player.character then
            return
        end

        -- if you're starting an emote, you cannot be moving
        player.movement.velocity = Vector3.zero

        if not emote or emote == "" or emote == "idle" then
            player.emote.idleEmote = nil
            player.emote.activeEmote = nil
        elseif loop then
            player.emote.idleEmote = emote
            player.emote.activeEmote = nil
        else
            player.emote.idleEmote = nil
            player.emote.activeEmote = { id = emote, speed = nil }
        end

        PlayEmote(player.character, player.emote)
    end)

    navMeshJumpEvent:Connect(function(playerId, jump, serverTime)
        local player = _clientPlayers[playerId]
        if not player or not player.character or jump.endTime < serverTime then
            return
        end

        player.navMeshJump = {
            startTime = Time.time,
            endTime = Time.time + (jump.endTime - jump.startTime),
            startPosition = jump.startPosition,
            endPosition = jump.endPosition,
            distance = (jump.endPosition - jump.startPosition).magnitude,
        }
    end)

    CancelTapToMoveEvent:Connect(CancelTapToMove)

    IgnoreMovementEvent:Connect(IgnoreMovementUpdatesForPlayer)
    MoveToPositionEvent:Connect(RequestLocalMoveToPositionForPlayer)
    SetupMeshLinks()
    SetupExternalInputAction()
    SetupDragGestureControls()
    SetupTapControls()
    ListenForChatInput()

    OtherPlayerSpeedChangedEvent:Connect(function(player: Player, speedMod: number)
        if not player or player.isDisconnected or not player.character then
            return
        end

        player.character.runSpeed *= speedMod
        player.character.jogSpeed *= speedMod
        player.character.walkSpeed *= speedMod
        SetRunEmote(RunId, player.character, speedMod)
        SetWalkEmote(WalkId, player.character, speedMod)
    end)
end

function RequestLocalMoveToPositionForPlayer(position: Vector3)
    TapMoveTo(position)
end

function CancelTapToMovePlayerData(playerData: PlayerInfo, position: Vector3)
    if playerData then
        playerData.tapToMove = false
        playerData.anchor = nil
        playerData.anchorState = AnchorState.None
        playerData.movement.position = position
        playerData.movement.velocity = Vector3.zero
        playerData.smoothVel = Vector3.zero
        playerData.character:Teleport(position)
        if playerData.character == client.localPlayer.character then
            targetWorldPosition = position
        end
    end
    HideMovementIndicator()
end

function CancelTapToMove(playerId: string, position: Vector3)
    local playerData = _clientPlayers[playerId]
    CancelTapToMovePlayerData(playerData, position)
end

function IgnoreMovementUpdatesForPlayer(playerId: string, ignore: boolean)
    local playerData = _clientPlayers[playerId]
    if playerData then
        playerData.ignoreUpdates = ignore
        playerData.emote.activeEmote = nil
        playerData.emote.idleEmote = nil
    end
end

function HandlePlayerJoinedScene(scene: Scene, player: Player, characterChangedCallback: CharacterChangedCallback?)
    if characterChangedCallback then
        if not player.character then
            player.CharacterChanged:Connect(characterChangedCallback)
        else
            characterChangedCallback(player, player.character)
        end
    end
end

function HandlePlayerCharacterChanged(player: Player, character: Character)
    local playerInfo = _clientPlayers[player.user.id]
    if not playerInfo then
        return
    end

    character.AnchorChanged:Connect(function(newAnchor, oldAnchor)
        if newAnchor then
            playerInfo.anchorState = AnchorState.Anchored
        else
            playerInfo.anchorState = AnchorState.None
        end
    end)

    local anchor = playerInfo.anchor
    if anchor then
        character:TeleportToAnchor(anchor)
    end
end

---
--- Cancel any outgoing anchor requests
---
local function CancelAnchorRequest()
    activeAnchorRequestId += 1
end

---
--- Request exclusive access to an anchor from the server
---
local function RequestAnchor(playerInfo: PlayerInfo, anchor: Anchor, callback: (boolean) -> ())
    activeAnchorRequestId += 1
    local anchorRequestId = activeAnchorRequestId
    requestAnchor:InvokeServer(anchor, anchorRequestId, function(serverAnchorRequestId, result)
        -- If a new anchor request came after the last then skip this
        if serverAnchorRequestId ~= activeAnchorRequestId then
            print("Anchor request out of date")
            return
        end
        callback(result)
    end)
end

function MoveCharacterToAnchor(playerData: PlayerInfo, anchor: Anchor)
    if anchor and playerData.character ~= nil then
        local currentAnchor = playerData.anchor and playerData.anchor.name or "none"
        if playerData.anchor == nil or playerData.anchor ~= anchor then
            playerData.anchor = anchor
            --moved = playerData.character:MoveToAnchor(anchor, -1)
            -- moved = playerData.character:MoveTo(anchor.transform.position, -1, function()
            --     print("MOVING TO ANCHOR")
            --     moved = playerData.character:MoveToAnchor(anchor, -1)
            -- end)
            -- moved = playerData.character:MoveToAnchor(anchor, -1)
            moved = playerData.character:MoveToAnchor(anchor, -1)
            playerData.anchorState = AnchorState.MovingToAnchor
            if not moved then
                if anchor then
                    playerData.character:TeleportToAnchor(anchor)
                else
                    --playerData.character:Teleport(point)
                end
            end
        end
    elseif playerData.anchor ~= nil then
        playerData.anchor = nil
        if playerData.anchorState == AnchorState.MovingToAnchor then
            playerData.character:Teleport(playerData.character.transform.position)
        end
        playerData.anchorState = AnchorState.None
    end
end

function SetupTapControls()
    Input.LongPressBegan:Connect(HandleLongPressBegan)
    Input.LongPressContinue:Connect(HandleLongPressContinue)
    Input.LongPressEnded:Connect(HandleLongPressEnded)
    Input.Tapped:Connect(HandleTap)
end

function SetupDragGestureControls()
    -- Handle drag start
    Input.PinchOrDragBegan:Connect(function(evt)
        if not options.enabled or not movementEnabled or evt.isPinching then
            return
        end

        if client.isEditor and evt.position.y >= Screen.height * _rotationScreenThreshold then
            return
        end

        currentTouchPosition = evt.position
        isDragging = true
        UpdateTargetPosition()

        if hasValidTarget then
            StartMovementProgressTracking()
        end
    end)

    -- Handle drag movement
    Input.PinchOrDragChanged:Connect(function(evt)
        if not options.enabled or not movementEnabled or not isDragging or evt.isPinching then
            localCharacter.state = CalculateCharacterState(localEmote, localNavMeshJump, 0)
            PlayMovementEmote(localCharacter, localEmote, localNavMeshJump, 0)
            return
        end

        currentTouchPosition = evt.position
        UpdateTargetPosition()
    end)

    -- Handle drag end
    Input.PinchOrDragEnded:Connect(function(evt)
        -- Only process if this was a drag (not pinch) that's ending
        if isDragging and not evt.isPinching then
            isDragging = false
            hasValidTarget = false
            targetWorldPosition = Vector3.zero
            StopMovementProgressTracking()
        end
    end)
end

function UpdateTargetPosition()
    local camera = movementCamera or client.mainCamera
    if not camera then
        hasValidTarget = false
        return
    end

    -- Convert screen position to ray
    local ray = camera:ScreenPointToRay(currentTouchPosition)

    local worldPosition: Vector3? = nil

    -- Try to hit the ground/navmesh first (excluding Character layer)
    local hitInfo: RaycastHit
    local hitSuccess: boolean
    hitSuccess, hitInfo = Physics.Raycast(ray, 1000, dragMask)

    if hitSuccess then
        worldPosition = hitInfo.point
    else
        -- Fallback to ground plane intersection
        local success, distance = groundPlane:Raycast(ray)
        if success then
            worldPosition = ray:GetPoint(distance)
        end
    end

    if worldPosition then
        -- Find the nearest point on the NavMesh
        local navMeshPoint = GetNearestNavMeshPoint(worldPosition)
        if navMeshPoint then
            targetWorldPosition = navMeshPoint
            hasValidTarget = true

            -- Limit the target distance
            if localCharacter then
                local distanceToTarget = (targetWorldPosition - localCharacter.transform.position).magnitude
                if distanceToTarget > maxMovementDistance then
                    local direction = (targetWorldPosition - localCharacter.transform.position).normalized
                    local limitedPosition = localCharacter.transform.position + direction * maxMovementDistance

                    -- Find NavMesh point for the limited position too
                    local limitedNavMeshPoint = GetNearestNavMeshPoint(limitedPosition)
                    if limitedNavMeshPoint then
                        targetWorldPosition = limitedNavMeshPoint
                    end
                end
            end
        else
            hasValidTarget = false
            StopMovementProgressTracking()
        end
    else
        hasValidTarget = false
        StopMovementProgressTracking()
    end
end

-- Tap to Move Functions
function ShowMovementIndicator(point: Vector3)
    -- Create the movement indicator if we have not created it yet
    if not movementIndicatorInstance and movementIndicator then
        movementIndicatorInstance = Object.Instantiate(movementIndicator) :: GameObject?
        if movementIndicatorInstance then
            movementIndicatorInstance:SetActive(false)
        end
    end

    if movementIndicatorInstance then
        movementIndicatorInstance.transform.position = point
        movementIndicatorInstance:SetActive(true)
    end
end

function HideMovementIndicator()
    if movementIndicatorInstance then
        movementIndicatorInstance:SetActive(false)
    end
end

function RayCast(position: Vector2)
    local camera = movementCamera or client.mainCamera
    if not camera or not camera.isActiveAndEnabled then
        return false
    end

    -- Create a ray from the screen position
    local ray = camera:ScreenPointToRay(Vector3.new(position.x, position.y, 0))

    -- Cast a ray from the camera into the world
    return Physics.Raycast(ray, 1000, options.tapMask)
end

function GetNearestNavMeshPoint(worldPosition: Vector3): Vector3?
    -- Try to sample the NavMesh at the hit point
    local success, navMeshHit = NavMesh.SamplePosition(worldPosition, 10.0, GameManager.LandAreaMask)
    if success then
        return navMeshHit.position
    end
    return nil
end

function StartMovementProgressTracking()
    if localCharacter then
        progressStartPosition = localCharacter.transform.position

        -- Stop any existing progress timer
        if progressTimer then
            progressTimer:Stop()
        end

        -- Start a timer that checks progress every second
        progressTimer = Timer.Every(1.0, function()
            if not localCharacter or not hasValidTarget then
                if progressTimer then
                    progressTimer:Stop()
                    progressTimer = nil
                end
                return
            end

            local currentPosition = localCharacter.transform.position
            local distanceMoved = (currentPosition - progressStartPosition).magnitude

            -- If we haven't moved far enough, cancel movement
            if distanceMoved < minimumProgressDistance then
                print("Movement cancelled: insufficient progress (" .. distanceMoved .. " units in 1 second)")
                hasValidTarget = false
                HideMovementIndicator()
                if pendingCallback then
                    pendingCallback = nil
                end

                -- Stop the timer
                if progressTimer then
                    progressTimer:Stop()
                    progressTimer = nil
                end
                return
            end

            -- Update starting position for next check
            progressStartPosition = currentPosition
        end)
    end
end

function StopMovementProgressTracking()
    if progressTimer then
        progressTimer:Stop()
        progressTimer = nil
    end
end

function GetTapHandler(transform: Transform): TapHandler?
    while transform do
        local tapHandler = transform:GetComponent(TapHandler)
        if tapHandler and tapHandler.enabled then
            return tapHandler
        end
        transform = transform.parent
    end
    return nil
end

local function IsAnchorOccupied(anchor: Anchor): boolean
    for _, playerInfo in pairs(_clientPlayers) do
        if playerInfo.anchor == anchor then
            return true
        end
    end
    return false
end

local function ReleaseLocalAnchor(tellServer: boolean)
    local localPlayerData = _clientPlayers[client.localPlayer.user.id]
    if localPlayerData and localPlayerData.anchor ~= nil then
        if tellServer then
            releaseAnchor:FireServer()
        end
        localPlayerData.anchor = nil
        localPlayerData.anchorState = AnchorState.None
    end
end

function HandleTapOnTapHandler(playerInfo: PlayerInfo, handler: TapHandler, tapPosition: Vector3, checkAnchors: boolean, anchor: Anchor?)
    if not options.tapHandlersEnabled then
        return
    end

    local character = localCharacter
    if not character then
        return
    end

    -- Optional anchor
    if checkAnchors and not anchor then
        anchor = handler:GetClosestAnchor(tapPosition)

        if anchor then
            if IsAnchorOccupied(anchor) then
                return
            end
            ReleaseLocalAnchor(false)
            RequestAnchor(playerInfo, anchor, function(result)
                if not result then
                    anchor = nil
                end
                HandleTapOnTapHandler(playerInfo, handler, tapPosition, false, anchor)
            end)
            return
        end
    end

    if anchor then
        local playerData = _clientPlayers[client.localPlayer.user.id]
        MoveCharacterToAnchor(playerData, anchor)
        RequestLocalPlayerMovementUpdate(anchor.transform.position, Vector3.zero, false, true)
        return
    end

    -- Where should we move to?
    local targetPosition = handler.moveTarget

    -- Calculate the position to move to based on the handler's distance
    local characterPosition = character.transform.position
    local distanceToTarget = Vector3.Distance(targetPosition, characterPosition)

    -- Pre walk callback on tap
    PreTap:Fire(handler.gameObject)

    -- If within range then perform it now
    if distanceToTarget <= handler.distance then
        handler:Perform(tapPosition)
    elseif handler.moveTo then
        -- Calculate where to move to: stop at the handler's distance from the target
        local directionToTarget = (targetPosition - characterPosition).normalized
        local moveToPosition = targetPosition - directionToTarget * handler.distance

        -- Find the nearest NavMesh point for the calculated position
        local navMeshPosition = GetNearestNavMeshPoint(moveToPosition)
        if navMeshPosition then
            -- Move the character to the NavMesh position and perform the action when arriving
            TapMoveTo(navMeshPosition, function()
                handler:Perform(tapPosition)
            end)
        end
    end
end

function PlayerTappedToPosition(playerData: PlayerInfo, position: Vector3)
    if playerData.character ~= nil then
        playerData.movement.position = position
        playerData.smoothVel = Vector3.zero
        playerData.tapToMove = true
        playerData.anchor = nil
        playerData.anchorState = AnchorState.None
        local success = playerData.character:MoveTo(position, -1, function() end)
        if not success then
            print("MoveTo failed, teleporting instead")
        end
        localNavMeshAgent.speed = _movementSpeed
    end
end

function StopTapToMove(playerData: PlayerInfo)
    CancelTapToMovePlayerData(playerData, playerData.character.transform.position)
end

function TapMoveTo(point: Vector3, callback: (() -> ())?)
    if not options.tapToMoveEnabled or not localCharacter then
        return
    end

    -- Stop any existing movement tracking
    StopMovementProgressTracking()

    -- Find the nearest point on the NavMesh
    local navMeshPoint = GetNearestNavMeshPoint(point)
    if not navMeshPoint then
        -- If no valid NavMesh point found, don't move
        return
    end

    -- Set the target for our existing movement system
    targetWorldPosition = navMeshPoint
    hasValidTarget = true

    -- Store the callback to execute when we arrive
    pendingCallback = callback

    -- Start tracking movement progress
    --StartMovementProgressTracking()

    RequestLocalPlayerMovementUpdate(point, Vector3.zero, true)
    local localPlayerData = _clientPlayers[client.localPlayer.user.id]
    PlayerTappedToPosition(localPlayerData, navMeshPoint)

    -- Show movement indicator at the NavMesh point
    ShowMovementIndicator(navMeshPoint)
end

function HandleTap(tap)
    -- If the player controller is disabled then do not handle taps
    if not options.enabled then
        return
    end

    -- If drag is active, don't handle taps
    if isDragging then
        return
    end

    -- If the local player does not have a character then do not handle taps
    if not client.localPlayer then
        return
    end
    local character = client.localPlayer.character
    if not character then
        return
    end

    -- Cast a ray from the camera into the world
    local success, hit: RaycastHit = RayCast(tap.position)
    if not success or not hit.collider then
        return
    end

    -- Check for a handler
    local handler = GetTapHandler(hit.collider.transform)
    if handler then
        HandleTapOnTapHandler(_clientPlayers[client.localPlayer.user.id], handler, hit.point, true)
        return
    else
        ReleaseLocalAnchor(true)
    end

    -- Characters should block movement taps
    character = hit.collider.gameObject:GetComponentInParent(Character)
    if character then
        --print("Tapped on character, if gift to give should give gift" .. character.player.name)
        if client.localPlayer ~= character.player then
            playerTappedOnEvent:FireServer(character.player)
        end
        return
    end

    -- Attempt to move the local character
    TapMoveTo(hit.point)
end

function HandleLongPressBegan(evt)
    if not options.enableLongPress then
        return
    end

    -- Cast a ray from the camera into the world
    local success, hit = RayCast(evt.position)
    if not success or not hit.collider then
        return
    end

    local character = hit.collider.gameObject:GetComponentInParent(Character)
    if not character or not character.player then
        return
    end

    longPressCharacter = character

    if longPressTween then
        longPressTween:Stop(false)
        longPressTween = nil
    end
end

function HandleLongPressContinue(evt)
    if longPressCharacter then
        local height = Easing.Sine(evt.progress) * options.characterLongPress.height
        longPressCharacter.renderPosition = Vector3.new(0, height, 0)
    end
end

function HandleLongPressEnded(evt)
    if not longPressCharacter then
        return
    end

    local character = longPressCharacter
    longPressCharacter = nil

    -- always return back to start
    longPressTween = character:TweenRenderPositionTo(Vector3.zero):EaseOutBounce(1, 3):Duration(options.characterLongPress.bounceDuration * evt.progress):Play()

    if not evt.cancelled then
        if longPressSound then
            longPressSound:Play()
        end
        UI:OpenMiniProfile(character.player)
    end
end

function InitializePlayerData(player: Player, characterChangedCallback: CharacterChangedCallback)
    if not _clientPlayers[player.user.id] then
        _clientPlayers[player.user.id] = {
            movement = {
                position = Vector3.zero,
                velocity = Vector3.zero,
            },
            character = player.character,
            navMeshAgent = player.character and player.character.gameObject:GetComponent(NavMeshAgent) or nil,
            navMeshJump = nil,
            emote = {
                idleEmote = nil,
                activeEmote = nil,
            },
            anchor = nil,
            anchorState = AnchorState.None,
        } :: PlayerInfo
    end

    ListenForCharacterChange(player, characterChangedCallback)
end

function ListenForCharacterChange(player: Player, callback: CharacterChangedCallback)
    if not callback then
        return
    end

    if player.character then
        callback(player, player.character)
    else
        player.CharacterChanged:Connect(callback)
    end
end

local function GetRunEmoteForCharacter(character: Character): (string, number)
    if character then
        for _, emoteData: PlayerEmoteMoveData in ipairs(_emoteMoveList) do
            if emoteData.Character and emoteData.Character == character then
                return emoteData.RunEmote, emoteData.MoveSpeedMod
            end
        end
    end
    return RunId, 1
end

local function GetWalkEmoteForCharacter(character: Character): (string, number)
    if character then
        for _, emoteData: PlayerEmoteMoveData in ipairs(_emoteMoveList) do
            if emoteData.Character and emoteData.Character == character then
                return emoteData.WalkEmote, emoteData.MoveSpeedMod
            end
        end
    end
    return WalkId, 1
end

function SetRunEmote(emote: string, character: Character, speedMod: number)
    for _, emoteData: PlayerEmoteMoveData in ipairs(_emoteMoveList) do
        if emoteData.Character and emoteData.Character == character then
            emoteData.RunEmote = emote
            emoteData.MoveSpeedMod = speedMod
            break
        end
    end
end

function SetWalkEmote(emote: string, character: Character, speedMod: number)
    for _, emoteData: PlayerEmoteMoveData in ipairs(_emoteMoveList) do
        if emoteData.Character and emoteData.Character == character then
            emoteData.WalkEmote = emote
            emoteData.MoveSpeedMod = speedMod
            break
        end
    end
end

function RestoreRunEmote(character: Character)
    SetRunEmote(RunId, character, 1)
end

function RestoreWalkEmote(character: Character)
    SetWalkEmote(WalkId, character, 1)
end

function MovementEmote(character: Character, navMeshJump, movementSpeed)
    if navMeshJump ~= nil then
        return JumpEmote(navMeshJump)
    elseif movementSpeed >= runningSpeedThreshold then
        return { id = GetRunEmoteForCharacter(character), speed = nil }
    elseif movementSpeed > 0 then
        return { id = GetWalkEmoteForCharacter(character), speed = nil }
    else
        return nil
    end
end

function JumpEmote(navMeshJump)
    local baseSpeed = 0.8
    return { id = JumpId, speed = baseSpeed / (navMeshJump.endTime - Time.time) }
end

function PlayMovementEmote(character, emote, navMeshJump, movementSpeed, turnedAround: boolean)
    -- print("PME: " .. movementSpeed)
    local movementEmote = MovementEmote(character, navMeshJump, movementSpeed)
    local movementEmoteId = movementEmote and movementEmote.id
    local emoteId = emote.activeEmote and emote.activeEmote.id
    if movementEmoteId ~= emoteId or turnedAround then
        emote.activeEmote = movementEmote
        PlayEmote(character, emote)
    end
end

function PlayEmote(character, emote)
    if not character then
        return
    end

    if emote.activeEmote then
        local emoteId = emote.activeEmote.id
        local emoteSpeed = emote.activeEmote.speed
        local isMovementEmote = string.find(emoteId, RunId) ~= nil or string.find(emoteId, WalkId) ~= nil or string.find(emoteId, JumpId) ~= nil

        if emoteSpeed then
            character:PlayEmote(emote.activeEmote.id, emoteSpeed, isMovementEmote)
        else
            character:PlayEmote(emote.activeEmote.id, isMovementEmote)
        end
    elseif emote.idleEmote then
        character:PlayEmote(emote.idleEmote, true)
    else
        character:StopEmote()
    end
end

function SetupMeshLinks()
    local allLinks = Object.FindObjectsOfType(OffMeshLink, true) :: any

    for _, link in allLinks do
        AddEntries(meshLinks, link, link.startTransform.position, maxLinkDistance)
        if link.biDirectional then
            AddEntries(reverseMeshLinks, link, link.endTransform.position, maxLinkDistance)
        end
    end
end

function AddEntries(entries, entry, position, maxDistance)
    local d = maxDistance
    local x = position.x // d
    local y = position.y // d
    local z = position.z // d

    -- adding entries for all the adjacent positions
    for xx = -1, 1 do
        local dx = d * xx

        for yy = -1, 1 do
            local dy = d * yy

            for zz = -1, 1 do
                local dz = d * zz
                AddXyzEntry(entries, entry, x + dx, y + dy, z + dz)
            end
        end
    end
end

function AddXyzEntry(links, link, x, y, z)
    if not links[x] then
        links[x] = {}
    end
    if not links[x][y] then
        links[x][y] = {}
    end
    if not links[x][y][z] then
        links[x][y][z] = {}
    end
    table.insert(links[x][y][z], link)
end

function SetupExternalInputAction()
    if externalInputAction and externalInputAction.action then
        externalInputAction.action:Enable()
    end
end

function self:ClientUpdate()
    -- Continuously update target position while dragging to handle camera movement
    if isDragging and options.enabled then
        UpdateTargetPosition()
    end

    if not localCharacter then
        return
    end

    UpdateLocalPlayer()
    UpdateOtherPlayers()
    UpdateNearbyMeshEntities()
end

function GetEntries(entries, x, y, z): { any }
    local entriesX = entries[x]
    if not entriesX then
        return {}
    end

    local entriesXY = entriesX[y]
    if not entriesXY then
        return {}
    end

    local entriesXYZ = entriesXY[z]
    if not entriesXYZ then
        return {}
    end

    return entriesXYZ
end

function UpdateNearbyMeshEntities()
    local localCharPosition = GameManager.GetLocalPlayerPosition()
    local x = localCharPosition.x // maxLinkDistance
    local y = localCharPosition.y // maxLinkDistance
    local z = localCharPosition.z // maxLinkDistance

    if nearbyMeshLink and not IsNextToMeshEntity(nearbyMeshLink.startPosition) then
        nearbyMeshLink = nil
    end

    if not nearbyMeshLink then
        for _, link in GetEntries(meshLinks, x, y, z) do
            if IsNextToMeshEntity(link.startTransform.position) then
                nearbyMeshLink = {
                    link = link,
                    startPosition = link.startTransform.position,
                    endPosition = link.endTransform.position,
                }
                break
            end
        end
    end

    if not nearbyMeshLink then
        for _, link in GetEntries(reverseMeshLinks, x, y, z) do
            if IsNextToMeshEntity(link.endTransform.position) then
                nearbyMeshLink = {
                    link = link,
                    startPosition = link.endTransform.position,
                    endPosition = link.startTransform.position,
                }
                break
            end
        end
    end
end

function IsNextToMeshEntity(linkPosition: Vector3)
    return localCharacter and (GameManager.GetLocalPlayerPosition() - linkPosition).magnitude < maxLinkDistance
end

function InputDirection()
    if not movementEnabled then
        return Vector2.zero
    elseif (isDragging or hasValidTarget) and localCharacter then
        -- Calculate direction towards target (works for both drag and tap)
        local currentPosition = GameManager.GetLocalPlayerPosition()
        local directionToTarget = targetWorldPosition - currentPosition

        -- Check if we're close enough to the target
        if directionToTarget.magnitude < arrivalThreshold then
            hasValidTarget = false
            StopMovementProgressTracking()

            -- Execute pending callback if we have one
            if pendingCallback then
                local callback = pendingCallback
                pendingCallback = nil
                callback()
            end

            return Vector2.zero
        end

        -- Convert 3D direction to 2D input (normalize to XZ plane)
        local inputDirection = Vector2.new(directionToTarget.x, directionToTarget.z).normalized
        return inputDirection
    elseif externalInputAction and externalInputAction.action then
        if _chatFocused then
            return Vector2.zero
        end

        return externalInputAction.action:ReadVector2()
    else
        return Vector2.zero
    end
end

local function HasCompletedTapToMove(playerData: PlayerInfo): boolean
    if playerData.character == localCharacter and isDragging then
        return true
    end
    return (playerData.character.state == CharacterState.Emote or playerData.character.state == CharacterState.Idle)
        and playerData.navMeshAgent.isOnNavMesh
        and (not playerData.navMeshAgent.hasPath or (playerData.navMeshAgent.remainingDistance <= _tapToMoveThreshold))
end

function UpdateLocalPlayer()
    if not options.enabled or not movementEnabled or not client.localPlayer then
        return
    end
    local inputDirection = InputDirection()
    local isInputActive = inputDirection.sqrMagnitude > 0

    if not localNavMeshAgent then
        return
    end

    localNavMeshAgent.speed = _movementSpeed

    -- Hide movement indicator when not moving or when we've arrived
    if not isInputActive then
        HideMovementIndicator()
    end

    local localPlayerInfo = _clientPlayers[client.localPlayer.user.id]
    if localPlayerInfo.anchorState == AnchorState.Anchored then
        return
    end

    if isDragging and localPlayerInfo.anchorState == AnchorState.MovingToAnchor then
        ReleaseLocalAnchor(true)
        StopTapToMove(localPlayerInfo)
        return
    end

    if localPlayerInfo.tapToMove then
        if HasCompletedTapToMove(localPlayerInfo) then
            _wasInputActive = false
            StopTapToMove(localPlayerInfo)
        else
            return
        end
    end

    if not _wasInputActive and isInputActive then
        localCharacter:Teleport(localCharacter.transform.position)
    end

    _wasInputActive = isInputActive

    if is2D then
        moveDirection = Vector3.new(inputDirection.x, inputDirection.y, 0)
    else
        -- For target-based movement, we already have world-space direction
        if (isDragging or hasValidTarget) and localCharacter then
            local directionToTarget = targetWorldPosition - GameManager.GetLocalPlayerPosition()
            moveDirection = Vector3.new(directionToTarget.x, 0, directionToTarget.z).normalized
        else
            -- For external input (keyboard/gamepad), convert to world space
            local angle = client.mainCamera.transform.eulerAngles.y / 180 * Mathf.PI
            local s = Mathf.Sin(angle)
            local c = Mathf.Cos(angle)
            local x = inputDirection.y * s + inputDirection.x * c
            local z = inputDirection.y * c - inputDirection.x * s
            moveDirection = Vector3.new(x, 0, z).normalized
        end
    end

    local playerVelocity = moveDirection * _movementSpeed
    local currentTime = Time.time

    if localNavMeshJump and currentTime > localNavMeshJump.endTime then
        localNavMeshAgent.enabled = true
        localNavMeshAgent:Warp(localNavMeshJump.endPosition)
        localNavMeshJump = nil
    end

    if localNavMeshJump then
        local progress = (currentTime - localNavMeshJump.startTime) / (localNavMeshJump.endTime - localNavMeshJump.startTime)
        local jumpVector = localNavMeshJump.endPosition - localNavMeshJump.startPosition
        local basePosition = localNavMeshJump.startPosition + jumpVector * progress
        localCharacter.transform.position = basePosition + NavMeshJumpOffset(progress, localNavMeshJump.distance)

        moveEulerAngles = EulerAnglesForVector(jumpVector)
        localCharacter.transform.eulerAngles = moveEulerAngles
    end

    local turnedAround = false
    local actualVelocity = playerVelocity

    if not localNavMeshJump and isInputActive then
        moveEulerAngles = EulerAnglesForVector(moveDirection)
        localCharacter.transform.eulerAngles = moveEulerAngles
        local fromPosition = GameManager.GetLocalPlayerPosition()
        local requestedStep = Time.deltaTime * playerVelocity
        local toPosition = fromPosition + requestedStep

        local hit, navData: NavMeshHit = NavMesh.SamplePosition(toPosition, 1.0, -1)
        toPosition = hit and navData.position or toPosition

        local playerDir = (toPosition - fromPosition)
        playerDir.y = 0
        playerDir = playerDir.normalized
        local dot = Vector3.Dot(playerDir, _lastLocalDirection)
        if dot < _turnAroundThreshold then
            turnedAround = true
        end

        localNavMeshAgent.enabled = true
        localNavMeshAgent:Warp(toPosition)

        local actualStep = localNavMeshAgent.nextPosition - fromPosition
        actualVelocity = actualStep / Time.deltaTime

        _lastLocalDirection = actualVelocity

        if nearbyMeshLink ~= nil then
            local moveVectorChange = 1 - actualStep.magnitude / requestedStep.magnitude
            local meshLinkVector = nearbyMeshLink.endPosition - nearbyMeshLink.startPosition
            local linkAngle = Vector3.Angle(requestedStep, meshLinkVector)

            if moveVectorChange > minLinkMoveStepChange and linkAngle < maxLinkAngle then
                PerformNavMeshJump(nearbyMeshLink.endPosition)
            end
        end
    end

    localCharacter.state = CalculateCharacterState(localEmote, localNavMeshJump, actualVelocity.magnitude, localPlayerInfo.anchorState)

    PlayMovementEmote(localCharacter, localEmote, localNavMeshJump, actualVelocity.magnitude, turnedAround)

    if (currentTime - lastMovementUpdateTime) > movementUpdateInterval then
        local playerPosition = GameManager.GetLocalPlayerPosition()
        RequestLocalPlayerMovementUpdate(playerPosition, actualVelocity, false)
    end
end

function CalculateCharacterState(emote, navMeshJump, movementSpeed, anchorState)
    if navMeshJump then
        return CharacterState.Jumping
    elseif movementSpeed >= runningSpeedThreshold then
        return CharacterState.Running
    elseif movementSpeed > 0 then
        return CharacterState.Walking
    elseif anchorState == 1 then
        return CharacterState.Walking
    elseif emote then
        return CharacterState.Emote
    else
        return CharacterState.Idle
    end
end

function PerformNavMeshJump(endPosition: Vector3)
    local startPosition = localCharacter.transform.position
    local distance = (endPosition - startPosition).magnitude
    local duration = distance / localNavMeshAgent.speed
    local startTime = Time.time
    local endTime = startTime + duration
    localNavMeshJump = {
        startPosition = startPosition,
        endPosition = endPosition,
        distance = distance,
        startTime = startTime,
        endTime = endTime,
    }
    localNavMeshAgent.enabled = false
    localEmote.activeEmote = JumpEmote(localNavMeshJump)
    PlayEmote(localCharacter, localEmote)
    navMeshJumpRequest:FireServer(startPosition, endPosition, duration)
end

function NavMeshJumpOffset(progress: number, distance: number)
    local yOffset = (1 - (progress * 2 - 1) * (progress * 2 - 1)) * distance / 3

    return Vector3.new(0, yOffset, 0)
end

function UpdateOtherPlayers()
    for playerId, playerData: PlayerInfo in pairs(_clientPlayers) do
        if client.localPlayer == nil or playerId == client.localPlayer.user.id or playerData.character == nil or playerData.ignoreUpdates then
            continue
        end

        if playerData.anchorState ~= AnchorState.None then
            continue
        end

        if playerData.tapToMove then
            if HasCompletedTapToMove(playerData) then
                StopTapToMove(playerData)
            else
                continue
            end
        end

        if playerData.navMeshJump then
            local jump = playerData.navMeshJump
            local progress = (Time.time - jump.startTime) / (jump.endTime - jump.startTime)

            if progress >= 1 then
                playerData.navMeshJump = nil
                playerData.movement.position = jump.endPosition
            else
                local positionChange = jump.endPosition - jump.startPosition
                playerData.movement.position = jump.startPosition + positionChange * progress + NavMeshJumpOffset(progress, jump.distance)
            end
        end

        local currentPos = playerData.character.transform.position
        -- Smooth the target itself (soft snapping)
        local currentNetPos = playerData.movement.position or currentPos
        if playerData.smoothVel == nil then
            playerData.smoothVel = Vector3.zero
        end

        local playerMoveSpeedMod = 1
        if playerData.character then
            _, speedMod = GetRunEmoteForCharacter(playerData.character)
            if speedMod then
                playerMoveSpeedMod = speedMod
            end
        end
        local newPos =
            Vector3.SmoothDamp(currentPos, currentNetPos, playerData.smoothVel, _smoothTime, _startingMovementSpeed * playerMoveSpeedMod, Time.deltaTime)

        if playerData.navMeshAgent and not playerData.navMeshJump then
            playerData.navMeshAgent:Warp(newPos)
        else
            playerData.character.transform.position = newPos
        end

        -- Use network velocity for animation to prevent extra steps when stopped
        local speed = playerData.movement.velocity.magnitude
        --local speed = playerData.smoothVel.magnitude
        if speed < 0.01 then
            speed = 0
        end

        if playerData.navMeshJump then
            playerData.character.transform.eulerAngles = EulerAnglesForVector(toPosition - fromPosition)
        elseif speed > 0 then
            playerData.character.transform.eulerAngles = EulerAnglesForVector(playerData.movement.velocity)
        end

        PlayMovementEmote(playerData.character, _clientPlayers[playerId].emote, playerData.navMeshJump, speed, false)
    end
end

-- even though movement can be in all kinds of directions, the xz plane seems to be the best for character angles, so we're ignoring y
function EulerAnglesForVector(vector: Vector3)
    if is2D then
        if vector.x >= 0 then
            return Vector3.new(0, 179, 0)
        else
            return Vector3.new(0, 181, 0)
        end
    else
        local angle = math.atan2(-vector.z, vector.x)
        local eulerAngle = angle / 2 / math.pi * 360 - 270
        return Vector3.new(0, eulerAngle, 0)
    end
end

function PlayFootstepSound()
    if not localCharacter or lastFootstepTime + footstepInterval > Time.time then
        return
    end

    lastFootstepTime = Time.time

    if localEmote.activeEmote and string.find(localEmote.activeEmote.id, WalkId) and footstepWalkSound then
        footstepWalkSound:Play()
    elseif localEmote.activeEmote and string.find(localEmote.activeEmote.id, RunId) and footstepRunSound then
        footstepRunSound:Play()
    end
end
-------------------------------------------------------------------------------
-- SERVER
-------------------------------------------------------------------------------
local _serverLastMovementUpdateTime: number = 0

local serverPlayers: {
    [string]: {
        player: Player,
        movement: {
            position: Vector3,
            velocity: Vector3,
        },
        idleEmote: string?,
        navMeshJump: {
            startTime: number,
            endTime: number,
            startPosition: Vector3,
            endPosition: Vector3,
        }?,
    },
} =
    {}
-- these fields are cleared once the update is sent, preventing unnecessary traffic
local playerMovementUpdate: { [string]: any } = {}
local hasPlayerMovementUpdate: boolean = false

function self:ServerAwake()
    releaseAnchor:Connect(HandleReleaseAnchor)
    requestAnchor.OnInvokeServer = HandleRequestAnchor
    scene.PlayerJoined:Connect(function(scene, player)
        serverPlayers[player.user.id] = {
            player = player,
            movement = {
                position = Vector3.zero,
                velocity = Vector3.zero,
            },
            navMeshJump = nil,
        }
        player.CharacterChanged:Connect(function(player, character)
            local position = character.transform.position
            local velocity = Vector3.zero
            serverPlayers[player.user.id].movement.position = position
            local moveData: PlayerMoveData = {
                position = position,
                velocity = velocity,
                anchor = nil,
                tapToMove = false,
            }
            playerMovementUpdate[player.user.id] = moveData

            playerInitializedEvent:FireClients(scene.players, player, position)
            initialPlayerDataEvent:FireClient(player, serverPlayers, anchors, Time.time)
        end)
    end)

    scene.PlayerLeft:Connect(function(scene, player)
        HandleReleaseAnchor(player)
        serverPlayers[player.user.id] = nil
        playerMovementUpdate[player.user.id] = nil
    end)

    movementUpdateRequest:Connect(function(player, position, velocity, tapToMove)
        serverPlayers[player.user.id].movement = {
            position = position,
            velocity = velocity,
        }
        serverPlayers[player.user.id].navMeshJump = nil

        playerMovementUpdate[player.user.id] = {
            position = position,
            velocity = velocity,
            anchor = GetAnchorForPlayer(player.user.id),
        }
        if tapToMove then
            playerMovementUpdate[player.user.id].tapToMove = true
        end
        hasPlayerMovementUpdate = true
    end)

    navMeshJumpRequest:Connect(function(player, startPosition, endPosition, duration)
        if not serverPlayers[player.user.id] then
            return
        end

        serverPlayers[player.user.id].navMeshJump = {
            startTime = Time.time,
            endTime = Time.time + duration,
            startPosition = startPosition,
            endPosition = endPosition,
        }
        navMeshJumpEvent:FireAllClients(player.user.id, serverPlayers[player.user.id].navMeshJump, Time.time)
    end)

    emoteRequest:Connect(function(player, emote, loop)
        if serverPlayers[player.user.id] then
            if loop then
                serverPlayers[player.user.id].idleEmote = emote
            else
                serverPlayers[player.user.id].idleEmote = nil
            end
        end

        emoteEvent:FireAllClients(player.user.id, emote, loop)
    end)
end

function self:ServerFixedUpdate()
    local currentTime = Time.time

    if (currentTime - _serverLastMovementUpdateTime) > movementUpdateInterval and hasPlayerMovementUpdate then
        local playerMovementUpdateCount = 0

        -- it turns out this is the only reliable way to count the number of values in this structure
        -- #playerMovementUpdate and table.getn(playerMovementUpdate) will not return the correct values
        -- when the keys aren't in order
        for _ in playerMovementUpdate do
            playerMovementUpdateCount = playerMovementUpdateCount + 1
        end

        for id, playerData in serverPlayers do
            local removedUpdate = playerMovementUpdate[id]
            local shouldSkipUpdate = playerMovementUpdateCount == 0 or (playerMovementUpdateCount == 1 and removedUpdate ~= nil)

            if shouldSkipUpdate then
                continue
            end

            -- removing the data the player already knows about to reduce traffic
            playerMovementUpdate[id] = nil
            movementUpdateEvent:FireClient(playerData.player, playerMovementUpdate)
            playerMovementUpdate[id] = removedUpdate
        end
        playerMovementUpdate = {}
        hasPlayerMovementUpdate = false
        _serverLastMovementUpdateTime = currentTime
    end
end

function SetAnchor(playerId: string, anchor: Anchor)
    local playerInfo = serverPlayers[playerId]
    if not playerInfo then
        return
    end

    -- Clear the ownership of the current anchor the player is on
    if playerInfo.anchor then
        anchors[playerInfo.anchor] = nil
    end

    -- Set the owner of the new anchor
    if anchor then
        anchors[anchor] = playerId
    end

    if playerInfo.character ~= nil then
        playerInfo.character.anchor = anchor
    end
end

function GetAnchorForPlayer(playerId: string): Anchor?
    for anchor, ownerId in anchors do
        if ownerId == playerId then
            return anchor
        end
    end
    return nil
end

local function ClearPlayersAnchors(playerId: string): boolean
    local cleared = false
    for anchor, ownerId in anchors do
        if ownerId == playerId then
            anchors[anchor] = nil
            cleared = true
        end
    end
    return cleared
end

function HandleRequestAnchor(player: Player, anchor: Anchor, anchorRequestId: number)
    -- Owned by another character?
    local currentOwner = anchors[anchor]
    if currentOwner and currentOwner ~= player then
        print("Anchor already owned by another player: ")
        return anchorRequestId, false
    end

    -- Already owned by the player's character?
    if currentOwner == player.character then
        print("Anchor already owned by this player: ")
        return anchorRequestId, true
    end

    ClearPlayersAnchors(player.user.id)
    SetAnchor(player.user.id, anchor)
    return anchorRequestId, true
end

function HandleReleaseAnchor(player: Player)
    local cleared = ClearPlayersAnchors(player.user.id)
    if cleared then
        playerReleasedAnchor:FireAllClients(player.user.id)
    end
end
