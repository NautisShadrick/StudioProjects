--!Type(ClientAndServer)

--!SerializeField
local myAnchorGO: GameObject = nil
local myAnchor = nil

local enterAnchorRequest = Event.new("EnterAnchorRequest")
local exitAnchorRequest = Event.new("ExitAnchorRequest")

local anchorOccupied = BoolValue.new("AnchorOccupied", false)

function self:ClientAwake()
    local myAnimator : Animator = self.gameObject:GetComponent(Animator)
    myAnchor = myAnchorGO:GetComponent(Anchor)

    anchorOccupied.Changed:Connect(function(newVal)
        print(tostring(newVal))
        myAnimator:SetBool("Mounted", newVal)
    end)

    myAnchor.Entered:Connect(function()
        enterAnchorRequest:FireServer()
    end)
    myAnchor.Exited:Connect(function()
        exitAnchorRequest:FireServer()
    end)
end

function self:ServerStart()
    enterAnchorRequest:Connect(function(player)
        anchorOccupied.value = true
    end)
    exitAnchorRequest:Connect(function(player)
        anchorOccupied.value = false
    end)
end