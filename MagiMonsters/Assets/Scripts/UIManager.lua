--!Type(Module)

--!SerializeField
local elementsIcons: {Texture} = nil

--!SerializeField
local BattleScreenOBJ: GameObject = nil
--!SerializeField
local FourButtonOBJ: GameObject = nil
--!SerializeField
local ResultsLabelObj: GameObject = nil
--!SerializeField
local TimerUIObject: GameObject = nil

timerUI = nil

local BattleScreenUI: BattleScreen = nil
local FourButtonUI: FourButtonMenu = nil
local ResultsLabelUI: ResultsUI = nil

ResponseChosenEvent = Event.new("ResponseChosenEvent")

local BattleDataModule = require("BattleData")
local cameraManager = require("CameraManager")
local playerTracker = require("PlayerTracker")
local battlGroundManager = require("BattleGroundController")
local gameManager = require("GameManager")
local inventoryManager = require("PlayerInventoryManager")

currentBattleTurn = 0

elementsIconsMap = {
    air = 1,
    death = 2,
    earth = 3,
    fire = 4,
    ice = 5,
    life = 6,
    lightning = 7,
    metal = 8,
    mist = 9,
    phsycic = 10,
    sand = 11,
    water = 12
}

function GetIcon(mapID)
    return elementsIcons[elementsIconsMap[mapID]]
end

function DialougeResponseHandler(responseID)
    if responseID == "choose_creature_earth" then
        inventoryManager.RequestFirstMonster("earth")
    end
    if responseID == "choose_creature_fire" then
        inventoryManager.RequestFirstMonster("fire")
    end
    if responseID == "choose_creature_water" then
        inventoryManager.RequestFirstMonster("water")
    end
    if responseID == "choose_creature_air" then
        inventoryManager.RequestFirstMonster("air")
    end
end

function InitializeBattle(enemy: string)
    FourButtonOBJ:SetActive(true)
    BattleScreenOBJ:SetActive(true)

    FourButtonUI.UpdateButtons(FourButtonUI.Menu_One)
    BattleScreenUI.InitializeBattle(enemy)

    cameraManager.SwitchCamera(1)

    battlGroundManager.InitializeBattleGrounds(playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value].speciesName, enemy)
end

function self:ClientStart()
    timerUI = TimerUIObject:GetComponent(HealthBarUI)

    BattleScreenUI = BattleScreenOBJ:GetComponent(BattleScreen)
    FourButtonUI = FourButtonOBJ:GetComponent(FourButtonMenu)
    ResultsLabelUI = ResultsLabelObj:GetComponent(ResultsUI)

    BattleDataModule.ActionEvent:Connect(function(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, actionName)
        BattleScreenUI.UpdateStats(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana)
        ResultsLabelUI.ShowPopup(actionName)

        if turn == 0 then
            Timer.After(1, function() currentBattleTurn = turn end)
        else
            currentBattleTurn = turn
        end
    end)

    BattleDataModule.EndBattleEvent:Connect(function(winner)
        local _gameOverText = winner == client.localPlayer and "You Win!" or "You Lose!"
        ResultsLabelUI.ShowPopup(_gameOverText)

        local _deadCreatureScript = winner == client.localPlayer and battlGroundManager.GetEnemyCreature() or battlGroundManager.GetPlayerCreature()
        _deadCreatureScript.setBool("dead", true)

        Timer.After(2, function()
            EndBattle()
        end)
    end)
    EndBattle()

    cameraManager.SwitchCamera(0)

    ResponseChosenEvent:Connect(DialougeResponseHandler)

end

function EndBattle()
    FourButtonOBJ:SetActive(false)
    BattleScreenOBJ:SetActive(false)
    currentBattleTurn = 0

    cameraManager.SwitchCamera(0)
    battlGroundManager.EndBattleGrounds()
end