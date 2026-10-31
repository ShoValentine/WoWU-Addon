local addonName = ...
local WoWU = CreateFrame("Frame")
local dashboard
local pages = {}
local tabs = {}
local currentPage = "Dashboard"
local initialized = false

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 0.85,
    visible = true,
    locked = false,
    page = "Dashboard",
}

local sections = {
    {"Dashboard", "Dashboard", "Second-screen command centre"},
    {"Bags", "Inventory", "Unified bag inventory"},
    {"Character", "Character", "Equipment and attributes"},
    {"Quests", "Quest Log", "Your adventures across Azeroth"},
    {"Map", "World Map", "Explore Azeroth"},
    {"Spells", "Spellbook", "Abilities and passive spells"},
    {"More", "More", "Additional Blizzard interfaces"}
}

local function makeText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    fs:SetTextColor(r, g, b)
    fs:SetJustifyH("LEFT")
    return fs
end

local function drawBorder(frame, color)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 20,
        insets = {left=5,right=5,top=5,bottom=5},
    })
    frame:SetBackdropColor(color[1], color[2], color[3], 0.98)
    frame:SetBackdropBorderColor(0.58, 0.43, 0.23, 1)
end

local function savePosition()
    if not dashboard or not WoWUDB then return end
    local point, _, relativePoint, x, y = dashboard:GetPoint(1)
    WoWUDB.point = point or "CENTER"
    WoWUDB.relativePoint = relativePoint or "CENTER"
    WoWUDB.x = x or 0
    WoWUDB.y = y or 0
end

local function showPage(name)
    if not pages[name] then return end
    if currentPage == "Dashboard" and name ~= "Dashboard" and WoWU_DashboardExit then WoWU_DashboardExit() end
    if name == "More" and type(WoWU_ResetMore) == "function" then WoWU_ResetMore() end
    for key, page in pairs(pages) do
        page:SetShown(key == name)
    end
    for key, tab in pairs(tabs) do
        if key == name then
            tab:SetBackdropColor(0.42, 0.29, 0.13, 1)
            tab:SetBackdropBorderColor(0.96, 0.77, 0.40, 1)
            tab.label:SetTextColor(1, 0.87, 0.62)
        else
            tab:SetBackdropColor(0.10, 0.13, 0.15, 1)
            tab:SetBackdropBorderColor(0.42, 0.35, 0.24, 1)
            tab.label:SetTextColor(0.75, 0.69, 0.56)
        end
    end
    currentPage = name
    WoWUDB.page = name
    if name == "Dashboard" and WoWU_DashboardEnter then WoWU_DashboardEnter() end
end

WoWU_ShowPage = showPage

-- Touch gesture helpers shared by all WoWU modules. Dragging is enabled only when locked.
function WoWU_IsLocked()
    return WoWUDB and WoWUDB.locked == true
end
function WoWU_SetLocked(value)
    if WoWUDB then WoWUDB.locked = not not value end
    if dashboard then
        if WoWU_IsLocked() then dashboard:RegisterForDrag() else dashboard:RegisterForDrag("LeftButton") end
    end
end
-- Poll the pointer across the WHOLE scroll viewport, including child buttons.
-- A tap only activates the child if movement stays below the drag threshold.
function WoWU_TouchTapAllowed(scroll)
    if not (WoWU_IsLocked() and scroll and scroll.WoWUTouchReady) then return true end
    local g=scroll.WoWUGesture
    if not g then return true end
    if g.dragging then return false end
    if g.down and GetCursorPosition then
        local x,y=GetCursorPosition()
        local scale=scroll:GetEffectiveScale() or 1
        if (x-g.startX)^2+(y-g.startY)^2 > (12*scale)^2 then return false end
    end
    return true
end
function WoWU_EnableTouchScroll(scroll)
    if not scroll or scroll.WoWUTouchReady then return end
    scroll.WoWUTouchReady=true
    scroll:EnableMouse(true)
    local g={down=false,dragging=false,wasPressed=false,startX=0,startY=0,lastY=0,velocity=0}
    scroll.WoWUGesture=g
    local function inside(x,y)
        local l,r,t,b=scroll:GetLeft(),scroll:GetRight(),scroll:GetTop(),scroll:GetBottom()
        if not (l and r and t and b) then return false end
        local scale=scroll:GetEffectiveScale() or 1
        x,y=x/scale,y/scale
        return x>=l and x<=r and y<=t and y>=b
    end
    scroll:HookScript('OnHide',function() g.down=false;g.dragging=false;g.velocity=0 end)
    scroll:HookScript('OnUpdate',function(self,elapsed)
        if not WoWU_IsLocked() then g.down=false;g.dragging=false;g.velocity=0;g.wasPressed=false;return end
        if not (IsMouseButtonDown and GetCursorPosition) then return end
        local child=self:GetScrollChild()
        if not child then return end
        local maximum=math.max(0,child:GetHeight()-self:GetHeight())
        local pressed=IsMouseButtonDown('LeftButton')
        local x,y=GetCursorPosition()
        local scale=self:GetEffectiveScale() or 1
        if pressed and not g.wasPressed and inside(x,y) then
            g.down=true;g.dragging=false;g.startX=x;g.startY=y;g.lastY=y;g.velocity=0
        end
        if g.down and pressed then
            if (x-g.startX)^2+(y-g.startY)^2>(12*scale)^2 then g.dragging=true end
            if g.dragging and maximum>0 then
                local dy=(y-g.lastY)/scale
                local previous=self:GetVerticalScroll()
                local target=math.max(0,math.min(maximum,previous+dy))
                self:SetVerticalScroll(target)
                g.velocity=(target-previous)/math.max(elapsed,.012)
            end
            g.lastY=y
        elseif g.down and not pressed then
            g.down=false
            if not g.dragging then g.velocity=0 end
            -- Keep dragging true until the NEXT press; this also guards an
            -- OnClick that fires on the same mouse release frame.
        elseif not pressed and math.abs(g.velocity)>10 and maximum>0 then
            local previous=self:GetVerticalScroll()
            local nextValue=math.max(0,math.min(maximum,previous+g.velocity*elapsed))
            self:SetVerticalScroll(nextValue)
            if nextValue==previous then g.velocity=0 else g.velocity=g.velocity*math.exp(-elapsed*10) end
        end
        g.wasPressed=pressed
    end)
end

local function build()
    dashboard = CreateFrame("Frame", "WoWU_MainFrame", UIParent, "BackdropTemplate")
    dashboard:SetSize(1280, 800)
    dashboard:SetScale(WoWUDB.scale or defaults.scale)
    dashboard:SetFrameStrata("HIGH")
    dashboard:SetMovable(true)
    dashboard:SetClampedToScreen(false)
    dashboard:EnableMouse(true)
    dashboard:RegisterForDrag("LeftButton")
    dashboard:SetScript("OnDragStart", function(self)
        if not WoWU_IsLocked() then self:StartMoving() end
    end)
    dashboard:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    dashboard:ClearAllPoints()
    dashboard:SetPoint(
        WoWUDB.point or "CENTER", UIParent,
        WoWUDB.relativePoint or "CENTER",
        WoWUDB.x or 0, WoWUDB.y or 0
    )
    drawBorder(dashboard, {0.09, 0.12, 0.15})
    WoWU_SetLocked(WoWUDB.locked)

    local background = dashboard:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetPoint("TOPLEFT", 13, -66)
    background:SetPoint("BOTTOMRIGHT", -13, 13)
    background:SetColorTexture(0.73, 0.59, 0.39, 1)

    local paper = dashboard:CreateTexture(nil, "BACKGROUND", nil, 2)
    paper:SetPoint("TOPLEFT", 18, -70)
    paper:SetPoint("BOTTOMRIGHT", -18, 18)
    paper:SetTexture("Interface\\QuestFrame\\QuestBG")
    paper:SetTexCoord(0.02, 0.98, 0.02, 0.98)
    paper:SetAlpha(0.35)

    local tabWidth = 168
    local tabGap = 8
    local leftInset = 22

    for i, entry in ipairs(sections) do
        local name, title, subtitle = entry[1], entry[2], entry[3]
        local tab = CreateFrame("Button", nil, dashboard, "BackdropTemplate")
        tab:SetSize(tabWidth, 45)
        tab:SetPoint("TOPLEFT", leftInset + (i-1)*(tabWidth+tabGap), -12)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 15,
            insets = {left=3,right=3,top=3,bottom=3}
        })
        local label = makeText(tab, 16, 1, 0.86, 0.59)
        label:SetPoint("CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetText(name)
        tab.label = label
        tabs[name] = tab
        tab:SetScript("OnClick", function() showPage(name) end)

        local page = CreateFrame("Frame", nil, dashboard)
        page:SetPoint("TOPLEFT", 25, -83)
        page:SetPoint("BOTTOMRIGHT", -25, 25)
        pages[name] = page

        -- The active top tab identifies the page; no separate category header.
        local panel = CreateFrame("Frame", nil, page, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 15, -10)
        panel:SetPoint("BOTTOMRIGHT", -15, 15)
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 20,
            insets = {left=5,right=5,top=5,bottom=5}
        })
        panel:SetBackdropColor(0.13, 0.17, 0.18, 0.96)
        panel:SetBackdropBorderColor(0.56, 0.43, 0.26, 1)

        if name == "Dashboard" and WoWU_BuildDashboard then
            WoWU_BuildDashboard(panel)
        elseif name == "Bags" and WoWU_BuildBags then
            WoWU_BuildBags(panel)
        elseif name == "Character" and WoWU_BuildCharacter then
            WoWU_BuildCharacter(panel)
        elseif name == "Quests" and WoWU_BuildQuests then
            WoWU_BuildQuests(panel)
        elseif name == "Map" and WoWU_BuildMap then
            WoWU_BuildMap(panel)
        elseif name == "Spells" and WoWU_BuildSpells then
            WoWU_BuildSpells(panel)
        elseif name == "Talents" and WoWU_BuildTalents then
            WoWU_BuildTalents(panel)
        elseif name == "More" and WoWU_BuildMore then
            WoWU_BuildMore(panel)
        else
        local placeholder = makeText(panel, 26, 0.91, 0.75, 0.47)
        placeholder:SetPoint("CENTER", 0, 14)
        placeholder:SetJustifyH("CENTER")
        placeholder:SetText(name .. " module")

        local status = makeText(panel, 15, 0.72, 0.69, 0.61)
        status:SetPoint("TOP", placeholder, "BOTTOM", 0, -15)
        status:SetJustifyH("CENTER")
        status:SetText("Framework ready. Blizzard UI integration comes next.")
        end
        page:Hide()
    end

    showPage(WoWUDB.page or "Dashboard")
    dashboard:SetShown(WoWUDB.visible ~= false)
    dashboard:HookScript("OnHide", function() if WoWU_DashboardExit then WoWU_DashboardExit() end end)
    dashboard:HookScript("OnShow", function() if currentPage == "Dashboard" and WoWU_DashboardEnter then WoWU_DashboardEnter() end end)
end

local function initialize()
    if initialized then return end
    initialized = true
    if type(WoWUDB) ~= "table" then WoWUDB = {} end
    for key, value in pairs(defaults) do
        if WoWUDB[key] == nil then WoWUDB[key] = value end
    end
    build()
    print("|cffebc36bWoWU|r v0.14.9 loaded. Type /wowu for commands.")
end

SLASH_WOWU1 = "/wowu"
SlashCmdList["WOWU"] = function(message)
    if not dashboard then return end
    local command, value = string.match(message or "", "^(%S*)%s*(.*)$")
    command = string.lower(command or "")
    if command == "reset" then
        dashboard:ClearAllPoints()
        dashboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        savePosition()
        dashboard:Show()
        WoWUDB.visible = true
    elseif command == "scale" then
        local number = tonumber(value)
        if number and number >= 0.3 and number <= 1.5 then
            dashboard:SetScale(number)
            WoWUDB.scale = number
            print("WoWU scale set to " .. number)
        else
            print("Usage: /wowu scale 0.3-1.5")
        end
    else
        if dashboard:IsShown() then
            dashboard:Hide()
            WoWUDB.visible = false
        else
            dashboard:Show()
            WoWUDB.visible = true
        end
    end
end

WoWU:RegisterEvent("ADDON_LOADED")
WoWU:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        initialize()
    end
end)
