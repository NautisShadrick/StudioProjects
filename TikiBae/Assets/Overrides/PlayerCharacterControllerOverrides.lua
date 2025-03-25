--[[
	
	Copyright (c) 2024 Pocket Worlds

	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely.
	
--]] 

--!Type(Module)

-------------------------------------------------------------------------------
-- Types
-------------------------------------------------------------------------------

type PlayerState =
{
	emote : string,
	anchor : Anchor
}

type PlayerInfo = 
{
	player : Player,
	state : PlayerState,
	stateValue : TableValue,
	lastFootStep : number
}

type MoveToCallback = (character: Character, completed : boolean) -> ()
type PlayerJoinedCallback = (playerInfo : PlayerInfo) -> ()
type CharacterChangedCallback = (player : Player, character : Character) -> ()

-------------------------------------------------------------------------------
-- Properties
-------------------------------------------------------------------------------

--!SerializeField
local movementIndicator : GameObject = nil

--!SerializeField
local longPressSound : AudioShader = nil

--!SerializeField
local footstepWalkSound : AudioShader = nil

--!SerializeField
local footstepRunSound : AudioShader = nil

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------

options = { }

if client then
	-- Whether or not the PlayerController is enabled
	options.enabled = true

	-- Whether or not tap to move is enabled
	options.tapToMoveEnabled = true

	-- Whether or not tap handlers are enabled
	options.tapHandlersEnabled = true
    
	-- True if long press for mini-profile should be enabled
	options.enableLongPress = true
	
	-- The mask to use for raycasting
	options.tapMask =
		bit32.bor(
			bit32.lshift(1, LayerMask.NameToLayer("Default")),
			bit32.lshift(1, LayerMask.NameToLayer("Character")),
			bit32.lshift(1, LayerMask.NameToLayer("Tappable")))
		
	-- Long press options
	options.characterLongPress =
	{
		enabled = true,
		height = 0.5,
		bounceDuration = 0.3
	}
end

-------------------------------------------------------------------------------
-- Private
-------------------------------------------------------------------------------

local moveRequest = Event.new("MoveRequest")
local moveEvent = Event.new("MoveEvent")
local emoteRequest = Event.new("EmoteRequest")
local emoteEvent = Event.new("EmoteEvent")
local requestAnchor = RemoteFunction.new("RequestAnchor")
local releaseAnchor = Event.new("ReleaseAnchor")
local players = {}
local anchors : {[Anchor] : Player} = {}
local movementIndicatorInstance : GameObject? = nil
local footstepEvent = "footstep"
local footstepEventThreshold = 0.1
local activeAnchorRequestId : number = 1

---
--- Track a player joining
---
local function HandlePlayerJoinedScene(
	scene : Scene,
	player : Player,
	playerJoinedCallback : PlayerJoinedCallback?,
	characterChangedCallback : CharacterChangedCallback?)

	local playerInfo = 
	{
		player = player,
		state = { emote = "", anchor = nil },
		stateValue = TableValue.new("state" .. tostring(player.id)),
		lastFootStep = Time.time
	} :: PlayerInfo
	
	players[player] = playerInfo
	
	if playerJoinedCallback then
		playerJoinedCallback(playerInfo)
	end

	if characterChangedCallback then
		player.CharacterChanged:Connect(characterChangedCallback)
	end
end

---
--- Handle a player leaving the scene
----
local function HandlePlayerLeftScene(scene : Scene, player : Player)
	-- If a player on an anchor leaves then free up the anchor
	local playerInfo = players[player]
	if not playerInfo then
		return
	end

	if server and playerInfo.state.anchor ~= nil then		
		anchors[playerInfo.state.anchor] = nil
	end

	-- Remove the player from the player info table
	players[player] = nil
end

---
--- Track players in the `players` table using `player` as the key  
---
local function TrackPlayers(playerJoinedCallback, characterChangedCallback)
	scene.PlayerJoined:Connect(function (scene : Scene, player : Player) 
		HandlePlayerJoinedScene(scene, player, playerJoinedCallback, characterChangedCallback)
	end)		
	scene.PlayerLeft:Connect(HandlePlayerLeftScene)
end

-------------------------------------------------------------------------------
-- CLIENT (Private)
-------------------------------------------------------------------------------

local longPressCharacter : Character? = nil;
local longPressTween : Tween? = nil;

---
--- Play a footstep sound
---
local function PlayFootstepSound(playerInfo : PlayerInfo)
	local c = playerInfo.player.character
	if not c then return end
	if playerInfo.lastFootStep + footstepEventThreshold > Time.time then return end

	playerInfo.lastFootStep = Time.time

	if c.state == CharacterState.Walking and footstepWalkSound then
		footstepWalkSound:Play(1,1)
	elseif c.state == CharacterState.Running and footstepRunSound then
		footstepRunSound:Play(1,1)
	end
end

---
--- Show the movement indicator at a given position
---
local function ShowMovementIndicator(point : Vector3)
	-- Create the movement indicator if we have not created it yet
	if not movementIndicatorInstance and movementIndicator then
		movementIndicatorInstance = Object.Instantiate(movementIndicator) :: GameObject?
		movementIndicatorInstance:SetActive(false)
	end
	
	if movementIndicatorInstance then
		movementIndicatorInstance.transform.position = point
		movementIndicatorInstance:SetActive(true)
	end
end

---
--- Hide the movement indicator
---
local function HideMovementIndicator()
	if movementIndicatorInstance then
		movementIndicatorInstance:SetActive(false)
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
local function RequestAnchor(playerInfo : PlayerInfo, anchor : Anchor, callback : (boolean) -> ())
	activeAnchorRequestId += 1
	local anchorRequestId = activeAnchorRequestId
	requestAnchor:InvokeServer(anchor, anchorRequestId, function(serverAnchorRequestId, result)
		-- If a new anchor request came after the last then skip this
		if serverAnchorRequestId ~= activeAnchorRequestId then return end
		callback(result)
	end)
end

--- Move a character to a given point using path finding
-- @param character Character to move
-- @param point World position to move the character to
-- @param areaMask Pathfinding area mask to use to move the character
-- @param distance Optional distance away from the point that character should move
-- @param callback Callback to call when the move is finished
-- @return True if a path was found and the character is moving
local function LocalMoveTo(
	character : Character,
	point : Vector3,
	areaMask : number,
	distance : number,
	anchor: Anchor?,
	callback : MoveToCallback?
    ) : boolean

	if not options.tapToMoveEnabled then return false end

	CancelAnchorRequest()

	if not character then return false end
	if not character.player or not character.player.isLocal then
		error("MoveTo should only be called on the local player's character")
		return false
	end

	local moved = false

	if anchor then
		moved = character:MoveToAnchor(anchor, areaMask, callback :: (any) -> (any))
		if not moved then
			releaseAnchor:FireServer(anchor)
		end
	elseif distance > 0 then
		moved = character:MoveWithinRangeOf(point, distance, areaMask, callback :: (any) -> (any))
	else
		moved = character:MoveTo(point, areaMask, callback :: (any) -> (any))
	end

	if (moved) then
		local indicatorPosition = character.destination			
		if anchor then
			indicatorPosition = anchor.transform.position
		end

		ShowMovementIndicator(indicatorPosition)

		moveRequest:FireServer(character.destination, anchor)
	end

	return moved
end

---
--- Handle clicking to move but failing due to one or more conditions
---
local function FailedMove(character : Character)
	if not character then return end

	if not character.player or not character.player.isLocal then
		error("FailedMove must only be called for the local player's character")
		return;
	end

	LocalMoveTo(character, character.transform.position, -1, 0, nil)
	character:PlayEmote("emote-no", false)
end

---
--- Perform a raycast into the world from the camera using a screen position
---
local function RayCast(position : Vector2)
	local camera = scene.mainCamera
	if not camera or not camera.isActiveAndEnabled then return false end

	-- Create a ray from the screen position
	local ray = camera:ScreenPointToRay(Vector3.new(position.x, position.y, 0))

	-- If this is an imported 2D room, use the iso room raycast implementation
	if client.isoRoomContext ~= nil then
		return client.isoRoomContext:Raycast(ray, options.tapMask)
	end
	-- Cast a ray from the camera into the world
	return Physics.Raycast(ray, 1000, options.tapMask)
end

---
--- Handles a tap event event on a specific tap handler
---
local function HandleTapOnTapHandler(playerInfo: PlayerInfo, handler : TapHandler, tapPosition: Vector3, checkAnchors : boolean, anchor: Anchor?) : ()

	if not options.tapHandlersEnabled then return end

	local character = playerInfo.player.character
	-- Optional anchor
	if checkAnchors and not anchor then
		anchor = handler:GetClosestAnchor(tapPosition)
		
		if anchor then
			if not options.tapToMoveEnabled then return end

			RequestAnchor(playerInfo, anchor, function (result)
				if not result then
					anchor = nil
				end
				HandleTapOnTapHandler(playerInfo, handler, tapPosition, false, anchor)
			end)			
			return
		end
	end	

	-- Where should we move to?
	local targetPosition = handler.moveTarget
	if anchor then 
		targetPosition = anchor.transform.position
	end	

	-- If within range then perform it now
	if Vector3.Distance(targetPosition, character.transform.position) <= handler.distance then
		if anchor and handler.moveTo then
			LocalMoveTo(character, targetPosition, -1, handler.distance, anchor)   
		end
		handler:Perform(tapPosition)
	elseif handler.moveTo then
		-- Move the character to the handler and perform the action when arriving
		LocalMoveTo(character, targetPosition, -1, handler.distance, anchor, function(character)
			handler:Perform(tapPosition)
		end)
	end
end

---
--- Searches the parent hierarchy of the given transform for a tap handler component
---
local function GetTapHandler (transform : Transform) : TapHandler?
	while transform do

		local tapHandler = transform:GetComponent(TapHandler)
		if tapHandler and tapHandler.enabled then
			return tapHandler
		end

		transform = transform.parent
	end

	return nil
end

---
--- Handles a tap event
---
local function HandleTap(tap : TapEvent)
	-- If the player controller is disabled then do not handle taps
	if not options.enabled then return end

	-- If the local player does not have a character then do not handle taps
	if not client.localPlayer then return end
	local character = client.localPlayer.character
	if not character then return end

	-- Cast a ray from the camera into the world
	local success, hit = RayCast(tap.position)
	if not success or not hit.collider then return end

	-- Check for a handler
	local handler = GetTapHandler(hit.collider.transform)
	if handler then 
		HandleTapOnTapHandler(players[client.localPlayer], handler, hit.point, true)
		return
	end		

	-- Characters should block movement taps
	if hit.collider.gameObject:GetComponentInParent(Character) then return end

	-- Attempt to move the local character
	LocalMoveTo(character, hit.point, -1, 0, nil, function() end)	
end

---
--- Handles the long press began event 
---
local function HandleLongPressBegan(evt : LongPressBeganEvent)
	if not options.enableLongPress then
		return
	end

	-- Cast a ray from the camera into the world
	local success, hit = RayCast(evt.position)
	if (not success or not hit.collider) then
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

---
--- Handles the long press continue event
---
local function HandleLongPressContinue(evt : LongPressContinueEvent)
	if not longPressCharacter then return end

	local height = Easing.Sine(evt.progress) * options.characterLongPress.height
	longPressCharacter.renderPosition = Vector3.new(0,height, 0)
end

---
--- Handles the long press ended event
---
local function HandleLongPressEnded(evt : LongPressEndedEvent)
	if not longPressCharacter then return end

	local character = longPressCharacter
	longPressCharacter = nil

	-- always return back to start
	longPressTween = character:TweenRenderPositionTo(Vector3.zero)
		:EaseOutBounce(1, 3)
		:Duration(options.characterLongPress.bounceDuration * evt.progress)
		:Play()

	if not evt.cancelled then
		if longPressSound then
			longPressSound:Play(1,1)
		end
		UI:OpenMiniProfile(character.player)
	end
end	

---
--- Handle a move event for a player from the server
---
local function HandleMoveEvent(player : Player, point : Vector3, anchor: Anchor)
	local character = player.character

	-- move for local player is already handled
	if player.isLocal or character == nil then return end

	player.character.usePathfinding = true

	local moved = false
	if anchor then
		moved = player.character:MoveToAnchor(anchor, -1)
	else
		moved = player.character:MoveTo(point, -1)
	end

	-- If the move failed we still need the character to end up at their destination
	-- so we will teleport them instead.
	if not moved then
		if anchor then
			character:TeleportToAnchor(anchor)
		else
			character:Teleport(point)
		end
	end
end

---
--- Handle the player's state changing
---
local function HandlePlayerStateChanged(playerInfo : PlayerInfo, newState : PlayerState, oldState: PlayerState)
	playerInfo.state = newState :: PlayerState

	local oldAnchor = nil;
	if (oldState) then oldAnchor = oldState.anchor end

	-- Handle emote changing
	local character = playerInfo.player.character
	if character and (not oldState or newState.emote ~= oldState.emote) then
		local emote = newState.emote
		if emote and emote ~= "" then
			character:PlayEmote(emote, true)
		else
			character:StopEmote()
		end
	end

	-- Handle initial anchor state
	if character and (not oldState and newState.anchor) then
		character:TeleportToAnchor(newState.anchor)
	end
end

---
--- Handle a player joining on the client
---
local function HandlePlayerJoinedClient(playerInfo : PlayerInfo)
	playerInfo.stateValue.Changed:Connect(function (newState, oldState)
		HandlePlayerStateChanged(playerInfo, newState :: PlayerState, oldState :: PlayerState)
	end)
end

---
--- Handle the players character state changing
---
local function HandleCharacterStateChanged(playerInfo: PlayerInfo, newState : number, oldState : number)
	local player = playerInfo.player
	if player.isLocal then
		local wasMoving = oldState == CharacterState.Walking or oldState == CharacterState.Running or oldState == CharacterState.Jumping
		local isMoving = newState == CharacterState.Walking or newState == CharacterState.Running or newState == CharacterState.Jumping
		if wasMoving and not isMoving then
			PlayFootstepSound(playerInfo)
		end

		if not isMoving then
			HideMovementIndicator()
		end
	end

	-- When returning back to idle if there is a looping emote play it
	if newState == CharacterState.Idle and oldState ~= CharacterState.Idle then
		local emote = playerInfo.state.emote
		if emote ~= "" then
			player.character:PlayEmote(emote, true)
		end
	end
end	

---
--- Handle a move event for a player from the server
---
local function HandlePlayerCharacterChanged(player : Player, character : Character)
	local playerInfo = players[player]
	if not playerInfo then return end

	character.AnchorChanged:Connect(function (newAnchor, oldAnchor)
		if not oldAnchor then return end
		releaseAnchor:FireServer(oldAnchor)
	end)

	character.StateChanged:Connect(function(newState, oldState)
		HandleCharacterStateChanged(playerInfo, newState, oldState)
	end)

	-- Handle footstep sounds
	if player.isLocal and player.character then
		local character = player.character
		character.AnimationEvent:Connect(function(evt)
			if evt.name == footstepEvent then
				PlayFootstepSound(playerInfo)
			end
		end)
	end

	local anchor = playerInfo.state.anchor
	if anchor then
		character:TeleportToAnchor(anchor)
	end
end

---
--- Handle client awake
---
function self:ClientAwake()
	-- Listen for an emote being selected in the UI and request the emote from the server
	UI.EmoteSelected:Connect(function(emote, loop)
		emoteRequest:FireServer(emote, loop)
	end)

	-- Listen for a one time emote to play on any character
	emoteEvent:Connect(function(player, emote)
		if player.character and emote and emote ~= "" then
			player.character:PlayEmote(emote, false)
		end
	end)

	Input.LongPressBegan:Connect(HandleLongPressBegan)
	Input.LongPressContinue:Connect(HandleLongPressContinue)	
	Input.LongPressEnded:Connect(HandleLongPressEnded)
	Input.Tapped:Connect(HandleTap)

	moveEvent:Connect(HandleMoveEvent)
	
	TrackPlayers(HandlePlayerJoinedClient, HandlePlayerCharacterChanged)
end

-------------------------------------------------------------------------------
-- SERVER
-------------------------------------------------------------------------------

---
--- Set the looping emote for a player
---
local function SetLoopingEmote(playerInfo: PlayerInfo, emote : string)
	if emote == playerInfo.state.emote then return end

	-- Update local copy
	playerInfo.state.emote = emote

	-- Update the acutal value to synchronize to clients
	playerInfo.stateValue.value = playerInfo.state
end

---
--- Set the current anchor for the player
---
local function SetAnchor(playerInfo: PlayerInfo, anchor: Anchor)
	if anchor == playerInfo.state.anchor then return end

	-- Clear the ownership of the current anchor the player is on
	if playerInfo.state.anchor then
		anchors[playerInfo.state.anchor] = nil
	end

	-- Set the owner of the new anchor
	if anchor then
		anchors[anchor] = playerInfo.player
	end

	-- Update local copy
	playerInfo.state.anchor = anchor

	if playerInfo.player ~= nil and playerInfo.player.character ~= nil then
		playerInfo.player.character.anchor = anchor
	end

	-- Update the actual value to synchronize to clients
	playerInfo.stateValue.value = playerInfo.state
end

---
--- Handle a request to move a player from the client
---
local function HandleMoveRequest(player : Player, point : Vector3, anchor: Anchor)
	-- Validate the player and character
	if not player or not player.character then return end

	-- Ensure any new players that join the scene will see the player at their final destination
	local playerInfo = players[player]
	local character = player.character
	player.character.gameObject.transform.position = point

	SetAnchor(playerInfo, anchor)

	-- Forward the move on to all clients now
	moveEvent:FireAllClients(player, point, anchor)
end

---
--- Handle a request to play an emote from the client
---
local function HandleEmoteRequest(player : Player, emote : string, loop : boolean)
	if not player.character then return end

	local playerInfo = players[player]
	if playerInfo == nil then return end

	-- Stop the emote?
	if (emote == "") then
		SetLoopingEmote(playerInfo, "")
		return
	end

	-- If looping then set the emote value
	if loop then
		SetLoopingEmote(playerInfo, emote)
	-- Otherwise clear the emote value and play a one time emote
	else
		SetLoopingEmote(playerInfo, "")
		emoteEvent:FireAllClients(player, emote);
	end			
end

local function HandleRequestAnchor(player : Player, anchor : Anchor, anchorRequestId : number)
	-- Owned by another character?
	local currentOwner = anchors[anchor]
	if currentOwner and currentOwner ~= player then
		return anchorRequestId, false
	end

	-- Already owned by the player's character?
	if currentOwner == player.character then
		return anchorRequestId, true
	end

	SetAnchor(players[player], anchor)
	return anchorRequestId, true
end

local function HandlePlayerJoinedServer(playerInfo : PlayerInfo)
	playerInfo.stateValue.value = playerInfo.state
end

local function HandleReleaseAnchor(player : Player, anchor : Anchor)
	if anchors[anchor] == player then
		anchors[anchor] = nil
	end
end

---
--- Handle server awake
---
function self:ServerAwake()
	moveRequest:Connect(HandleMoveRequest)
	emoteRequest:Connect(HandleEmoteRequest)
	releaseAnchor:Connect(HandleReleaseAnchor)
	requestAnchor.OnInvokeServer = HandleRequestAnchor

	TrackPlayers(HandlePlayerJoinedServer)
end

-------------------------------------------------------------------------------
-- Public
-------------------------------------------------------------------------------

---
--- Returns true if the given anchor is occupied
---
function IsAnchorOccupied(anchor : Anchor) : boolean
	if not server then
		error("IsAnchorOccupied must be called on the server")
	end

	return anchors[anchor] ~= nil
end
