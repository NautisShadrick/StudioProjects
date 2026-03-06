--!Type(ScriptableObject)

--!SerializeField
local message: string = ""
--!SerializeField
local specialAnimationID: number = 0
--!SerializeField
local textColor: Color = Color.new(15, 44, 56)
--!SerializeField
local excludeFromLocalization: boolean = false

function SetMessage(newMessage: string)
    message = newMessage
end

function GetMessageData()
    return message, specialAnimationID, textColor, excludeFromLocalization
end