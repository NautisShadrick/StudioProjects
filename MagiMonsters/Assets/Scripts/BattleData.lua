--!Type(Module)

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
    return obj
end

function Battle:GetStats()
    print("Player: "..self.player.name)
    print("Player Monster: "..self.playerMonster.name)
    print("Enemy: "..self.enemy.name)
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

    _attacker.currentMana = _attacker.currentMana - action.GetActionManaCost()
    _target.currentHealth = _target.currentHealth - action.GetActionDamage()
    print(_target.name.." has ".._target.currentHealth.." health remaining")

    self.turn = self.turn == 0 and 1 or 0

end

return {
    Battle = Battle
}