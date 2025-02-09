--!Type(Client)

--!SerializeField
local emote : string = ""


function self:Start()
    self.gameObject:GetComponent(Character):PlayEmote(emote, 1, true)
end