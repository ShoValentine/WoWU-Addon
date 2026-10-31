if WoWUClient.classicMajor~=5 then return end
local U=WoWUMistsUI
local P=C_PvP or {}
local function combat()return InCombatLockdown()or UnitIsDeadOrGhost("player")end
local function leader()return UnitIsGroupLeader("player")end
local function request(fn,...)
 if type(fn)~="function"then return false,"This action is unavailable in this client."end
 local ok,result=pcall(fn,...)
 if not ok then return false,tostring(result)end
 if result==false then return false,"The game declined this request."end
 return true
end
function WoWU_CreateMistsPVP(parent,back,premades)
 local root=U.Panel(parent);root:SetAllPoints();root:SetFrameLevel(parent:GetFrameLevel()+25);root:Hide()
 local mode="Casual";local selected,rows,notice=nil,{},nil;local dirty=true;local refresh,details
 local title=U.Text(root,26);title:SetPoint("TOPLEFT",22,-18);title:SetText("Dungeon Finder - Player vs. Player")
 local exit=U.Button(root,120,"Back",back);exit:SetPoint("TOPRIGHT",-22,-15)
 local status=U.Message(root)
 local tabs={}
 for i,name in ipairs({"Casual","Rated","War Games","Queues"})do
  local value=name;local b=U.Button(root,160,name,function()mode=value;selected=nil;notice=nil;dirty=true end);b:SetPoint("TOPLEFT",22+(i-1)*170,-63);tabs[name]=b
 end
 local find=U.Button(root,220,"PvP premade groups",premades);find:SetPoint("TOPLEFT",702,-63)
 local roles={false,false,true};local roleButtons={}
 for i,name in ipairs({"Tank","Healer","Damage"})do
  local role=i;local b=U.Button(root,184,name,function()roles[role]=not roles[role];dirty=true end)
  b:SetSize(184,70);b:SetPoint("TOPLEFT",22+(i-1)*198,-112);b.label:SetFont("Fonts\\FRIZQT__.TTF",19,"");roleButtons[i]=b
 end
 local currency=U.Text(root,16);currency:SetPoint("TOPRIGHT",-22,-125);currency:SetWidth(540);currency:SetJustifyH("RIGHT")
 local left=U.Panel(root);left:SetPoint("TOPLEFT",16,-202);left:SetPoint("BOTTOMLEFT",16,45);left:SetWidth(570)
 local list=U.List(left);list:SetPoint("TOPLEFT",8,-8);list:SetPoint("BOTTOMRIGHT",-30,8);list.rowHeight=82
 local right=U.Panel(root);right:SetPoint("TOPLEFT",left,"TOPRIGHT",12,0);right:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-16,45)
 local heading=U.Text(right,25);heading:SetPoint("TOPLEFT",22,-22);heading:SetPoint("TOPRIGHT",-22,-22);heading:SetHeight(65)
 local scroll,body=U.Scroll(right);scroll:SetPoint("TOPLEFT",22,-100);scroll:SetPoint("BOTTOMRIGHT",-32,210)
 local info=U.Text(body,17);info:SetPoint("TOPLEFT");info:SetPoint("TOPRIGHT",-8,0);info:SetWordWrap(true)
 local function button(text,y)
  local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate");b:SetPoint("BOTTOMLEFT",22,y);b:SetPoint("BOTTOMRIGHT",-22,y);b:SetHeight(52);b:SetText(text);b:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",18,"");return b
 end
 local solo=button("Join battle",142);local group=button("Join as group",80);local manage=button("View queues",18)
 local function say(ok,why)notice=ok and "Request sent. The game's queue status will confirm it."or (why or "Request failed.");dirty=true end
 local function selectedRow()for _,d in ipairs(rows)do if d.id==selected then return d end end end
 local function canRated(d)
  if not d or combat()or not leader()or (UnitLevel("player")or 0)<(SHOW_CONQUEST_LEVEL or 90)then return false,"Requires an eligible group leader at the rated PvP level."end
  if U.Call(GetCurrentArenaSeason)==NO_ARENA_SEASON then return false,"There is no active arena season."end
  local size=GetNumGroupMembers()
  if size~=d.size then return false,"Requires exactly "..d.size.." players in your group."end
  local token=IsInRaid()and "raid"or "party"
  for i=1,(token=="raid"and size or size-1)do if not UnitIsConnected(token..i)then return false,"All group members must be connected."end end
  return true
 end
 local function canWar(d)
  if not d or combat()then return false,"Choose a War Game."end
  if not leader()then return false,"You must lead your group."end
  if not U.Call(UnitLeadsAnyGroup,"target")or UnitIsUnit("player","target")then return false,"Target the leader of the opposing group."end
  local n=GetNumGroupMembers()
  if d.arena then if n~=2 and n~=3 and n~=5 then return false,"Arena War Games require a group of 2, 3 or 5."end
  elseif n<(d.min or 1)or n>(d.size or 40)then return false,"Your group must contain "..(d.min or 1).." - "..(d.size or 40).." players."end
  return true
 end
 local function queue(d,asGroup)
  if combat()or not d or not d.bgID or not d.canQueue then return end
  if asGroup and not leader()then return end
  if not asGroup and IsInGroup()then notice="Leave your group to queue solo, or use Join as group.";dirty=true;return end
  if not (roles[1]or roles[2]or roles[3])then notice="Select at least one available role.";dirty=true;return end
  local ok,why=request(SetPVPRoles,roles[1],roles[2],roles[3]);if not ok then say(ok,why);return end
  if d.world then say(request(JoinWorldPVPQueue,false,asGroup,d.bgID))else say(request(P.JoinBattlefield or JoinBattlefield,d.bgID,asGroup))end
 end
 solo:SetScript("OnClick",function()
  local d=selectedRow();if not d or combat()then return end
  if mode=="Casual"then queue(d,false)
  elseif mode=="Rated"then if canRated(d)then say(request(d.ratedBG and JoinRatedBattlefield or JoinArena))end
  elseif mode=="War Games"then if canWar(d)then say(request(StartWarGame,"target",d.name))end
  elseif mode=="Queues"then local state=U.Call(GetBattlefieldStatus,d.slot);if state=="confirm"then say(request(AcceptBattlefieldPort,d.slot,true))end end
 end)
 group:SetScript("OnClick",function()
  local d=selectedRow();if not d or combat()then return end
  if mode=="Casual"then queue(d,true)
  elseif mode=="Queues"then local state=U.Call(GetBattlefieldStatus,d.slot);if state=="queued"or state=="confirm"then say(request(AcceptBattlefieldPort,d.slot,false))end end
 end)
 manage:SetScript("OnClick",function()mode="Queues";selected=nil;dirty=true end)
 details=function()
  local d=selectedRow();solo:Disable();group:Hide();solo:Show();manage:SetShown(mode~="Queues")
  heading:SetText(d and d.name or "Choose an activity")
  local text="Choose an activity on the left. Queue restrictions are enforced by the game."
  if mode=="Casual"then
   solo:SetText("Join battle");group:SetText("Join as group");group:Show()
   if d then text=(d.description or "").."\n\n"..(d.size and (d.size.." vs "..d.size.."\n")or "")..(d.gameType or "")..(d.min and ("\nMinimum level: "..d.min)or "")..(d.canQueue and ""or "\n\nThis activity is currently unavailable for your character.")end
   local ready=d and d.canQueue and not combat()and (roles[1]or roles[2]or roles[3])
   solo:SetEnabled(ready and not IsInGroup());group:SetEnabled(ready and leader())
  elseif mode=="Rated"then
   solo:SetText("Join rated queue")
   if d then local ok,reason=canRated(d);solo:SetEnabled(ok);text="Rated "..d.size.."-player team\n\nCurrent rating: "..(d.rating or 0).."\nSeason best: "..(d.best or 0).."\nSeason wins: "..(d.wins or 0).."\n\n"..(reason or "Your group meets the basic size and leadership requirements. The game checks remaining eligibility on joining.")end
  elseif mode=="War Games"then
   solo:SetText("Challenge target")
   if d then local ok,reason=canWar(d);solo:SetEnabled(ok);text="Private match - no public queue.\n\n"..(d.arena and "Arena group sizes: 2, 3 or 5"or ("Group size: "..(d.min or 1).." - "..(d.size or 40))).."\n\n"..(reason or "Ready to challenge the targeted opposing leader.")end
  else
   solo:SetText("Enter battle");group:SetText("Leave queue / decline");group:Show()
   if d then text="Queue status: "..d.state.."\n\nEnter battle becomes available when your invitation arrives. Leaving a queue or declining an invitation is an explicit action.";solo:SetEnabled(not combat()and d.state=="confirm");group:SetEnabled(not combat()and (d.state=="queued"or d.state=="confirm"))end
  end
  info:SetText(text);body:SetHeight(math.max(1,info:GetStringHeight()+14));scroll:SetVerticalScroll(0)
 end
 refresh=function()
  if not root:IsVisible()then return end;dirty=false;rows={}
  for name,b in pairs(tabs)do WoWU_Theme.Tab(b,mode==name);b:SetEnabled(not combat())end
  local t,h,d=U.Call(UnitGetAvailableRoles,"player")
  if C_LFGList and C_LFGList.GetAvailableRoles then t,h,d=U.Call(C_LFGList.GetAvailableRoles)end
  for i,b in ipairs(roleButtons)do local available=({t,h,d})[i]==true;if not available then roles[i]=false end;b:SetShown(mode=="Casual");b:SetEnabled(available and not combat());WoWU_Theme.Tab(b,roles[i])end
  if mode=="Casual"then
   local seen={}
   local function bonus(data,name,world,overrideID)
    local id=overrideID or (data and data.bgID)
    if not data or not id or seen[id]then return end;seen[id]=true
    rows[#rows+1]={id="bg"..id,bgID=id,name=name or data.name or "Battleground",sub=world and "World PvP"or "Bonus battleground",queue=true,canQueue=data.canQueue and (not world or data.isActive),world=world,min=data.minLevel,description=data.name}
   end
   bonus(U.Call(P.GetRandomBGInfo),"Random Battleground")
   local holiday=U.Call(P.GetHolidayBGInfo);if holiday and holiday.bgID then bonus(holiday,"Call to Arms: "..(holiday.name or "Battleground"))end
   for i=1,(U.Call(GetNumBattlegroundTypes)or 0)do
    local name,canEnter,_,random,id,description,_,size,kind,_,_,_,world=U.Call(GetBattlegroundInfo,i)
    if name and id and not seen[id]then
     if world and world>0 then bonus(U.Call(P.GetWorldPVPAreaInfo,i),name,true,id)
     elseif not random then seen[id]=true;rows[#rows+1]={id="bg"..id,bgID=id,name=name,description=description,size=size,gameType=kind,queue=true,sub=(size and size.." vs "..size.." / "or "")..(kind or "Battleground")..(canEnter and ""or " / Locked"),canQueue=canEnter}end
    end
   end
  elseif mode=="Rated"then
   for i,size in ipairs({2,3,5,10})do local rating,best,_,_,wins=U.Call(GetPersonalRatedInfo,i);rows[#rows+1]={id=i,name=i==4 and "Rated Battleground"or (size.." vs "..size.." Arena"),size=size,ratedBG=i==4,rating=rating,best=best,wins=wins,queue=true,sub="Rating: "..(rating or 0).." / Group of "..size}end
  elseif mode=="War Games"then
   for i=1,(U.Call(GetNumWarGameTypes)or 0)do local name,kind,collapsed,id,min,max,_,icon=U.Call(GetWarGameTypeInfo,i);if name=="header"then rows[#rows+1]={id="header"..i,name=kind==INSTANCE_TYPE_ARENA and "Arenas"or "Battlegrounds",header=i,collapsed=collapsed,sub=collapsed and "Tap to expand"or "Tap to collapse"}elseif name then rows[#rows+1]={id=id or i,name=name,index=i,min=min,size=max,arena=kind==INSTANCE_TYPE_ARENA,queue=true,sub=kind==INSTANCE_TYPE_ARENA and "Private arena match"or "Private battleground match"}end end
  else
   for i=1,(U.Call(GetMaxBattlefieldID)or MAX_BATTLEFIELD_QUEUES or 3)do local state,name=U.Call(GetBattlefieldStatus,i);if state and state~="none"then rows[#rows+1]={id=i,slot=i,name=name or "PvP queue",state=state,queue=true,sub=state=="confirm"and "Invitation ready - select to enter"or state}end end
  end
  local data=rows;if #data==0 then data={{name="No entries available",sub=mode=="Queues"and "You are not queued for PvP."or "Activity availability depends on the client and your character."}}end
  list:SetData(data,function(row)if row.header then if not combat()then U.Call(row.collapsed and ExpandWarGameHeader or CollapseWarGameHeader,row.header);selected=nil;dirty=true end elseif row.id then selected=row.id;details()end end,selected);details()
  local function balance(id)local c=U.Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,id);return c and c.quantity or 0 end
  currency:SetText("Honor: "..balance(392).."   /   Conquest: "..balance(390))
  status:SetText(notice or (combat()and "PvP actions are unavailable during combat."or "Select your activity. Match invitations also appear in Queues."))
 end
 root:SetScript("OnShow",function()
  local ok,why=U.Load("Blizzard_PVPUI");if not ok then status:SetText(why);return end
  local t,h,d=U.Call(GetPVPRoles);if t~=nil then roles={t,h,d}end
  U.Call(RequestRandomBattlegroundInstanceInfo);U.Call(RequestRatedInfo);U.Call(RequestPVPOptionsEnabled);U.Call(UpdateWarGamesList);dirty=true;refresh()
 end)
 local e=CreateFrame("Frame",nil,root)
 for _,event in ipairs({"UPDATE_BATTLEFIELD_STATUS","BATTLEFIELDS_SHOW","PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE","PVP_RATED_STATS_UPDATE","PVP_ROLE_UPDATE","CURRENCY_DISPLAY_UPDATE","GROUP_ROSTER_UPDATE","PLAYER_TARGET_CHANGED","PLAYER_FLAGS_CHANGED","PLAYER_LEVEL_UP","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"})do U.Call(e.RegisterEvent,e,event)end
 e:SetScript("OnEvent",function()dirty=true end)
 local elapsed=0;root:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>.3 then elapsed=0;if dirty then refresh()end end end)
 return root
end
