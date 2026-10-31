local N,E=WoWUNavigation,WoWUExplorer

-- Only the temporary placement surface receives input. Ordinary markers never do.
local placement
function E.CancelPin()
    E.pinMode=nil
    if placement then
        local scroll=placement.scroll
        if scroll and scroll.mouseButtonInfo then
            for _,button in pairs(scroll.mouseButtonInfo) do button.down=false end
        end
        placement:Hide()
    end
end
function E.BeginPin(name,kind,callback)
    if N.IsDead() then return false,"Corpse guidance takes priority while dead." end
    if InCombatLockdown and InCombatLockdown() then return false,"Place a pin after combat." end
    local map=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame
    if not map or not map.WoWUNavigationDocked or not map:IsVisible() or not map.ScrollContainer then
        return false,"Open the docked world map first."
    end
    local scroll=map.ScrollContainer
    if not placement then
        placement=CreateFrame("Frame",nil,scroll);placement.WoWUMapOverlay=true
        placement:EnableMouse(true);placement:EnableMouseWheel(true)
        placement.cursor=CreateFrame("Frame",nil,placement);placement.cursor:SetSize(24,24);placement.cursor:EnableMouse(false)
        local cross=placement.cursor:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        cross:SetAllPoints();cross:SetText("+");cross:SetTextColor(1,.85,.25);cross:SetFont("Fonts\\FRIZQT__.TTF",28,"OUTLINE")
        placement:SetScript("OnMouseDown",function(self,button)
            if button=="RightButton" then local cb=E.pinMode and E.pinMode.callback;E.CancelPin();if cb then cb("Pin placement cancelled.") end;return end
            if button~="LeftButton" then return end
            self.downX,self.downY=GetCursorPosition();self.moved=false
            -- Native panning continues beneath this temporary input surface.
            N.Call(self.scroll.OnMouseDown,self.scroll,button)
        end)
        placement:SetScript("OnMouseUp",function(self,button)
            local mode=E.pinMode
            if not mode or button~="LeftButton" or not self.downX then return end
            local cx,cy=GetCursorPosition();local threshold=12*self:GetEffectiveScale()
            local moved=self.moved or (cx-self.downX)^2+(cy-self.downY)^2>threshold^2
            self.downX=nil;self.downY=nil
            -- End panning without triggering native click-to-zoom or quest actions.
            if self.scroll.mouseButtonInfo and self.scroll.mouseButtonInfo.LeftButton then self.scroll.mouseButtonInfo.LeftButton.down=false end
            if moved or not self:IsMouseOver() then return end
            local x,y=map:GetNormalizedCursorPosition()
            x,y=N.Coordinates(x,y)
            if not x then return end
            local _,message=E.Save({mapID=map:GetMapID(),x=x,y=y},mode.name,mode.kind)
            E.CancelPin();if mode.callback then mode.callback(message) end
        end)
        placement:SetScript("OnMouseWheel",function(self,delta) N.Call(self.scroll.OnMouseWheel,self.scroll,delta) end)
        placement:SetScript("OnUpdate",function(self)
            if not E.pinMode then return end
            if N.IsDead() or (InCombatLockdown and InCombatLockdown()) or not map.WoWUNavigationDocked or map:GetMapID()~=E.pinMode.mapID then
                local cb=E.pinMode.callback;E.CancelPin();if cb then cb("Pin placement cancelled.") end;return
            end
            local x,y=GetCursorPosition();local scale=self:GetEffectiveScale()
            if self.downX and (x-self.downX)^2+(y-self.downY)^2>(12*scale)^2 then self.moved=true end
            self.cursor:SetShown(self:IsMouseOver());self.cursor:ClearAllPoints()
            self.cursor:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
        end)
        placement:SetScript("OnHide",function(self)
            E.pinMode=nil;self.downX=nil;self.downY=nil
            if self.scroll and self.scroll.mouseButtonInfo and self.scroll.mouseButtonInfo.LeftButton then self.scroll.mouseButtonInfo.LeftButton.down=false end
        end)
    end
    placement.scroll=scroll;placement:SetParent(scroll);placement:SetAllPoints(scroll)
    placement:SetFrameStrata(map:GetFrameStrata());placement:SetFrameLevel(scroll:GetFrameLevel()+250)
    E.pinMode={name=name,kind=kind,callback=callback,mapID=map:GetMapID()};placement:Show()
    return true,"Tap the map to place a pin. Drag to pan; right-click or press Save map pin again to cancel."
end

function E.Markers(mapID)
    local points=E.Points(mapID)
    if not N.IsDead() then
        if WoWUMistsQuests then
            for _,p in ipairs(WoWUMistsQuests.Points(mapID))do points[#points+1]=p end
        else
        -- Nearby quests are clustered automatically; no separate mode or button.
        for _,group in ipairs(E.Clusters(mapID)) do
            if #group.quests>1 then
                group.category="quests";group.icon=E.icons.quests;group.count=#group.quests
                points[#points+1]=group
            end
        end
        end
    end
    return points
end
local function newLayer(parent)
    local f=CreateFrame("Frame",nil,parent);f.WoWUMapOverlay=true;f:SetAllPoints(parent);f:EnableMouse(false);f.markers={};return f
end
local function top(layer,parent)
    local level=parent:GetFrameLevel()+20
    local function visit(frame,depth)
        if depth==0 or not frame.GetChildren then return end
        for _,child in ipairs({frame:GetChildren()}) do
            if child~=layer and child~=placement and not child.WoWUMapOverlay and not (child.IsForbidden and child:IsForbidden()) then
                level=math.max(level,child:GetFrameLevel()+5);visit(child,depth-1)
            end
        end
    end
    visit(parent,3);layer:SetFrameStrata(parent:GetFrameStrata());layer:SetFrameLevel(level)
end
local function marker(layer,index,p,x,y,size)
    local m=layer.markers[index]
    if not m then
        m=CreateFrame("Frame",nil,layer);m:EnableMouse(false)
        m.icon=m:CreateTexture(nil,"ARTWORK");m.icon:SetAllPoints()
        m.count=m:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");m.count:SetPoint("BOTTOMRIGHT",3,-2)
        layer.markers[index]=m
    end
    m:SetSize(size,size);m.icon:SetTexture(p.icon or E.icons.pois);m.icon:SetBlendMode("BLEND");m.icon:SetTexCoord(0,1,0,1)
    m.count:ClearAllPoints()
    if p.questNumber then
        local selected=WoWUMistsQuests and WoWUMistsQuests.ActiveQuest()==p.questID
        m.icon:SetTexture('Interface\\WorldMap\\UI-QuestPoi-NumberIcons')
        m.icon:SetTexCoord(selected and .5 or .875,selected and .625 or 1,.375,.5)
        m.count:SetPoint('CENTER',0,0);m.count:SetText(p.questNumber)
        m.count:SetTextColor(selected and .1 or 1,selected and .08 or .85,0)
    else
        m.count:SetPoint('BOTTOMRIGHT',3,-2);m.count:SetText(p.count and tostring(p.count)or '');m.count:SetTextColor(1,.82,0)
    end
    m:ClearAllPoints();m:SetPoint("CENTER",layer,"TOPLEFT",x,-y);m:Show()
end
local function unused(layer,count) for i=count+1,#layer.markers do layer.markers[i]:Hide() end end
local world,canvas,mini;local worldTime,miniTime=0,0
local pointCache={}
local function pointsFor(mapID)
    local now=GetTime();local dead=N.IsDead()
    local cached=pointCache[mapID]
    if not cached or now-cached.time>.75 or dead~=cached.dead or cached.filters~=E.filterRevision then
        cached={points=E.Markers(mapID),time=now,dead=dead,filters=E.filterRevision};pointCache[mapID]=cached
    end
    return cached.points
end
local function drawWorld()
    local map=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame
    if not map or not map:IsVisible() or not map.GetCanvas then if world then world:Hide() end;return end
    local current=map:GetCanvas();if not current then return end
    if current~=canvas then if world then world:Hide() end;canvas=current;world=newLayer(canvas) end
    top(world,canvas);world:Show()
    local id=map:GetMapID();local used=0
    local scale=math.max(.1,canvas:GetEffectiveScale()/map:GetEffectiveScale())
    local worldPoints={}
    for _,p in ipairs(pointsFor(id))do
        if not(map.WoWUMistsQuestLayer and p.questID)then worldPoints[#worldPoints+1]=p end
    end
    if not N.IsDead() and WoWU_GetPreference("availableWorld") and WoWUQuestOffers then
        for _,p in ipairs(WoWUQuestOffers.Points(id))do worldPoints[#worldPoints+1]=p end
    end
    -- Imported service/spawn references must not consume the marker budget
    -- before quests and native/current locations have been drawn.
    local prioritized={}
    for _,p in ipairs(worldPoints)do if p.kind~="reference"then prioritized[#prioritized+1]=p end end
    for _,p in ipairs(worldPoints)do if p.kind=="reference"then prioritized[#prioritized+1]=p end end
    for _,p in ipairs(prioritized) do
        local x,y=N.Project(p.mapID,p.x,p.y,id)
        if x and x>=0 and x<=1 and y>=0 and y<=1 and used<250 then
            used=used+1;marker(world,used,p,x*canvas:GetWidth(),y*canvas:GetHeight(),18/scale)
        end
    end
    unused(world,used)
end
local function drawMini()
    if not Minimap or not Minimap:IsVisible() then if mini then mini:Hide() end;return end
    if not mini then mini=newLayer(Minimap) end
    local map=N.Call(C_Map and C_Map.GetBestMapForUnit,"player")
    local radius=N.MinimapRadius()
    if not map or not radius or radius<=0 then mini:Hide();return end
    top(mini,Minimap);mini:Show();local used=0
    local w,h=Minimap:GetWidth(),Minimap:GetHeight();local r=math.min(w,h)/2-12
    local facing=GetCVarBool and GetCVarBool("rotateMinimap") and N.Number(N.Call(GetPlayerFacing)) or 0
    for _,p in ipairs(pointsFor(map)) do
        local t=N.PointDestination(p,map)
        if t and t.distance<=radius and used<120 then
            local e,n=t.east,t.north
            if facing and facing~=0 then e,n=e*math.cos(facing)+n*math.sin(facing),n*math.cos(facing)-e*math.sin(facing) end
            used=used+1;marker(mini,used,p,w/2+e*r/radius,h/2-n*r/radius,16)
        end
    end
    unused(mini,used)
end
local driver=CreateFrame("Frame")
driver:SetScript("OnUpdate",function(_,dt)
    worldTime=worldTime+dt;miniTime=miniTime+dt
    if worldTime>=.5 then worldTime=0;local ok=pcall(drawWorld);if not ok and world then world:Hide() end end
    if miniTime>=.1 then miniTime=0;local ok=pcall(drawMini);if not ok and mini then mini:Hide() end end
end)
