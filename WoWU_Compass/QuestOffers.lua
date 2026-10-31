-- Shared, read-only available-quest locations. Loaded by either addon.
if WoWUQuestOffers then return end
local O={};WoWUQuestOffers=O
local requested={}
local function sightings()
 local db=WoWUDB or WoWUCompassDB
 if not db then return {}end
 db.questOfferSightings=db.questOfferSightings or {}
 local guid=UnitGUID("player")or "player";db.questOfferSightings[guid]=db.questOfferSightings[guid]or {}
 return db.questOfferSightings[guid]
end
local function call(fn,...)
 if type(fn)~="function"then return end
 local ok,a=pcall(fn,...);if ok then return a end
end
local function number(v)return type(v)=="number"and not (issecretvalue and issecretvalue(v))and v==v and v~=math.huge and v~=-math.huge end
local function eligible(id,q)
 if not q then return false end
 local function active(n)return call(C_QuestLog and C_QuestLog.IsOnQuest,n)end
 local function done(n)return call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,n)end
 if active(id)~=false or done(id)~=false then return false end
 local level=UnitLevel("player")
 if level<(q.requiredLevel or 1)or q.requiredMaxLevel and q.requiredMaxLevel>0 and level>q.requiredMaxLevel then return false end
 local _,_,race=UnitRace("player");local _,_,class=UnitClass("player")
 local raceBits={[1]=1,[2]=2,[3]=4,[4]=8,[5]=16,[6]=32,[7]=64,[8]=128,[9]=256,[95]=4294967296,[96]=8589934592}
 local function matches(mask,bit)
  return not mask or mask==0 or bit and math.floor(mask/bit)%2==1
 end
 if not matches(q.requiredRaces,raceBits[race])or not matches(q.requiredClasses,class and 2^(class-1))then return false end
 local function list(v)if type(v)=="table"then return v elseif v and v~=0 then return {v}else return {}end end
 for _,n in pairs(list(q.preQuestGroup))do if done(n)~=true then return false end end
 if q.preQuestSingle and next(list(q.preQuestSingle))then
  local any=false;for _,n in pairs(list(q.preQuestSingle))do if done(n)==true then any=true end end
  if not any then return false end
 end
 for _,key in ipairs({"exclusiveTo","nextQuestInChain","breadcrumbForQuestId","disabledByQuest"})do
  for _,n in pairs(list(q[key]))do if active(n)~=false or done(n)~=false then return false end end
 end
 for _,n in pairs(list(q.parentQuest))do if active(n)~=true then return false end end
 for _,n in pairs(list(q.availableUntilCompleted))do if done(n)~=false then return false end end
 if q.availableStartingWith then
  local any=false;for _,n in pairs(list(q.availableStartingWith))do if active(n)==true or done(n)==true then any=true end end
  if not any then return false end
 end
 return true
end
function O.Points(mapID)
 if not number(mapID)or mapID<=0 then return {}end
 local now=GetTime()
 if not requested[mapID]or now-requested[mapID]>10 then
  requested[mapID]=now;call(C_QuestLine and C_QuestLine.RequestQuestLinesForMap,mapID)
 end
 local result,seen={},{}
 local function add(info,task)
  if type(info)~="table"then return end
  local id=info.questID
  if not number(id)or id<=0 or seen[id]then return end
  if task and info.isQuestStart~=true then return end
  if info.inProgress or call(C_QuestLog and C_QuestLog.IsOnQuest,id)==true then return end
  if call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,id)==true and not info.isDaily and not info.isRepeatable then return end
  if info.isHidden and call(C_Minimap and C_Minimap.IsTrackingHiddenQuests)~=true then return end
  if info.isAccountCompleted and call(C_Minimap and C_Minimap.IsTrackingAccountCompletedQuests)==false then return end
  local x,y=info.x,info.y
  if not number(x)or not number(y)or x<0 or x>1 or y<0 or y>1 or x==0 and y==0 then return end
  -- Native offer pins use coordinates on the queried map. startMapID may be
  -- a child zone and is not the coordinate space of this returned record.
  local title=info.questName or call(C_QuestLog and C_QuestLog.GetTitleForQuestID,id)or call(C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID,id)
  seen[id]=true;result[#result+1]={questID=id,kind="offer",category="offers",name=(title or "Available quest")..(info.npcName and (" - "..info.npcName)or ""),mapID=mapID,x=x,y=y,icon="Interface\\GossipFrame\\AvailableQuestIcon"}
 end
 for _,info in pairs(call(C_QuestLine and C_QuestLine.GetAvailableQuestLines,mapID)or {})do add(info)end
 for _,id in pairs(call(C_QuestLine and C_QuestLine.GetForceVisibleQuests,mapID)or {})do add(call(C_QuestLine and C_QuestLine.GetQuestLineInfo,id,mapID))end
 local tasks=call(GetTasksOnMapCached,mapID)or call(C_TaskQuest and C_TaskQuest.GetQuestsForPlayerByMapID,mapID)
 for _,info in pairs(tasks or {})do add(info,true)end
 for _,info in pairs(call(C_QuestLog and C_QuestLog.GetQuestsOnMap,mapID)or {})do add(info,true)end
 -- Database/observed locations supplement APIs, never overwrite their offers.
 for _,info in pairs(sightings())do
  if info.mapID==mapID and call(C_QuestLog and C_QuestLog.IsOnQuest,info.questID)==false
   and call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,info.questID)==false then add(info)end
 end
 local data=WoWUQuestOfferData
 for _,info in ipairs(data and data.maps[mapID]or {})do
  if not seen[info.questID]and eligible(info.questID,data.requirements[info.questID])then add(info)end
 end
 return result
end
local function remember()
 local available=call(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
 if type(available)~="table"then return end
 local map=call(C_Map and C_Map.GetBestMapForUnit,"player")
 local position=call(C_Map and C_Map.GetPlayerMapPosition,map,"player")
 if not position or not position.GetXY then return end
 local x,y=position:GetXY();if not number(x)or not number(y)then return end
 local saved=sightings();local npc=UnitName("npc")
 -- Record the player's interaction location, not an inferred exact NPC position.
 for _,offer in ipairs(available)do
  if number(offer.questID)then saved[offer.questID]={questID=offer.questID,questName=offer.title,npcName=npc,mapID=map,x=x,y=y}end
 end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"GOSSIP_SHOW","GOSSIP_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_LEVEL_UP","ZONE_CHANGED_NEW_AREA"})do pcall(events.RegisterEvent,events,event)end
events:SetScript("OnEvent",function(_,event)
 requested={}
 if event=="GOSSIP_SHOW"or event=="GOSSIP_UPDATE"then pcall(remember)end
end)
SLASH_WOWUOFFERS1="/wowuoffers"
SlashCmdList.WOWUOFFERS=function()
 local map=call(C_Map and C_Map.GetBestMapForUnit,"player")
 local points=O.Points(map);print("WoWU available quests: map "..tostring(map)..", "..#points.." markers")
 local native=call(C_QuestLine and C_QuestLine.GetAvailableQuestLines,map)
 print("Native quest-line offers: "..(type(native)=="table"and #native or "unavailable"))
 print("Terrence quest 96895: in log="..tostring(call(C_QuestLog and C_QuestLog.IsOnQuest,96895))..", completed="..tostring(call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,96895)))
 for _,point in ipairs(points)do print(point.questID..": "..point.name)end
end
