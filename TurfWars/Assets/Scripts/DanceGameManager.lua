--!Type(Module)

--!SerializeField
local prefabToSpawn : GameObject = nil

local BoardState = StringValue.new("BoardState")

UpdateTilesEvent = Event.new("UpdateTilesEvent")
local changeTileRequestEvent = Event.new("ChangeTileRequest")


roundTime = NumberValue.new("RoundTime", 10)
gameState = NumberValue.new("GameState", 1)

roundDurations = {
    30,
    60,
}


local audioManager = require("AudioManager")
local uiManager = require("UIModule")
local playerTracker = require("PlayerTrackerTemplate")

local gridSize = {14,14}

-------- CLIENT --------

function ScoreChanged(scores)
    uiManager.SetScores(scores)
end

function self:ClientStart()
    UpdateTilesEvent:Connect(ScoreChanged)

    
    local activeColor = "o"
    local spacing = 1
    local rowOffset = 0
    local Pixels = {}
    PixelCount = 0

    function SpawnGrid()
        for i = 1, gridSize[2] do
            local currentRowOffset = ((i % 2 == 0) and rowOffset or 0)
            for j = 1, gridSize[1] do
                local spawnPosition = Vector3.new(((j - 1) * spacing) + currentRowOffset, 0, (-i + 1) * spacing)
                local newObject = Object.Instantiate(prefabToSpawn)
                local newObjectTran = newObject.transform
                newObjectTran.parent = self.transform
                newObjectTran.localPosition = spawnPosition
                newObjectTran.localEulerAngles = Vector3.new(-180,0,0)
                newObjectTran.localScale = Vector3.new(1,1,1)
                table.insert(Pixels, newObject:GetComponent(TileController))
                PixelCount = PixelCount + 1
                newObject:GetComponent(TileController).myIndex = PixelCount
            end
        end
    end

    function UpdateBoard(renderString)
        for i = 1, #Pixels do
            local newID = 0
            if(renderString:sub(i,i) == "0") then newID = 0 end
            if(renderString:sub(i,i) == "1") then newID = 1 end
            if(renderString:sub(i,i) == "2") then newID = 2 end
            Pixels[i].UpdateTile(newID)
        end
    end

    SpawnGrid()
    UpdateBoard(BoardState.value)
    BoardState.Changed:Connect(function(newVal, oldVal)
        UpdateBoard(newVal)
    end)
end

function ChangeTileReq(index)
    changeTileRequestEvent:FireServer(index)
end


-------- SERVER --------

local roundTimer = nil
local newBoardString = ""

function replaceCharAtIndex(str, index, newChar)
    if index == 1 then
        return newChar .. str:sub(2)
    else
        return str:sub(1, index - 1) .. newChar .. str:sub(index + 1, #str)
    end
end

function CalculateScores()
    local teamOneScore = 0
    local teamTwoScore = 0

    for i = 1, #BoardState.value do
        if BoardState.value:sub(i,i) == "1" then
            teamOneScore = teamOneScore + 1
        elseif BoardState.value:sub(i,i) == "2" then
            teamTwoScore = teamTwoScore + 1
        end
    end

    return {left = teamOneScore, right = teamTwoScore}
end

function ChangeColor(player, index, color)
    if(BoardState.value[index] == color)then
        return
    else
        modifiedString = replaceCharAtIndex(BoardState.value, index, color)
        BoardState.value = modifiedString
    end
    UpdateTilesEvent:FireAllClients(CalculateScores())
end

function ResetTiles()
    --Reset all the tiles
    newBoardString = ""
    for i = 1, gridSize[2] do
        for j = 1, gridSize[1] do
            newBoardString = newBoardString .. "o"
        end
    end
    BoardState.value = newBoardString
end

function self:ServerStart()

    newBoardString = ""
    for i = 1, gridSize[2] do
        for j = 1, gridSize[1] do
            newBoardString = newBoardString .. "o"
        end
    end
    BoardState.value = newBoardString

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

    changeTileRequestEvent:Connect(function(player, index)
        local TeamID = playerTracker.GetTeam(player)
        if TeamID == 0 then return end
        ChangeColor(player, index, TeamID)
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
