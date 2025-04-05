--!Type(ScriptableObject)

--!SerializeField
local lootTableIDS : {string} = {}
--!SerializeField
local lootTableAmounts : {number} = {}
--!SerializeField
local lootTableWeights : {number} = {}

function GenerateLoot(numberOfLoot : number)

    local _lootTable = {}

    for i = 1, #lootTableIDS do
        local lootID = lootTableIDS[i]
        local lootAmount = lootTableAmounts[i]
        local lootWeight = lootTableWeights[i]

        table.insert(_lootTable, {id = lootID, amount = lootAmount, weight = lootWeight})
    end

    local _foundLoot = {}

    -- Calculate the total weight of all loot items
    local totalWeight = 0
    for _, loot in ipairs(_lootTable) do
        totalWeight = totalWeight + loot.weight
    end

    for i = 1, numberOfLoot do
        local randomValue = math.random() * totalWeight
        local cumulativeWeight = 0

        for _, loot in ipairs(_lootTable) do
            cumulativeWeight = cumulativeWeight + loot.weight

            if randomValue <= cumulativeWeight then
                if loot.id == "" or loot.amount == 0 then
                    break
                end
                local lootID = loot.id
                local lootAmount = loot.amount

                table.insert(_foundLoot, {id = lootID, amount = lootAmount})
                break
            end
        end
    end

    return _foundLoot
end