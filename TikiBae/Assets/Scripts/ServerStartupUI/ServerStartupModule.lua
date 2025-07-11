--!Type(Module)

--!SerializeField
local startupUIOBJ : GameObject = nil

export type StartMessageData = {
    title: string,
    message: string,
    header: string,
    live: boolean,
}

local sendStartMessageEvent = Event.new("SendStartMessage")

local startMessageUI : ServerStartupUI

function self:ClientStart()
    startMessageUI = startupUIOBJ:GetComponent(ServerStartupUI)
    startupUIOBJ:SetActive(false)
    sendStartMessageEvent:Connect(function(startMessageData)
        Timer.After(5, function()
            if startMessageUI then
                startupUIOBJ:SetActive(true)
                startMessageUI.DisplayStartMessage(startMessageData)
            end
        end)
    end)
end


function self:ServerAwake()
    scene.PlayerJoined:Connect(function(scene, player)

        Storage.GetValue("start_message", function(startMessageData)
            if startMessageData then
                if startMessageData.live == false then
                    print("Start message is not live, not sending to player:", player.Name)
                    return
                end
                print("Sending start message to player:", player.name)
                sendStartMessageEvent:FireClient(player, startMessageData)

            else
                startMessageData = {
                    title = "Welcome to the Game!",
                    message = "This is a sample message to welcome players.",
                    header = "Welcome",
                    live = false,
                }
                Storage.SetValue("start_message", startMessageData)
            end
        end)
    end)
end