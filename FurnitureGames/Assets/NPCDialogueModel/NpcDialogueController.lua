--!Type(Client)

--!SerializeField
local dialogueUIObject: GameObject = nil
--!SerializeField
local npcColor: Color = Color.new(157, 56, 187)
--!SerializeField
local npcName: string = "NPC"

--!SerializeField
local startChunk: DialogueChunk = nil


--!SerializeField
local npcImage: Texture = nil
--!SerializeField
local npcAvatar: Character = nil
--!SerializeField
local outfit: CharacterOutfit = nil

local tapHandler: TapHandler = nil
local dialogueUI: DialogueUI = nil

--local audioManager = require("AudioManager")
local TweenModule = require("TweenModule")

local Tween = TweenModule.Tween
local Easing = TweenModule.Easing

local pulseTween = nil
local originalY = nil

local camObj = GameObject.FindWithTag("MainCamera")

function StartAnimation(tapIndicatorObject)
    if not tapIndicatorObject then return end

    local transform = tapIndicatorObject.transform
    originalY = transform.position.y

    pulseTween = Tween:new(
        0, 0.15, 0.7,
        true, true,
        Easing.easeInOutQuad,
        function(value)
            local pos = transform.position
            transform.position = Vector3.new(pos.x, originalY + value, pos.z)
            transform.localScale = Vector3.new(1.2 + value,1.2 + value,1.2 + value)
        end
    )
    pulseTween:start()
end


function StopAnimation()
    if pulseTween then
        pulseTween:stop()
        pulseTween = nil
    end
end

function OnTapped()
    if not dialogueUI then print("There is no Dialogue UI") return end
    dialogueUIObject:SetActive(true)

    local messageTexts = {}
    messageTexts = startChunk.GetPages()

    --audioManager.PlaySound("haptic_Medium")
    dialogueUI.InitializeDialogue(npcColor, npcName, startChunk, npcImage, npcAvatar, outfit)
end


function self:Start()
    dialogueUI = dialogueUIObject:GetComponent(DialogueUI)
    tapHandler = self.gameObject:GetComponent(TapHandler)
    tapHandler.Tapped:Connect(OnTapped)
end