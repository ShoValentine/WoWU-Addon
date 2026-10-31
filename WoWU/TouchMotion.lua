-- Shared motion for WoWU lists and the two docked quest lists. Input may arrive
-- less often than render frames; keep the destination separate from its display.
local Motion = {}
local function clamp(value, maximum) return math.max(0, math.min(maximum, value)) end
function Motion:Stop()
    self.target, self.written, self.velocity = nil, nil, 0
end
function Motion:Begin(y)
    self.target = self.scroll:GetVerticalScroll()
    self.written = self.target
    self.lastY, self.sampleTime, self.lastMove = y, GetTime(), GetTime()
    self.velocity = 0
end
function Motion:Sync(maximum)
    local current = self.scroll:GetVerticalScroll()
    -- Wheel input, selection changes and content refreshes own their new position.
    if self.written and math.abs(current-self.written) > 0.1 then
        self.target, self.velocity = current, 0
    end
    self.target = clamp(self.target or current, maximum)
    self.written = current
    return current
end
function Motion:Sample(y, scale, maximum)
    self:Sync(maximum)
    local time = GetTime()
    local dy = (y-self.lastY)/scale
    if dy ~= 0 then
        local previous = self.target
        self.target = clamp(previous+dy, maximum)
        -- Measure between pointer samples, not between render frames. A 50 ms
        -- input packet must not be interpreted as a single 8 ms flick.
        local dt = math.max(time-self.sampleTime, 1/120)
        local speed = math.max(-2500, math.min(2500, (self.target-previous)/dt))
        if time-self.lastMove > 0.12 or speed*self.velocity < 0 then self.velocity = 0 end
        self.velocity = self.velocity+(speed-self.velocity)*(1-math.exp(-dt/0.04))
        if self.target == previous then self.velocity = 0 end
        self.sampleTime, self.lastMove = time, time
    elseif time-self.lastMove > 0.12 then
        self.velocity = 0
    end
    self.lastY = y
end
function Motion:Release()
    if GetTime()-(self.lastMove or 0) > 0.12 then self.velocity = 0 end
end
function Motion:Step(elapsed, released, maximum)
    if not self.target then return end
    local current = self:Sync(maximum)
    -- Bound motion after a stalled frame; integrate decay independently of FPS.
    local dt = math.min(math.max(elapsed, 0), 0.05)
    if released and math.abs(self.velocity) > 10 then
        local decay = math.exp(-dt*10)
        self.target = clamp(self.target+self.velocity*(1-decay)/10, maximum)
        self.velocity = self.velocity*decay
    elseif released then self.velocity = 0 end
    local value = current+(self.target-current)*(1-math.exp(-dt/0.025))
    if math.abs(self.target-value) < 0.05 then value = self.target end
    value = clamp(value, maximum)
    if value ~= current then self.scroll:SetVerticalScroll(value) end
    self.written = value
    if (self.target == 0 and self.velocity < 0) or
        (self.target == maximum and self.velocity > 0) then self.velocity = 0 end
    if released and self.velocity == 0 and value == self.target then self:Stop() end
end
function WoWU_NewTouchMotion(scroll)
    return setmetatable({scroll=scroll,velocity=0}, {__index=Motion})
end
