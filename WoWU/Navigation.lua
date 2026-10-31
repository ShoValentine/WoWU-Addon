local C={}
WoWUNavigation=C
local pi, abs = math.pi, math.abs

function C.Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function C.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local mapSizes={}
function C.MapWorldSize(id)
    local w,h=C.Call(C_Map and C_Map.GetMapWorldSize,id)
    if C.Number(w)and C.Number(h)and w>0 and h>0 then return w,h end
    local prior=mapSizes[id];if prior then return prior[1],prior[2]end
    if not(C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D)then return end
    local a,p=C.Call(C_Map.GetWorldPosFromMapPos,id,CreateVector2D(0,0))
    local b,q=C.Call(C_Map.GetWorldPosFromMapPos,id,CreateVector2D(1,1))
    if a and a==b and p and q and p.GetXY and q.GetXY then
        local px,py=p:GetXY();local qx,qy=q:GetXY()
        if C.Number(px)and C.Number(py)and C.Number(qx)and C.Number(qy)then
            w,h=math.abs(qy-py),math.abs(qx-px)
            if w>0 and h>0 then mapSizes[id]={w,h};return w,h end
        end
    end
end
function C.MinimapRadius()
    local r=C.Number(C.Call(C_Minimap and C_Minimap.GetViewRadius))
    if r and r>0 then return r end
    if not(WoWUClient and WoWUClient.isClassic and Minimap)then return end
    -- Classic zoom diameters in yards; divide by two to obtain the view radius.
    local outdoor={466+2/3,400,333+1/3,266+2/6,200,133+1/3}
    local indoor={300,240,180,120,80,50}
    local zoom=Minimap:GetZoom()
    local outside=tonumber(C.Call(GetCVar,'minimapZoom'))==zoom
    local diameter=(outside and outdoor or indoor)[zoom+1]
    return diameter and diameter/2
end

function C.Text(value, fallback)
    if issecretvalue and issecretvalue(value) then return fallback end
    return type(value) == "string" and value ~= "" and value or fallback
end

function C.Wrap(degrees) return degrees % 360 end
function C.Delta(degrees, facing) return (degrees - facing + 180) % 360 - 180 end

-- WoW's facing is radians, increasing counter-clockwise from north.
-- The tape uses conventional clockwise compass degrees.
function C.Heading(radians)
    radians = C.Number(radians)
    return radians and C.Wrap(-radians * 180 / pi) or nil
end

function C.Smooth(previous, current, elapsed)
    if not previous then return current end
    return C.Wrap(previous + C.Delta(current, previous) * (1 - math.exp(-math.min(elapsed, .2) / .045)))
end

local function atan2(y, x)
    -- Plain Lua 5.1 compatible; do not depend on WoW's degree-based global atan2.
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and pi or -pi) end
    if y > 0 then return pi / 2 end
    if y < 0 then return -pi / 2 end
    return 0
end

function C.Coordinates(x, y)
    x, y = C.Number(x), C.Number(y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
    return x, y
end

function C.Vector(v)
    if not v or (issecretvalue and issecretvalue(v)) then return nil end
    local ok, x, y = pcall(function()
        if v.GetXY then return v:GetXY() end
        return v.x, v.y
    end)
    if ok then return C.Coordinates(x, y) end
end

function C.Bearing(px, py, tx, ty, width, height)
    width, height = C.Number(width), C.Number(height)
    if not width or not height or width <= 0 or height <= 0 then return nil end
    px, py = C.Coordinates(px, py)
    tx, ty = C.Coordinates(tx, ty)
    if not px or not tx then return nil end
    local east, north = (tx - px) * width, (py - ty) * height
    local distance = math.sqrt(east * east + north * north)
    return C.Wrap(atan2(east, north) * 180 / pi), distance
end

-- Map rectangles put neighboring zones into a shared geographic coordinate
-- space. Never subtract normalized coordinates from two different zone maps.
local function ancestry(id)
    local out,seen={},{}
    for i=1,12 do
        if not id or id<=0 or seen[id] then break end
        seen[id]=true
        local info=C.Call(C_Map and C_Map.GetMapInfo,id)
        if not info then break end
        -- World/cosmic atlases may rearrange continents; they are not geographic.
        local types=Enum and Enum.UIMapType
        if info.mapType==(types and types.World or 1) or info.mapType==(types and types.Cosmic or 0) then break end
        out[#out+1]=id;id=info.parentMapID
    end
    return out
end
local function rect(source,view)
    if source==view then return 0,1,0,1 end
    local a,b,c,d=C.Call(C_Map and C_Map.GetMapRectOnMap,source,view)
    a,b,c,d=C.Number(a),C.Number(b),C.Number(c),C.Number(d)
    if a and b and c and d and b>a and d>c then return a,b,c,d end
end
local function shared(a,b)
    local aa,bb=ancestry(a),ancestry(b)
    for _,first in ipairs(aa) do for _,second in ipairs(bb) do if first==second then return first end end end
end
function C.Project(source,x,y,view)
    if source==view then return x,y end
    local common=shared(source,view);if not common then return end
    local a,b,c,d=rect(source,common);local e,f,g,h=rect(view,common)
    if not a or not e then return end
    return (a+x*(b-a)-e)/(f-e),(c+y*(d-c)-g)/(h-g)
end
function C.ProjectEndpoints(t,view)
    t.projections=t.projections or {}
    if t.projections[view] then return unpack(t.projections[view]) end
    local px,py=C.Project(t.playerMap,t.playerX,t.playerY,view)
    local x,y=C.Project(t.targetMap,t.targetX,t.targetY,view)
    if px and x then t.projections[view]={px,py,x,y};return px,py,x,y end
end
local function questPosition(id,map)
    if not map then return end
    local x,y=C.Call(WoWUQuestLog and WoWUQuestLog.GetNextWaypointForMap,id,map)
    x,y=C.Coordinates(x,y);if x then return x,y end
    local pois=C.Call(WoWUQuestLog and WoWUQuestLog.GetQuestsOnMap,map)
    if type(pois)=='table' then
        for _,poi in ipairs(pois) do
            if poi.questID==id and (not poi.mapID or poi.mapID==map) then
                x,y=C.Coordinates(poi.x,poi.y);if x then return x,y end
            end
        end
    end
end
function C.IsDead() return C.Call(UnitIsDeadOrGhost,"player")==true end
function C.ReadDestination()
    local mapID=C.Number(C.Call(C_Map and C_Map.GetBestMapForUnit,'player'))
    if not mapID or mapID<=0 then return nil,'Location unavailable' end
    if C.IsDead() then
        local point=C.Call(C.sources.corpse)
        if not point then return nil,"Corpse location unavailable" end
        return C.PointDestination(point,mapID)
    end
    local state=C.State();if state.stopped then return nil end
    local active=state.active
    if active and active.kind~='quest' then
        local point=active;local resolver=C.sources[active.kind]
        if resolver then point=C.Call(resolver,active) end
        return C.PointDestination(point,mapID)
    end
    local user=C.Call(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint)==true
    local id=active and active.questID or C.Number(C.Call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID))
    if not active and not user and(not id or id<=0)and WoWUClient and (WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5) then
        local selected=C.selectedQuestID
        id=selected and C.Call(WoWUQuestLog.IsQuestWatched,selected)and selected or C.Call(WoWUQuestLog.GetQuestIDForQuestWatchIndex,1)
    end
    if active then user=false end
    local point={kind=user and 'pin' or 'quest',questID=id}
    if user then
        local pin=C.Call(C_Map and C_Map.GetUserWaypoint)
        if pin then point.mapID=pin.uiMapID;point.x,point.y=C.Vector(pin.position) end
        point.name='Map pin'
    elseif id and id>0 then
        point.name=C.Text(C.Call(WoWUQuestLog and WoWUQuestLog.GetTitleForQuestID,id),'Tracked quest')
        local m,x,y=C.Call(WoWUQuestLog and WoWUQuestLog.GetNextWaypoint,id)
        x,y=C.Coordinates(x,y)
        if x and C.Number(m) and m>0 then point.mapID=m;point.x=x;point.y=y end
        if not point.x then
            local questMap=C.Number(C.Call(GetQuestUiMapID,id)) or C.Number(C.Call(WoWUQuestLog and WoWUQuestLog.GetQuestUiMapID,id))
            if questMap and questMap>0 then
                point.x,point.y=questPosition(id,questMap);point.mapID=questMap
            end
        end
        if not point.x then point.x,point.y=questPosition(id,mapID);if point.x then point.mapID=mapID end end
        -- Continent POIs can expose a quest even when the per-zone waypoint API cannot.
        if not point.x then
            for _,parent in ipairs(ancestry(mapID)) do
                local px,py=questPosition(id,parent)
                if px then point.mapID=parent;point.x=px;point.y=py;break end
            end
        end
    else return nil end
    if point.x then
        local target,reason=C.PointDestination(point,mapID)
        if target then return target end
    end
    -- Native entrance/transport waypoint is preferable to a fabricated
    -- connection across different continents or instances.
    if user or id==C.Call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) then
        local x,y=C.Call(C_Navigation and C_Navigation.GetNextWaypointForMap,mapID)
        x,y=C.Coordinates(x,y)
        if x then point.mapID=mapID;point.x=x;point.y=y;return C.PointDestination(point,mapID) end
    end
    return nil,(point.name or 'Destination')..' - location unavailable'
end

function C.Resolve()
    local ok, target, reason = pcall(C.ReadDestination)
    if ok then return target, reason end
    -- Guard secret/restricted values or malformed API data at the UI boundary.
    return nil, "Destination unavailable"
end


C.sources={}
function C.State()
    WoWUDB=WoWUDB or {}
    if type(WoWUDB.navigation)~="table" then WoWUDB.navigation={} end
    return WoWUDB.navigation
end
function C.RegisterSource(kind,resolver) C.sources[kind]=resolver end
function C.PointDestination(point,mapID)
    if type(point)~='table' or not C.Number(point.mapID) then return nil,'Location unavailable' end
    local tx,ty=C.Coordinates(point.x,point.y)
    local px,py=C.Vector(C.Call(C_Map and C_Map.GetPlayerMapPosition,mapID,'player'))
    if not tx or not px then return nil,'Location unavailable' end
    local space=mapID==point.mapID and mapID or shared(mapID,point.mapID)
    if not space then return nil,'No geographic connection available' end
    local x,y=C.Project(point.mapID,tx,ty,space)
    local p,q=C.Project(mapID,px,py,space)
    if not x or not p then return nil,'Map position unavailable' end
    local width,height=C.MapWorldSize(space)
    local bearing,distance=C.Bearing(p,q,x,y,width,height)
    if not bearing then return nil,'Direction unavailable' end
    return {name=point.name or 'Destination',kind=point.kind,questID=point.questID,icon=point.icon,category=point.category,mapID=mapID,
        playerMap=mapID,playerX=px,playerY=py,targetMap=point.mapID,targetX=tx,targetY=ty,
        x=x,y=y,px=p,py=q,width=width,height=height,east=(x-p)*width,north=(q-y)*height,
        bearing=bearing,distance=distance}
end
function C.SelectQuest(id) C.selectedQuestID=id end
function C.StartQuest(id)
    if C.IsDead() then return false,"Corpse guidance takes priority while dead." end
    id=C.Number(id or C.selectedQuestID)
    if not id or id<=0 then return false,"Select a quest first" end
    if InCombatLockdown and InCombatLockdown() then return false,"Start navigation after combat" end
    C.Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID,id)
    if WoWUClient and (WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5) then C.Call(WoWUQuestLog.AddQuestWatch,id)end
    local s=C.State();s.active={kind="quest",questID=id};s.stopped=false;C.cacheTime=nil
    if WoWUClient and (WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5) and not C.Destination()then return true,"Quest selected; no known Classic location for this stage."end
    return true,"Navigating to quest"
end
function C.SetDestination(point)
    if C.IsDead() then return false,"Corpse guidance takes priority while dead." end
    if type(point)~="table" or type(point.kind)~="string" then return false end
    local s=C.State();s.active={kind=point.kind,id=point.id,mapID=point.mapID,x=point.x,y=point.y,name=point.name,icon=point.icon,category=point.category}
    s.stopped=false;C.cacheTime=nil;return true
end
function C.Stop() if C.IsDead() then return false,"Corpse guidance takes priority while dead." end;local s=C.State();s.active=nil;s.stopped=true;C.cacheTime=nil end
function C.Destination()
    local now=GetTime()
    if not C.cacheTime or now-C.cacheTime>=.1 then
        C.target,C.reason=C.Resolve();C.cacheTime=now
    end
    return C.target,C.reason
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","QUEST_LOG_UPDATE","QUEST_REMOVED","QUEST_TURNED_IN","SUPER_TRACKING_CHANGED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA"}) do events:RegisterEvent(e) end
 events:SetScript("OnEvent",function(_,event,id)
    C.cacheTime=nil
    local s=C.State()
    if (event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN") and s.active and s.active.questID==id then
        if WoWUClient and (WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5) then s.active=nil;s.stopped=false
        else C.Stop()end
    end
    if event=="SUPER_TRACKING_CHANGED" and not C.IsDead() then
        if not s.active or s.active.kind=="quest" then s.active=nil;s.stopped=false end
    end
end)
