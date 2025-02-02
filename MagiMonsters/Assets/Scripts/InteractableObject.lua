--!Type(Client)

--!SerializeField
local objectType : string = ""
--!SerializeField
local timerPoint : Transform = nil
--!SerializeField
local duration : number = 5

local gameManager = require("GameManager")
local uiManager = require("UIManager")

local TweenModule = require("TweenModule")
local Tween = TweenModule.Tween

local characterController = require("PlayerCharacterController")

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

        TapBounce:start()

        local timerUI = uiManager.timerUI
        local timerUIObject = uiManager.timerUI.gameObject

        timerUIObject:SetActive(true)
        timerUIObject.transform.position = timerPoint.transform.position
        timerUI.PlayTimer(duration)

        characterController.options.enabled = false
        Timer.After(duration, function()
            gameManager.Search(objectType)
            characterController.options.enabled = true
        end)

    end)
end