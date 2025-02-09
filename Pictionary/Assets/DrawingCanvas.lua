--!Type(Module)

local ChangedChunksRequest = Event.new("ChangedChinksRequest")
local ChangedChunksResponse = Event.new("ChangedChinksResponse")

--!SerializeField
local canvasQuad : GameObject = nil


function self:ClientStart()

    local CHUNK_SIZE = 32
    local previousTexture = {} -- Stores previous chunk states


    local width = 256
    local height = 256
    local texture = Texture2D.new(width, height)
    local brushSize = 1

    function InitializeCanvas()
        -- Set all pixels to white using SetPixel in a loop
        for x = 0, width-1 do
            for y = 0, height-1 do
                texture:SetPixel(x, y, Color.white)
            end
        end
        texture:Apply()


        -- Apply texture to the Quad's material
        local renderer = canvasQuad:GetComponent(MeshRenderer)
        renderer.material.mainTexture = texture
    end

    function Draw(x, y, brushSize, color)
        for i = -brushSize, brushSize do
            for j = -brushSize, brushSize do
                local px, py = x + i, y + j

                -- Check if pixel is inside the circle (distance formula)
                if (i * i + j * j) <= (brushSize * brushSize) then
                    if px >= 0 and px < width and py >= 0 and py < height then
                        texture:SetPixel(px, py, color)
                    end
                end
            end
        end
        texture:Apply()
    end


    InitializeCanvas()

    function GetQuadUVFromTouch(screenPosition)
        local camera = Camera.main
        local worldUpPlane = Plane.new(Vector3.up, Vector3.new(0, 0, 0)) -- cached to avoid re-generating every call
        
        -- Convert the corrected screen position to a ray
        local ray = camera:ScreenPointToRay(screenPosition) -- Convert screen position to ray
        local hitInfo: RaycastHit -- Initialize hitInfo to store raycast hit details
        local hitSuccess: boolean -- Boolean to store if the ray hit something

        -- Perform the raycast against colliders in the scene
        hitSuccess, hitInfo = Physics.Raycast(ray)
        if hitSuccess then
            if hitInfo.collider.gameObject == canvasQuad then
                -- Convert world hit point to local UV coordinates (0-1 range)
                local uv = hitInfo.textureCoord
                return math.floor(uv.x * width), math.floor(uv.y * height)
            end
        end

        return nil, nil
    end

    function OnDragBegan(evt)
        local x, y = GetQuadUVFromTouch(evt.position)
        if x and y then
            Draw(x, y, brushSize, Color.black)
        end
    end

    function OnDrag(evt)
        local x, y = GetQuadUVFromTouch(evt.position)
        if x and y then
            Draw(x, y, brushSize, Color.black)
        end
    end

    function OnDragEnded(evt)
        -- No specific behavior needed
    end

    Input.PinchOrDragBegan:Connect(OnDragBegan)
    Input.PinchOrDragChanged:Connect(OnDrag)
    Input.PinchOrDragEnded:Connect(OnDragEnded)


    function EncodeChangedChunks()
        local changedChunks = {}
    
        for chunkX = 0, width / CHUNK_SIZE - 1 do
            for chunkY = 0, height / CHUNK_SIZE - 1 do
                local chunkKey = string.format("%d,%d", chunkX, chunkY)
                local changedPixels = {}
    
                for x = chunkX * CHUNK_SIZE, (chunkX + 1) * CHUNK_SIZE - 1 do
                    for y = chunkY * CHUNK_SIZE, (chunkY + 1) * CHUNK_SIZE - 1 do
                        local color = texture:GetPixel(x, y)
                        local prevColor = previousTexture[chunkX] and previousTexture[chunkX][chunkY] and previousTexture[chunkX][chunkY][x] and previousTexture[chunkX][chunkY][x][y] or Color.white
                        
                        if color ~= prevColor then
                            table.insert(changedPixels, string.format("%d,%d,%.2f,%.2f,%.2f", x % CHUNK_SIZE, y % CHUNK_SIZE, color.r, color.g, color.b))
    
                            -- Store new color in previousTexture
                            if not previousTexture[chunkX] then previousTexture[chunkX] = {} end
                            if not previousTexture[chunkX][chunkY] then previousTexture[chunkX][chunkY] = {} end
                            if not previousTexture[chunkX][chunkY][x] then previousTexture[chunkX][chunkY][x] = {} end
                            previousTexture[chunkX][chunkY][x][y] = color
                        end
                    end
                end
            end
        end

        --print out the length of each changed chunk
        for chunkKey, pixelData in pairs(changedChunks) do
            print(chunkKey, pixelData)
        end
    
        return changedChunks
    end
    
    function DecodeAndApplyChunks(changedChunks)
        for chunkKey, pixelData in pairs(changedChunks) do
            local chunkX, chunkY = chunkKey:match("(%d+),(%d+)")
            chunkX, chunkY = tonumber(chunkX), tonumber(chunkY)
    
            for pixel in string.gmatch(pixelData, "([^;]+)") do
                local x, y, r, g, b = pixel:match("(%d+),(%d+),([%d%.]+),([%d%.]+),([%d%.]+)")
                x, y = tonumber(x) + chunkX * CHUNK_SIZE, tonumber(y) + chunkY * CHUNK_SIZE
                local color = Color.new(r, g, b)
                texture:SetPixel(x, y, color)
            end
        end
        texture:Apply()
    end
    
    ChangedChunksResponse:Connect(DecodeAndApplyChunks)
    

    function SendDrawing()
        local changedChunks = EncodeChangedChunks() -- Function to encode Data
        if next(changedChunks) then -- Only send if there's a change
            ChangedChunksRequest:FireServer(changedChunks)
            print("Sent updated chunks to server!")
        else
            print("No changes detected, nothing sent.")
        end
    end

    Timer.Every(1, SendDrawing)

    function ColorChunksRandomly()
        for chunkX = 0, width / CHUNK_SIZE - 1 do
            for chunkY = 0, height / CHUNK_SIZE - 1 do
                -- Generate a random color
                local randomColor = Color.new(math.random(), math.random(), math.random())
    
                -- Calculate the top-left pixel of the chunk
                local startX, startY = chunkX * CHUNK_SIZE, chunkY * CHUNK_SIZE
    
                -- Draw the entire chunk with the random color
                Draw(startX + CHUNK_SIZE / 2, startY + CHUNK_SIZE / 2, CHUNK_SIZE / 2, randomColor)
            end
        end
    end
    
    -- Call this function to color the canvas randomly
    --ColorChunksRandomly()
    
end

function self:ServerStart()
    ChangedChunksRequest:Connect(function(player, changedChunks)
        ChangedChunksResponse:FireAllClients(changedChunks)
    end)
end