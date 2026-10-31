-- Private API views: clients keep their own Blizzard globals and function signatures.
WoWUSpellBook=C_SpellBook
WoWUQuestLog=C_QuestLog
if not (WoWUClient and WoWUClient.isClassic)then return end
local function copy(t)local out={};for k,v in pairs(t or {})do out[k]=v end;return out end
local B=copy(C_SpellBook);WoWUSpellBook=B
local Q=copy(C_QuestLog);WoWUQuestLog=Q
local banks=Enum and Enum.SpellBookSpellBank or {}
B.PlayerBank=banks.Player or 0;B.PetBank=banks.Pet or 1
B.legacy=type(GetSpellBookItemInfo)=='function'and type(GetNumSpellTabs)=='function'
if B.legacy then
 for _,name in ipairs({'GetNumSpellBookSkillLines','GetSpellBookSkillLineInfo','GetSpellBookItemInfo','HasPetSpells','IsSpellKnown','PickupSpellBookItem'})do B[name]=nil end
end
if type(GetQuestLogTitle)=='function'and type(GetNumQuestLogEntries)=='function'then
 for _,name in ipairs({'GetNumQuestLogEntries','GetInfo','GetLogIndexForQuestID','GetSelectedQuest','SetSelectedQuest','GetQuestObjectives','IsComplete','IsOnQuest','GetTitleForQuestID','AddQuestWatch','RemoveQuestWatch','GetNumQuestWatches','GetQuestIDForQuestWatchIndex'})do Q[name]=nil end
end
local function bank(v)return (v=='pet'or v==B.PetBank)and 'pet'or 'spell'end
B.GetNumSpellBookSkillLines=B.GetNumSpellBookSkillLines or GetNumSpellTabs
B.GetSpellBookSkillLineInfo=B.GetSpellBookSkillLineInfo or function(index)
 local name,icon,offset,count,_,offSpecID=GetSpellTabInfo(index)
 if name then return {name=name,iconID=icon,itemIndexOffset=offset,numSpellBookItems=count,isGuild=false,offSpecID=type(offSpecID)=='number'and offSpecID>0 and offSpecID or nil}end
end
B.GetSpellBookItemInfo=B.GetSpellBookItemInfo or function(slot,kind)
 local book=bank(kind);local typ,id=GetSpellBookItemInfo(slot,book)
 if not typ or typ=='NONE'then return end
 local name,subName=GetSpellBookItemName(slot,book)
 local types=Enum and Enum.SpellBookItemType or {}
 return {name=name,subName=subName,spellID=id,actionID=id,iconID=GetSpellBookItemTexture(slot,book),isPassive=IsPassiveSpell and not not IsPassiveSpell(slot,book),itemType=typ=='FUTURESPELL'and(types.FutureSpell or 2)or typ=='FLYOUT'and(types.Flyout or 4)or(types.Spell or 1)}
end
B.HasPetSpells=B.HasPetSpells or HasPetSpells
B.IsSpellKnown=B.IsSpellKnown or function(id,kind)return IsSpellKnown and IsSpellKnown(id,bank(kind)=='pet')or IsPlayerSpell and IsPlayerSpell(id)end
B.PickupSpellBookItem=B.PickupSpellBookItem or function(slot,kind)return PickupSpellBookItem(slot,bank(kind))end
Q.GetNumQuestLogEntries=Q.GetNumQuestLogEntries or GetNumQuestLogEntries
Q.GetInfo=Q.GetInfo or function(index)
 local title,level,group,header,collapsed,complete,frequency,id=GetQuestLogTitle(index)
 if title then return {title=title,level=level,suggestedGroup=group,isHeader=header==true or header==1,isCollapsed=collapsed==true or collapsed==1,isComplete=complete,frequency=frequency,questID=id,logIndex=index}end
end
Q.GetLogIndexForQuestID=Q.GetLogIndexForQuestID or GetQuestLogIndexByID or function(id)
 for i=1,GetNumQuestLogEntries()do if select(8,GetQuestLogTitle(i))==id then return i end end
end
Q.GetSelectedQuest=Q.GetSelectedQuest or function()return select(8,GetQuestLogTitle(GetQuestLogSelection()))end
Q.SetSelectedQuest=Q.SetSelectedQuest or function(id)local i=Q.GetLogIndexForQuestID(id);if i and i>0 then SelectQuestLogEntry(i)end end
Q.GetLogText=function(index)
 if not GetQuestLogSelection or not SelectQuestLogEntry or not GetQuestLogQuestText then
  local d=Q.GetInfo(index);local fn=C_QuestLog and C_QuestLog.GetQuestDescription
  if d and fn then return fn(d.questID)end;return
 end
 local old=GetQuestLogSelection();SelectQuestLogEntry(index)
 local description,objectives=GetQuestLogQuestText()
 if old and old>0 and old~=index then SelectQuestLogEntry(old)end
 return description,objectives
end
Q.GetQuestDescription=Q.GetQuestDescription or function(id)local i=Q.GetLogIndexForQuestID(id);if i and i>0 then return Q.GetLogText(i)end end
Q.GetQuestObjectives=Q.GetQuestObjectives or function(id)
 local i=Q.GetLogIndexForQuestID(id);local out={};if not i or i<1 then return out end
 for n=1,GetNumQuestLeaderBoards(i)do local value,kind,finished=GetQuestLogLeaderBoard(n,i);out[#out+1]={text=value,type=kind,finished=finished}end
 return out
end
Q.IsComplete=Q.IsComplete or function(id)local i=Q.GetLogIndexForQuestID(id);return i and i>0 and select(6,GetQuestLogTitle(i))==1 or false end
Q.IsOnQuest=Q.IsOnQuest or function(id)local i=Q.GetLogIndexForQuestID(id);return i and i>0 or false end
Q.GetTitleForQuestID=Q.GetTitleForQuestID or function(id)local i=Q.GetLogIndexForQuestID(id);if i and i>0 then return GetQuestLogTitle(i)end end
Q.AddQuestWatch=Q.AddQuestWatch or function(id)local i=Q.GetLogIndexForQuestID(id);if i and i>0 then AddQuestWatch(i)end end
Q.RemoveQuestWatch=Q.RemoveQuestWatch or function(id)local i=Q.GetLogIndexForQuestID(id);if i and i>0 then RemoveQuestWatch(i)end end
Q.GetNumQuestWatches=Q.GetNumQuestWatches or GetNumQuestWatches
Q.GetQuestIDForQuestWatchIndex=Q.GetQuestIDForQuestWatchIndex or (not GetQuestIndexForWatch and C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex)or function(watch)local i=GetQuestIndexForWatch and GetQuestIndexForWatch(watch);if i then return select(8,GetQuestLogTitle(i))end end
-- Era/Mists keep an independent WoWU watch list, including dialogue quests,
-- without depending on the client-specific native objective-tracker watch APIs.
if WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5 then
 local nativeCompleted=IsQuestFlaggedCompleted or Q.IsQuestFlaggedCompleted
 if nativeCompleted then Q.IsQuestFlaggedCompleted=function(id)return nativeCompleted(id)end
 elseif GetQuestsCompleted then
  local completed,ready={},false
  local function readCompleted()
   local ok,value=pcall(GetQuestsCompleted,completed)
   if ok then if type(value)=='table'then completed=value end;ready=true end
  end
  local completionEvents=CreateFrame('Frame')
  for _,event in ipairs({'PLAYER_LOGIN','QUEST_QUERY_COMPLETE','QUEST_TURNED_IN'})do pcall(completionEvents.RegisterEvent,completionEvents,event)end
  completionEvents:SetScript('OnEvent',function(_,event,id)
   if event=='PLAYER_LOGIN'then if QueryQuestsCompleted then pcall(QueryQuestsCompleted)else readCompleted()end
   elseif event=='QUEST_QUERY_COMPLETE'then readCompleted()
   elseif id then completed[id]=true end
  end)
  Q.IsQuestFlaggedCompleted=function(id)if ready then return not not completed[id]end end
 end
 local function preferences()
  if not WoWUDB then return {}end
  WoWUDB.classicQuestWatches=WoWUDB.classicQuestWatches or {}
  local key=UnitGUID('player')or UnitName('player')or 'Player'
  local all=WoWUDB.classicQuestWatches;all[key]=all[key]or {};return all[key]
 end
 local function trackedEntries()
  local result,seen={},{};local prefs=preferences()
  local function add(info,index)
   if not info or info.isHeader==true or info.isHeader==1 then return end
   local id=tonumber(info.questID)
   if not id or id<=0 or seen[id]or prefs[id]==false then return end
   seen[id]=true;info.logIndex=info.logIndex or index;result[#result+1]=info
  end
  for i=1,Q.GetNumQuestLogEntries()or 0 do
   add(Q.GetInfo(i),i)
  end
  -- Retain explicitly tracked quests whose chapter is collapsed in the native UI.
  for id,value in pairs(prefs)do
   if value and not seen[id]then local i=Q.GetLogIndexForQuestID(id);if i and i>0 then add(Q.GetInfo(i),i)end end
  end
  return result
 end
 Q.GetTrackedEntries=trackedEntries
 local function watched()local result={};for _,info in ipairs(trackedEntries())do result[#result+1]=info.questID end;return result end
 Q.GetNumQuestWatches=function()return #watched()end
 Q.GetQuestIDForQuestWatchIndex=function(i)return watched()[i]end
 Q.IsQuestWatched=function(id)return Q.IsOnQuest(id)and preferences()[id]~=false end
 Q.AddQuestWatch=function(id)if Q.IsOnQuest(id)then preferences()[id]=true;Q.watchRevision=(Q.watchRevision or 0)+1;return true end end
 Q.RemoveQuestWatch=function(id)
  preferences()[id]=false;Q.watchRevision=(Q.watchRevision or 0)+1
  local n=WoWUNavigation
  if n then
   local state=n.State();local nativeID=C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
   if state.active and state.active.questID==id or n.selectedQuestID==id or nativeID==id then n.Stop();n.cacheTime=nil end
  end
  return true
 end
end
