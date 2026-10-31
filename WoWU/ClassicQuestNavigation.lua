-- Read-only Era spawn facts, evaluated only for active quests. No pathfinding.
if not(WoWUClient and WoWUClient.classicMajor==1 and WoWUClassicQuestLocations)then return end
local D,Q,N=WoWUClassicQuestLocations,WoWUQuestLog,WoWUNavigation
local cache={}
local function location(id,map)
 local entry=cache[id];local now=GetTime()
 if entry and entry.map==map and now-entry.time<.5 then return unpack(entry.result)end
 local q=D.quests[id];if not q or not Q.IsOnQuest(id)then return end
 local pools={};local live=Q.GetQuestObjectives(id)or {};local complete=Q.IsComplete(id)
 local allFinished=#live>0
 for _,o in ipairs(live)do if not(o.finished==true or o.finished==1)then allFinished=false end end
 if complete or allFinished or #q.objectives==0 then
  pools[1]=q.turnin
 else
  local ordinal={}
  for _,o in ipairs(q.objectives)do
   local kind=o[1];ordinal[kind]=(ordinal[kind]or 0)+1
   local n,objective=0,nil
   for _,value in ipairs(live)do
    if value.type==kind then n=n+1;if n==ordinal[kind]then objective=value;break end end
   end
   if not objective or not(objective.finished==true or objective.finished==1)then pools[#pools+1]=o[2]end
  end
 end
 local best,score
 for _,pool in ipairs(pools)do
  for _,p in ipairs(D.points[pool]or {})do
   local target=N.PointDestination({mapID=p[1],x=p[2],y=p[3]},map)
   -- Prefer the current zone, then the closest geographically connected point.
   local distance=(p[1]==map and 0 or 1000000)+(target and target.distance or 1000000000)
   if not score or distance<score then best=p;score=distance end
  end
 end
 local result=best and {best[1],best[2],best[3]}or {}
 cache[id]={time=now,map=map,result=result}
 return unpack(result)
end
WoWUClassicQuestLocation=location
Q.GetNextWaypoint=function(id)return location(id,C_Map.GetBestMapForUnit('player'))end
Q.GetNextWaypointForMap=function(id,map)local m,x,y=location(id,map);if m==map then return x,y end end
Q.GetQuestUiMapID=function(id)local m=location(id,C_Map.GetBestMapForUnit('player'));return m end
Q.GetQuestsOnMap=function(map)
 local out={}
 for i=1,Q.GetNumQuestWatches()do
  local id=Q.GetQuestIDForQuestWatchIndex(i)
  local m,x,y=location(id,map)
  if m==map and x then out[#out+1]={questID=id,mapID=m,x=x,y=y,childDepth=0}end
 end
 return out
end
local events=CreateFrame('Frame')
events:RegisterEvent('QUEST_LOG_UPDATE');events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:SetScript('OnEvent',function()cache={}end)
