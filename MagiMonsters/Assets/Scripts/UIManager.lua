--!Type(Module)

--!SerializeField
local BattleScreenOBJ: GameObject = nil
--!SerializeField
local FourButtonOBJ: GameObject = nil
--!SerializeField
local ResultsLabelObj: GameObject = nil

local BattleScreenUI: BattleScreen = nil
local FourButtonUI: FourButtonMenu = nil
local ResultsLabelUI: ResultsUI = nil

local BattleDataModule = require("BattleData")
local cameraManager = require("CameraManager")
local playerTracker = require("PlayerTracker")
local battlGroundManager = require("BattleGroundController")

currentBattleTurn = 0

function InitializeBattle(enemy: string)
    FourButtonOBJ:SetActive(true)
    BattleScreenOBJ:SetActive(true)

    FourButtonUI.UpdateButtons(FourButtonUI.Menu_One)
    BattleScreenUI.InitializeBattle(enemy)

    cameraManager.SwitchCamera(1)

    battlGroundManager.InitializeBattleGrounds(playerTracker.players[client.localPlayer].monsterData.value.speciesName, enemy)

end

function self:ClientStart()
    BattleScreenUI = BattleScreenOBJ:GetComponent(BattleScreen)
    FourButtonUI = FourButtonOBJ:GetComponent(FourButtonMenu)
    ResultsLabelUI = ResultsLabelObj:GetComponent(ResultsUI)

    BattleDataModule.ActionEvent:Connect(function(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, actionName)
        BattleScreenUI.UpdateStats(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana)
        currentBattleTurn = turn
        ResultsLabelUI.ShowPopup(actionName)
    end)

    BattleDataModule.EndBattleEvent:Connect(function(winner)
        EndBattle()
    end)
    EndBattle()

    cameraManager.SwitchCamera(0)

end

function EndBattle()
    FourButtonOBJ:SetActive(false)
    BattleScreenOBJ:SetActive(false)
    currentBattleTurn = 0

    cameraManager.SwitchCamera(0)
end