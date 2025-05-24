--!Type(UI)

--!Bind
local battle_screen: UILuaView = nil
--!Bind
local player_name: Label = nil
--!Bind
local player_level: Label = nil
--!Bind
local player_healthbar_fill: VisualElement = nil
--!Bind
local player_hp: Label = nil
--!Bind
local player_mp: Label = nil
--!Bind
local enemy_name: Label = nil
--!Bind
local enemy_level: Label = nil
--!Bind
local enemy_healthbar_fill: VisualElement = nil
--!Bind
local enemy_hp: Label = nil
--!Bind
local enemy_mp: Label = nil


local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")

function InitializeBattle(enemy: string, customName)
    local _playerMonsterData = playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value]
    local _enemyMonsterData = monsterLibrary.GetDefaultMonsterData(enemy)

    player_name.text = _playerMonsterData.name
    --player_level.text = "Lvl. ".._playerMonsterData.level
    player_hp.text = _playerMonsterData.currentHealth.."/".._playerMonsterData.maxHealth
    player_mp.text = "mp: " .. _playerMonsterData.currentMana.."/".._playerMonsterData.maxMana
    player_healthbar_fill.style.width = StyleLength.new(Length.Percent((_playerMonsterData.currentHealth / _playerMonsterData.maxHealth)*100))

    enemy_name.text = customName or _enemyMonsterData.name
    --enemy_level.text = "Lvl. ".._enemyMonsterData.level
    enemy_hp.text = _enemyMonsterData.currentHealth.."/".._enemyMonsterData.maxHealth
    enemy_mp.text = "mp: " .. _enemyMonsterData.currentMana.."/".._enemyMonsterData.maxMana
    enemy_healthbar_fill.style.width = StyleLength.new(Length.Percent((_enemyMonsterData.currentHealth / _enemyMonsterData.maxHealth)*100))
end

function UpdateStats(turn, playerHealth, playerMana, enemyHealth, enemyMaxHealth, enemyMana, enemyMaxMana)

    playerHealth = math.max(0, playerHealth)
    playerMana = math.max(0, playerMana)

    enemyHealth = math.max(0, enemyHealth)
    enemyMana = math.max(0, enemyMana)

    local _playerMonsterData = playerTracker.players[client.localPlayer].monsterCollection.value[playerTracker.players[client.localPlayer].currentMosnterIndex.value]

    player_name.text = _playerMonsterData.name
    
    player_hp.text = playerHealth.."/".._playerMonsterData.maxHealth
    player_mp.text = "mp: " .. playerMana.."/".._playerMonsterData.maxMana
    player_healthbar_fill.style.width = StyleLength.new(Length.Percent((playerHealth / _playerMonsterData.maxHealth)*100))

    enemy_hp.text = enemyHealth.."/"..enemyMaxHealth
    enemy_mp.text = "mp:" .. enemyMana.."/"..enemyMaxMana
    enemy_healthbar_fill.style.width = StyleLength.new(Length.Percent((enemyHealth / enemyMaxHealth)*100))
end