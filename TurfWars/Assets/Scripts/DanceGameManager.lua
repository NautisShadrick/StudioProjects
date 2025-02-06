--!Type(Module)


-------- SERVER --------

local dancefloorTiles = TableValue.new("TeamOneTiles", {})

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

    print("Total Tiles: ", #dancefloorTiles.value)
    -- Get hoiw many tiles have this id
    local count = 0
    for i, tileData in ipairs(dancefloorTiles.value) do
        if tileData[2] == ID then
            count = count + 1
        end
    end
    print("Total Tiles with ID: ", count)
end

function self:ServerStart()
end
