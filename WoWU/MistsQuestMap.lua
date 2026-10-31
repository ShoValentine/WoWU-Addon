-- One native Mists quest-POI source for the owned map and WoWU navigation.
if not(WoWUClient and WoWUClient.classicMajor==5)then return end
local N,Q=WoWUNavigation,WoWUQuestLog
local M={};WoWUMistsQuests=M
local native=C_QuestLog or {};local cache={};local version=0
local function call(fn,...)return N.Call(fn,...)end
function M.Number(id)
 local count=0
 for i=1,call(Q.GetNumQuestLogEntries)or 0 do
  local info=call(Q.GetInfo,i)
  if info and not info.isHeader and info.questID and info.questID>0 then
   count=count+1;if info.questID==id then return count end
  end
 end
end
function M.Points(mapID)
 if not mapID then return {}end
 local old=cache[mapID];local now=GetTime()
 if old and now-old.time<.5 then return old.points end
 local points,seen={},{}
 for _,info in ipairs(call(native.GetQuestsOnMap,mapID)or {})do
  local id=N.Number(info.questID);local x,y=N.Coordinates(info.x,info.y)
  if id and id>0 and x and not seen[id]and call(Q.IsOnQuest,id)then
   seen[id]=true
   points[#points+1]={questID=id,questNumber=M.Number(id)or #points+1,mapID=mapID,x=x,y=y,
    name=call(Q.GetTitleForQuestID,id)or 'Quest',kind='quest',category='quests'}
  end
 end
 cache[mapID]={time=now,points=points};return points
end
function M.Location(id,preferredMap)
 local nativeMap=N.Number(call(GetQuestUiMapID,id))
 if not nativeMap or nativeMap<=0 then nativeMap=N.Number(call(native.GetQuestUiMapID,id))end
 for _,mapID in ipairs({nativeMap or 0,preferredMap or 0})do
  if mapID>0 then for _,p in ipairs(M.Points(mapID))do if p.questID==id then return mapID,p.x,p.y end end end
 end
end
local waypoint=Q.GetNextWaypoint
Q.GetNextWaypoint=function(id)
 local map,x,y=call(waypoint,id);x,y=N.Coordinates(x,y)
 if map and map>0 and x then return map,x,y end
 return M.Location(id,call(C_Map.GetBestMapForUnit,'player'))
end
local waypointForMap=Q.GetNextWaypointForMap
Q.GetNextWaypointForMap=function(id,mapID)
 local x,y=call(waypointForMap,id,mapID);x,y=N.Coordinates(x,y)
 if x then return x,y end
 for _,p in ipairs(M.Points(mapID))do if p.questID==id then return p.x,p.y end end
end
function M.ActiveQuest()
 local state=N.State()
 if state.stopped then return end
 if state.active then return state.active.kind=='quest'and state.active.questID or nil end
 local id=call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
 if not id or id<=0 then
  local selected=N.selectedQuestID
  id=selected and call(Q.IsQuestWatched,selected)and selected or call(Q.GetQuestIDForQuestWatchIndex,1)
 end
 return id and call(Q.IsOnQuest,id)and id or nil
end
local selecting=false
function M.Select(id)
 if selecting then return true end
 if not call(Q.IsOnQuest,id)then return false,'This quest is no longer in the quest log.'end
 selecting=true
 local called,ok,message=pcall(N.StartQuest,id)
 if not called then selecting=false;return false,tostring(ok)end
 if ok then
  N.SelectQuest(id);call(Q.SetSelectedQuest,id)
  cache={};version=version+1
 end
 selecting=false;return ok,message
end
function M.ShowOnMap(id)
 local ok,message=M.Select(id);if not ok then return false,message end
 if WoWU_ShowPage then WoWU_ShowPage('Map')end
 local mapID=M.Location(id,call(C_Map.GetBestMapForUnit,'player'))
 if not mapID or mapID<=0 then mapID=call(GetQuestUiMapID,id)end
 local map=WoWU_GetActiveMap and WoWU_GetActiveMap()
 if mapID and mapID>0 and map and map.SetMapID then map:SetMapID(mapID);return true,'Quest selected on map.'end
 return false,'This quest has no native map location yet.'
end
function M.Attach(map)
 if map.WoWUMistsQuestLayer then return end
 local canvas=map:GetCanvas();local viewport=map.ScrollContainer
 local layer=CreateFrame('Frame',nil,canvas);layer:SetAllPoints(canvas)
 layer.WoWUMapOverlay=true;layer:SetFrameLevel(canvas:GetFrameLevel()+45)
 map.WoWUMistsQuestLayer=layer
 local blob
 local ok,result=pcall(CreateFrame,'QuestPOIFrame',nil,canvas)
 if ok then
  blob=result;blob.WoWUMapOverlay=true;blob:SetAllPoints(canvas);blob:EnableMouse(false)
  blob:SetFrameLevel(canvas:GetFrameLevel()+5)
  blob:SetFillTexture('Interface\\WorldMap\\UI-QuestBlob-Inside')
  blob:SetBorderTexture('Interface\\WorldMap\\UI-QuestBlob-Outside')
  blob:SetFillAlpha(128);blob:SetBorderAlpha(192);blob:SetBorderScalar(1)
 elseif WoWUDB then WoWUDB.mistsQuestBlobError=tostring(result)end
 local buttons,hover={},nil
 local dirty=true;local lastMap,lastQuest,lastVersion,lastW,lastH
 local function drawArea()
  if not blob then return end
  local success,err=pcall(function()
   blob:DrawNone();blob:SetMapID(map:GetMapID())
   local active=M.ActiveQuest()
   if active then blob:DrawBlob(active,true)end
   if hover and hover~=active then blob:DrawBlob(hover,true)end
   blob:Show()
  end)
  if not success then blob:Hide()end
  if WoWUDB then WoWUDB.mistsQuestBlobError=not success and tostring(err)or nil end
 end
 local function makeButton()
  local b=CreateFrame('Button',nil,layer);b:SetSize(40,40)
  b.art=b:CreateTexture(nil,'ARTWORK');b.art:SetSize(32,32);b.art:SetPoint('CENTER')
  b.art:SetTexture('Interface\\WorldMap\\UI-QuestPoi-NumberIcons')
  b.number=b:CreateFontString(nil,'OVERLAY','GameFontNormal')
  b.number:SetFont('Fonts\\FRIZQT__.TTF',15,'OUTLINE');b.number:SetPoint('CENTER',0,0)
  b:SetScript('OnMouseDown',function(self,button)
   if button=='LeftButton'then self.down={GetCursorPosition()};if viewport.OnMouseDown then viewport:OnMouseDown(button)end end
  end)
  b:SetScript('OnMouseUp',function(self,button)
   local down=self.down;self.down=nil
   if viewport.WoWUStopPan then viewport.WoWUStopPan()end
   if button~='LeftButton'or not down then return end
   local x,y=GetCursorPosition();local threshold=12*self:GetEffectiveScale()
   if(x-down[1])^2+(y-down[2])^2>threshold^2 or not self:IsMouseOver()then return end
   local selected,message=M.Select(self.questID)
   if not selected and message then print('WoWU: '..message)end
   dirty=true
  end)
  b:SetScript('OnEnter',function(self)
   hover=self.questID;drawArea()
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.questTitle)
   for _,objective in ipairs(call(Q.GetQuestObjectives,self.questID)or {})do
    if objective.text then GameTooltip:AddLine(objective.text,.9,.85,.65,true)end
   end
   GameTooltip:AddLine('Tap to track this quest.',.8,.8,.8,true);GameTooltip:Show()
  end)
  b:SetScript('OnLeave',function()hover=nil;GameTooltip:Hide();drawArea()end)
  return b
 end
 local function refresh()
  local mapID=map:GetMapID();if not mapID then return end
  local width,height=canvas:GetWidth(),canvas:GetHeight();local selected=M.ActiveQuest()
  local occupied={};local points=M.Points(mapID)
  for i,p in ipairs(points)do
   local b=buttons[i];if not b then b=makeButton();buttons[i]=b end
   b.questID=p.questID;b.questTitle=p.name
   b.number:SetText(p.questNumber)
   b.art:SetTexCoord(selected==p.questID and .5 or .875,selected==p.questID and .625 or 1,.375,.5)
   b.number:SetTextColor(selected==p.questID and .12 or 1,selected==p.questID and .08 or .85,0)
   local x,y=p.x*width,p.y*height
   for attempt=0,24 do
    local ox=attempt==0 and 0 or ((attempt-1)%5-2)*22
    local oy=attempt==0 and 0 or (math.floor((attempt-1)/5)-2)*22
    local cx,cy=math.max(20,math.min(width-20,x+ox)),math.max(20,math.min(height-20,y+oy))
    local clear=true;for _,at in ipairs(occupied)do if(cx-at[1])^2+(cy-at[2])^2<30^2 then clear=false;break end end
    if clear or attempt==24 then x,y=cx,cy;break end
   end
   occupied[#occupied+1]={x,y};b:ClearAllPoints();b:SetPoint('CENTER',layer,'TOPLEFT',x,-y);b:Show()
  end
  for i=#points+1,#buttons do buttons[i]:Hide()end
  drawArea();dirty=false
  lastMap,lastQuest,lastVersion,lastW,lastH=mapID,selected,version,width,height
 end
 local elapsed=0
 layer:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
  if dirty or lastMap~=map:GetMapID()or lastQuest~=M.ActiveQuest()or lastVersion~=version or lastW~=canvas:GetWidth()or lastH~=canvas:GetHeight()then
   local success,err=pcall(refresh)
   if not success then
    dirty=false;lastVersion=version
    lastMap,lastQuest,lastW,lastH=map:GetMapID(),M.ActiveQuest(),canvas:GetWidth(),canvas:GetHeight()
    if WoWUDB then WoWUDB.mistsQuestMapError=tostring(err)end
    for _,b in ipairs(buttons)do b:Hide()end
    if blob then blob:Hide()end
   elseif WoWUDB then WoWUDB.mistsQuestMapError=nil end
  end
 end)
 map:HookScript('OnShow',function()dirty=true end)
 map:HookScript('OnHide',function()hover=nil;GameTooltip:Hide()end)
end
local events=CreateFrame('Frame')
for _,event in ipairs({'QUEST_LOG_UPDATE','QUEST_POI_UPDATE','QUEST_WATCH_LIST_CHANGED','SUPER_TRACKED_QUEST_CHANGED','SUPER_TRACKING_CHANGED','QUEST_TURNED_IN','PLAYER_ENTERING_WORLD'})do pcall(events.RegisterEvent,events,event)end
events:SetScript('OnEvent',function(_,event)
 cache={};version=version+1;N.cacheTime=nil
 if event=='PLAYER_ENTERING_WORLD'or event=='QUEST_LOG_UPDATE'then call(QuestPOIUpdateIcons)end
end)
if hooksecurefunc and type(QuestMapFrame_ShowQuestDetails)=='function'then
 hooksecurefunc('QuestMapFrame_ShowQuestDetails',function(id)
  if WoWUViewport and WoWUViewport.active then M.Select(id)end
 end)
end
