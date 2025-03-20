--!Type(Module)

local purchaseItemReq = Event.new("PurchaseItemRequest")

local requestFirstMonsterRequest = Event.new("RequestFirstMonsterRequest")

local playerTracker = require("PlayerTracker")
local monsterLibrary = require("MonsterLibrary")

------------ Client ------------

function RequestFirstMonster(type)
    requestFirstMonsterRequest:FireServer(type)
end


function PurchaseItem(id : string, price : number, quantity : number)
    purchaseItemReq:FireServer(id, price, quantity)
end


------------- Server --------------

---- PLAYER MONSTER MANAGEMENT ----

function SaveEggCollectionToStorage(player: Player)
    local _eggCollection = playerTracker.players[player].eggCollection.value
    Storage.SetPlayerValue(player, "egg_collection", _eggCollection, function()
        print("Egg Collection Saved")
    end)
end

function GivePlayerEgg(player: Player, eggData)
    local _eggCollection = playerTracker.players[player].eggCollection.value
    table.insert(_eggCollection, eggData)
    playerTracker.players[player].eggCollection.value = _eggCollection
    SaveEggCollectionToStorage(player)
end

function GivePlayerMonster(player, monsterSpecies, monsterName)
    print("Giving Player Monster", player.name, monsterSpecies, "named", monsterName)
    local playerInfo = playerTracker.players[player]
    local monsterCollection = playerInfo.monsterCollection.value

    local monsterData = monsterLibrary.GetStorageMonsterData(monsterSpecies)
    monsterData.name = monsterName

    table.insert(monsterCollection, monsterData)
    playerTracker.players[player].monsterCollection.value = monsterCollection
    playerTracker.SavePlayerMonstersToStorage(player)
end

function self:ServerStart()
    requestFirstMonsterRequest:Connect(function(player, type)
        local playerInfo = playerTracker.players[player]
        local monsterCollection = playerInfo.monsterCollection.value
        local eggCollection = playerInfo.eggCollection.value

        if #monsterCollection > 0 or #eggCollection > 0 then print("Someone trying to reclaim freebies, like a chump") return end

        local _newEggData = {monster = "Zapkit", totalDuration = 60}
        GivePlayerEgg(player, _newEggData)
    end)

    
    purchaseItemReq:Connect(function(player: Player, id: string, price: number, quantity: number)
        local transaction = InventoryTransaction.new()
        :TakePlayer(player, "Tokens", price)
        :GivePlayer(player, id, quantity)

        Inventory.CommitTransaction(transaction, function(transactionId: string, error: InventoryError)
            if error ~= InventoryError.None then
                print("Transaction Error: " .. tostring(error))
            end
            GetAllPlayerItems_From_API(player, 100, nil, {}, UpdatePlayerInventory)
        end)

    end)
    scene.PlayerJoined:Connect(function(scene, player)
        print("Player Joined: " .. player.user.id .. " Getting Items")
        GetAllPlayerItems_From_API(player, 100, nil, {}, UpdatePlayerInventory)

        
        --Timer.After(1, function() GivePlayerItem(player, "free_daub", 2) end)
        --Timer.After(1, function() GivePlayerItem(player, "Tokens", 1500) end)

    end)

    -- Commit All Queued Transactions every 5 seconds
    Timer.Every(3, function()
        CommitQueuedTransactions()
    end)
end


---- GENRAL INVENTORY MANAGEMENT ----

local GiveTransactionsToCommit = {}
local TakeTransactionsToCommit = {}

function UpdatePlayerInventory(player, items)
    print("Sending " .. tostring(#items) .. " items to " .. player.name)
    --Convert the items to a format that can be sent to the client
    local clientItems = {}
    for index, item in items do
        clientItems[index] = {
            id = item.id,
            amount = item.amount
        }
    end

    playerTracker.players[player].playerInventory.value = clientItems
end

function UpdatePlayerInventory_Temporary(player, itemId, amount)

    print("Updating " .. player.name .. "'s Inventory with " .. tostring(amount) .. " " .. itemId)

    local Player_Inventory_Table_Value = playerTracker.players[player].playerInventory.value

    local itemExists = false
    for index, item in Player_Inventory_Table_Value do
        if item.id == itemId then
            item.amount = item.amount + amount
            if item.amount <= 0 and itemId ~= "Tokens" then
                table.remove(Player_Inventory_Table_Value, index)
            end
            itemExists = true
            break
        end
    end

    if not itemExists and amount > 0 then
        table.insert(Player_Inventory_Table_Value, {id = itemId, amount = amount})
    end

    --Set the players Items on Server via Player Tracker
    playerTracker.players[player].playerInventory.value = Player_Inventory_Table_Value
end

function GivePlayerItem(player : Player | nil, itemId : string, amount : number, playerID : string | nil)
    local player = player
    if not player then
        for plr, info in playerTracker.players do
            if plr.user.id == playerID then
                player = plr
            end
        end
    end
    if player then
        print("Giving " .. tostring(amount) .. " " .. itemId .. " to " .. player.name)
        table.insert(GiveTransactionsToCommit, {playerID = player.user.id, itemId = itemId, amount = amount})
        UpdatePlayerInventory_Temporary(player, itemId, amount)
    else
        playerID = playerID or "nil"
        if playerID then print("ERROR: Player not found for ID: " .. playerID) end
    end
end

function TakePlayerItem(player : Player, itemId : string, amount : number)
    table.insert(TakeTransactionsToCommit, {playerID = player.user.id, itemId = itemId, amount = amount})
    print("Taking " .. tostring(amount) .. " " .. itemId .. " from " .. player.name)
    UpdatePlayerInventory_Temporary(player, itemId, -amount)
end

function CommitQueuedTransactions()

    if #GiveTransactionsToCommit == 0 and #TakeTransactionsToCommit == 0 then
        return
    end

    print("Committing " .. tostring(#GiveTransactionsToCommit) .. " Give Transactions and " .. tostring(#TakeTransactionsToCommit) .. " Take Transactions")

    local compiledTransaction = InventoryTransaction.new()

    for index, transaction in GiveTransactionsToCommit do
        compiledTransaction:Give(transaction.playerID, transaction.itemId, transaction.amount)
    end
    for index, transaction in TakeTransactionsToCommit do
        compiledTransaction:Take(transaction.playerID, transaction.itemId, transaction.amount)
    end

    Inventory.CommitTransaction(compiledTransaction)

    GiveTransactionsToCommit = {}
    TakeTransactionsToCommit = {}
end

function GetAllPlayerItems_From_API(player, limit, cursorId, accumulatedItems, callback)
    accumulatedItems = accumulatedItems or {}
    
    Inventory.GetPlayerItems(player, limit, cursorId, function(items, newCursorId, errorCode)
        if items == nil then
            print("Got error " .. InventoryError[errorCode] .. " while getting items")
            return
        end

        -- Add fetched items to the accumulatedItems table
        
        for index, item in items do
            table.insert(accumulatedItems, item)
        end

        if newCursorId ~= nil then
            -- Continue fetching the next batch of items
            GetAllPlayerItems_From_API(player, limit, newCursorId, accumulatedItems, UpdatePlayerInventory)
        else
            -- No more items to fetch, call the callback with the accumulated items
            for each, item in accumulatedItems do
                ----print(item.id .. " " .. item.amount)
            end
            callback(player, accumulatedItems)
        end
    end)
end