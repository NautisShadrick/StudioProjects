--!Type(Module)

local ChangedChunksRequest = Event.new("ChangedChinksRequest")
local ChangedChunksResponse = Event.new("ChangedChinksResponse")

--!SerializeField
local canvasQuad : GameObject = nil


function self:ClientStart()

    local CHUNK_SIZE = 32
    local previousTexture = {} -- Stores previous chunk states


    local width = 64
    local height = 64
    local texture = Texture2D.new(width, height)
    local brushSize = 1

    local ChangedPixels = {} -- Stores the pixels that have changed since the last frame

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

                        -- Store the changed pixel
                        ChangedPixels[px] = ChangedPixels[px] or {}
                        ChangedPixels[px][py] = 'k'

                        texture:SetPixel(px, py, color)
                    end
                end
            end
        end
        texture:Apply()
    end

    -- example encoded data of changed pixels:   "0,0,b;10,5,r;123,4,g" -> x,y,color;x,y,color;x,y,color
    function EncodeChangedPixels()
        -- We'll store each pixel's data in a table and then concat them with semicolons.
        local encodedChunks = {}
        for x, yTable in pairs(ChangedPixels) do
            for y, color in pairs(yTable) do
                -- Instead of two-digit formatting, just convert x and y directly to strings
                table.insert(encodedChunks, x .. "," .. y .. "," .. color)
            end
        end
    
        -- Join all pixel chunks with `;` as the separator.
        -- This yields something like: "0,0,b;1,0,b;10,5,b" etc.
        local encodedData = table.concat(encodedChunks, ";")
        print("Encoded data:", encodedData)
        return encodedData
    end

    -- Simple split function: splits 'input' by the separator 'sep'
    local function Split(input, sep)
        local fields = {}
        local pattern = string.format("([^%s]+)", sep)
        for match in (input..sep):gmatch(pattern) do
            table.insert(fields, match)
        end
        return fields
    end

    function GetColorFromChar(color)
        if color == 'r' then
            return Color.red
        elseif color == 'g' then
            return Color.green
        elseif color == 'b' then
            return Color.blue
        elseif color == 'w' then
            return Color.white
        elseif color == 'k' then
            return Color.black
        end
    end

    function SetPixelInTexture(px, py, color)
        -- Ensure pixel is within texture bounds.
        if px >= 0 and px < width and py >= 0 and py < height then
            -- Update the pixel in the texture.
            texture:SetPixel(px, py, GetColorFromChar(color))
            -- If you want changes to appear immediately, call this here.
            texture:Apply()
        end
    end

    function DecodeChangedPixelsUpdateTexture(encodedData)
        -- Split by `;` to get each "x,y,color" triple
        local pixelChunks = Split(encodedData, ";")

        for _, chunk in ipairs(pixelChunks) do
            -- Skip empty chunks (e.g. if there's a trailing ';')
            if chunk ~= "" then
                -- Split each chunk by `,`
                local parts = Split(chunk, ",")
                if #parts == 3 then
                    local xStr, yStr, colorStr = parts[1], parts[2], parts[3]
                    local x = tonumber(xStr)
                    local y = tonumber(yStr)

                    -- Your logic for updating the pixel here:
                    -- e.g. SetPixelInTexture(x, y, colorStr)
                    SetPixelInTexture(x, y, colorStr)
                end
            end
        end
    end

    Timer.Every(.1, function()
        -- Encode the changed pixels
        local encodedData = EncodeChangedPixels()
        -- Reset the changed pixels table
        ChangedPixels = {}
        -- check if there are any changes
        if encodedData == "" then
            return
        end
        -- Send the encoded data to the server
        ChangedChunksRequest:FireServer(encodedData)
    end)


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

    ChangedChunksResponse:Connect(function(changedChunks)
        DecodeChangedPixelsUpdateTexture(changedChunks)
    end)
    
end

function self:ServerStart()
    ChangedChunksRequest:Connect(function(player, changedChunks)
        ChangedChunksResponse:FireAllClients(changedChunks)
    end)
end