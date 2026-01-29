--!Type(Client)

--!SerializeField
local EmojiTextures : {Texture} = {}


local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

local startPos

function self:Start()

    startPos = self.transform.localPosition

    local hoverTween = Tween:new(
        -.2,
        .2,
        2,
        true,
        true,
        Easing.easeInOutQuad,
        function(value)
        self.transform.localPosition = startPos + Vector3.new(0, value, 0)
        end,
        function()end
    )
    hoverTween:start()

    local mat = self.gameObject:GetComponent(MeshRenderer).material
    local randomIndex = math.random(1, #EmojiTextures)
    mat.mainTexture = EmojiTextures[randomIndex]
    Timer.Every(1, function()
        local randomIndex = math.random(1, #EmojiTextures)
        mat.mainTexture = EmojiTextures[randomIndex]
    end)
end