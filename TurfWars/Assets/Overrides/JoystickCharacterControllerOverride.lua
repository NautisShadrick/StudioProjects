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

-------------------------------------------------------------------------------
-- SERIALIZED
-------------------------------------------------------------------------------

--!SerializeField
local footstepWalkSound : AudioShader = nil

--!SerializeField
local footstepRunSound : AudioShader = nil

--!Tooltip("Keyboard and gamepad input used on Desktop clients")
--!SerializeField
local externalInputAction: InputActionReference = nil

--!Tooltip("The running emote will be used beyond this speed")
--!SerializeField
local runningSpeedThreshold: number = 5

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

--!Header("Thumbstick Configuration")
--!Tooltip("Hides the thumbstick on desktop platforms")
--!SerializeField
local hideOnDesktop: boolean = false
--!Tooltip("Hides the thumbstick when keyboard or gamepad input is active")
--!SerializeField
local hideOnExternalInput: boolean = true
--!Tooltip("Makes the thumbstick stay in one spot on the screen")
--!SerializeField
local anchorThumbstick: boolean = false
--!Tooltip("Prevents the thumbstick from being dragged on screen")
--!SerializeField
local preventDraggingThumbstick: boolean = false


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


-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

local RequestLocalPlayerMovementUpdate: (Vector3, Vector3) -> () = nil

movementEnabled = true

function SetLocalPlayerPosition(position: Vector3)
	if RequestLocalPlayerMovementUpdate then
		RequestLocalPlayerMovementUpdate(position, Vector3.zero)
	end
end

-------------------------------------------------------------------------------
-- CLIENT
-------------------------------------------------------------------------------

type NavMeshJumpInfo = {
	startTime: number,
	endTime: number,
	distance: number,
	startPosition: Vector3,
	endPosition: Vector3
}

type EmoteInfo = {
	idleEmote: string?,
	activeEmote: {
		id: string?,
		speed: number?
	}
}

type PlayerInfo = {
	movement: {
		position: Vector3,
		velocity: Vector3
	},
	character: Character?,
	navMeshAgent: NavMeshAgent?,
	navMeshJump: NavMeshJumpInfo?,
	emote: EmoteInfo
}

function Client()
	-- other player data
	local players: {[string]: PlayerInfo} = {}

	-- local player data
	local movementUpdateInterval: number = 0.1
	local lastMovementUpdateTime: number = 0
	local lastPlayerPosition: Vector3 = Vector3.zero
	local lastPlayerVelocity: Vector3 = Vector3.zero
	local localCharacter: Character = nil
	local localNavMeshAgent: NavMeshAgent = nil
	local localEmote: EmoteInfo = { idleEmote = nil, activeEmote = nil }
	local localNavMeshJump: NavMeshJumpInfo? = nil

	-- input
	local uiThumbstick: UIThumbstick = nil

	-- mesh links
	local meshLinks: {[number]: {[number]: {[number]: {OffMeshLink}}}} = {}
	local reverseMeshLinks: {[number]: {[number]: {[number]: {OffMeshLink}}}} = {}
	local nearbyMeshLink: {link: OffMeshLink, startPosition: Vector3, endPosition: Vector3}? = nil

	-- footsteps
	local footstepEvent = "footstep"
	local footstepInterval = 0.1
	local lastFootstepTime = 0

	RequestLocalPlayerMovementUpdate = function (position: Vector3, velocity: Vector3)
		if position ~= lastPlayerPosition or velocity ~= lastPlayerVelocity then
			movementUpdateRequest:FireServer(position, velocity)
			lastPlayerPosition = position
			lastPlayerVelocity = velocity
			lastMovementUpdateTime = Time.time
		end

		if client.localPlayer.character then
			client.localPlayer.character.transform.position = position
		end
	end

	function self:ClientAwake()
		scene.PlayerJoined:Connect(function(scene, player)
			InitializePlayerData(player)

	        player.CharacterChanged:Connect(function(player, character)
				if player.isLocal then
					localCharacter = character

					if character then
						localNavMeshAgent = character.gameObject:GetComponent(NavMeshAgent)

						character.AnimationEvent:Connect(function(evt)
							if evt.name == footstepEvent then
								PlayFootstepSound()
							end
						end)
					end
				else
					playerData = players[player.id]

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

				PlayEmote(character, players[player.id].emote)
	        end)
	    end)

		scene.PlayerLeft:Connect(function(scene, player)
			players[player.id] = nil
		end)

		playerInitializedEvent:Connect(function (player, position)
			InitializePlayerData(player)
	    	players[player.id].movement.position = position
		end)

		initialPlayerDataEvent:Connect(function (remotePlayers, serverTime)
			for playerId, remotePlayerData in pairs(remotePlayers) do
				local playerData = players[playerId]
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
						distance = (jump.endPosition - jump.startPosition).magnitude
					}
				end

				players[playerId] = {
					movement = {
						position = remotePlayerData.movement.position,
						velocity = remotePlayerData.movement.velocity
					},
					character = character,
					emote = {
						idleEmote = remotePlayerData.idleEmote,
						activeEmote = MovementEmote(navMeshJump, speed)
					},
					navMeshJump = navMeshJump
				} :: PlayerInfo

				PlayEmote(character, players[playerId].emote)
			end
		end)

	    movementUpdateEvent:Connect(function (playerMovement)
			for playerId, movement in pairs(playerMovement) do
	            if playerId == client.localPlayer.id then
	                continue
	            end

	            local playerData = players[playerId]

	            if playerData ~= nil then
					if movement then
						for position, velocity in movement do
							playerData.movement.position = position
							playerData.movement.velocity = velocity
						end
					else
						playerData.movement.position = Vector3.zero
						playerData.movement.velocity = Vector3.zero
					end
	            end
	        end

			for playerId, playerData in pairs(players) do
				if not playerMovement[playerId] then
					playerData.movement.velocity = Vector3.zero
				end
			end
	    end)

		UI.EmoteSelected:Connect(function(emote, loop)
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
			local player = players[playerId]
			if not player or not player.character then
				return
			end

			-- if you're starting an emote, you cannot be moving
			player.movement.velocity = Vector3.zero

			if (not emote or emote == "" or emote == "idle") then
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

		navMeshJumpEvent:Connect(function (playerId, jump, serverTime)
			local player = players[playerId]
			if not player or not player.character or jump.endTime < serverTime then
				return
			end

			player.navMeshJump = {
				startTime = Time.time,
				endTime = Time.time + (jump.endTime - jump.startTime),
				startPosition = jump.startPosition,
				endPosition = jump.endPosition,
				distance = (jump.endPosition - jump.startPosition).magnitude
			}
		end)

		SetupMeshLinks()
		SetupExternalInputAction()
		SetupThumbstickControls()
	end

	function InitializePlayerData(player)
		if not players[player.id] then
			players[player.id] = {
				movement = {
					position = Vector3.zero,
					velocity = Vector3.zero,
				},
				character = nil,
				navMeshJump = nil,
				emote = {
					idleEmote = nil,
					activeEmote = nil
				}
			} :: PlayerInfo
		end
	end

	function MovementEmote(navMeshJump, movementSpeed)
		if navMeshJump ~= nil then
			return JumpEmote(navMeshJump)
		elseif movementSpeed >= runningSpeedThreshold then
			return { id = "run", speed = nil }
		elseif movementSpeed > 0 then
			return { id = "walk", speed = nil }
		else
			return nil
		end
	end

	function JumpEmote(navMeshJump)
		local baseSpeed = 0.8
		return { id = "jump", speed = baseSpeed / (navMeshJump.endTime - Time.time) }
	end

	function PlayMovementEmote(character, emote, navMeshJump, movementSpeed)
		local movementEmote = MovementEmote(navMeshJump, movementSpeed)
		local movementEmoteId = movementEmote and movementEmote.id
		local emoteId = emote.activeEmote and emote.activeEmote.id
		if movementEmoteId ~= emoteId then
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
			local isMovementEmote = emoteId == "run" or emoteId == "walk" or emoteId == "jump"

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
		local d = maxDistance;
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

	function SetupThumbstickControls()
		uiThumbstick = UIThumbstick.new()
		uiThumbstick:AddToClassList("movement-thumbstick")
		uiThumbstick.isAnchored = anchorThumbstick
		uiThumbstick.preventDragging = preventDraggingThumbstick
		if hideOnDesktop then
			uiThumbstick:AddToClassList("hide-on-desktop")
		end
		CenterThumbstick()
		UI.aboveChat:Add(uiThumbstick)
	end

	function CenterThumbstick()
		if uiThumbstick.worldBound.width > 0 then
			local container = uiThumbstick:ElementAt(0)
			local containerHeight = uiThumbstick.worldBound.height
			local containerWidth = container.worldBound.width
			local parentHeight = uiThumbstick.worldBound.height
			local parentWidth = uiThumbstick.worldBound.width
			local adjustedBottom = (parentHeight - containerHeight) / 2
			local adjustedLeft = (parentWidth - containerWidth) / 2

			container.style.bottom = StyleLength.new(Length.new(adjustedBottom))
			container.style.left = StyleLength.new(Length.new(adjustedLeft))
		else
			defer(CenterThumbstick)
		end
	end

	function self:ClientUpdate()
		UpdateLocalPlayer()
		UpdateOtherPlayers()
		UpdateNearbyMeshEntities()
	end

	function GetEntries(entries, x, y, z): {any}
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
		local x = localCharacter.transform.position.x // maxLinkDistance
		local y = localCharacter.transform.position.y // maxLinkDistance
		local z = localCharacter.transform.position.z // maxLinkDistance

		if nearbyMeshLink and not IsNextToMeshEntity(nearbyMeshLink.startPosition) then
			nearbyMeshLink = nil
		end

		if not nearbyMeshLink then
			for _, link in GetEntries(meshLinks, x, y, z) do
				if IsNextToMeshEntity(link.startTransform.position) then
					nearbyMeshLink = {
						link = link,
						startPosition = link.startTransform.position,
						endPosition = link.endTransform.position
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
						endPosition = link.startTransform.position
					}
					break
				end
			end
		end
	end

	function IsNextToMeshEntity(linkPosition: Vector3)
		return localCharacter and (localCharacter.transform.position - linkPosition).magnitude < maxLinkDistance
	end

	function InputDirection()
		if not movementEnabled then
			return Vector2.zero
		elseif uiThumbstick and uiThumbstick.movementDirection ~= Vector2.zero then
			return uiThumbstick.movementDirection
		elseif externalInputAction and externalInputAction.action then
			return externalInputAction.action:ReadVector2()
		else
			return Vector2.zero
		end
	end

	function UpdateLocalPlayer()
		-- for some reason needed for virtual players
		if not uiThumbstick then return end

		local inputDirection = InputDirection()
		local isJoystickActive = inputDirection.magnitude > 0

		if hideOnExternalInput then
			uiThumbstick.visible = externalInputAction.action:ReadVector2() == Vector2.zero
		end

		if is2D then
			moveDirection = Vector3.new(inputDirection.x, inputDirection.y, 0)
		else
			local angle = client.mainCamera.transform.eulerAngles.y / 180 * Mathf.PI
			local s = Mathf.Sin(angle)
			local c = Mathf.Cos(angle)
			local x = inputDirection.y * s + inputDirection.x * c
			local z = inputDirection.y * c - inputDirection.x * s
			moveDirection = Vector3.new(x, 0, z)
		end

		local playerVelocity = moveDirection * localNavMeshAgent.speed
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

		local actualVelocity = playerVelocity

		if not localNavMeshJump and isJoystickActive then
			moveEulerAngles = EulerAnglesForVector(moveDirection)
			localCharacter.transform.eulerAngles = moveEulerAngles
			local fromPosition = localCharacter.transform.position
			local requestedStep = Time.deltaTime * playerVelocity
			local toPosition = fromPosition + requestedStep

			localNavMeshAgent.enabled = true
			localNavMeshAgent:Warp(toPosition)

			local actualStep = localNavMeshAgent.nextPosition - fromPosition
			actualVelocity = actualStep / Time.deltaTime

			if nearbyMeshLink ~= nil then
				local moveVectorChange = 1 - actualStep.magnitude / requestedStep.magnitude;
				local meshLinkVector = nearbyMeshLink.endPosition - nearbyMeshLink.startPosition
				local linkAngle = Vector3.Angle(requestedStep, meshLinkVector)

				if moveVectorChange > minLinkMoveStepChange and linkAngle < maxLinkAngle then
					PerformNavMeshJump(nearbyMeshLink.endPosition)
				end
			end
		end

		localCharacter.state = CalculateCharacterState(localEmote, localNavMeshJump, actualVelocity.magnitude)

		PlayMovementEmote(localCharacter, localEmote, localNavMeshJump, actualVelocity.magnitude)

		if (currentTime - lastMovementUpdateTime) > movementUpdateInterval then
			local playerPosition = localCharacter.transform.position
			RequestLocalPlayerMovementUpdate(playerPosition, actualVelocity)
		end
	end

	function CalculateCharacterState(emote, navMeshJump, movementSpeed)
		if navMeshJump then
			return CharacterState.Jumping
		elseif movementSpeed >= runningSpeedThreshold then
			return CharacterState.Running
		elseif movementSpeed > 0 then
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
			endTime = endTime
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
	    for playerId, playerData in pairs(players) do
	        if client.localPlayer == nil or playerId == client.localPlayer.id or playerData.character == nil then
	            continue
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

			if not playerData.navMeshJump then
				playerData.movement.position = playerData.movement.position + playerData.movement.velocity * Time.deltaTime
			end

			local speed = playerData.movement.velocity.magnitude
			local fromPosition = playerData.character.transform.position
			local toPosition = 0.9 * fromPosition + 0.1 * playerData.movement.position

			if not playerData.navMeshJump and playerData.navMeshAgent then
				playerData.navMeshAgent.enabled = true
				playerData.navMeshAgent:Warp(toPosition)
			else
				if playerData.navMeshAgent then
					playerData.navMeshAgent.enabled = false
				end
				playerData.character.transform.position = toPosition
			end

			if playerData.navMeshJump then
				playerData.character.transform.eulerAngles = EulerAnglesForVector(toPosition - fromPosition)
			elseif speed > 0 then
				playerData.character.transform.eulerAngles = EulerAnglesForVector(playerData.movement.velocity)
			end

			PlayMovementEmote(playerData.character, players[playerId].emote, playerData.navMeshJump, speed)
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

		if localEmote.activeEmote and localEmote.activeEmote.id == "walk" and footstepWalkSound then
			footstepWalkSound:Play()
		elseif localEmote.activeEmote and localEmote.activeEmote.id == "run" and footstepRunSound then
			footstepRunSound:Play()
		end
	end
end

-------------------------------------------------------------------------------
-- SERVER
-------------------------------------------------------------------------------

function Server()
	local movementUpdateInterval: number = 0.1
	local lastMovementUpdateTime: number = 0

	local players: {[string]: {
		player: Player,
		movement: {
			position: Vector3,
			velocity: Vector3
		},
		idleEmote: string?,
		navMeshJump: {
			startTime: number,
			endTime: number,
			startPosition: Vector3,
			endPosition: Vector3
		}?
	}} = {}
	-- these fields are cleared once the update is sent, preventing unnecessary traffic
	local playerMovementUpdate: {[string]: {Vector3}} = {}
	local hasPlayerMovementUpdate: boolean = false

	function self:ServerAwake()
	    scene.PlayerJoined:Connect(function(scene, player)
			players[player.id] = {
				player = player,
				movement = {
					position = Vector3.zero,
					velocity = Vector3.zero
				},
				navMeshJump = nil
			}
			player.CharacterChanged:Connect(function(player, character)
				local position = character.transform.position
				local velocity = Vector3.zero
				players[player.id].movement.position = position
				playerMovementUpdate[player.id] = {[position] = velocity}

				playerInitializedEvent:FireAllClients(player, position)
				initialPlayerDataEvent:FireClient(player, players, Time.time)
			end)
	    end)

		scene.PlayerLeft:Connect(function (scene, player)
			players[player.id] = nil
			playerMovementUpdate[player.id] = nil
		end)

	    movementUpdateRequest:Connect(function (player, position, velocity)
			players[player.id].movement = {
				position = position,
				velocity = velocity
			}
			players[player.id].navMeshJump = nil

			playerMovementUpdate[player.id] = {[position] = velocity}
			hasPlayerMovementUpdate = true
	    end)

		navMeshJumpRequest:Connect(function (player, startPosition, endPosition, duration)
			if not players[player.id] then
				return
			end

			players[player.id].navMeshJump = {
				startTime = Time.time,
				endTime =  Time.time + duration,
				startPosition = startPosition,
				endPosition = endPosition
			}
			navMeshJumpEvent:FireAllClients(player.id, players[player.id].navMeshJump, Time.time)
		end)

		emoteRequest:Connect(function (player, emote, loop)
			if players[player.id] then
				if loop then
					players[player.id].idleEmote = emote
				else
					players[player.id].idleEmote = nil
				end
			end

			emoteEvent:FireAllClients(player.id, emote, loop)
		end)
	end

	function self:ServerFixedUpdate()
		local currentTime = Time.time

		if (currentTime - lastMovementUpdateTime) > movementUpdateInterval and hasPlayerMovementUpdate then
			local playerMovementUpdateCount = 0

			-- it turns out this is the only reliable way to count the number of values in this structure
			-- #playerMovementUpdate and table.getn(playerMovementUpdate) will not return the correct values
			-- when the keys aren't in order
			for _ in playerMovementUpdate do
				playerMovementUpdateCount = playerMovementUpdateCount + 1
			end

			for id, playerData in players do
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
			lastMovementUpdateTime = currentTime
		end
	end
end

-------------------------------------------------------------------------------
-- Client/Server switch
-------------------------------------------------------------------------------

if server then
    Server()
else
    Client()
end
