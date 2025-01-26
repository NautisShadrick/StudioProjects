--!Type(ScriptableObject)

--!SerializeField
local message: string = ""
--!SerializeField
local specialAnimationID: number = 0
--!SerializeField
local textColor: Color = Color.new(15, 44, 56)

function GetMessageData()
    return message, specialAnimationID, textColor
end