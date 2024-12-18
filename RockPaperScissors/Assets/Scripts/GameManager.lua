--!Type(Module)

local uiManager = require("UIManager")
local playerTracker = require("PlayerTracker")

-------- CLIENT --------
function self:ClientAwake()
end

function StartChallenge()
    uiManager.ShowOptions()
end



-------- SERVER --------
function self:ServerAwake()
end