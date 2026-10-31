-- Collect actual addon buttons: do not proxy protected clicks or replace handlers.
local function combat() return InCombatLockdown and InCombatLockdown() end
local function safe(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...);if ok then return a,b end
end
local function forbidden(f) return not f or f.IsForbidden and f:IsForbidden() end
local function clean(name) return (tostring(name or "Addon"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^LibDBIcon10_","")) end
function WoWU_BuildAddonMenu(parent,middle,holder)
    local toggle=CreateFrame("Button",nil,middle,"BackdropTemplate")
    toggle:SetSize(44,44);toggle:SetPoint("LEFT",holder,"RIGHT",8,-75)
    toggle.label=toggle:CreateFontString(nil,"OVERLAY","GameFontNormal");toggle.label:SetPoint("CENTER");toggle.label:SetText("Addons");toggle.label:SetFont("Fonts\\FRIZQT__.TTF",10,"")
    WoWU_Theme.Tab(toggle,false);WoWU_Theme.Button(toggle)
    local popup=CreateFrame("Frame",nil,parent,"SecureHandlerStateTemplate,BackdropTemplate")
    popup:SetSize(340,400);popup:SetPoint("TOPRIGHT",holder,"TOPRIGHT",48,-8)
    popup:SetFrameLevel(parent:GetFrameLevel()+250);popup:EnableMouse(true);WoWU_Theme.Panel(popup,"outer",false);popup:Hide()
    popup:SetAttribute("_onstate-combat",[[if newstate=="1" then self:Hide() end]])
    RegisterStateDriver(popup,"combat","[combat] 1; 0")
    local title=popup:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",18,-18);title:SetText("Addon shortcuts")
    local close=CreateFrame("Button",nil,popup,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",function() if not combat() then popup:Hide() end end)
    local scroll=CreateFrame("ScrollFrame",nil,popup,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",14,-49);scroll:SetPoint("BOTTOMRIGHT",-34,68)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(288,1);scroll:SetScrollChild(body)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    WoWU_Theme.Scrollbar(scroll)
    local hint=popup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");hint:SetPoint("BOTTOMLEFT",17,13);hint:SetWidth(305);hint:SetJustifyH("LEFT");hint:SetText("Original addon clicks and tooltips. Scroll for more.")
    local collect=CreateFrame("CheckButton",nil,popup,"UICheckButtonTemplate");collect:SetSize(30,30);collect:SetPoint("BOTTOMLEFT",13,32)
    local collectLabel=popup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");collectLabel:SetPoint("LEFT",collect,"RIGHT",4,0);collectLabel:SetText("Collect minimap icons")
    local entries,byButton,compartmentEntries={},{},{}
    local layout,discover
    local function enabled()
        if not (WoWUViewport and WoWUViewport.active) then return false end
        if WoWU_GetMinimapLocation and WoWU_GetMinimapLocation()=="main"then return false end
        -- Keep collected buttons on the companion while switching modules;
        -- only ending the mode (or disabling collection) returns them to WoW.
        if WoWUDashboardLayout and WoWUDashboardLayout.IsEnabled and not WoWUDashboardLayout.IsEnabled("mapcontrols") then return false end
        return not WoWUDB or WoWUDB.collectMinimapIcons~=false
    end
    local function snapshot(b)
        local original={parent=b:GetParent(),points={},scale=b:GetScale(),strata=b:GetFrameStrata(),level=b:GetFrameLevel(),shown=b:IsShown(),insets={b:GetHitRectInsets()},drag=b:GetScript("OnDragStart"),stop=b:GetScript("OnDragStop"),click=b:GetScript("OnClick")}
        for i=1,b:GetNumPoints()do original.points[i]={b:GetPoint(i)}end
        return original
    end
    local function place(e)
        if combat() or e.busy or not enabled() or forbidden(e.button) then return end
        local b=e.button;e.busy=true
        if not e.docked then e.original=snapshot(b);e.docked=true end
        b:SetParent(e.row);b:ClearAllPoints();b:SetPoint("LEFT",e.row,"LEFT",7,0)
        b:SetScale(1);b:SetFrameStrata(popup:GetFrameStrata());b:SetFrameLevel(e.row:GetFrameLevel()+2)
        b:SetScript("OnDragStart",nil);b:SetScript("OnDragStop",nil)
        if e.click then b:SetScript("OnClick",e.click) end
        b:SetHitRectInsets(0,-math.max(0,268-b:GetWidth()),-5,-5)
        b:Show();e.busy=false
    end
    local function restore(e)
        if not e.docked then return end
        local b,o=e.button,e.original;if forbidden(b) then return end
        e.busy=true;b:SetParent(o.parent);b:ClearAllPoints()
        for _,point in ipairs(o.points) do b:SetPoint(unpack(point)) end
        b:SetScale(o.scale);b:SetFrameStrata(o.strata);b:SetFrameLevel(o.level)
        b:SetHitRectInsets(unpack(o.insets));b:SetScript("OnDragStart",o.drag);b:SetScript("OnDragStop",o.stop)
        if e.click then b:SetScript("OnClick",o.click) end
        b:SetShown(o.shown);e.docked=false;e.busy=false;e.row:Hide()
    end
    local function row(name)
        local r=CreateFrame("Frame",nil,body,"BackdropTemplate");r:SetSize(288,50);WoWU_Theme.Panel(r,"inset",false)
        local label=r:CreateFontString(nil,"OVERLAY","GameFontNormal");label:SetPoint("LEFT",52,0);label:SetWidth(224);label:SetJustifyH("LEFT");label:SetText(clean(name));r.label=label
        return r
    end
    local function take(b,name)
        if forbidden(b) or byButton[b] or not b.IsObjectType or not b:IsObjectType("Button") then return end
        local e={button=b,name=clean(name or b:GetName()),original={parent=b:GetParent(),points={},scale=b:GetScale(),strata=b:GetFrameStrata(),level=b:GetFrameLevel(),shown=b:IsShown(),insets={b:GetHitRectInsets()},drag=b:GetScript("OnDragStart"),stop=b:GetScript("OnDragStop")}}
        for i=1,b:GetNumPoints() do e.original.points[i]={b:GetPoint(i)} end
        if not b:IsProtected() and not b:GetAttribute("type") and b:GetScript("OnClick") then
            e.original.click=b:GetScript("OnClick")
            e.click=function(self,...)
                if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end
                return e.original.click(self,...)
            end
        end
        e.row=row(e.name);entries[#entries+1]=e;byButton[b]=e
        -- Some libraries periodically restore circular anchors; constrain only
        -- buttons explicitly collected here, and only outside combat.
        if hooksecurefunc then
            hooksecurefunc(b,"SetPoint",function() place(e) end)
            hooksecurefunc(b,"SetParent",function() place(e) end)
        end
        place(e)
    end
    local function exclusions()
        local set={[toggle]=true,[close]=true,[collect]=true}
        for _,name in ipairs({"MinimapZoomIn","MinimapZoomOut","MiniMapTracking","MiniMapTrackingButton","MiniMapMailFrame","MiniMapMailBorder","MiniMapBattlefieldFrame","MiniMapWorldMapButton","MiniMapInstanceDifficulty","MiniMapChallengeMode","MiniMapVoiceChatFrame","MinimapZoneTextButton","GameTimeFrame","QueueStatusMinimapButton","QueueStatusButton","AddonCompartmentFrame","TimeManagerClockButton","MinimapBackdrop","MinimapCluster","Minimap"}) do if _G[name] then set[_G[name]]=true end end
        for _,owner in pairs({Minimap,MinimapCluster,MinimapCluster and MinimapCluster.Tracking}) do
            for _,key in ipairs({"ZoomIn","ZoomOut","Tracking","TrackingButton","ZoneTextButton","Calendar","Clock","MailFrame","IndicatorFrame","InstanceDifficulty","AddonCompartmentFrame","Button","DifficultyIndicator","ExpansionLandingPageMinimapButton"}) do
                if owner[key] then set[owner[key]]=true end
            end
        end
        return set
    end
    local function candidate(b,excluded)
        if WoWUMinimapControls and WoWUMinimapControls.IsDocked(b) then return false end
        if forbidden(b) or excluded[b] or byButton[b] or not b.IsObjectType or not b:IsObjectType("Button") then return false end
        local name=b:GetName() or ""
        if name:find("^WoWU") or name:find("^MiniMapTracking") or name:find("^QueueStatus") or name:find("^ExpansionLanding") then return false end
        return b:GetWidth()>=16 and b:GetWidth()<=80 and b:GetHeight()>=16 and b:GetHeight()<=80 and (b:GetScript("OnClick") or b:GetAttribute("type"))
    end
    discover=function()
        if combat() then return end
        if not enabled() then
            popup:Hide()
            for _,e in ipairs(entries) do restore(e) end
        end
        local known={}
        if enabled() then
            local lib=LibStub and LibStub("LibDBIcon-1.0",true)
            if lib then
                for name,b in pairs(lib.objects or {}) do if not forbidden(b) then take(b,name) end end
                for _,name in ipairs(safe(lib.GetButtonList,lib) or {}) do take(safe(lib.GetMinimapButton,lib,name),name) end
            end
            local excluded=exclusions()
            local function walk(f,depth)
                if forbidden(f) or depth>2 or not f.GetChildren then return end
                for _,b in ipairs({f:GetChildren()}) do
                    if candidate(b,excluded) then take(b,b:GetName())
                    elseif not excluded[b] and not byButton[b] then walk(b,depth+1) end
                end
            end
            for _,root in pairs({Minimap,MinimapBackdrop,MinimapCluster}) do walk(root,0) end
            -- Also collect custom UIParent buttons anchored beside the minimap.
            for _,b in ipairs({UIParent:GetChildren()}) do
                if candidate(b,excluded) then
                    for i=1,b:GetNumPoints() do
                        local _,relative=b:GetPoint(i)
                        if relative==Minimap or relative==MinimapBackdrop or relative==MinimapCluster then take(b,b:GetName());break end
                    end
                end
            end
        end
        for _,e in ipairs(entries) do known[string.lower(e.name)]=true end
        -- Include entries registered only with Blizzard's addon compartment.
        local compartment=AddonCompartmentFrame
        for _,data in ipairs(compartment and compartment.registeredAddons or {}) do
            if type(data.func)=="function" and not compartmentEntries[data] then
                local e={name=clean(data.text),data=data};e.row=row(e.name)
                local b=CreateFrame("Button",nil,e.row);b:SetAllPoints();b:RegisterForClicks("AnyUp")
                local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(28,28);icon:SetPoint("LEFT",12,0)
                if data.icon and safe(C_Texture and C_Texture.GetAtlasInfo,data.icon) then icon:SetAtlas(data.icon) else icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_Gear_01") end
                b:SetScript("OnClick",function(_,mouse)
                    if combat() or WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end
                    local ok=pcall(data.func,nil,{buttonName=mouse},nil)
                    if not ok then hint:SetText("This addon could not open its shortcut. Try its original menu.") end
                end)
                b:SetScript("OnEnter",function(self) safe(data.funcOnEnter,self) end)
                b:SetScript("OnLeave",function(self) safe(data.funcOnLeave,self) end)
                compartmentEntries[data]=e
            end
        end
        layout()
    end
    layout=function()
        if combat() then return end
        local sorted,names={},{}
        if enabled() then for _,e in ipairs(entries) do sorted[#sorted+1]=e;names[string.lower(e.name)]=true end end
        for _,e in pairs(compartmentEntries) do if not names[string.lower(e.name)] then sorted[#sorted+1]=e else e.row:Hide() end end
        table.sort(sorted,function(a,b) return string.lower(a.name)<string.lower(b.name) end)
        for i,e in ipairs(sorted) do
            e.row:ClearAllPoints();e.row:SetPoint("TOPLEFT",0,-(i-1)*55);e.row:Show()
            if e.button then place(e) end
        end
        body:SetHeight(math.max(1,#sorted*55));collect:SetChecked(enabled())
        title:SetText("Addon shortcuts ("..#sorted..")")
        if #sorted==0 then hint:SetText("No addon shortcuts found yet. Load an addon with a minimap button.") end
    end
    collect:SetScript("OnClick",function(self)
        if combat() then return end
        WoWUDB=WoWUDB or {};WoWUDB.collectMinimapIcons=self:GetChecked() and true or false
        if not enabled() then for _,e in ipairs(entries) do restore(e) end end
        discover()
    end)
    toggle:SetScript("OnClick",function()
        if combat() then return end
        if popup:IsShown() then popup:Hide() else discover();scroll:SetVerticalScroll(0);popup:Show() end
    end)
    toggle:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Addon shortcuts");GameTooltip:AddLine("Open your collected minimap icons.",1,.82,.5);GameTooltip:Show() end)
    toggle:SetScript("OnLeave",function() GameTooltip:Hide() end)
    parent:HookScript("OnHide",function() if not combat() then popup:Hide() end end)
    local driver=CreateFrame("Frame");local elapsed=0;local pending=true
    for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED"}) do driver:RegisterEvent(event) end
    driver:SetScript("OnEvent",function() pending=true end)
    driver:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<(pending and 1 or 10) or combat() then return end
        elapsed=0;pending=false;discover()
    end)
    WoWU_RefreshAddonMenu=discover
    WoWU_RestoreAddonMenu=function()
        if combat()then return end
        popup:Hide()
        for _,e in ipairs(entries)do restore(e)end
    end
    WoWU_CloseAddonMenu=function()if not combat()then popup:Hide()end end
    return toggle
end
