-- Only active while WoWU owns the native map. Other map addons keep their pins.
local active
local function combat() return InCombatLockdown and InCombatLockdown() end
local function points(f)
    local out={};for i=1,f:GetNumPoints() do out[i]={f:GetPoint(i)} end;return out
end
-- Docking and quest navigation must agree on the canvas rectangle. Separate
-- Classic/Retail constants in their update loops caused continuous resizing.
function WoWU_GetMapCanvasInsets()
    if WoWUClient and WoWUClient.isClassic then return 12,48,12,12 end
    if WoWUClient and WoWUClient.isRetail then return 8,8,8,8 end
    return 8,74,8,8
end
function WoWU_EndMapNavigation(map)
    local s=active
    if not s or s.map~=map or combat() then return end
    active=nil;map.WoWUNavigationDocked=nil
    for pin,r in pairs(s.pins) do
        if pin.OnMouseClickAction==r.wrapper then pin.OnMouseClickAction=r.original end
    end
    if s.quest then
        if s.shown and map.ShowQuests then pcall(map.ShowQuests,map)
        elseif not s.shown and map.HideQuests then pcall(map.HideQuests,map) end
        s.quest:SetShown(s.shown)
    end
    if s.toggle then s.toggle:SetShown(s.toggleShown) end
    if s.scroll then
        s.scroll:ClearAllPoints();for _,p in ipairs(s.points) do s.scroll:SetPoint(unpack(p)) end
    end
    if map.UpdateSpacerFrameAnchoring then map:UpdateSpacerFrameAnchoring()end
    if map.OnFrameSizeChanged then map:OnFrameSizeChanged()end
end
local function refresh()
    local s=active;if not s or combat() then return end
    local map=s.map
    if not map:IsVisible() then return end
    local questClosed=false
    if s.quest and s.quest:IsShown() then
        if map.HideQuests then pcall(map.HideQuests,map) end
        s.quest:Hide()
        questClosed=true
        if map.UpdateSpacerFrameAnchoring then map:UpdateSpacerFrameAnchoring()end
    end
    if s.toggle then s.toggle:Hide() end
    if s.scroll then
        local left,top,right,bottom=WoWU_GetMapCanvasInsets()
        local corners={}
        for i=1,s.scroll:GetNumPoints() do
            local point,relative,to,x,y=s.scroll:GetPoint(i)
            if relative==map and point==to then
                if point=="TOPLEFT"and x==left and y==-top then corners.top=true
                elseif point=="BOTTOMRIGHT"and x==-right and y==bottom then corners.bottom=true end
            end
        end
        local changed=s.scroll:GetNumPoints()~=2 or not corners.top or not corners.bottom
        if changed then
            -- Replace all native anchors: Retail's third RIGHT anchor otherwise
            -- continues reserving the hidden quest sidebar's width.
            s.scroll:ClearAllPoints()
            s.scroll:SetPoint("TOPLEFT",map,"TOPLEFT",left,-top)
            s.scroll:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",-right,bottom)
        end
        -- Rebuild canvas zoom from the final viewport size, once per change.
        -- Stable layouts leave zoom and panning untouched.
        if (changed or questClosed)and map.OnFrameSizeChanged then map:OnFrameSizeChanged()end
    end
    if not map.EnumeratePins then return end
    for pin in map:EnumeratePins() do
        if pin.GetQuestID and type(pin.OnMouseClickAction)=="function" and not s.pins[pin]
            and not (pin.IsForbidden and pin:IsForbidden()) and not (pin.IsProtected and pin:IsProtected()) then
            local r={original=pin.OnMouseClickAction};s.pins[pin]=r
            if not pin.WoWUNavigationPointerHook then
                pin.WoWUNavigationPointerHook=true
                pin:HookScript("OnMouseDown",function(self,button)
                    if active and button=="LeftButton" then
                        self.WoWUNavigationDown={GetCursorPosition()}
                    end
                end)
            end
            r.wrapper=function(self,button,...)
                if active~=s or combat() or button~="LeftButton" then return r.original(self,button,...) end
                local down=self.WoWUNavigationDown;self.WoWUNavigationDown=nil
                if down then
                    local x,y=GetCursorPosition();local scale=self:GetEffectiveScale()
                    if (x-down[1])^2+(y-down[2])^2>(12*scale)^2 then return end
                end
                local id=self:GetQuestID()
                if WoWU_SelectQuest and WoWU_SelectQuest(id,true) then return end
                -- Unaccepted offers are not in WoWU's quest log: preserve native action.
                return r.original(self,button,...)
            end
            pin.OnMouseClickAction=r.wrapper
        end
    end
end
function WoWU_BeginMapNavigation(map)
    if combat() then return end
    if active and active.map~=map then WoWU_EndMapNavigation(active.map) end
    if not active then
        local quest=map.QuestLog or QuestMapFrame
        active={map=map,quest=quest,shown=quest and quest:IsShown(),scroll=map.ScrollContainer,
            toggle=map.SidePanelToggle,toggleShown=map.SidePanelToggle and map.SidePanelToggle:IsShown(),pins={}}
        active.points=active.scroll and points(active.scroll) or {}
    end
    map.WoWUNavigationDocked=true
    pcall(refresh)
end
local driver=CreateFrame("Frame");local elapsed=0
driver:SetScript("OnUpdate",function(_,dt)
    if not active then return end
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    pcall(refresh)
end)
