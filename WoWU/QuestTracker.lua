-- Native Dashboard tracker. Reads the game's watch list, never another addon's frames.
local C=WoWUClient
local function call(fn,...) return C.Call(fn,...) end
local function publicText(value)
 return C.Public(value) and type(value)=="string" and value or nil
end
local function yes(value) return C.Public(value) and (value==true or value==1) end
local function combat() return InCombatLockdown and InCombatLockdown() end
local yellow="|cffffff00"
local green="|cff00ff00"
local white="|cffeeeeee"
local function font(parent,size)
 local text=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 local path="Fonts\\FRIZQT__.TTF"
 -- Honour the same optional shared font used by the previous presentation.
 -- FRIZQT is always available, even when no other addons are installed.
 local media=LibStub and LibStub("LibSharedMedia-3.0",true)
 if media and media.IsValid and media:IsValid("font","2002") then path=media:Fetch("font","2002") end
 text:SetFont(path,size,"")
 text:SetJustifyH("LEFT");text:SetJustifyV("TOP");text:SetWordWrap(true)
 text:SetShadowColor(0,0,0,1);text:SetShadowOffset(1,-1)
 return text
end
local function watchedQuests()
 local result,seen={},{}
 local function add(id,index)
  id=C.Number(id)
  if not id or id<=0 or seen[id] then return end
  index=index or call(WoWUQuestLog and WoWUQuestLog.GetLogIndexForQuestID,id)
  local info=index and call(WoWUQuestLog and WoWUQuestLog.GetInfo,index)
  local title=publicText(call(WoWUQuestLog and WoWUQuestLog.GetTitleForQuestID,id))
  title=title or (info and publicText(info.title))
  if not title and index then title=publicText(call(GetQuestLogTitle,index)) end
  if not title then return end
  seen[id]=true
  result[#result+1]={id=id,index=index,title=title,
   complete=yes(call(WoWUQuestLog and WoWUQuestLog.IsComplete,id)) or (info and yes(info.isComplete)),
   failed=yes(call(WoWUQuestLog and WoWUQuestLog.IsFailed,id))}
 end
 if C.isClassic and WoWUQuestLog and WoWUQuestLog.GetTrackedEntries then
  for _,info in ipairs(call(WoWUQuestLog.GetTrackedEntries)or {})do add(info.questID,info.logIndex)end
 elseif WoWUQuestLog and WoWUQuestLog.GetNumQuestWatches and WoWUQuestLog.GetQuestIDForQuestWatchIndex then
  for i=1,C.Number(call(WoWUQuestLog.GetNumQuestWatches)) or 0 do
   add(call(WoWUQuestLog.GetQuestIDForQuestWatchIndex,i))
  end
 elseif GetNumQuestWatches and GetQuestIndexForWatch then
  for i=1,call(GetNumQuestWatches) or 0 do
   local index=call(GetQuestIndexForWatch,i)
   local _,_,_,_,_,_,_,id=call(GetQuestLogTitle,index)
   add(id,index)
  end
 end
 return result
end
local function objectiveLine(text,finished,fulfilled,required)
 text=publicText(text) or ""
 -- Native objectives commonly put counts last ("Boars slain: 0/4").
 -- The established card presentation puts the counter first.
 local description,current,total=text:match("^(.-):?%s+(%d+)%s*/%s*(%d+)%s*$")
 if description and description~="" then
  description=description:gsub(":%s*$","")
  text=current.."/"..total.." "..description
 end
 if finished then return green.."|TInterface\\RaidFrame\\ReadyCheck-Ready:13:13:0:0|t "..text.."|r" end
 local count=C.Number(fulfilled)
 local goal=C.Number(required)
 local tint=(count and count>0) and yellow or "|cffff3333"
 local replaced
 text,replaced=text:gsub("(%d+)%s*/%s*(%d+)",function(a,b)
  return ((tonumber(a)>0) and yellow or "|cffff3333")..a.."/"..b.."|r"..white
 end,1)
 if replaced==0 and count and goal and goal>0 then
  text=tint..count.."/"..goal.."|r"..white.." "..text
 end
 return white.."- "..text.."|r"
end
local function objectives(quest)
 local lines={}
 local list=call(WoWUQuestLog and WoWUQuestLog.GetQuestObjectives,quest.id)
 if type(list)=="table" then
  for _,objective in ipairs(list) do
   local text=publicText(objective.text) or publicText(objective.description)
   if text and text~="" then
    lines[#lines+1]=objectiveLine(text,yes(objective.finished),objective.numFulfilled,objective.numRequired)
   end
  end
 end
 if #lines==0 and quest.index then
  for i=1,call(GetNumQuestLeaderBoards,quest.index) or 0 do
   local text,_,finished=call(GetQuestLogLeaderBoard,i,quest.index)
   if publicText(text) then lines[#lines+1]=objectiveLine(text,yes(finished)) end
  end
 end
 if #lines==0 then
  local _,instruction
  if WoWUQuestLog and WoWUQuestLog.GetLogText then _,instruction=call(WoWUQuestLog.GetLogText,quest.index)
  else _,instruction=call(GetQuestLogQuestText,quest.index)end
  instruction=publicText(instruction)
  if instruction and instruction~="" then
   lines[1]=objectiveLine(instruction,quest.complete)
  else
   lines[1]=quest.complete and green.."Ready for turn-in|r" or white.."Open quest for details.|r"
  end
 end
 if quest.failed then lines[#lines+1]="|cffff3333Quest failed|r" end
 return table.concat(lines,"\n")
end

function WoWU_BuildQuestTracker(parent)
 local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",0,-48);scroll:SetPoint("BOTTOMRIGHT",-20,6)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(240,1);scroll:SetScrollChild(body)
 WoWU_EnableTouchScroll(scroll)
 local empty=font(body,13);empty:SetPoint("TOPLEFT",6,-9);empty:SetWidth(225)
 empty:SetText("Track a quest in the Quest Journal to display it here.");empty:SetTextColor(.8,.8,.75)
 local rows,dirty={},true
 local menu=CreateFrame("Frame",nil,parent,"BackdropTemplate")
 menu:SetSize(224,217);menu:SetFrameStrata("DIALOG");WoWU_Theme.Panel(menu);menu:Hide()
 local menuTitle=font(menu,14);menuTitle:SetPoint("TOPLEFT",12,-12);menuTitle:SetWidth(200);menuTitle:SetHeight(36)
 local function allowed() return not WoWU_TouchTapAllowed or WoWU_TouchTapAllowed(scroll) end
 local function select(id)
  if combat() then return end
  if WoWU_SelectQuest then WoWU_SelectQuest(id) end
 end
 local function track(id)
  if WoWUNavigation then
   local ok,message=WoWUNavigation.StartQuest(id)
   if not ok and message then print("WoWU: "..message) end
  end
  dirty=true
 end
 local actions={
  {"Open Quest",select},
  {"Navigate",track},
  {"Show on Map",function(id)
   if combat() then return end
   if WoWUMistsQuests then
    local ok,message=WoWUMistsQuests.ShowOnMap(id)
    if not ok and message then print('WoWU: '..message)end
    return
   end
   call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,"Blizzard_QuestLog")
   call(C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID,id)
   if WoWU_ShowPage then WoWU_ShowPage("Map") end
   if WoWUClassicQuestLocation and WoWU_GetActiveMap then
    local m=call(WoWUClassicQuestLocation,id,call(C_Map.GetBestMapForUnit,'player'))
    local map=WoWU_GetActiveMap();if m and map and map.SetMapID then map:SetMapID(m)end
    return
   end
   call(QuestMapFrame_OpenToQuestDetails,id)
  end},
  {"Stop Tracking",function(id)
   if combat() then return end
   if WoWUQuestLog and WoWUQuestLog.RemoveQuestWatch then call(WoWUQuestLog.RemoveQuestWatch,id)
   else call(RemoveQuestWatch,call(GetQuestLogIndexByID,id)) end
   dirty=true
  end},
 }
 for i,action in ipairs(actions) do
  local b=CreateFrame("Button",nil,menu,"BackdropTemplate");b:SetSize(200,32);b:SetPoint("TOPLEFT",12,-48-(i-1)*37)
  b.label=font(b,13);b.label:SetPoint("CENTER");b.label:SetText(action[1]);WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)
  local fn=action[2]
  b:SetScript("OnClick",function()
   if combat() then return end
   local id=menu.questID;menu:Hide();if id then fn(id) end
  end)
 end
 local close=CreateFrame("Button",nil,menu,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",5,5)
 close:SetScript("OnClick",function()if not combat() then menu:Hide() end end)
 -- Keep the secure quest-item action outside the scroll child. Swiping over
 -- cards can never use an item, and rebuilding cards never alters secure attributes.
 local item=CreateFrame("Button",nil,menu,"SecureActionButtonTemplate")
 item:SetSize(200,34);item:SetPoint("TOPLEFT",12,-198);item:RegisterForClicks("AnyUp","AnyDown")
 item.texture=item:CreateTexture(nil,"ARTWORK");item.texture:SetSize(30,30);item.texture:SetPoint("LEFT",0,0)
 item.label=font(item,13);item.label:SetPoint("LEFT",item.texture,"RIGHT",8,0);item.label:SetWidth(155)
 item.label:SetText("Use quest item")
 item:SetScript("OnEnter",function(self)
  if self.link then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.link);GameTooltip:Show() end
 end)
 item:SetScript("OnLeave",function()GameTooltip:Hide()end)
 item:Hide()
 local function openMenu(row)
  if not allowed() or combat() then return end
  if menu:IsShown() and menu.questID==row.questID then menu:Hide();return end
  menu.questID=row.questID;menuTitle:SetText(row.questTitle)
  local link,texture=call(GetQuestLogSpecialItemInfo,row.logIndex)
  item:SetAttribute("type",nil);item:SetAttribute("item",nil);item.link=nil;item:Hide()
  menu:SetHeight(217)
  if publicText(link) and texture then
   item.link=link;item.texture:SetTexture(texture)
   item:SetAttribute("item",link);item:SetAttribute("type","item")
   item:Show();menu:SetHeight(244)
  end
  menu:ClearAllPoints();menu:SetPoint("TOPLEFT",parent,"TOPRIGHT",4,-48);menu:Show()
 end
 local function createRow()
  local row=CreateFrame("Button",nil,body)
  row:RegisterForClicks("LeftButtonUp","RightButtonUp")
  local bg=row:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.018,.026,.03,.98)
  local highlight=row:CreateTexture(nil,"HIGHLIGHT");highlight:SetAllPoints();highlight:SetColorTexture(.8,.65,.2,.08)
  row.title=font(row,15);row.title:SetPoint("TOPLEFT",35,-5)
  row.detail=font(row,13);row.detail:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-1)
  row.icon=CreateFrame("Button",nil,row);row.icon:SetSize(26,26);row.icon:SetPoint("TOPLEFT",5,-5)
  row.activeHalo=row.icon:CreateTexture(nil,"BACKGROUND")
  row.activeHalo:SetPoint("TOPLEFT",-3,3);row.activeHalo:SetPoint("BOTTOMRIGHT",3,-3)
  row.activeHalo:SetColorTexture(1,.8,.12,.65)
  local haloMask=row.icon:CreateMaskTexture()
  haloMask:SetAllPoints(row.activeHalo);haloMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  row.activeHalo:AddMaskTexture(haloMask);row.activeHalo:Hide()
  -- A small circular quest marker, not a square item icon or missing-font glyph.
  local ring=row.icon:CreateTexture(nil,"BACKGROUND")
  ring:SetDrawLayer("BACKGROUND",1);row.ring=ring
  ring:SetAllPoints();ring:SetColorTexture(.8,.63,.02,1)
  local rimMask=row.icon:CreateMaskTexture()
  rimMask:SetAllPoints(ring);rimMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  ring:AddMaskTexture(rimMask)
  local core=row.icon:CreateTexture(nil,"ARTWORK");core:SetPoint("TOPLEFT",2,-2);core:SetPoint("BOTTOMRIGHT",-2,2)
  core:SetColorTexture(.06,.045,.01,1)
  local coreMask=row.icon:CreateMaskTexture()
  coreMask:SetAllPoints(core);coreMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  core:AddMaskTexture(coreMask)
  row.mark=font(row.icon,18);row.mark:SetPoint("CENTER",0,1);row.mark:SetTextColor(1,.85,0)
  row.icon:SetScript("OnClick",function()openMenu(row)end)
  row:SetScript("OnClick",function(self,button)
   if not allowed() then return end
   if button=="RightButton" then openMenu(self)
   elseif not combat() then menu:Hide();track(self.questID) end
  end)
  row:SetScript("OnEnter",function(self)
   if not allowed() then return end
   GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.questTitle)
   GameTooltip:AddLine("Tap to track quest. Tap its marker for actions.",.8,.8,.8,true);GameTooltip:Show()
  end)
  row:SetScript("OnLeave",function()GameTooltip:Hide()end)
  return row
 end
 local function refresh()
  if not parent:IsVisible() or scroll:GetWidth()<50 then return end
  -- Defer rebuilding rows beneath a finger; do not change the tapped quest mid-gesture.
  local gesture=scroll.WoWUGesture
  if gesture and gesture.down then return end
  dirty=false
  local quests=watchedQuests()
  local width=math.max(100,scroll:GetWidth());body:SetWidth(width);empty:SetWidth(width-12)
  local y=0
  for i,quest in ipairs(quests) do
   local row=rows[i]
   if not row then row=createRow();rows[i]=row end
   row.questID=quest.id;row.questTitle=quest.title;row.logIndex=quest.index
   row.title:SetWidth(width-41);row.detail:SetWidth(width-41)
   row.title:SetText((quest.complete and green or yellow)..quest.title.."|r")
   row.detail:SetText(objectives(quest))
   row.mark:SetText(quest.complete and "?"or WoWUMistsQuests and WoWUMistsQuests.Number(quest.id)or "...")
   local height=math.max(39,row.title:GetStringHeight()+row.detail:GetStringHeight()+12)
   row:SetSize(width,height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:Show()
   y=y+height+6
  end
  for i=#quests+1,#rows do rows[i]:Hide() end
  empty:SetShown(#quests==0)
  body:SetHeight(math.max(y,60))
  scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
  if menu:IsShown() then
   local found=false
   for _,quest in ipairs(quests) do if quest.id==menu.questID then found=true end end
   if not found and not combat() then menu:Hide() end
  end
 end
 local function highlightActive()
  local state=WoWUNavigation and WoWUNavigation.State()
  local active=state and state.active
  local id
  if WoWUMistsQuests then id=WoWUMistsQuests.ActiveQuest()end
  if not WoWUMistsQuests and not (state and state.stopped) then
   if active then
    if active.kind=="quest" then id=active.questID end
   else id=C.Number(call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)) end
  end
  for _,row in ipairs(rows) do
   local selected=id and id>0 and row.questID==id
   row.activeHalo:SetShown(not not selected)
   if selected then
    row.ring:SetColorTexture(1,.95,.45,1);row.mark:SetTextColor(1,1,.75)
   else
    row.ring:SetColorTexture(.8,.63,.02,1);row.mark:SetTextColor(1,.85,0)
   end
  end
 end
 local elapsed,watchRevision=0,nil
 parent:HookScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt
  if elapsed>=.1 then
   elapsed=0
   local revision=WoWUQuestLog and WoWUQuestLog.watchRevision
   if revision~=watchRevision then watchRevision=revision;dirty=true end
   if dirty then
    local ok,err=pcall(refresh)
    if not ok then
     dirty=false;empty:SetText('Quest tracker could not update. Use /wowuclassicdebug for details.');empty:Show()
     if WoWUDB then WoWUDB.classicTrackerError=tostring(err)end
    elseif WoWUDB then WoWUDB.classicTrackerError=nil end
   end
   highlightActive()
  end
 end)
 scroll:HookScript("OnSizeChanged",function()dirty=true end)
 parent:HookScript("OnShow",function()dirty=true end)
 parent:HookScript("OnHide",function()if not combat() then menu:Hide() end end)
 local events=CreateFrame("Frame",nil,parent)
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","QUEST_WATCH_LIST_CHANGED",
  "QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","SUPER_TRACKING_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do
  pcall(events.RegisterEvent,events,event)
 end
 events:SetScript("OnEvent",function(_,event)
  dirty=true
  if event=="PLAYER_REGEN_ENABLED" then menu:Hide() end
 end)
 dirty=true
 return {Refresh=function()dirty=true end,scroll=scroll,
  Close=function()if not combat()then menu:Hide()end end}
end
