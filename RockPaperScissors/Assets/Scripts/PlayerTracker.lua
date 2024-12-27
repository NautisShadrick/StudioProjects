--!Type(Module)

local gameManger = require("GameManager")
--local uiManager = require("UIManager")
players = {}
local playercount = 0

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    scene.PlayerJoined:Connect(function(scene, player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            isReady = BoolValue.new("isReady" .. player.user.id, true),
            winStreak = IntValue.new("winStreak" .. player.user.id, 0)
        }

        player.CharacterChanged:Connect(function(player, character) 
            local playerinfo = players[player]
            if (character == nil) then
                return
            end 

            if characterCallback then
                characterCallback(playerinfo)
            end
        end)
    end)

    game.PlayerDisconnected:Connect(function(player)
        playercount = playercount - 1
        players[player] = nil
    end)
end

chalengeSent = false

------------- CLIENT -------------
function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        local _myIndicator = character.gameObject.transform:GetChild(1).gameObject
        local _myChallengeIndicator = character.gameObject.transform:GetChild(2).gameObject
        local _myWinStreakUIObject = character.gameObject.transform:GetChild(4):GetChild(0).gameObject
        local _myWinStreakUIScript = _myWinStreakUIObject:GetComponent(WinStreakUI)

        playerinfo.isReady.Changed:Connect(function(ready)
            print("Player " .. player.name .. " is ready: " .. tostring(ready))

            _myIndicator:SetActive(not ready)

            if ready then _myChallengeIndicator:SetActive(false) end

            if not ready and gameManger.currentTargetPlayer == player and chalengeSent == false then
                gameManger.currentTargetPlayer = nil
                gameManger.ResetGame()
            end
        end)

        playerinfo.winStreak.Changed:Connect(function(winStreak)
            print(tostring(winStreak))
            _myWinStreakUIScript.UpdateWinStreak(winStreak)
        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------
function self:ServerAwake()
    TrackPlayers(server)
end
