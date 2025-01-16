--!Type(Module)

ActionEvent = Event.new("ActionEvent")
EndBattleEvent = Event.new("EndBattleEvent")

local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")

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

    print(_attacker.name)
    print(_target.name)
    print(action.GetActionName())

    --_attacker.currentMana = _attacker.currentMana - action.GetActionManaCost()
    local _damage = action.GetActionDamage() * math.random(80,120)/100
    _damage = math.floor(_damage)
    print(_damage)
    _target.currentHealth = _target.currentHealth - _damage

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

return {
    Battle = Battle
}