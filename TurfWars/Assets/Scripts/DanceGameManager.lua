--!Type(Module)

local dancefloorTiles = TableValue.new("TeamOneTiles", {})

roundTime = NumberValue.new("RoundTime", 1)
gameState = NumberValue.new("GameState", 1)

roundDurations = {
    20,
    30,
}


local uiManager = require("UIModule")
local playerTracker = require("PlayerTrackerTemplate")

-------- CLIENT --------

function OnDancefloorTilesChanged(newFloor)
    local numberOfTeamOneTiles = 0
    local numberOfTeamTwoTiles = 0

    for i, tileData in ipairs(newFloor) do
        if tileData[2] == 1 then
            numberOfTeamOneTiles = numberOfTeamOneTiles + 1
        elseif tileData[2] == 2 then
            numberOfTeamTwoTiles = numberOfTeamTwoTiles + 1
        end
    end

    uiManager.SetScores({left = numberOfTeamOneTiles, right = numberOfTeamTwoTiles})
end

function self:ClientAwake()
    dancefloorTiles.Changed:Connect(OnDancefloorTilesChanged)

end




-------- SERVER --------

local roundTimer = nil


function AddTileToFloor (tileScript: TileController, ID)
    local _tempFloor = dancefloorTiles.value
    table.insert(_tempFloor, {tileScript, ID})
    dancefloorTiles.value = _tempFloor
end

function ChangeTileID(tileScript : TileController, ID : number)

    local _tempfloor = dancefloorTiles.value

    for i, tileData in ipairs(_tempfloor) do
        if tileData[1] == tileScript then
            _tempfloor[i][2] = ID
        end
    end

    dancefloorTiles.value = _tempfloor

    --print("Total Tiles: ", #dancefloorTiles.value)
    -- Get hoiw many tiles have this id
    local count = 0
    for i, tileData in ipairs(dancefloorTiles.value) do
        if tileData[2] == ID then
            count = count + 1
        end
    end
    --print("Total Tiles with ID: ", count)
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
                --reset each tile in the floor
                for i, tileData in ipairs(dancefloorTiles.value) do
                    tileData[1].tileID.value = 0
                    tileData[2] = 0
                end
            elseif gameState.value == 1 then -- Intermission
                -- GAME JSUT ENDED
                playerTracker.ClearTeams()
            end
        end

    end)
end
