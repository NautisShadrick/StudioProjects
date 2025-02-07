--!Type(Module)

--!SerializeField
local teamOutfits : {CharacterOutfit} = nil

setPlayerTeamEvent = Event.new("SetPlayerTeam")

--local uiManager = require("UIManager")
players = {}
local playercount = 0
local currentTeam = 1

------------ Player Tracking ------------
function TrackPlayers(game, characterCallback)
    game.PlayerConnected:Connect(function(player)
        playercount = playercount + 1
        players[player] = {
            player = player,
            playerTeam = NumberValue.new("PlayerTeam"..player.user.id, 0),
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

function GetTeam(player)
    return players[player].playerTeam.value
end

------------- CLIENT -------------


function self:ClientAwake()
    function OnCharacterInstantiate(playerinfo)
        local player = playerinfo.player
        local character = playerinfo.player.character

        local namePlateUI = player.character.gameObject.transform:GetChild(1).gameObject:GetComponent(Nameplate)

        playerinfo.playerTeam.Changed:Connect(function(team)
            --print("Player team changed to "..team .. " for player "..player.name)
            namePlateUI.ChangeTeamColor(team)
        end)
    end

    TrackPlayers(client, OnCharacterInstantiate)
end

------------- SERVER -------------

function self:ServerAwake()
    TrackPlayers(server)
end

function SetTeams()
    currentTeam = 1
    for i, playerinfo in pairs(players) do
        playerinfo.playerTeam.value = currentTeam
        currentTeam = currentTeam == 1 and 2 or 1
    end
end

function ClearTeams()
    for i, playerinfo in pairs(players) do
        playerinfo.playerTeam.value = 0
    end
end