--!Type(Module)

local GameState = NumberValue.new("gameState", 0)



---- CLIENT ----

function SyncToState(newState, oldState)
    print("GameState", newState)
end

function self:ClientAwake()
    GameState.Changed:Connect(SyncToState)
end



---- SERVER ----

function self:ServerAwake()
end