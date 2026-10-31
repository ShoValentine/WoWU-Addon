local addonName, C = ...
local defaults = {enabled=true,locked=true,showDestination=true,showDistance=true,width=560,scale=1,opacity=.85,x=0,y=-.035,
    showPOIs=true,poiQuests=true,poiOffers=true,poiTurnins=true,poiInns=true,poiMail=true,poiTrainers=true,poiOther=true,poiRepairs=true,poiFlights=true,poiRares=true,poiBookmarks=true,
    iconSize=24,poiRange=1500,groupMarkers=true,fadeDistant=true,showNames=true,navigationOnly=false}
local db, frame, options, events
local elapsed, destinationElapsed, geometryElapsed = 0, 0, 0
local heading, target, targetReason, geometrySignature, registeredAPI
local inWorld = false
local points,poiElapsed={},0
local function dead()return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")or false end
local directions = {[0]="N",[45]="NE",[90]="E",[135]="SE",[180]="S",[225]="SW",[270]="W",[315]="NW"}

local function message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd9b675WoWU Compass:|r "..text) end
end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function normalize()
    if type(WoWUCompassDB) ~= "table" then WoWUCompassDB={} end
    db=WoWUCompassDB
    for key,value in pairs(defaults) do
        if type(value)=="boolean" then
            if type(db[key])~="boolean" then db[key]=value end
        elseif not C.Number(db[key]) then db[key]=value end
    end
    db.iconSize=math.max(16,math.min(36,db.iconSize));db.poiRange=math.max(100,math.min(5000,db.poiRange))
    db.width=math.max(320,math.min(900,db.width))
    db.scale=math.max(.5,math.min(2,db.scale))
    db.opacity=math.max(.2,math.min(1,db.opacity))
    db.x=math.max(-.5,math.min(.5,db.x));db.y=math.max(-1,math.min(0,db.y))
end
local function font(parent, size, color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    f:SetTextColor(unpack(color or {.94,.89,.76}))
    f:SetShadowColor(0,0,0,.95);f:SetShadowOffset(1,-1)
    return f
end
local function line(parent,x,y,w,h,color,layer)
    local t=parent:CreateTexture(nil,layer or "ARTWORK")
    t:SetColorTexture(unpack(color));t:SetSize(w,h);t:SetPoint("CENTER",parent,"CENTER",x,y)
    return t
end
local function mainRect()
    local native=WoWUViewport and WoWUViewport.GetGameplayRect
    local nativeRect=C.Rect(C.Call(native))
    if nativeRect then return nativeRect end
    local api=Offhand and Offhand.API
    local r=C.Rect(C.Call(api and api.GetMainhandRect))
    if r then return r end
    -- Compatibility with Offhand versions without the public Mainhand API.
    local viewport=Offhand and Offhand.Viewport
    local m=C.Call(viewport and viewport.GetMetrics,viewport)
    if Offhand and Offhand.db and Offhand.db.enabled and type(m)=="table" and m.isSpanned then
        r=C.Rect({left=m.gameLeft,bottom=m.gameBottom,right=m.gameRight,top=m.gameTop})
        if r then return r end
        return nil -- Never center over a combined display when its game region is unknown.
    end
    return C.Rect({left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()})
end
local function applyLayout(force)
    if not frame or frame.dragging then return end
    frame:EnableMouse(inWorld and not db.locked and not combat())
    frame.moveHint:SetShown(not db.locked and not combat())
    frame:SetAlpha(db.opacity)
    if not inWorld or not db.enabled then frame:Hide();return end
    if combat() then
        if not geometrySignature then frame:Hide() end
        return
    end
    local rect=mainRect()
    if not rect then frame:Hide();geometrySignature=nil;return end
    local scale,x,y=C.Geometry(rect,db)
    local signature=table.concat({rect.left,rect.bottom,rect.right,rect.top,scale,db.width,db.x,db.y},":")
    if force or signature~=geometrySignature then
        frame:SetScale(scale);frame:SetSize(db.width,116)
        frame:ClearAllPoints();frame:SetPoint("TOP",UIParent,"BOTTOMLEFT",x,y)
        frame.track:SetWidth(db.width-28)
        frame.detail:SetWidth(db.width-20)
        geometrySignature=signature
    end
    frame:Show()
end
local function registerGeometry()
    local api=Offhand and Offhand.API
    if api and api~=registeredAPI and type(api.RegisterGeometryCallback)=="function" then
        local ok=C.Call(api.RegisterGeometryCallback,addonName,function() applyLayout(true);return true end)
        if ok then registeredAPI=api end
    end
end
local function refreshDestination()
    if db.showDestination or dead() then target,targetReason=C.Destination() else target,targetReason=nil,nil end
    if dead() and target and target.kind~="corpse"then target=nil;targetReason="Corpse location unavailable"end
end
local function refreshPOIs()
    points=C.POIs and C.POIs(db,target) or {}
end
local iconRoot="Interface\\MINIMAP\\TRACKING\\"
local icons={quests="Interface\\GossipFrame\\AvailableQuestIcon",offers="Interface\\GossipFrame\\AvailableQuestIcon",
 turnins="Interface\\GossipFrame\\ActiveQuestIcon",inns=iconRoot.."Innkeeper",mail=iconRoot.."Mailbox",
 trainers=iconRoot.."Profession",repairs=iconRoot.."Repair",flights=iconRoot.."FlightMaster",
 rares="Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",bookmarks="Interface\\Icons\\UI_GreenFlag",
 other="Interface\\GossipFrame\\GossipGossipIcon"}
local function newMarker(parent)
 local m=CreateFrame("Frame",nil,parent);m:EnableMouse(false)
 m.icon=m:CreateTexture(nil,"ARTWORK");m.icon:SetAllPoints();m.icon:SetBlendMode("BLEND")
 m.count=font(m,10,{1,1,1});m.count:SetPoint("BOTTOMRIGHT",5,-2)
 m.grave=CreateFrame("Frame",nil,m);m.grave:SetAllPoints();m.grave:EnableMouse(false)
 -- A simple gravestone outline is independent of client icon atlases.
 local function stroke(ax,ay,bx,by)
  local l=m.grave:CreateLine(nil,"OVERLAY");l:SetThickness(3);l:SetColorTexture(.84,.88,.91,1)
  l:SetStartPoint("CENTER",m.grave,ax,ay);l:SetEndPoint("CENTER",m.grave,bx,by)
 end
 stroke(-10,-12,10,-12);stroke(-8,-12,-8,7);stroke(-8,7,-4,12);stroke(-4,12,4,12);stroke(4,12,8,7);stroke(8,7,8,-12)
 stroke(0,-5,0,5);stroke(-4,1,4,1);m.grave:Hide()
 -- Small silhouettes, without inventory-icon squares or portrait backplates.
 m.scroll=CreateFrame("Frame",nil,m);m.scroll:SetSize(32,32);m.scroll:SetPoint("CENTER");m.scroll:EnableMouse(false)
 local function rectangle(parent,x,y,w,h,r,g,b)
  local t=parent:CreateTexture(nil,"ARTWORK");t:SetColorTexture(r,g,b,1);t:SetSize(w,h);t:SetPoint("CENTER",x,y);return t
 end
 rectangle(m.scroll,0,0,17,23,.29,.17,.06);rectangle(m.scroll,0,0,15,21,.88,.71,.40)
 rectangle(m.scroll,-1,10,21,5,.36,.23,.09);rectangle(m.scroll,-1,10,19,3,1,.87,.59)
 rectangle(m.scroll,1,-10,21,5,.36,.23,.09);rectangle(m.scroll,1,-10,19,3,.93,.77,.45)
 for row=0,2 do rectangle(m.scroll,0,4-row*4,9-row,1,.42,.27,.10)end
 m.flag=CreateFrame("Frame",nil,m);m.flag:SetSize(32,32);m.flag:SetPoint("CENTER");m.flag:EnableMouse(false)
 rectangle(m.flag,-7,0,3,27,.28,.20,.11);rectangle(m.flag,-7,0,1,27,.93,.82,.59)
 rectangle(m.flag,1,7,15,11,.30,.07,.04);rectangle(m.flag,1,7,13,9,.78,.15,.08)
 m.scroll:Hide();m.flag:Hide()
 return m
end
local function paint(m,point,size,active)
 m:SetSize(size,size)
 local category=point.category or (point.kind=="quest"and "quests"or "bookmarks")
 if point.questID and category~="offers" then local q=WoWUQuestLog or C_QuestLog;category=C.Call(q and q.IsComplete,point.questID)and "turnins"or "quests"end
 local corpse=point.kind=="corpse"
 local scroll=not corpse and category=="quests";local flag=not corpse and category=="bookmarks"
 m.grave:SetShown(corpse);m.scroll:SetShown(scroll);m.flag:SetShown(flag)
 m.scroll:SetScale(size/32);m.flag:SetScale(size/32)
 m.icon:SetShown(not corpse and not scroll and not flag)
 if not corpse then
  local texture=icons[category]
  if category=="trainers"and point.icon then texture=point.icon end
  if (category=="other"or category=="pois")and point.atlas and C.Call(C_Texture and C_Texture.GetAtlasInfo,point.atlas)then m.icon:SetAtlas(point.atlas)
  else m.icon:SetTexture(((category=="other"or category=="pois")and point.icon)or texture or point.icon or icons.other)end
  m.icon:SetVertexColor(1,1,1,1)
 end
 m:SetAlpha(active and 1 or db.fadeDistant and math.max(.38,1-.62*point.distance/db.poiRange)or 1)
end
local function renderPOIs(width,reserved)
 for _,m in ipairs(frame.poiMarkers)do m:Hide()end
 if not db.showPOIs or db.navigationOnly or not heading or dead()then return nil,0 end
 local groups,count=C.POILayout(points,heading,width,db,reserved);local nearest,angle
 for i,group in ipairs(groups)do
  local m=frame.poiMarkers[i];if not m then m=newMarker(frame.track);frame.poiMarkers[i]=m end
  paint(m,group.point,db.iconSize,false);m.count:SetText(group.count>1 and tostring(group.count)or "")
  m:ClearAllPoints();m:SetPoint("CENTER",frame.track,"CENTER",group.x,13);m:Show()
  local delta=math.abs(C.Delta(group.point.bearing,heading))
  if delta<8 and (not angle or delta<angle)then nearest=group.point;angle=delta end
 end
 return nearest,count
end
local function render(dt)
 local current=C.Heading(C.Call(GetPlayerFacing))
 if not current then
  heading=nil;for _,tick in ipairs(frame.ticks)do tick:Hide()end
  frame.marker:Hide();frame.leftArrow:Hide();frame.rightArrow:Hide()
  for _,m in ipairs(frame.poiMarkers)do m:Hide()end
  frame.detail:SetText("Direction unavailable");frame.distance:SetText("");return
 end
 heading=C.Smooth(heading,current,dt);local width=frame.track:GetWidth()
 for _,tick in ipairs(frame.ticks)do
  local delta=C.Delta(tick.degrees,heading);tick:SetShown(math.abs(delta)<=88)
  if math.abs(delta)<=88 then tick:ClearAllPoints();tick:SetPoint("CENTER",frame.track,"CENTER",delta*width/180,0);tick:SetAlpha(math.min(1,math.max(.18,(90-math.abs(delta))/18)))end
 end
 frame.marker:Hide();frame.leftArrow:Hide();frame.rightArrow:Hide()
 local active=(db.showDestination or dead())and target;local x,edge
 if active then x,edge=C.Marker(active.bearing,heading,width)end
 local nearest,count=renderPOIs(width,active and not edge and x or nil)
 local detail,distance="",""
 if active then
  local m=frame.marker;paint(m,active,db.iconSize*1.35,true);m.count:SetText(count>0 and ("+"..count)or "")
  m:ClearAllPoints();m:SetPoint("CENTER",frame.track,"CENTER",x,13);m:Show()
  if edge then (edge=="left"and frame.leftArrow or frame.rightArrow):Show()end
  m.halo:SetVertexColor(dead()and .75 or 1,dead()and .85 or .7,dead()and 1 or .25,.35)
  detail=db.showNames and active.name or ""
  if db.showDistance or active.distance<5 then distance=C.DistanceText(active.distance)end
  if edge then distance=distance..(distance~=""and "  |  "or "").."Turn "..edge end
 elseif (db.showDestination or dead())and targetReason then detail=targetReason
 elseif nearest and db.showNames then detail=nearest.name;distance=db.showDistance and C.DistanceText(nearest.distance)or ""end
 frame.detail:SetTextColor(dead()and .88 or 1,dead()and .93 or .89,dead()and 1 or .63);frame.detail:SetText(detail);frame.distance:SetText(distance)
end
local function apply()
    normalize();applyLayout(true)
    if inWorld and db.enabled then refreshDestination();refreshPOIs();render(.1) end
end

-- Optional bridge: WoWU can control the companion without writing its DB or
-- relying on load order. Only explicit settings are accepted here.
WoWUCompassAPI={
    Get=function(key) if db and defaults[key]~=nil then return db[key] end end,
    Set=function(key,value)
        if not db or defaults[key]==nil then return false,"Compass is not ready." end
        if type(defaults[key])=="boolean" then
            if type(value)~="boolean" then return false,"Invalid compass setting." end
        elseif key=="scale" then
            value=tonumber(value)
            if not C.Number(value) or value<.5 or value>2 then return false,"Enter a compass scale from 50 to 200%." end
        elseif key=="iconSize" or key=="poiRange" or key=="width" or key=="opacity" then
            local limits={iconSize={16,36},poiRange={100,5000},width={320,900},opacity={.2,1}}
            value=tonumber(value);local range=limits[key]
            if not C.Number(value)or value<range[1]or value>range[2]then return false,"Value outside the supported range."end
        else return false,"This setting is not exposed." end
        db[key]=value;apply()
        return true,combat() and "Saved; compass layout changes apply after combat." or ""
    end,
}
local function makeButton(parent,title,w,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w,32);b:SetText(title);b:SetScript("OnClick",fn);return b
end
local function makeOptions()
    local f=CreateFrame("Frame","WoWUCompassOptions",UIParent,"BackdropTemplate")
    f:SetSize(440,430);f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=18,insets={left=5,right=5,top=5,bottom=5}})
    f:SetBackdropColor(.04,.06,.07,.98);f:SetBackdropBorderColor(.7,.55,.31,1)
    f:EnableMouse(true)
    local title=font(f,22,{.95,.8,.5});title:SetPoint("TOPLEFT",24,-23);title:SetText("WoWU Compass")
    local hint=font(f,13,{.7,.73,.69});hint:SetPoint("TOPLEFT",24,-57);hint:SetWidth(392);hint:SetJustifyH("LEFT")
    hint:SetText("A compass for your main gameplay screen.")
    local checks={}
    for i,option in ipairs({{"enabled","Show compass"},{"locked","Lock compass position"},{"showDestination","Show active quest / map pin"},{"showDistance","Show destination distance"}}) do
        local key,label=option[1],option[2]
        local check=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
        check:SetSize(34,34);check:SetPoint("TOPLEFT",24,-88-(i-1)*43)
        local text=font(f,16);text:SetPoint("LEFT",check,"RIGHT",7,0);text:SetText(label)
        check:SetScript("OnClick",function(self) db[key]=self:GetChecked() and true or false;apply();if combat() then message("Position and lock changes will apply after combat.") end end)
        checks[key]=check
    end
    local scaleText=font(f,14);scaleText:SetPoint("TOPLEFT",29,-278)
    local function updateScale() scaleText:SetText(string.format("Size: %d%%",math.floor(db.scale*100+.5))) end
    local minus=makeButton(f,"-",40,function() db.scale=math.max(.5,db.scale-.1);apply();updateScale() end)
    minus:SetPoint("TOPRIGHT",-82,-267)
    local plus=makeButton(f,"+",40,function() db.scale=math.min(2,db.scale+.1);apply();updateScale() end)
    plus:SetPoint("LEFT",minus,"RIGHT",8,0)
    local reset=makeButton(f,"Reset position",165,function() db.x=0;db.y=defaults.y;apply();message("Position reset to the main screen.") end)
    reset:SetPoint("BOTTOMLEFT",25,67)
    local close=makeButton(f,"Close",100,function() f:Hide() end);close:SetPoint("BOTTOMRIGHT",-25,67)
    local foot=font(f,12,{.69,.72,.67});foot:SetPoint("BOTTOMLEFT",25,19);foot:SetWidth(390);foot:SetJustifyH("LEFT")
    foot:SetText("Unlock to drag the bar. Locked: clicks pass through.\nUse Track Quest in WoWU, or track a pin on the map.")
    f:SetScript("OnShow",function()
        local rect=mainRect() or C.Rect({left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()})
        if rect then
            local scale=math.min(1,(rect.width-20)/440,(rect.height-20)/430)
            f:SetScale(math.max(.1,scale));f:ClearAllPoints()
            f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",(rect.left+rect.width/2)/f:GetScale(),(rect.bottom+rect.height/2)/f:GetScale())
        end
        for k,check in pairs(checks) do check:SetChecked(db[k]) end
        updateScale()
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="WoWUCompassOptions" end
    f:Hide();return f
end
local function build()
    frame=CreateFrame("Frame","WoWUCompassFrame",UIParent)
    frame:SetSize(db.width,116);frame:SetFrameStrata("HIGH");frame:SetFrameLevel(20)
    frame:SetMovable(true);frame:SetClampedToScreen(false);frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)
        if db.locked or combat() then return end
        self.dragging=true;self:StartMoving()
    end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();self.dragging=false
        local rect=mainRect()
        local cx=self:GetCenter();local top=self:GetTop()
        if rect and cx and top then
            local scale=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
            db.x=(cx*scale-rect.left-rect.width/2)/rect.width
            db.y=(top*scale-rect.top)/rect.height
        end
        normalize();applyLayout(true)
    end)
    frame:SetScript("OnMouseUp",function(_,button)
        if button=="RightButton" and not db.locked then options:Show() end
    end)
    frame.track=CreateFrame("Frame",nil,frame)
    frame.track:SetSize(db.width-28,36);frame.track:SetPoint("TOP",0,-16);frame.track:EnableMouse(false)
    local rule=line(frame.track,0,0,db.width-28,1,{.72,.62,.40,.8});rule:ClearAllPoints();rule:SetPoint("LEFT",0,0);rule:SetPoint("RIGHT",0,0)
    local caret=frame.track:CreateLine(nil,"OVERLAY");caret:SetThickness(2);caret:SetColorTexture(1,.85,.48,1);caret:SetStartPoint("CENTER",frame.track,-5,-3);caret:SetEndPoint("CENTER",frame.track,0,-8)
    caret=frame.track:CreateLine(nil,"OVERLAY");caret:SetThickness(2);caret:SetColorTexture(1,.85,.48,1);caret:SetStartPoint("CENTER",frame.track,0,-8);caret:SetEndPoint("CENTER",frame.track,5,-3)
    frame.ticks={};frame.poiMarkers={}
    for degrees=0,345,15 do
        local tick=CreateFrame("Frame",nil,frame.track);tick:SetSize(34,30);tick:EnableMouse(false);tick.degrees=degrees
        line(tick,0,-3,1,directions[degrees]and 9 or 5,{.8,.74,.6,.8})
        if directions[degrees]then local fs=font(tick,degrees%90==0 and 17 or 12);fs:SetPoint("CENTER",0,-19);fs:SetText(directions[degrees])end
        frame.ticks[#frame.ticks+1]=tick
    end
    frame.marker=newMarker(frame.track);frame.marker:SetFrameLevel(frame.track:GetFrameLevel()+5)
    local halo=frame.marker:CreateTexture(nil,"BACKGROUND",nil,-1);halo:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");halo:SetBlendMode("ADD");halo:SetPoint("TOPLEFT",-13,13);halo:SetPoint("BOTTOMRIGHT",13,-13);frame.marker.halo=halo
    frame.leftArrow=font(frame,23,{1,.82,.4});frame.leftArrow:SetPoint("TOPLEFT",-5,-9);frame.leftArrow:SetText("<")
    frame.rightArrow=font(frame,23,{1,.82,.4});frame.rightArrow:SetPoint("TOPRIGHT",5,-9);frame.rightArrow:SetText(">")
    frame.detail=font(frame,16,{1,.89,.63});frame.detail:SetPoint("TOP",0,-68);frame.detail:SetWidth(db.width-20);frame.detail:SetHeight(20);frame.detail:SetWordWrap(false)
    frame.distance=font(frame,13,{.94,.88,.73});frame.distance:SetPoint("TOP",0,-89)
    frame.moveHint=font(frame,10,{.6,.8,.75});frame.moveHint:SetPoint("BOTTOM",0,0);frame.moveHint:SetText("Drag to move | right-click for settings")
    options=makeOptions()
end

local function slash(input)
    local command,arg=string.match(string.lower(input or ""),"^%s*(%S*)%s*(.-)%s*$")
    if command=="" or command=="settings" then options:SetShown(not options:IsShown());return end
    if command=="show" then db.enabled=true
    elseif command=="hide" then db.enabled=false
    elseif command=="lock" then db.locked=true
    elseif command=="unlock" then db.locked=false;db.enabled=true
    elseif command=="reset" then db.x=0;db.y=defaults.y;db.enabled=true;db.locked=true
    elseif command=="scale" and C.Number(tonumber(arg)) then db.scale=tonumber(arg)
    elseif command=="width" and C.Number(tonumber(arg)) then db.width=tonumber(arg)
    elseif command=="opacity" and C.Number(tonumber(arg)) then db.opacity=tonumber(arg)
    else message("/wowucompass - settings; show, hide, lock, unlock, reset, scale 0.5-2, width 320-900, opacity 0.2-1");return end
    apply()
    if combat() then message("Position and lock changes will apply after combat.") end
end

events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name==addonName and not frame then
        normalize();build();registerGeometry();apply()
        SLASH_WOWUCOMPASS1="/wowucompass";SLASH_WOWUCOMPASS2="/wcompass"
        SlashCmdList.WOWUCOMPASS=slash
        for _,e in ipairs({"PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
            "DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","ZONE_CHANGED_INDOORS",
            "SUPER_TRACKING_CHANGED","SUPER_TRACKING_PATH_UPDATED","USER_WAYPOINT_UPDATED","QUEST_LOG_UPDATE","NAVIGATION_FRAME_CREATED","NAVIGATION_FRAME_DESTROYED",
            "QUEST_POI_UPDATE","QUEST_WATCH_LIST_CHANGED","QUESTLINE_UPDATE","AREA_POIS_UPDATED","MINIMAP_UPDATE_TRACKING","MINIMAP_UPDATE_ZOOM"}) do
            pcall(events.RegisterEvent,events,e)
        end
        events:SetScript("OnUpdate",function(_,dt)
            if not inWorld or not db.enabled then return end
            geometryElapsed=geometryElapsed+dt
            if geometryElapsed>=1 then geometryElapsed=0;registerGeometry();applyLayout(false) end
            if not frame:IsShown() then return end
            elapsed=elapsed+dt;destinationElapsed=destinationElapsed+dt;poiElapsed=poiElapsed+dt
            if elapsed<1/30 then return end
            if destinationElapsed>=.25 then destinationElapsed=0;refreshDestination() end
            if poiElapsed>=.5 then poiElapsed=0;refreshPOIs() end
            render(elapsed);elapsed=0
        end)
    elseif frame then
        if event=="PLAYER_LEAVING_WORLD" then
            inWorld=false
            if frame.dragging then frame:GetScript("OnDragStop")(frame) end
            frame:Hide();target=nil;heading=nil;points={}
            elapsed=0;destinationElapsed=0;geometryElapsed=0;poiElapsed=0
            return
        end
        if event=="PLAYER_ENTERING_WORLD" then inWorld=true end
        if event=="PLAYER_REGEN_DISABLED" then
            if frame.dragging then frame:GetScript("OnDragStop")(frame) end
            -- Lock state is still saved, but this unprotected HUD never captures
            -- the mouse during combat, even when repositioning was enabled.
            frame:EnableMouse(false)
            frame.moveHint:Hide()
        elseif event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" or event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" or event=="ADDON_LOADED" then
            registerGeometry();applyLayout(true)
        end
        if inWorld and db.enabled then refreshDestination();refreshPOIs();render(.1) end
    end
end)
