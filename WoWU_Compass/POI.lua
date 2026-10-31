local _, C = ...
local requestedMap,requestTime
local categories={quests="poiQuests",offers="poiOffers",turnins="poiTurnins",inns="poiInns",mail="poiMail",trainers="poiTrainers",repairs="poiRepairs",flights="poiFlights",rares="poiRares",bookmarks="poiBookmarks",pois="poiOther",other="poiOther"}
C.POICategories=categories

-- These are map-API records, not an enumeration of the engine's native blips.
-- Never infer a position from icon art, a tooltip name, or another map's coordinates.
function C.POICategory(info)
    local atlas=string.lower(C.Text(info.atlasName, ""))
    if atlas:find("innkeeper",1,true) or atlas:find("resting",1,true) then return "inns" end
    if atlas:find("mail",1,true) then return "mail" end
    if atlas:find("repair",1,true) then return "repairs" end
    if atlas:find("trainer",1,true) then return "trainers" end
    return "other"
end

local function read(db,target)
    local questAPI=WoWUQuestLog or C_QuestLog
    if not db.showPOIs or db.navigationOnly or WoWUNavigation and WoWUNavigation.IsDead() then return {} end
    local mapID=C.Number(C.Call(C_Map and C_Map.GetBestMapForUnit,"player"))
    if not mapID then return {} end
    local px,py=C.Vector(C.Call(C_Map and C_Map.GetPlayerMapPosition,mapID,"player"))
    local width,height
    if WoWUNavigation and WoWUNavigation.MapWorldSize then width,height=WoWUNavigation.MapWorldSize(mapID)
    else width,height=C.Call(C_Map and C_Map.GetMapWorldSize,mapID)end
    if not px or not C.Number(width) or not C.Number(height) then return {} end
    local result,seen={},{}
    local radius=C.Number(C.Call(C_Minimap and C_Minimap.GetViewRadius))
    local function add(key,category,x,y,name,atlas,questID,nearby)
        if seen[key] or db[categories[category]]==false then return end
        if WoWUExplorer and WoWUExplorer.IsEnabled and (category=="inns" or category=="mail" or category=="trainers" or category=="repairs") and not WoWUExplorer.IsEnabled(category) then return end
        if questID and target and target.questID==questID then return end
        local bearing,distance=C.Bearing(px,py,x,y,width,height)
        if not bearing or nearby and radius and distance>radius then return end
        seen[key]=true
        result[#result+1]={key=key,category=category,name=C.Text(name,"Point of interest"),atlas=C.Text(atlas),bearing=bearing,distance=distance,questID=questID}
    end
    local function quest(info,offer)
        if type(info)~="table" then return end
        if info.isQuestStart and not info.inProgress then return end -- shared offer collector handles these
        local id=C.Number(info.questID)
        if not id or id<=0 or info.mapID and info.mapID~=mapID or info.startMapID and info.startMapID~=mapID then return end
        if info.childDepth and info.childDepth~=0 then return end
        if info.floorLocation and Enum and Enum.QuestLineFloorLocation and info.floorLocation~=Enum.QuestLineFloorLocation.Same then return end
        if info.isHidden and C.Call(C_Minimap and C_Minimap.IsTrackingHiddenQuests)~=true then return end
        if offer and (info.inProgress or C.Call(questAPI and questAPI.IsOnQuest,id)==true) then return end
        if offer and C.Call(questAPI and questAPI.IsQuestFlaggedCompleted,id)==true and not info.isDaily then return end
        local kind=(offer or info.isQuestStart and not info.inProgress) and "offers" or (C.Call(questAPI and questAPI.IsComplete,id)==true and "turnins" or "quests")
        local x,y=C.Coordinates(info.x,info.y)
        if not x then x,y=C.Call(questAPI and questAPI.GetNextWaypointForMap,id,mapID) end
        add("q:"..id,kind,x,y,info.questName or C.Call(questAPI and questAPI.GetTitleForQuestID,id),nil,id)
    end
    local quests=C.Call(questAPI and questAPI.GetQuestsOnMap,mapID)
    if type(quests)=="table" then for _,info in ipairs(quests) do quest(info,false) end end
    -- Also resolve watched quests that have route points but no map POI record.
    local count=C.Number(C.Call(questAPI and questAPI.GetNumQuestWatches)) or 0
    for i=1,math.min(100,count) do
        local id=C.Number(C.Call(questAPI and questAPI.GetQuestIDForQuestWatchIndex,i))
        if id then quest({questID=id},false) end
    end
    if db.poiOffers~=false and WoWUQuestOffers then
        for _,p in ipairs(WoWUQuestOffers.Points(mapID))do
            add("q:"..p.questID,"offers",p.x,p.y,p.name,nil,p.questID)
        end
    end
    local ids=C.Call(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap,mapID)
    if type(ids)=="table" then
        for _,id in ipairs(ids) do
            local info=C.Call(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo,mapID,id)
            if type(info)=="table" then
                local x,y=C.Vector(info.position)
                add("area:"..tostring(id),C.POICategory(info),x,y,info.name,info.atlasName,nil,true)
            end
        end
    end
    if WoWUExplorer and WoWUNavigation then
        for _,p in ipairs(WoWUExplorer.Points(mapID)) do
            local category=categories[p.category] and p.category or "other"
            local t=WoWUNavigation.PointDestination(p,mapID)
            local active=t and target and target.targetMap==p.mapID and target.targetX and math.abs(target.targetX-p.x)<.0001 and math.abs(target.targetY-p.y)<.0001
            if t and not active and db[categories[category]]~=false then
                -- Prefer the service image from the shared marker provider.
                local duplicate
                for _,existing in ipairs(result) do
                    if existing.name==p.name and math.abs(existing.distance-t.distance)<15 then duplicate=existing;break end
                end
                if duplicate then duplicate.icon=p.icon
                else result[#result+1]={key="wowu:"..p.mapID..":"..p.x..":"..p.y..":"..p.category,
                    category=category,name=p.name,bearing=t.bearing,distance=t.distance,icon=p.icon} end
            end
        end
    end
    for i=#result,1,-1 do if result[i].distance>(db.poiRange or 1500)then table.remove(result,i)end end
    table.sort(result,function(a,b) if a.distance==b.distance then return a.key<b.key end;return a.distance<b.distance end)
    return result
end

function C.POIs(db,target)
    local ok,points=pcall(read,db,target)
    return ok and points or {}
end

-- Group coincident headings instead of covering the closest icon with distant ones.
function C.POILayout(points,heading,width,db,reserved)
    local visible,groups={},{};local size=db.iconSize or 24;local gap=size+10;local nearTarget=0
    for _,point in ipairs(points)do
        local x,edge=C.Marker(point.bearing,heading,width)
        if not edge then
            if reserved and math.abs(x-reserved)<size*1.4 then nearTarget=nearTarget+1
            else visible[#visible+1]={point=point,x=x,count=1}end
        end
    end
    table.sort(visible,function(a,b)if a.x==b.x then return a.point.key<b.point.key end;return a.x<b.x end)
    for _,entry in ipairs(visible)do
        local last=groups[#groups]
        if db.groupMarkers~=false and last and entry.x-last.lastX<gap then
            last.count=last.count+1;last.lastX=entry.x
            if entry.point.distance<last.point.distance then last.point=entry.point;last.x=entry.x end
        else entry.lastX=entry.x;groups[#groups+1]=entry end
    end
    return groups,nearTarget
end
