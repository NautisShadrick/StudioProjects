--!Type(Module)

local playerTracker = require("PlayerTracker")
local actionLibrary = require("ActionLibrary")
local monsterLibrary = require("MonsterLibrary")
local itemLibrary = require("ItemLibrary")
local gameManager = require("GameManager")
local uiManager = require("UIManager")

export type battleObject = {
    player: Player,
    playerMonster: monsterLibrary.MonsterData,
    enemy: monsterLibrary.MonsterData,
    turn: number
}

PVPBattle = {}
PVPBattle.__index = PVPBattle

function PVPBattle:new(player: Player, playerMonster: monsterLibrary.MonsterData, enemyPlayer: Player, enemyPlayerMonster: monsterLibrary.MonsterData)
    local obj: battleObject = {
        player = player,
        playerMonster = playerMonster,
        enemyPlayer = enemyPlayer,
        enemy = enemyPlayerMonster,
        turn = 0
    }
    setmetatable(obj, PVPBattle)
    self.turn = 0
    return obj
end

function PVPBattle:GetStats()
    print("Player: "..self.player.name)
    print("Player Monster: "..self.playerMonster.name)
    print("Enemy: "..self.enemy.name)
end

function PVPBattle:EndBattle(_winner)
    print(_winner.name)
    uiManager.EndBattleEvent:FireClient(self.player, _winner)
    uiManager.EndBattleEvent:FireClient(self.enemyPlayer, _winner)
    if _winner == self.player then
        gameManager.HandleBattleVictory(self.player, self.enemy)
    else
        gameManager.HandleBattleVictory(self.enemyPlayer, self.playerMonster)
    end
    gameManager.HandleBattleEnd(self.player)
    gameManager.HandleBattleEnd(self.enemyPlayer)
end

function PVPBattle:Flee(player: Player)
    -- Determine the winner
    local _winner = player == self.player and self.enemy or self.player
    self:EndBattle(_winner)
end

function PVPBattle:DoAction(actionID: string)

    local action = actionLibrary.GetActionByID(actionID)

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
        return false
    end

    _attacker.currentMana = _attacker.currentMana - action.GetActionManaCost()
    local _damage = action.GetActionDamage() * math.random(80,120)/100
    _damage = math.floor(_damage)

    _target.currentHealth = _target.currentHealth - _damage

    if self.turn == 1 then -- The player 1 is being attacked
        -- Update Player 1's Monster Stats
        playerTracker.SetHealthInCollection(self.player, _target.currentHealth)
    else -- The player 2 is being attacked
        -- Update Player 2's Monster Stats
        playerTracker.SetHealthInCollection(self.enemyPlayer, _target.currentHealth)
    end

    -- 0 for player, 1 for enemy
    self.turn = self.turn == 0 and 1 or 0
    print("Turn: "..self.turn)

    -- Fire the action event to update the clients
    -- Fire the ActionEvent to Player 1
    uiManager.ActionEvent:FireClient(self.player,
        self.turn,
        self.playerMonster.currentHealth,
        self.playerMonster.currentMana,
        self.enemy.currentHealth,
        self.enemy.maxHealth,
        self.enemy.currentMana,
        self.enemy.maxMana,
        action.GetActionName()
    )

    -- Fire the ActionEvent to Player 2
    uiManager.ActionEvent:FireClient(self.enemyPlayer,
        self.turn,
        self.enemy.currentHealth,
        self.enemy.currentMana,
        self.playerMonster.currentHealth,
        self.playerMonster.maxHealth,
        self.playerMonster.currentMana,
        self.playerMonster.maxMana,
        action.GetActionName()
    )

    if self.playerMonster.currentHealth <= 0 or self.enemy.currentHealth <= 0 then
        local _winner = self.playerMonster.currentHealth > 0 and self.player or self.enemy
        self:EndBattle(_winner)
        return true
    end

    return true

end

function PVPBattle:SwapMonster()
    
    -- Swap the monster for the player whos turn it is
    if self.turn == 0 then
        self.playerMonster = playerTracker.players[self.player].monsterCollection.value[playerTracker.players[self.player].currentMosnterIndex.value]
    else
        self.enemy = playerTracker.players[self.enemyPlayer].monsterCollection.value[playerTracker.players[self.enemyPlayer].currentMosnterIndex.value]
    end
    
    -- 0 for player, 1 for enemy
    self.turn = self.turn == 0 and 1 or 0

    -- Fire the action event to update the clients
    -- Fire the ActionEvent to Player 1
    uiManager.ActionEvent:FireClient(self.player,
        self.turn,
        self.playerMonster.currentHealth,
        self.playerMonster.currentMana,
        self.enemy.currentHealth,
        self.enemy.maxHealth,
        self.enemy.currentMana,
        self.enemy.maxMana,
        nil,
        self.enemy
    )

    -- Fire the ActionEvent to Player 2
    uiManager.ActionEvent:FireClient(self.enemyPlayer,
        self.turn,
        self.enemy.currentHealth,
        self.enemy.currentMana,
        self.playerMonster.currentHealth,
        self.playerMonster.maxHealth,
        self.playerMonster.currentMana,
        self.playerMonster.maxMana,
        nil,
        self.playerMonster
    )

    if self.playerMonster.currentHealth <= 0 or self.enemy.currentHealth <= 0 then
        local _winner = self.playerMonster.currentHealth > 0 and self.player or self.enemy
        self:EndBattle(_winner)
        return
    end

end

function PVPBattle:UseItem(itemID: string)
    local itemData = itemLibrary.GetConsumableByID(itemID)
    local _effect = itemData.GetEffect()
    local _strength = itemData.GetStrength()

    if _effect == "heal" then
        
        -- Heal the monster for player 1 if it's their turn
        if self.turn == 0 then
            self.playerMonster.currentHealth = math.min(self.playerMonster.currentHealth + _strength, self.playerMonster.maxHealth)
            playerTracker.SetHealthInCollection(self.player, self.playerMonster.currentHealth)
        else -- Heal the monster for player 2 if it's their turn
            self.enemy.currentHealth = math.min(self.enemy.currentHealth + _strength, self.enemy.maxHealth)
            playerTracker.SetHealthInCollection(self.enemyPlayer, self.enemy.currentHealth)
        end

        -- 0 for player, 1 for enemy
        self.turn = self.turn == 0 and 1 or 0

        -- Fire the action event to update the clients
        -- Fire the ActionEvent to Player 1
        uiManager.ActionEvent:FireClient(self.player,
            self.turn,
            self.playerMonster.currentHealth,
            self.playerMonster.currentMana,
            self.enemy.currentHealth,
            self.enemy.maxHealth,
            self.enemy.currentMana,
            self.enemy.maxMana,
            itemData.GetDisplayName()
        )
        -- Fire the ActionEvent to Player 2
        uiManager.ActionEvent:FireClient(self.enemyPlayer,
            self.turn,
            self.enemy.currentHealth,
            self.enemy.currentMana,
            self.playerMonster.currentHealth,
            self.playerMonster.maxHealth,
            self.playerMonster.currentMana,
            self.playerMonster.maxMana,
            itemData.GetDisplayName()
        )

    end

end

return {
    PVPBattle = PVPBattle
}