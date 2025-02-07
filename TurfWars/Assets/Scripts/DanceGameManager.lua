--!Type(Module)

UpdateTilesEvent = Event.new("UpdateTilesEvent")

roundTime = NumberValue.new("RoundTime", 10)
gameState = NumberValue.new("GameState", 1)

roundDurations = {
    30,
    60,
}


local uiManager = require("UIModule")
local playerTracker = require("PlayerTrackerTemplate")

-------- CLIENT --------

function ScoreChanged(scores)
    uiManager.SetScores(scores)
end

function self:ClientAwake()
    UpdateTilesEvent:Connect(ScoreChanged)
end




-------- SERVER --------

local roundTimer = nil
local dancefloorTiles = {}

function AddTileToFloor (tileScript: TileController, ID)
    table.insert(dancefloorTiles, {tileScript, ID})
end

function CalculateScores()
    local teamOneScore = 0
    local teamTwoScore = 0

    for i, tileData in ipairs(dancefloorTiles) do
        if tileData[2] == 1 then
            teamOneScore = teamOneScore + 1
        elseif tileData[2] == 2 then
            teamTwoScore = teamTwoScore + 1
        end
    end

    return {left = teamOneScore, right = teamTwoScore}
end

function ChangeTileID(tileScript : TileController, ID : number)
    tileScript.tileID.value = ID
    for i, tileData in ipairs(dancefloorTiles) do
        if tileData[1] == tileScript then
            dancefloorTiles[i][2] = ID
        end
    end
    UpdateTilesEvent:FireAllClients(CalculateScores())
end

function ResetTiles()
    --Reset all the tiles
    for i, tileData in ipairs(dancefloorTiles) do
        tileData[1].tileID.value = 0
        dancefloorTiles[i][2] = 0
    end
    UpdateTilesEvent:FireAllClients(CalculateScores())
end

function self:ServerStart()
    roundTimer = Timer.Every(1, function()
        roundTime.value = roundTime.value - 1

        if roundTime.value <= 0 then
            -- Set Timer to appropriate value per the game state
            gameState.value = gameState.value == 1 and 2 or 1
            roundTime.value = roundDurations[gameState.value]

            if gameState.value == 2 then -- Dance Off
                playerTracker.SetTeams()
            elseif gameState.value == 1 then -- Intermission
                -- GAME JSUT ENDED
                playerTracker.ClearTeams()
                Timer.After(10,ResetTiles)
            end
        end
    end)

    server.PlayerConnected:Connect(function(player)
        player.CharacterChanged:Connect(function(player, character) 
            if (character == nil) then
                return
            end
            UpdateTilesEvent:FireClient(player, CalculateScores())
        end)
    end)
end
