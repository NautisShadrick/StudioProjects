--!Type(Client)

--!SerializeField
local userID : string = ""

local _tapHandler = nil

function self:Awake()
    _tapHandler = self.gameObject:GetComponent(TapHandler)
    _tapHandler.Tapped:Connect(function()
        print("Opening Mini Profile")
        UI:OpenMiniProfile(userID)
    end)
end