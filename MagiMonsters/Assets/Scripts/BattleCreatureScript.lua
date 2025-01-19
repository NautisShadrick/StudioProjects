--!Type(Client)

local animator: Animator = nil

function self:Awake()
    animator = self.gameObject:GetComponent(Animator)
end

function playTrigger(triggerName: string)
    animator:SetTrigger(triggerName)
end