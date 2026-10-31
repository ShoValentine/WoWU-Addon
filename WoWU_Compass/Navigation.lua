local _, C = ...
local pi, abs = math.pi, math.abs

function C.Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function C.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
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

-- Read-only: never selects a quest, modifies a waypoint, or changes the world map.
-- Resolve on the player's current map so unrelated continents/floors cannot
-- accidentally produce a plausible but wrong bearing.
function C.ReadDestination()
    local mapID = C.Number(C.Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    if not mapID or mapID <= 0 then return nil, "Location unavailable" end
    local super = C_SuperTrack
    local user = C.Call(super and super.IsSuperTrackingUserWaypoint) == true
    local quest = C.Call(super and super.IsSuperTrackingQuest) == true
    local questID
    if quest then questID = C.Number(C.Call(super and super.GetSuperTrackedQuestID)) end
    -- Older clients can provide the quest ID but not the type predicate.
    if super and not super.IsSuperTrackingQuest and not user then
        questID = C.Number(C.Call(super.GetSuperTrackedQuestID))
        quest = questID and questID > 0 or false
    end
    if not user and not (quest and questID and questID > 0) then return nil end

    local name, x, y, destinationMap
    if user then
        name = "Map pin"
        local point = C.Call(C_Map and C_Map.GetUserWaypoint)
        if type(point) == "table" then destinationMap = C.Number(point.uiMapID) end
        x, y = C.Vector(C.Call(C_Map and C_Map.GetUserWaypointPositionForMap, mapID))
        if not x and destinationMap == mapID then x, y = C.Vector(point.position) end
    else
        name = C.Text(C.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, questID), "Tracked quest")
        x, y = C.Call(C_QuestLog and C_QuestLog.GetNextWaypointForMap, questID, mapID)
        x, y = C.Coordinates(x, y)
        if not x then
            local m, tx, ty = C.Call(C_QuestLog and C_QuestLog.GetNextWaypoint, questID)
            destinationMap = C.Number(m)
            if destinationMap == mapID then x, y = C.Coordinates(tx, ty) end
        end
    end
    -- Some Forever quests publish map POIs but no navigation waypoint.
    if not x and questID then
        local pois=C.Call(C_QuestLog and C_QuestLog.GetQuestsOnMap,mapID)
        if type(pois)=="table" then
            for _,poi in ipairs(pois) do
                if type(poi)=="table" and poi.questID==questID and (not poi.mapID or poi.mapID==mapID) and (not poi.childDepth or poi.childDepth==0) then
                    x,y=C.Coordinates(poi.x,poi.y)
                    if x then break end
                end
            end
        end
    end
    -- The native navigation system can supply the next entrance/route point
    -- on this map when the final objective is on another floor or in another zone.
    if not x then
        local nx, ny = C.Call(C_Navigation and C_Navigation.GetNextWaypointForMap, mapID)
        x, y = C.Coordinates(nx, ny)
    end
    if not x then
        local mapInfo = destinationMap and C.Call(C_Map and C_Map.GetMapInfo, destinationMap)
        local zone = type(mapInfo) == "table" and C.Text(mapInfo.name)
        return nil, name .. " - " .. (zone and ("in " .. zone) or "location unavailable")
    end
    local px, py = C.Vector(C.Call(C_Map and C_Map.GetPlayerMapPosition, mapID, "player"))
    if not px then return nil, name .. " - player location unavailable" end
    local width, height = C.Call(C_Map and C_Map.GetMapWorldSize, mapID)
    local bearing, distance = C.Bearing(px, py, x, y, width, height)
    if not bearing then return nil, name .. " - direction unavailable" end
    return { name = name, bearing = bearing, distance = distance, kind = user and "pin" or "quest", questID=questID }
end

function C.Destination()
    if WoWUNavigation and WoWUNavigation.Destination then return WoWUNavigation.Destination() end
    if C.Call(UnitIsDeadOrGhost,"player")==true then
        local map=C.Number(C.Call(C_Map and C_Map.GetBestMapForUnit,"player"))
        local x,y=C.Vector(C.Call(C_DeathInfo and C_DeathInfo.GetCorpseMapPosition,map))
        local px,py=C.Vector(C.Call(C_Map and C_Map.GetPlayerMapPosition,map,"player"))
        local width,height=C.Call(C_Map and C_Map.GetMapWorldSize,map)
        local bearing,distance=C.Bearing(px,py,x,y,width,height)
        if bearing then return {kind="corpse",name="Your corpse",bearing=bearing,distance=distance}end
        return nil,"Corpse location unavailable"
    end
    local ok, target, reason = pcall(C.ReadDestination)
    if ok then return target, reason end
    -- Guard secret/restricted values or malformed API data at the UI boundary.
    return nil, "Destination unavailable"
end

function C.Marker(bearing, heading, width)
    local delta = C.Delta(bearing, heading)
    local edge = delta < -88 and "left" or delta > 88 and "right" or nil
    return math.max(-88, math.min(88, delta)) * width / 180, edge
end

function C.DistanceText(distance)
    if distance < 5 then return "Arrived" end
    if distance >= 1000 then return string.format("%.1f k yd", distance / 1000) end
    return string.format("%d yd", math.floor(distance + .5))
end

function C.Rect(rect)
    if type(rect) ~= "table" then return nil end
    local l,b,r,t = C.Number(rect.left), C.Number(rect.bottom), C.Number(rect.right), C.Number(rect.top)
    if not l or not b or not r or not t or r <= l or t <= b then return nil end
    return {left=l,bottom=b,right=r,top=t,width=r-l,height=t-b}
end

function C.Geometry(rect, db)
    -- All rectangle values are UIParent units; offsets passed to the scaled
    -- compass must be divided by its own scale, including the screen origin.
    local scale = math.min(db.scale, math.max(.05, (rect.width-24)/db.width), math.max(.05,(rect.height-12)/116))
    local width, height = db.width*scale, 116*scale
    local x = rect.left + rect.width/2 + db.x*rect.width
    local top = rect.top + db.y*rect.height
    x = math.max(rect.left+width/2+6, math.min(rect.right-width/2-6, x))
    top = math.max(rect.bottom+height+6, math.min(rect.top-6, top))
    return scale, x/scale, top/scale
end
