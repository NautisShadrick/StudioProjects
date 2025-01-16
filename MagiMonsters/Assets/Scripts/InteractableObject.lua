--!Type(Client)

--!SerializeField
local objectType : string = ""

local gameManager = require("GameManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local TapBounce = Tween:new(
    .75,
    1,
    0.5,
    false,
    false,
    TweenModule.Easing.easeOutBack,
    function(value)
        self.transform.localScale = Vector3.new(value, value, value)
    end,
    function()
        self.transform.localScale = Vector3.new(1, 1, 1)
    end
)

function self:Awake()
    local tapHander = self.gameObject:GetComponent(TapHandler)
    tapHander.Tapped:Connect(function()
        gameManager.Search(objectType)
        TapBounce:start()
    end)
end