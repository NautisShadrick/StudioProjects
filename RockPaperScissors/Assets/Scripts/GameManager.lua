--!Type(Module)

--!SerializeField
local rockEffect: GameObject = nil
--!SerializeField
local bloodParticle: GameObject = nil
--!SerializeField
local paperEffect: GameObject = nil
--!SerializeField
local scissorsEffect: GameObject = nil

local updateStatus = Event.new("UpdateStatus")

local SendChallengeRequest = Event.new("SendChallengeRequest")
local RecieveChallengeRequest = Event.new("RecieveChallengeRequest")
local SendResponseRequest = Event.new("SendResponseRequest")
local CompleteGameEvent = Event.new("CompleteGameEvent")

local uiManager = require("UIManager")
local playerTracker = require("PlayerTracker")

currentTargetPlayer = nil
currentChallengerPlayer = nil

local responsePendingTimer = nil
local pendingTimer = nil



localPlayerIsResponding = false

-------- CLIENT --------

function PlayLosingAnimation(_losingPlayer: Player, winningActionID: number)
    -- Play emote based on winning action
    print(winningActionID)
    if winningActionID == 1 then
        --- Play Rock Animations
        Timer.After(0.2, function()
            _losingPlayer.character:PlayEmote("emote-death2", 2, false)
            local _bloodParticle = GameObject.Instantiate(bloodParticle)
            _bloodParticle.transform.position = _losingPlayer.character.gameObject.transform.position + Vector3.new(0, 2, 0)
        end)
        local rockEffectInstance = GameObject.Instantiate(rockEffect)
        rockEffectInstance.transform.position = _losingPlayer.character.gameObject.transform.position
        GameObject.Destroy(rockEffectInstance, 2)

    elseif winningActionID == 2 then
        --- Play Paper Animations
        local paperEffectInstance = GameObject.Instantiate(paperEffect)
        paperEffectInstance.transform.position = _losingPlayer.character.gameObject.transform.position

        _losingPlayer.character:PlayEmote("emote-gravity", 2, false)

    elseif winningActionID == 3 then
        --- Play Scissors Animations
        _losingPlayer.character:PlayEmote("emote-apart", 1.5, false)
        Timer.After(.8, function()
            local _bloodParticle = GameObject.Instantiate(bloodParticle)
            _bloodParticle.transform.position = _losingPlayer.character.gameObject.transform.position + Vector3.new(0, 2, 0)
        end)
        local scissorsEffectInstance = GameObject.Instantiate(scissorsEffect)
        scissorsEffectInstance.transform.position = _losingPlayer.character.gameObject.transform.position
        GameObject.Destroy(scissorsEffectInstance, 2)
    end
end

function self:ClientAwake()
    RecieveChallengeRequest:Connect(function(challengerPlayer)
        currentChallengerPlayer = challengerPlayer

        local _challengeIndicator = challengerPlayer.character.gameObject.transform:GetChild(2).gameObject
        _challengeIndicator:SetActive(true)

        local _busyIndicator = challengerPlayer.character.gameObject.transform:GetChild(1).gameObject
        _busyIndicator:SetActive(false)

        uiManager.ShowResponse()
        if responsePendingTimer then responsePendingTimer:Stop() end
        responsePendingTimer = Timer.After(5, function()
            ResetGame()
        end)
    end)

    CompleteGameEvent:Connect(function(challengerPlayer, respondingPlayer, winner, winningActionID)
        if client.localPlayer == challengerPlayer or client.localPlayer == respondingPlayer then
            uiManager.ResetGame()
            localPlayerIsResponding = false
            UpdateBusy(false)

            local _challengeIndicator = challengerPlayer.character.gameObject.transform:GetChild(2).gameObject
            _challengeIndicator:SetActive(false)
            currentChallengerPlayer = nil
            playerTracker.chalengeSent = false

            if responsePendingTimer then responsePendingTimer:Stop(); responsePendingTimer = nil end
            if pendingTimer then pendingTimer:Stop(); pendingTimer = nil end

            if client.localPlayer == challengerPlayer and winner == 1 then
                uiManager.ShowResults("win")
            elseif client.localPlayer == challengerPlayer and winner == 2 then
                uiManager.ShowResults("lose")
            elseif client.localPlayer == respondingPlayer and winner == 1 then
                uiManager.ShowResults("lose")
            elseif client.localPlayer == respondingPlayer and winner == 2 then
                uiManager.ShowResults("win")
            elseif winner == 0 then
                uiManager.ShowResults("draw")
            end

        end

        local _isDraw = false

        local _winningPlayer:Player = winner == 1 and challengerPlayer or winner == 2 and respondingPlayer or nil
        local _losingPlayer:Player = winner == 1 and respondingPlayer or winner == 2 and challengerPlayer or nil

        if not _winningPlayer and not _losingPlayer then _isDraw = true end
        
        if _winningPlayer then _winningPlayer.character:PlayEmote("emote-happy", 1.5, false) end
        if _losingPlayer then
            PlayLosingAnimation(_losingPlayer, winningActionID)
        end

        if _isDraw then
            PlayLosingAnimation(challengerPlayer, winningActionID)
            PlayLosingAnimation(respondingPlayer, winningActionID)
        end

    end)
end

function ResetGame()
    print("RESET GAME")
    uiManager.ResetGame()
    localPlayerIsResponding = false
    currentChallengerPlayer = nil
    currentTargetPlayer = nil
    UpdateBusy(false)
    playerTracker.chalengeSent = false
end

function StartChallenge(targetPlayer: Player)
    currentTargetPlayer = targetPlayer
    uiManager.ShowOptions()
    UpdateBusy(true)
end

function SendChallenge(challengeID: number)
    playerTracker.chalengeSent = true
    SendChallengeRequest:FireServer(currentTargetPlayer, challengeID)
    uiManager.DisableOptions()
    -- After pending time cancel and reset
    if pendingTimer then pendingTimer:Stop() end
    pendingTimer = Timer.After(5, function()
        uiManager.ResetGame()
        localPlayerIsResponding = false
        UpdateBusy(false)
    end)
end

function SendResponse(responseID: number)
    SendResponseRequest:FireServer(currentChallengerPlayer, responseID)
end

function UpdateBusy(Busy: boolean)
    updateStatus:FireServer(Busy)
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

    updateStatus:Connect(function(player, Busy)
        playerTracker.players[player].isReady.value = not Busy
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