--!Type(Module)

Tween = {}
Tween.__index = Tween

local tweens = {}

-- Easing functions
Easing = {
    linear = function(t) return t end,
    easeInQuad = function(t) return t * t end,
    easeOutQuad = function(t) return t * (2 - t) end,
    easeInOutQuad = function(t)
        -- For the first half of the animation (ease-in)
        if t < 0.5 then
            return 2 * t * t
        -- For the second half of the animation (ease-out)
        else
            return -1 + (4 - 2 * t) * t
        end
    end,    
    easeInBack = function(t)
        local c1 = 1.70158-- Increase this to make the dip at the beginning faster
        local c3 = c1 + 1
    
        return c3 * t * t * t - c1 * t * t
    end,
    easeInBackLinear = function(t)
        local c1 = 3 -- Controls the strength of the backward pull
        local c3 = c1 + 1
    
        -- Apply backward pull for the first part, then linear motion
        if t < 0.5 then
            return c3 * t * t * t - c1 * t * t -- Backward pull
        else
            -- Smooth transition into linear part
            local linear_t = (t - 0.5) * 2  -- Scaling to keep it continuous
            return (c3 * 0.5 * 0.5 * 0.5 - c1 * 0.5 * 0.5) + linear_t -- Start linear from where the dip ends
        end
    end,
    easeOutBack = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        
        t = 1 - t -- Invert `t` to make the easing go fast at the start
        return 1 - (c3 * t * t * t - c1 * t * t)
    end,
    bounce = function(t)
        if t < (1 / 2.75) then
            return 7.5625 * t * t
        elseif t < (2 / 2.75) then
            t = t - (1.5 / 2.75)
            return 7.5625 * t * t + 0.75
        elseif t < (2.5 / 2.75) then
            t = t - (2.25 / 2.75)
            return 7.5625 * t * t + 0.9375
        else
            t = t - (2.625 / 2.75)
            return 7.5625 * t * t + 0.984375
        end
    end
}

-- Constructor for the Tween class
-- Parameters:
--   from: starting value
--   to: ending value
--   duration: time in seconds over which to tween
--   loop: boolean, if true the tween will loop
--   pingPong: boolean, if true the tween will reverse on each loop
--   easing: easing function (optional, defaults to linear)
--   onUpdate: callback function(value) called every update
--   onComplete: callback function() called when tween finishes
function Tween:new(from, to, duration, loop, pingPong, easing, onUpdate, onComplete)
    local obj = {
        from = from,
        to = to,
        duration = duration,
        loop = loop,
        pingPong = pingPong,
        easing = easing or Easing.linear,
        onUpdate = onUpdate,
        onComplete = onComplete,
        elapsed = 0,
        finished = false,
        direction = 1  -- 1 for forward, -1 for backward (used in ping-pong)
    }
    setmetatable(obj, Tween)
    return obj
end

-- Update the tween
-- deltaTime: time elapsed since last update (in seconds)
function Tween:update(deltaTime)
    if self.finished then
        return
    end

    self.elapsed = self.elapsed + deltaTime * self.direction
    local t = self.elapsed / self.duration

    if t >= 1 then
        t = 1
        if self.loop then
            if self.pingPong then
                self.direction = -self.direction  -- Reverse the direction
                self.elapsed = self.duration  -- Start at the end when ping-ponging
            else
                self.elapsed = 0  -- Restart from the beginning
            end
        else
            self.finished = true
        end
    elseif t <= 0 and self.pingPong then
        t = 0
        if self.loop then
            self.direction = -self.direction  -- Reverse the direction
            self.elapsed = 0  -- Start at the beginning when ping-ponging
        else
            self.finished = true
        end
    end

    local easedT = self.easing(t)
    local currentValue = self.from + (self.to - self.from) * easedT

    if self.onUpdate then
        self.onUpdate(currentValue, easedT)
    end

    if self.finished and self.onComplete then
        self.onComplete()
        if not self.loop then
            tweens[self] = nil
        end
    end
end

-- Reset the tween to its initial state
function Tween:start()
    self.elapsed = 0
    self.finished = false
    self.direction = 1  -- Reset direction to forward
    tweens[self] = self
end

-- Stop the Tween in case of a loop
function Tween:stop(doCompleteCB)
    doCompleteCB = doCompleteCB or false
    self.finished = true
    if doCompleteCB and self.onComplete then
        self.onComplete()
        if not self.loop then
            tweens[self] = nil
        end
    end
end

-- Check if the tween has finished
function Tween:isFinished()
    return self.finished
end

function self:ClientUpdate()
    for _, tween in pairs(tweens) do
        if not tween.finished then
            tween:update(Time.deltaTime)
            if tween:isFinished() then
                tweens[tween] = nil
            end
        end
    end
end

return {
    Tween = Tween,
    Easing = Easing
}
