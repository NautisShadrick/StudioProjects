--!Type(Module)

ActionEvent = Event.new("ActionEvent")
EndBattleEvent = Event.new("EndBattleEvent")

local playerTracker = require("PlayerTracker")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local itemLibrary = require("ItemLibrary")
local gameManager = require("GameManager")

export type battleObject = {
    player: Player,
    playerMonster: monsterLibrary.MonsterData,
    enemy: monsterLibrary.MonsterData,
    turn: number
}

Battle = {}
Battle.__index = Battle

function Battle:new(player: Player, playerMonster: monsterLibrary.MonsterData, enemy: monsterLibrary.MonsterData)
    local obj: battleObject = {
        player = player,
        playerMonster = playerMonster,
        enemy = enemy,
        turn = 0
    }
    setmetatable(obj, Battle)
    self.turn = 0
    return obj
end

function Battle:GetStats()
    print("Player: "..self.player.name)
    print("Player Monster: "..self.playerMonster.name)
    print("Enemy: "..self.enemy.name)
end

function Battle:EndBattle(_winner)
    EndBattleEvent:FireClient(self.player, _winner)
    if _winner == self.player then
        gameManager.HandleBattleVictory(self.player, self.enemy)
    end
end

function Battle:DoAction(actionID: string)

    local action = actionLibrary.actions[actionID]

    local _target : monsterLibrary.MonsterData
    local _attacker : monsterLibrary.MonsterData

    if self.turn == 0 then
        _attacker = self.playerMonster
        _target = self.enemy
    else
        _attacker = self.enemy
        _target = self.playerMonster
    end

    if _attacker.currentMana < action.GetActionManaCost() then
        print(_attacker.name.." does not have enough mana to use "..action.GetActionName())
        return
    end

    _attacker.currentMana = _attacker.currentMana - action.GetActionManaCost()
    local _damage = action.GetActionDamage() * math.random(80,120)/100
    _damage = math.floor(_damage)

    _target.currentHealth = _target.currentHealth - _damage

    if self.turn == 1 then -- The player is being attacked
        -- Update Player Monster Stats
        playerTracker.SetHealthInCollection(self.player, _target.currentHealth)
    end

    -- 0 for player, 1 for enemy
    self.turn = self.turn == 0 and 1 or 0

    ActionEvent:FireClient(self.player,
    self.turn,
    self.playerMonster.currentHealth,
    self.playerMonster.currentMana,
    self.enemy.currentHealth,
    self.enemy.maxHealth,
    self.enemy.currentMana,
    self.enemy.maxMana,
    action.GetActionName())

    if self.playerMonster.currentHealth <= 0 or self.enemy.currentHealth <= 0 then
        local _winner = self.playerMonster.currentHealth > 0 and self.player or self.enemy
        self:EndBattle(_winner)
        return
    end

    if self.turn == 1 then
        Timer.After(2, function() self:DoAction(self.enemy.actionIDs[math.random(1,#self.enemy.actionIDs)]) end)
    end

end

function Battle:SwapMonster()
    self.playerMonster = playerTracker.players[self.player].monsterCollection.value[playerTracker.players[self.player].currentMosnterIndex.value]
    -- 0 for player, 1 for enemy
    self.turn = self.turn == 0 and 1 or 0

    ActionEvent:FireClient(self.player,
    self.turn,
    self.playerMonster.currentHealth,
    self.playerMonster.currentMana,
    self.enemy.currentHealth,
    self.enemy.maxHealth,
    self.enemy.currentMana,
    self.enemy.maxMana,
    nil)

    if self.playerMonster.currentHealth <= 0 or self.enemy.currentHealth <= 0 then
        local _winner = self.playerMonster.currentHealth > 0 and self.player or self.enemy
        self:EndBattle(_winner)
        return
    end

    if self.turn == 1 then
        Timer.After(2, function() self:DoAction(self.enemy.actionIDs[math.random(1,#self.enemy.actionIDs)]) end)
    end
end

function Battle:UseItem(itemID: string)
    local itemData = itemLibrary.GetConsumableByID(itemID)
    local _effect = itemData.GetEffect()
    local _strength = itemData.GetStrength()

    if _effect == "heal" then
        self.playerMonster.currentHealth = math.min(self.playerMonster.currentHealth + _strength, self.playerMonster.maxHealth)

        -- 0 for player, 1 for enemy
        self.turn = 1

        ActionEvent:FireClient(self.player,
        self.turn,
        self.playerMonster.currentHealth,
        self.playerMonster.currentMana,
        self.enemy.currentHealth,
        self.enemy.maxHealth,
        self.enemy.currentMana,
        self.enemy.maxMana,
        itemData.GetDisplayName())
        playerTracker.SetHealthInCollection(self.player, self.playerMonster.currentHealth)
    end
    
    if self.turn == 1 then
        Timer.After(2, function() self:DoAction(self.enemy.actionIDs[math.random(1,#self.enemy.actionIDs)]) end)
    end
end

return {
    Battle = Battle
}