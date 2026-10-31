-- Touch support for Blizzard's docked quest list.
-- Never walk WorldMapFrame or its ScrollContainer: that subtree owns map panning.
local controllers = setmetatable({}, {__mode = "k"})
local records = setmetatable({}, {__mode = "k"})
local THRESHOLD, RELEASE_GUARD = 12, 0.25
local function now() return GetTime() end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function forbidden(frame)
    return frame.IsForbidden and frame:IsForbidden()
end
local function protected(frame)
    return frame.IsProtected and frame:IsProtected()
end
local function descendant(frame, parent)
    while frame do
        if forbidden(frame) then return false end
        if frame == parent then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end
local function excluded(frame)
    return forbidden(frame) or protected(frame) or (frame.IsObjectType and
        (frame:IsObjectType("Slider") or frame:IsObjectType("EditBox")))
end

local Controller = {}
function Controller:Active()
    return WoWU_IsLocked() and not combat() and self.scroll:IsVisible() and self.enabled()
end
function Controller:Inside()
    local s = self.scroll
    local l, r, t, b = s:GetLeft(), s:GetRight(), s:GetTop(), s:GetBottom()
    if not (l and r and t and b) then return false end
    local x, y = GetCursorPosition()
    local scale = s:GetEffectiveScale()
    return x >= l*scale and x <= r*scale and y <= t*scale and y >= b*scale
end
function Controller:Accepts(frame)
    local child = self.scroll:GetScrollChild()
    if not frame or not child then return false end
    -- The viewport can have protected ancestors when an external UI parents secure item
    -- buttons here. Only refuse protected input targets, never edit those buttons.
    if frame == self.scroll then return true end
    while frame and frame ~= self.scroll do
        if excluded(frame) then return false end
        if frame == child then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end
function Controller:PointerTarget()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        -- The topmost mouse receiver decides; do not reach through a popup or
        -- secure item button to an underlying quest row.
        return foci and foci[1]
    elseif GetMouseFocus then
        return GetMouseFocus()
    end
end
function Controller:Begin(target)
    if self.down then return true end
    if not self:Active() or not self:Inside() or not self:Accepts(target) then return false end
    self.down, self.dragging, self.cancelled = true, false, false
    self.startX, self.startY = GetCursorPosition()
    self.motion:Begin(self.startY)
    self.velocity, self.blockUntil = 0, 0
    self.wasPressed = true
    return true
end
function Controller:Move(elapsed)
    if not self.down then return end
    local x, y = GetCursorPosition()
    local scale = self.scroll:GetEffectiveScale()
    if (x-self.startX)^2 + (y-self.startY)^2 > (THRESHOLD*scale)^2 then
        self.dragging = true
    end
    if self.dragging then
        local maximum = math.max(0, self.scroll:GetVerticalScrollRange() or 0)
        self.motion:Sample(y, scale, maximum)
        self.motion:Step(elapsed, false, maximum)
        self.velocity = self.motion.velocity
    end
end
function Controller:Cancel()
    if self.down then
        self.down, self.cancelled = false, true
        self.blockUntil = now()+RELEASE_GUARD
    end
    self.velocity = 0
    self.motion:Stop()
end
function Controller:Release()
    if self.down then
        if self:Active() then self:Move(0) else self:Cancel() end
        self.down = false
        if self.dragging then self.blockUntil = now()+RELEASE_GUARD end
        if self.dragging then self.motion:Release() else self.motion:Stop() end
        self.velocity = self.motion.velocity
    end
end
function Controller:Blocked()
    if self.down then
        if self:Active() then self:Move(0) else self:Cancel() end
    end
    return (self.down and self.dragging) or self.cancelled or now() < self.blockUntil
end

local function wire(frame, controller)
    if excluded(frame) or not frame.GetScript or not frame.SetScript then return end
    local record = records[frame]
    if not record then
        record = {scripts = {}}
        records[frame] = record
    end
    record.controller = controller
    local function install(event, make, always)
        if frame.HasScript and not frame:HasScript(event) then return end
        local current = frame:GetScript(event)
        local previous = record.scripts[event]
        if (previous and previous == current) or (not current and not always) then return end
        local wrapper = make(current)
        record.scripts[event] = wrapper
        frame:SetScript(event, wrapper)
    end
    install("OnMouseDown", function(original)
        return function(self, button, ...)
            -- Another addon may chain our previous script before a pool refresh.
            -- Replaying the saved visual press must not start a second gesture.
            if record.replayingDown then
                if original then return original(self, button, ...) end
                return
            end
            if button == "LeftButton" then record.pendingDown = nil end
            local c = record.controller
            if button == "LeftButton" and not c.down then
                c.cancelled, c.blockUntil, c.velocity = false, 0, 0
                c.motion:Stop()
            end
            if button == "LeftButton" and c:Begin(self) then
                -- Native title OnMouseDown/Up move the text by one pixel. Defer
                -- the pair until a tap, so cancelling a swipe cannot leave it offset.
                record.pendingDown = original and {original, button, ...} or nil
                return
            end
            if original then return original(self, button, ...) end
        end
    end, true)
    install("OnMouseUp", function(original)
        return function(self, button, ...)
            local c = record.controller
            if button == "LeftButton" then
                c:Release()
                local pending = record.pendingDown
                record.pendingDown = nil
                if c:Blocked() then return end
                if pending then
                    record.replayingDown = true
                    pending[1](self, unpack(pending, 2))
                    record.replayingDown = false
                end
            end
            if original then return original(self, button, ...) end
        end
    end, true)
    for _, event in ipairs({"OnClick", "OnDoubleClick"}) do
        install(event, function(original)
            return function(self, button, ...)
                if button == "LeftButton" and record.controller:Blocked() then return end
                return original(self, button, ...)
            end
        end)
    end
    for _, event in ipairs({"OnDragStart", "OnDragStop"}) do
        install(event, function(original)
            return function(self, ...)
                local c = record.controller
                if c.down or c:Blocked() then return end
                return original(self, ...)
            end
        end)
    end
end

function Controller:Refresh()
    if combat() or forbidden(self.scroll) then return end
    local function visit(frame)
        if not frame or excluded(frame) then return end
        wire(frame, self)
        if frame.GetChildren then
            for _, child in ipairs({frame:GetChildren()}) do visit(child) end
        end
    end
    -- Restrict traversal to content. Scrollbar/search/menu controls are siblings.
    visit(self.scroll:GetScrollChild())
end
function Controller:Update(elapsed)
    local pressed = IsMouseButtonDown("LeftButton")
    if not self:Active() then
        self:Cancel()
        -- Keep a cancelled press blocked through release, including a combat
        -- transition. A fresh press always starts a new decision.
        if self.cancelled and pressed then self.blockUntil = now()+RELEASE_GUARD end
        if not pressed and now() >= self.blockUntil then self.cancelled = false end
        self.wasPressed = pressed
        return
    end
    self.scanElapsed = self.scanElapsed+elapsed
    if self.scanElapsed >= 0.25 then self.scanElapsed = 0; self:Refresh() end
    if pressed and not self.wasPressed then
        self.cancelled, self.blockUntil, self.velocity = false, 0, 0
        self.motion:Stop()
        self:Begin(self:PointerTarget())
    end
    if self.down then
        if pressed then self:Move(elapsed) else self:Release() end
    elseif not pressed then
        self.motion:Step(elapsed, true, math.max(0, self.scroll:GetVerticalScrollRange() or 0))
        self.velocity = self.motion.velocity
    end
    if not pressed and now() >= self.blockUntil then self.cancelled = false end
    self.wasPressed = pressed
end

function WoWU_AttachExternalTouchScroll(scroll, enabled)
    if not scroll or forbidden(scroll) or combat() then return end
    -- Forever's QuestScrollFrame exposes this pixel-scroll API.
    if not (scroll.GetScrollChild and scroll.GetVerticalScrollRange and
        scroll.GetVerticalScroll and scroll.SetVerticalScroll) then return end
    local c = controllers[scroll]
    if not c then
        c = setmetatable({scroll=scroll, enabled=enabled, velocity=0, blockUntil=0,
            motion=WoWU_NewTouchMotion(scroll),
            scanElapsed=0, wasPressed=IsMouseButtonDown("LeftButton")}, {__index=Controller})
        controllers[scroll] = c
        -- Own the update frame; leave external OnUpdate/OnMouseWheel scripts intact.
        local driver = CreateFrame("Frame", nil, scroll)
        driver:SetScript("OnUpdate", function(_, elapsed) c:Update(elapsed) end)
        driver:SetScript("OnHide", function() c:Cancel() end)
        driver:SetScript("OnShow", function()
            c.wasPressed = IsMouseButtonDown("LeftButton")
            c:Refresh()
        end)
        c.driver = driver
    else
        c.enabled = enabled
    end
    c:Refresh()
    return c
end

local mapHooked = false
local refreshMap
function WoWU_BindMapQuestTouch(map, host, isDocked)
    if combat() then return end
    local questMap = _G.QuestMapFrame
    local quests = questMap and questMap.QuestsFrame
    local scroll = quests and quests.ScrollFrame or _G.QuestScrollFrame
    if not scroll or not descendant(scroll, map) then return end
    local function enabled()
        return isDocked() and map:GetParent() == host and host:IsVisible()
    end
    local c = WoWU_AttachExternalTouchScroll(scroll, enabled)
    refreshMap = function() if c then c:Refresh() end end
    if not mapHooked and QuestLogQuests_Update and hooksecurefunc then
        mapHooked = true
        hooksecurefunc("QuestLogQuests_Update", function() if refreshMap then refreshMap() end end)
    end
end
