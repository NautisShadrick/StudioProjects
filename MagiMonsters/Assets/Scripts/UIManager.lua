--!Type(Module)

--!SerializeField
local elementsIcons: {Texture} = nil
--!SerializeField
local elementsBGs: {Texture2D} = nil

--!SerializeField
local statIcons: {Texture} = nil

--!SerializeField
local BattleScreenOBJ: GameObject = nil
--!SerializeField
local FourButtonOBJ: GameObject = nil
--!SerializeField
local ResultsLabelObj: GameObject = nil
--!SerializeField
local TimerUIObject: GameObject = nil
--!SerializeField
local NameMonsterUIObj: GameObject = nil
--!SerializeField
local GeneralInventoryUIObj: GameObject = nil
--!SerializeField
local MonsterInfoUIObj: GameObject = nil
--!SerializeField
local RewardParticleUIObj: GameObject = nil
--!SerializeField
local HudButtonsObj: GameObject = nil
--!SerializeField
local itemReceivedNotificationObj: GameObject = nil
--!SerializeField
local postBattleScreenObj: GameObject = nil
--!SerializeField
local TeamManagerUIObj: GameObject = nil
--!SerializeField
local HatchEggUIObj: GameObject = nil

timerUI = nil

local BattleScreenUI: BattleScreen = nil
local FourButtonUI: FourButtonMenu = nil
local ResultsLabelUI: ResultsUI = nil
local GeneralInventoryUI: GeneralItemsInventory = nil
local MonsterInfoUI: MonsterInfo = nil
local RewardParticleUI: RewardParticle = nil
local HudButtonsUI: HudButtons = nil
local nameMonsterUI = nil
local itemsReceivedNotificationUI: ItemsReceivedNotification = nil
local postBattleScreenUI: PostBattleScreen = nil
local teamManagerUI: TeamManagerUI = nil
local hatchEggUI: HatchEggUI = nil

ResponseChosenEvent = Event.new("ResponseChosenEvent")

ActionEvent = Event.new("ActionEvent")
EndBattleEvent = Event.new("EndBattleEvent")

local hatcheryController = require("HatcheryController")
local BattleDataModule = require("BattleData")
local cameraManager = require("CameraManager")
local playerTracker = require("PlayerTracker")
local battlGroundManager = require("BattleGroundController")
local gameManager = require("GameManager")
local inventoryManager = require("PlayerInventoryManager")
local sceneManager = require("SceneManager")

currentBattleTurn = 0

local currentSlotId = 0 -- the Slot that is currently reciving and Egg to hatch
local currentHatchingSlotId = 0 -- the Slot that is currently being hatched

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

elementsBGsMap = {
    air = 1,
    water = 2,
    earth = 3,
    fire = 4,
    ice = 5,
    life = 6,
    lightning = 7,
    metal = 8,
    mist = 9,
    phsycic = 10,
    sand = 11,
    death = 12
}

statIconsMap = {
    health = 1,
    mana = 2,
    attack = 3,
    defense = 4,
    accuracy = 5,
}

function GetStatIcon(stat)
    return statIcons[statIconsMap[stat]]
end

function GetIcon(mapID)
    return elementsIcons[elementsIconsMap[mapID]]
end

function GetBG(mapID)
    return elementsBGs[elementsBGsMap[mapID]]
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

function InitializeBattle(enemyID: string, customName)
    HudButtonsObj:SetActive(false)

    FourButtonOBJ:SetActive(true)
    BattleScreenOBJ:SetActive(true)

    FourButtonUI.UpdateButtons(FourButtonUI.Menu_One)
    BattleScreenUI.InitializeBattle(enemyID, customName)

    cameraManager.SwitchCamera(1)

    battlGroundManager.InitializeBattleGrounds(playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value].speciesName, enemyID)
end

function self:ClientStart()
    timerUI = TimerUIObject:GetComponent(HealthBarUI)

    BattleScreenUI = BattleScreenOBJ:GetComponent(BattleScreen)
    FourButtonUI = FourButtonOBJ:GetComponent(FourButtonMenu)
    ResultsLabelUI = ResultsLabelObj:GetComponent(ResultsUI)
    nameMonsterUI = NameMonsterUIObj:GetComponent(NameMonsterUI)
    GeneralInventoryUI = GeneralInventoryUIObj:GetComponent(GeneralItemsInventory)
    RewardParticleUI = RewardParticleUIObj:GetComponent(RewardParticle)
    HudButtonsUI = HudButtonsObj:GetComponent(HudButtons)
    itemsReceivedNotificationUI = itemReceivedNotificationObj:GetComponent(ItemsReceivedNotification)
    postBattleScreenUI = postBattleScreenObj:GetComponent(PostBattleScreen)
    MonsterInfoUI = MonsterInfoUIObj:GetComponent(MonsterInfo)
    teamManagerUI = TeamManagerUIObj:GetComponent(TeamManagerUI)
    hatchEggUI = HatchEggUIObj:GetComponent(HatchEggUI)

    ActionEvent:Connect(function(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, actionName, enemyCreature)
        BattleScreenUI.UpdateStats(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana, enemyCreature)
        ResultsLabelUI.ShowPopup(actionName)

        Timer.After(1, function() currentBattleTurn = turn end)
    end)

    EndBattleEvent:Connect(function(winner)
        local _gameOverText = winner == client.localPlayer and "You Win!" or "You Lose!"
        ResultsLabelUI.ShowPopup(_gameOverText)

        local _deadCreatureScript = winner == client.localPlayer and battlGroundManager.GetEnemyCreature() or battlGroundManager.GetPlayerCreature()
        _deadCreatureScript.setBool("dead", true)

        Timer.After(2, function()
            EndBattle()
        end)
    end)
    EndBattle()

    gameManager.VictoryResponse:Connect(DisplayPostbattleScreen)

    cameraManager.SwitchCamera(0)

    ResponseChosenEvent:Connect(DialougeResponseHandler)
end

function DisplaySearchLoot(Items)
    RewardParticleUI.CollectItemsAnimation(Items)
    itemsReceivedNotificationUI.DisplayItems(Items)
end

function DisplayPostbattleScreen(loot)
    print(typeof(loot))
    print(#loot)
    postBattleScreenObj:SetActive(true)
    postBattleScreenUI.InitializePostBattle(loot)
end

function EndBattle()
    FourButtonOBJ:SetActive(false)
    BattleScreenOBJ:SetActive(false)
    currentBattleTurn = 0

    cameraManager.SwitchCamera(0)
    battlGroundManager.EndBattleGrounds()
    HudButtonsObj:SetActive(true)
end

function SwitchSceneRequest(scene)
    if scene == "home" then
        sceneManager.goHomeRequest:FireServer()
    elseif scene == "main" then
        sceneManager.leaveHomeRequest:FireServer()
    end
end

function OpenHatcherySelection(slotId)
    currentSlotId = slotId
    GeneralInventoryUIObj:SetActive(true)
    GeneralInventoryUI.SetSection(2)
    HudButtonsObj:SetActive(false)
end

function SelectEggForHatchery(eggId)
    hatcheryController.StartEggRequest:FireServer(currentSlotId, eggId)
end

function OpenNameMonsterUI(slotId)
    currentHatchingSlotId = slotId
    NameMonsterUIObj:SetActive(true)
    nameMonsterUI.InitializeUI(slotId)
end

function OpenGeneralInventoryUI()
    GeneralInventoryUIObj:SetActive(true)
    HudButtonsObj:SetActive(false)
    GeneralInventoryUI.SetSection(3)
end

function CloseGeneralInventoryUI()
    GeneralInventoryUIObj:SetActive(false)
    HudButtonsObj:SetActive(true)
end

function OpenMonsterInfoUI(playerMonsterIndex)
    HudButtonsObj:SetActive(false)
    MonsterInfoUIObj:SetActive(true)
    MonsterInfoUI.InitializeUI(playerMonsterIndex)
end

function CloseMonsterInfoUI()
    HudButtonsObj:SetActive(true)
    MonsterInfoUIObj:SetActive(false)
end

function OpenTeamManagerUI()
    HudButtonsObj:SetActive(false)
    TeamManagerUIObj:SetActive(true)
    teamManagerUI.InitializeTeamManagerUI()
end

function CloseTeamManagerUI()
    HudButtonsObj:SetActive(true)
    TeamManagerUIObj:SetActive(false)
end

function OpenHatchEggUI(slotId)
    HatchEggUIObj:SetActive(true)
    hatchEggUI.InitializeHatchingUI(slotId)
end

function CloseHatchEggUI()
    HatchEggUIObj:SetActive(false)
end