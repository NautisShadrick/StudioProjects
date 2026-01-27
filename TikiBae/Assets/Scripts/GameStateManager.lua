--!Type(Module)

--!SerializeField
local boatPrefab : GameObject = nil
--!SerializeField
local stateDuration : number = 60
--!SerializeField
local mainCamera : Camera = nil

BOATDURATION = 120 -- seconds

local GetpairsResponse = Event.new("GetpairsResponse")
makeChoiceRequest = Event.new("makeChoiceRequest")

playerMatchedEvent = Event.new("playerMatchedEvent")
playerMismatchedEvent = Event.new("playerMismatchedEvent")

startRideEvent = Event.new("startRideEvent")
endboatRideEvent = Event.new("endBoatRideEvent")

uiManager = require("UIManager")
playerTracker = require("PlayerTracker")
characterController = require("PlayerCharacterController")
local camScript = nil

--- Utility Functions ---

-- Function to convert seconds to min:seconds 00:00
function SecondsToMinSec(seconds)
    local min = math.floor(seconds / 60)
    local sec = seconds % 60
    return string.format("%02d:%02d", min, sec)
end

---- CLIENT ----
function self:ClientStart()

    camScript = mainCamera.gameObject:GetComponent(ThirdPersonCameraOverride)

    Chat.TextMessageReceivedHandler:Connect(function(channelInfo, player, message)
        info = channelInfo
        local canSeeMessage = true
        local messageToDisplay = canSeeMessage and message or "..."
        Chat:DisplayTextMessage(channelInfo, player, messageToDisplay)
    end)

    startRideEvent:Connect(function(player1, player2)
        -- spawn the boat
        local _newBoat = GameObject.Instantiate(boatPrefab)
        local _pointA = _newBoat.transform:Find("A").gameObject:GetComponent(Anchor)
        local _pointB = _newBoat.transform:Find("B").gameObject:GetComponent(Anchor)

        if player1 == client.localPlayer then
            characterController.options.enabled = false
        end
        if player2 == client.localPlayer then
            characterController.options.enabled = false
        end

        player1.character:TeleportToAnchor(_pointA)
        player2.character:TeleportToAnchor(_pointB)

        Timer.After(BOATDURATION, function()
            --Destroy the boat
            GameObject.Destroy(_newBoat)
            uiManager.ToggleTimerUI(false)
            uiManager.ToggleSelectionUI(false)
        end)

        if client.localPlayer == player1 or client.localPlayer == player2 then
            Timer.After(BOATDURATION - 5, function()
                -- Start the Match Req
                uiManager.ToggleSelectionUI(true)
            end)

            uiManager.ToggleTimerUI(true)
            uiManager.PlayTimer(BOATDURATION)
        end

    end)

    endboatRideEvent:Connect(function(player1, player2)

        if player1 == client.localPlayer or player2 == client.localPlayer then
            playerTracker.TeleportLocalPlayerRequest(Vector3.new(math.random(-5,5),0,math.random(-5,5)))
        end

        if player1 == client.localPlayer then
            characterController.options.enabled = true
        end
        if player2 == client.localPlayer then
            characterController.options.enabled = true
        end
    end)
end



---- SERVER ----
local choicesByPlayer = {}

function self:ServerAwake()
    makeChoiceRequest:Connect(function(player, choice)
        choicesByPlayer[player] = choice
    end)
    server.PlayerDisconnected:Connect(function(player)
        choicesByPlayer[player] = nil

        -- If the disconnecting player was on a boat ride, end it for their partner
        local playerData = playerTracker.players[player]
        if playerData and playerData.currentPartnerID.value ~= "" then
            local partnerID = playerData.currentPartnerID.value
            -- Find the partner player
            for otherPlayer, data in pairs(playerTracker.players) do
                if otherPlayer.user.id == partnerID then
                    EndBoatRide(player, otherPlayer)
                    break
                end
            end
        end
    end)
end


function EndBoatRide(player1, player2)
    endboatRideEvent:FireAllClients(player1, player2)
    playerTracker.players[player1].currentPartnerID.value = ""
    playerTracker.players[player2].currentPartnerID.value = ""
end

function StartBoatRideForPair(player1, player2)
    choicesByPlayer[player1] = 0
    choicesByPlayer[player2] = 0
    startRideEvent:FireAllClients(player1, player2)
    playerTracker.players[player1].currentPartnerID.value = player2.user.id
    playerTracker.players[player2].currentPartnerID.value = player1.user.id

    Timer.After(BOATDURATION, function()
        -- Check if they matched
        local choice1 = choicesByPlayer[player1] or 0
        local choice2 = choicesByPlayer[player2] or 0

        if choice1 == 1 and choice2 == 1 then
            playerMatchedEvent:FireClients({player1, player2})

            -- Save match data for player1
            local player1Matches = playerTracker.players[player1].matches.value or {}
            local matchCount1 = 0
            if player1Matches[player2.user.id] then
                matchCount1 = player1Matches[player2.user.id][2] or 0
            end
            player1Matches[player2.user.id] = {player2.name, matchCount1 + 1}
            playerTracker.players[player1].matches.value = player1Matches
            Storage.SetPlayerValue(player1, "matches", player1Matches)

            -- Save match data for player2
            local player2Matches = playerTracker.players[player2].matches.value or {}
            local matchCount2 = 0
            if player2Matches[player1.user.id] then
                matchCount2 = player2Matches[player1.user.id][2] or 0
            end
            player2Matches[player1.user.id] = {player1.name, matchCount2 + 1}
            playerTracker.players[player2].matches.value = player2Matches
            Storage.SetPlayerValue(player2, "matches", player2Matches)
        else
            playerMismatchedEvent:FireClients({player1, player2})
        end

        EndBoatRide(player1, player2)
    end)
end
