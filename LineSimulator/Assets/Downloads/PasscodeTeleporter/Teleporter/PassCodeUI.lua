--!Type(UI)

--!SerializeField
local PassKey : string = ""

--!SerializeField
local b1Audio : AudioShader = nil
--!SerializeField
local b2Audio : AudioShader = nil
--!SerializeField
local b3Audio : AudioShader = nil
--!SerializeField
local b4Audio : AudioShader = nil
--!SerializeField
local b5Audio : AudioShader = nil
--!SerializeField
local b6Audio : AudioShader = nil
--!SerializeField
local b7Audio : AudioShader = nil
--!SerializeField
local b8Audio : AudioShader = nil
--!SerializeField
local b9Audio : AudioShader = nil
--!SerializeField
local decAudio : AudioShader = nil
--!SerializeField
local appAudio : AudioShader = nil

--!Bind
local NumpadElement : VisualElement = nil
--!Bind
local inputLabel : UILabel = nil
--!Bind
local button1 : UIButton = nil
--!Bind
local button2 : UIButton = nil
--!Bind
local button3 : UIButton = nil
--!Bind
local button4 : UIButton = nil
--!Bind
local button5 : UIButton = nil
--!Bind
local button6 : UIButton = nil
--!Bind
local button7 : UIButton = nil
--!Bind
local button8 : UIButton = nil
--!Bind
local button9 : UIButton = nil
--!Bind
local enterButton : UIButton = nil

--!Bind
local label1 : UILabel = nil
--!Bind
local label2 : UILabel = nil
--!Bind
local label3 : UILabel = nil
--!Bind
local label4 : UILabel = nil
--!Bind
local label5 : UILabel = nil
--!Bind
local label6 : UILabel = nil
--!Bind
local label7 : UILabel = nil
--!Bind
local label8 : UILabel = nil
--!Bind
local label9 : UILabel = nil
--!Bind
local labelenter : UILabel = nil

local currentNumber = ""
local Entered = false

local teleporterScript = nil

function SetVsible(state, ts)
    self.gameObject:SetActive(state)
    if ts then teleporterScript = ts end
end

function checkKey()
    if currentNumber == PassKey then 
        inputLabel:SetPrelocalizedText("APPROVED")
        Audio:PlayShader(appAudio)
        Timer.After(1, function() self.gameObject:SetActive(false)
            teleporterScript.Teleport(true)
        end)
        Entered = true 
    else 
        inputLabel:SetPrelocalizedText("DECLINED")
        Audio:PlayShader(decAudio)
        Timer.After(1, function() self.gameObject:SetActive(false) end)
        Entered = true 
    end
end

function inputNumber(input)
    if Entered then currentNumber = "" end
    currentNumber = currentNumber .. tostring(input)
    inputLabel:SetPrelocalizedText(currentNumber)
    if #currentNumber > 9 then currentNumber = tostring(input); inputLabel:SetPrelocalizedText(currentNumber) end
    Entered = false
end



inputLabel:SetPrelocalizedText("passcode")

button1:RegisterPressCallback(function()
    inputNumber(1)
    Audio:PlayShader(b1Audio)
end, true, true, true)

button2:RegisterPressCallback(function()
    inputNumber(2)
    Audio:PlayShader(b2Audio)
end, true, true, true)

button3:RegisterPressCallback(function()
    inputNumber(3)
    Audio:PlayShader(b3Audio)
end, true, true, true)

button4:RegisterPressCallback(function()
    inputNumber(4)
    Audio:PlayShader(b4Audio)
end, true, true, true)

button5:RegisterPressCallback(function()
    inputNumber(5)
    Audio:PlayShader(b5Audio)
end, true, true, true)

button6:RegisterPressCallback(function()
    inputNumber(6)
    Audio:PlayShader(b6Audio)
end, true, true, true)

button7:RegisterPressCallback(function()
    inputNumber(7)
    Audio:PlayShader(b7Audio)
end, true, true, true)

button8:RegisterPressCallback(function()
    inputNumber(8)
    Audio:PlayShader(b8Audio)
end, true, true, true)

button9:RegisterPressCallback(function()
    inputNumber(9)
    Audio:PlayShader(b9Audio)
end, true, true, true)

enterButton:RegisterPressCallback(function()
    checkKey()
end, true, true, true)

label1:SetPrelocalizedText("1")
label2:SetPrelocalizedText("2")
label3:SetPrelocalizedText("3")
label4:SetPrelocalizedText("4")
label5:SetPrelocalizedText("5")
label6:SetPrelocalizedText("6")
label7:SetPrelocalizedText("7")
label8:SetPrelocalizedText("8")
label9:SetPrelocalizedText("9")
labelenter:SetPrelocalizedText("ENTER")

function self:Start()
    SetVsible(false, nil)
end
