--!Type(UI)

--!SerializeField
local kiteBuilderObject: GameObject = nil

--!Bind
local _designButton: Label = nil

local function openKiteBuilder()
    if not kiteBuilderObject then
        print("DesignHudButton: KiteBuilder not assigned")
        return
    end

    kiteBuilderObject:SetActive(true)

    local _kiteBuilder = kiteBuilderObject:GetComponent(KiteBuilder)
    if _kiteBuilder then
        _kiteBuilder.InitializeBuilder()
    end
end

function self:Start()
    _designButton:RegisterPressCallback(function()
        openKiteBuilder()
    end)
end
