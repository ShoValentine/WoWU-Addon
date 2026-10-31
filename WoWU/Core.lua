local addonName = ...
local WoWU = CreateFrame("Frame")
local dashboard
local pages = {}
local tabs = {}
local currentPage = "Dashboard"
local initialized = false
local scalePending = false

function WoWU_SetScale(value)
    if WoWUViewport and WoWUViewport.active then return false,"Stop the viewport preview before changing WoWU scale." end
    local number=tonumber(value)
    if not number or number~=number or number<.3 or number>1.5 then
        return false,"Enter a WoWU scale from 30 to 150%."
    end
    if not WoWUDB then return false,"WoWU is not ready yet." end
    WoWUDB.scale=number
    if InCombatLockdown and InCombatLockdown() then
        scalePending=true
        return true,"WoWU scale saved; applies after combat."
    end
    if dashboard then dashboard:SetScale(number) end
    scalePending=false
    return true,"WoWU scale: "..math.floor(number*100+.5).."%"
end

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 0.85,
    visible = true,
    locked = true,
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

function WoWU_RefreshTopTabs()
    local old=WoWUDB.topTabs or {}
    local editable={Bags=true,Character=true,Quests=true,Map=true,Spells=true,Professions=true,Achievements=true,Social=true,Talents=true,Legacy=true,Settings=true,Adventure=true,Collections=true,["Adventure Guide"]=true,["Dungeon Journal"]=true,["Dungeon Finder"]=true,["Housing Dashboard"]=true,Shop=true}
    local configured,seen={},{}
    for i=1,6 do local name=WoWUClient.ModuleName(old[i]);if name=="Group Finder"then name="Dungeon Finder"end;if editable[name]and WoWUClient.ModuleAvailable(name)and not seen[name]and #configured<5 then configured[#configured+1]=name;seen[name]=true end end
    for _,name in ipairs({"Bags","Character","Quests","Map","Spells"})do if #configured<5 and not seen[name]then configured[#configured+1]=name;seen[name]=true end end
    WoWUDB.topTabs=configured
    local allowed={Dashboard=true,Bags=true,Character=true,Quests=true,Map=true,Spells=true,More=true,
        Professions=true,Achievements=true,Social=true,Talents=true,Legacy=true,Settings=true,Adventure=true,Collections=true,["Adventure Guide"]=true,["Dungeon Journal"]=true,["Dungeon Finder"]=true,["Housing Dashboard"]=true,Shop=true}
    for i,entry in ipairs(sections)do
        local tab=tabs[entry[1]]
        if tab then
            local name=i==1 and "Dashboard" or i==7 and "More" or configured[i-1]or entry[1]
            if not allowed[name]then name=entry[1]end
            tab.module=name;tab.label:SetText(name);WoWU_Theme.Tab(tab,name==(WoWUDB.page or "Dashboard"))
        end
    end
end

local function makeText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    WoWU_Theme.TextColor(fs,r, g, b)
    fs:SetJustifyH("LEFT")
    return fs
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
    name=WoWUClient.ModuleName(name)
    if name=="Group Finder"then name="Dungeon Finder"end
    if InCombatLockdown and InCombatLockdown() then
        print("WoWU: change main tabs after combat.")
        return
    end
    if WoWUDetails then WoWUDetails.Close()end
    if WoWUInteractions and WoWUInteractions.OnNavigate then WoWUInteractions.OnNavigate()end
    if not WoWUClient.ModuleAvailable(name)then name="More"end
    local requested=name
    if (name=="Housing Dashboard"or name=="Shop")and WoWU_OpenRetailShortcut then
        local ok,message=WoWU_OpenRetailShortcut(name);if not ok then print("WoWU: "..tostring(message))end;return
    end
    if name=="Adventure" then if WoWU_OpenAdventure then WoWU_OpenAdventure()end;return end
    local module
    if not pages[name] then module=name;name="More" end
    if not pages[name] then return end
    if currentPage == "Dashboard" and name ~= "Dashboard" and WoWU_DashboardExit then WoWU_DashboardExit() end
    if name == "More" and type(WoWU_ResetMore) == "function" then WoWU_ResetMore() end
    for key, page in pairs(pages) do
        page:SetShown(key == name)
    end
    for key, tab in pairs(tabs) do
        WoWU_Theme.Tab(tab, (tab.module or key) == requested)
    end
    currentPage = name
    WoWUDB.page = requested
    if module and WoWU_OpenMoreModule then WoWU_OpenMoreModule(module)end
    if name == "Dashboard" and WoWU_DashboardEnter then WoWU_DashboardEnter() end
end

WoWU_ShowPage = showPage
function WoWU_GetCurrentModuleFrame()return pages[currentPage]end

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
function WoWU_StopTouchScroll(scroll,untilRelease)
    local g=scroll and scroll.WoWUGesture
    if not g then return end
    g.down=false;g.dragging=false;g.blockUntilRelease=untilRelease==true
    g.wasPressed=IsMouseButtonDown and IsMouseButtonDown("LeftButton")or false
    if g.motion then g.motion:Stop()end
end
function WoWU_EnableTouchScroll(scroll)
    if not scroll or scroll.WoWUTouchReady then return end
    scroll.WoWUTouchReady=true
    WoWU_Theme.Scrollbar(scroll)
    scroll:EnableMouse(true)
    local g={down=false,dragging=false,wasPressed=false,startX=0,startY=0}
    local motion=WoWU_NewTouchMotion(scroll)
    g.motion=motion
    scroll.WoWUGesture=g
    local function inside(x,y)
        local l,r,t,b=scroll:GetLeft(),scroll:GetRight(),scroll:GetTop(),scroll:GetBottom()
        if not (l and r and t and b) then return false end
        local scale=scroll:GetEffectiveScale() or 1
        x,y=x/scale,y/scale
        return x>=l and x<=r and y<=t and y>=b
    end
    scroll:HookScript('OnHide',function() g.down=false;g.dragging=false;motion:Stop() end)
    scroll:HookScript('OnUpdate',function(self,elapsed)
        if not (IsMouseButtonDown and GetCursorPosition) then return end
        local pressed=IsMouseButtonDown('LeftButton')
        local blocked=self.WoWUTouchBlocked and self.WoWUTouchBlocked()
        if blocked then g.blockUntilRelease=pressed end
        if self.WoWUSuspendTouch or blocked or g.blockUntilRelease or not WoWU_IsLocked() then
            g.down=false;g.dragging=false;motion:Stop();g.wasPressed=pressed
            if not pressed then g.blockUntilRelease=false end
            return
        end
        local child=self:GetScrollChild()
        if not child then return end
        local maximum=math.max(0,child:GetHeight()-self:GetHeight())
        local x,y=GetCursorPosition()
        local scale=self:GetEffectiveScale() or 1
        if pressed and not g.wasPressed then
            motion:Stop()
            if inside(x,y) then
                g.down=true;g.dragging=false;g.startX=x;g.startY=y;motion:Begin(y)
            end
        end
        if g.down and pressed then
            if (x-g.startX)^2+(y-g.startY)^2>(12*scale)^2 then g.dragging=true end
            if g.dragging then
                motion:Sample(y,scale,maximum)
                motion:Step(elapsed,false,maximum)
                -- Reward/item hover panels can repeatedly open as content moves
                -- underneath a held finger. Hide only a tooltip owned by this list.
                local owner=GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()
                while owner do
                    if owner==self then GameTooltip:Hide();break end
                    owner=owner.GetParent and owner:GetParent()
                end
            end
        elseif g.down and not pressed then
            g.down=false
            if g.dragging then motion:Sample(y,scale,maximum);motion:Release()
            else motion:Stop() end
            -- Keep dragging true until the NEXT press; this also guards an
            -- OnClick that fires on the same mouse release frame.
        elseif not pressed then
            motion:Step(elapsed,true,maximum)
        end
        g.wasPressed=pressed
    end)
end

local function build()
    dashboard = CreateFrame("Frame", "WoWU_MainFrame", UIParent, "BackdropTemplate")
    dashboard:Hide() -- Build hidden; mode activation is the only automatic reveal.
    WoWUDetails.SetHost(dashboard)
    dashboard:SetSize(1280, 800)
    dashboard:SetScale(WoWUDB.scale or defaults.scale)
    dashboard:SetFrameStrata("HIGH")
    dashboard:SetMovable(true)
    dashboard:SetClampedToScreen(false)
    dashboard:EnableMouse(true)
    dashboard:RegisterForDrag("LeftButton")
    dashboard:SetScript("OnDragStart", function(self)
        if not WoWU_IsLocked() and not (WoWUViewport and WoWUViewport.active) then self:StartMoving() end
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
    WoWU_Theme.Panel(dashboard, "outer", false)
    WoWU_SetLocked(WoWUDB.locked)

    local tabWidth = 168
    local tabGap = 8
    local leftInset = 22

    for i, entry in ipairs(sections) do
        local name, title, subtitle = entry[1], entry[2], entry[3]
        local tab = CreateFrame("Button", nil, dashboard, "BackdropTemplate")
        tab:SetSize(tabWidth, 66)
        tab:SetPoint("TOPLEFT", leftInset + (i-1)*(tabWidth+tabGap), -12)
        WoWU_Theme.Backdrop(tab,{
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
        tab.module=name
        tabs[name] = tab
        WoWU_Theme.Button(tab)
        tab:SetScript("OnClick", function() showPage(tab.module or name) end)

        local page = CreateFrame("Frame", nil, dashboard)
        page:SetPoint("TOPLEFT", 25, -83)
        page:SetPoint("BOTTOMRIGHT", -25, 25)
        pages[name] = page

        -- The active top tab identifies the page; no separate category header.
        local panel = CreateFrame("Frame", nil, page, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 15, -10)
        panel:SetPoint("BOTTOMRIGHT", -15, 15)
        WoWU_Theme.Backdrop(panel,{
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 20,
            insets = {left=5,right=5,top=5,bottom=5}
        })
        WoWU_Theme.Color(panel,0.13, 0.17, 0.18, 0.96)
        WoWU_Theme.Panel(panel, "inset")

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

    if WoWU_BuildInteractions then WoWU_BuildInteractions(dashboard)end
    if WoWU_BuildNPCDialogs then WoWU_BuildNPCDialogs()end
    if WoWU_BuildCompanionPrompts then WoWU_BuildCompanionPrompts(dashboard)end
    WoWU_RefreshTopTabs()
    showPage(WoWUDB.page or "Dashboard")
    dashboard:Hide() -- Start hidden; companion activation or /wowushow reveals it.
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
    WoWU_Theme.Initialize()
    build()
    print("|cffebc36bWoWU|r v0.13.4 loaded. Type /wowu for commands; /wowuclient for game version.")
end

SLASH_WOWU1 = "/wowu"
SlashCmdList["WOWU"] = function(message)
    if not dashboard then return end
    local command, value = string.match(message or "", "^(%S*)%s*(.*)$")
    command = string.lower(command or "")
    if command=="on" or command=="off" then
        local ok,status
        if command=="on" then ok,status=WoWUCompanionBridge.PromptEnable()
        else ok,status=WoWUCompanionBridge.PromptDisable() end
        if not ok then print("WoWU: "..tostring(status)) end
    elseif command == "reset" then
        dashboard:ClearAllPoints()
        dashboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        savePosition()
        dashboard:Show()
        WoWUDB.visible = true
    elseif command=="settings" or command=="more" then
        if InCombatLockdown()then print("WoWU: open modules after combat.");return end
        dashboard:Show();WoWUDB.visible=true;showPage(command=="settings" and "Settings" or "More")
    elseif command == "scale" then
        local number = tonumber(value)
        local _,status=WoWU_SetScale(number)
        print(status)
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
WoWU:RegisterEvent("PLAYER_REGEN_ENABLED")
WoWU:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        initialize()
    elseif event=="PLAYER_REGEN_ENABLED" and scalePending then
        WoWU_SetScale(WoWUDB.scale)
    end
end)

SLASH_WOWUSHOW1="/wowushow"
SlashCmdList.WOWUSHOW=function()
 if WoWU_MainFrame then WoWU_MainFrame:Show() end
end
SLASH_WOWUHIDE1="/wowuhide"
SlashCmdList.WOWUHIDE=function()
 if WoWU_MainFrame then WoWU_MainFrame:Hide() end
end
