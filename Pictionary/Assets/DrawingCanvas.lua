--!Type(Module)

local ChangedChunksRequest = Event.new("ChangedChunksRequest")
local ChangedChunksResponse = Event.new("ChangedChunksResponse")

--!SerializeField
local canvasQuad : GameObject = nil


function self:ClientStart()

    local CHUNK_SIZE = 8
    local previousTexture = {} -- Stores previous chunk states


    local width = 64
    local height = 64
    local texture = Texture2D.new(width, height)
    local brushSize = 1

    -- We have (64 / 8) = 8 chunks in each dimension, so total 64 chunks
    local totalChunksX = width / CHUNK_SIZE
    local totalChunksY = height / CHUNK_SIZE

    -- Keep track of which chunks have changed (dirty)
    local dirtyChunks = {}
    
    -- 1) Mark the chunk “dirty” if any pixel in that chunk changes
    local function MarkChunkDirty(x, y)
        local chunkX = math.floor(x / CHUNK_SIZE)
        local chunkY = math.floor(y / CHUNK_SIZE)
        local chunkIndex = chunkY * totalChunksX + chunkX
        dirtyChunks[chunkIndex] = true
    end


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
    
    ChangedChunksResponse:Connect()
    

    function SendDrawing()
        local changedChunks = nil -- Function to encode Data
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
    end)
end