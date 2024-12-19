--!Type(Module)

local SendChallengeRequest = Event.new("SendChallengeRequest")
local RecieveChallengeRequest = Event.new("RecieveChallengeRequest")
local SendResponseRequest = Event.new("SendResponseRequest")
local CompleteGameEvent = Event.new("CompleteGameEvent")

local uiManager = require("UIManager")
local playerTracker = require("PlayerTracker")

local currentTargetPlayer = nil
local currentChallengerPlayer = nil

localPlayerIsResponding = false

-------- CLIENT --------
function self:ClientAwake()
    RecieveChallengeRequest:Connect(function(challengerPlayer)
        currentChallengerPlayer = challengerPlayer
        uiManager.ShowResponse()
    end)

    CompleteGameEvent:Connect(function(challengerPlayer, respondingPlayer, winner, winningActionID)
        if client.localPlayer == challengerPlayer or client.localPlayer == respondingPlayer then
            uiManager.ResetGame()
            localPlayerIsResponding = false
        end
    end)
end

function StartChallenge(targetPlayer: Player)
    currentTargetPlayer = targetPlayer
    uiManager.ShowOptions()
end

function SendChallenge(challengeID: number)
    SendChallengeRequest:FireServer(currentTargetPlayer, challengeID)
    uiManager.DisableOptions()
end

function SendResponse(responseID: number)
    SendResponseRequest:FireServer(currentChallengerPlayer, responseID)
end


-------- SERVER --------
function self:ServerAwake()

    local challengeIDbyPlayer = {}

    SendChallengeRequest:Connect(function(challengerPlayer, targetPlayer, challengeID)
        challengeIDbyPlayer[challengerPlayer] = challengeID
        RecieveChallengeRequest:FireClient(targetPlayer, challengerPlayer)
    end)
    SendResponseRequest:Connect(function(respondingPlayer, challengerPlayer, responseID)
        local winStats = DetermineWinner(challengeIDbyPlayer[challengerPlayer], responseID)
        CompleteGameEvent:FireAllClients(challengerPlayer, respondingPlayer, winStats[1], winStats[2])
    end)

    server.PlayerDisconnected:Connect(function(player)
        challengeIDbyPlayer[player] = nil
    end)
end


-- Returns 0 if it's a tie, 1 if the challenger wins, and 2 if the responder wins
-- Output {winner, winningActionID}
function DetermineWinner(challengeID: number, responseID: number): {number}
    if challengeID == responseID then
        return {0, challengeID}
    elseif (challengeID == 1 and responseID == 3) or (challengeID == 2 and responseID == 1) or (challengeID == 3 and responseID == 2) then
        return {1, challengeID}
    else
        return {2, responseID}
    end
end