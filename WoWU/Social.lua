-- WoWU Social: private UI, session-only chat history and explicit user actions.
local S={rooms={},order={},dirty=true,unread=0};WoWUSocial=S
local function call(fn,...)
 if type(fn)~="function" then return end
 local ok,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q=pcall(fn,...)
 if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q end
end
local function plain(value)
 if issecretvalue and issecretvalue(value) then return "" end
 return type(value)=="string" and value or ""
end
local function preferences()
 WoWUDB=WoWUDB or {};WoWUDB.social=WoWUDB.social or {}
 local key=UnitGUID("player") or "player";WoWUDB.social[key]=WoWUDB.social[key] or {favorites={}}
 local s=WoWUDB.social[key];s.favorites=s.favorites or {};return s
end
local function room(kind,target,title)
 local key=kind..":"..string.lower(tostring(target or ""))
 if not S.rooms[key] then
  -- Bound session history without evicting the conversation currently on screen.
  if #S.order>=60 then
   for i,id in ipairs(S.order) do if id~=S.openKey then table.remove(S.order,i);S.rooms[id]=nil;break end end
  end
  S.rooms[key]={key=key,kind=kind,target=target,title=title or target or kind,lines={},unread=0};S.order[#S.order+1]=key
 end
 local r=S.rooms[key];r.title=title or r.title;return r
end
local chatEvents={CHAT_MSG_WHISPER="WHISPER",CHAT_MSG_WHISPER_INFORM="WHISPER",CHAT_MSG_BN_WHISPER="BN_WHISPER",CHAT_MSG_BN_WHISPER_INFORM="BN_WHISPER",CHAT_MSG_GUILD="GUILD",CHAT_MSG_OFFICER="OFFICER",CHAT_MSG_PARTY="PARTY",CHAT_MSG_PARTY_LEADER="PARTY",CHAT_MSG_RAID="RAID",CHAT_MSG_RAID_LEADER="RAID",CHAT_MSG_RAID_WARNING="RAID",CHAT_MSG_INSTANCE_CHAT="INSTANCE_CHAT",CHAT_MSG_INSTANCE_CHAT_LEADER="INSTANCE_CHAT",CHAT_MSG_SAY="SAY",CHAT_MSG_YELL="YELL",CHAT_MSG_CHANNEL="CHANNEL"}
local labels={GUILD="Guild",OFFICER="Officers",PARTY="Party",RAID="Raid",INSTANCE_CHAT="Instance",SAY="Say",YELL="Yell"}
local function recount()
 local total=0;for _,r in pairs(S.rooms)do total=total+r.unread end;S.unread=total
end
local events=CreateFrame("Frame")
for event in pairs(chatEvents)do events:RegisterEvent(event)end
for _,event in ipairs({"FRIENDLIST_UPDATE","BN_FRIEND_LIST_SIZE_CHANGED","BN_FRIEND_INFO_CHANGED","BN_FRIEND_INVITE_ADDED","BN_FRIEND_INVITE_REMOVED","BN_CONNECTED","BN_DISCONNECTED","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GROUP_ROSTER_UPDATE","IGNORELIST_UPDATE","CHANNEL_UI_UPDATE","PLAYER_ENTERING_WORLD","CHAT_MSG_SYSTEM","CHAT_MSG_WHISPER_PLAYER_OFFLINE","CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE","CHAT_MSG_RESTRICTED"})do pcall(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function(_,event,...)
 S.dirty=true
 local kind=chatEvents[event]
 if not kind then
  if event:find("CHAT_MSG",1,true) then S.feedback=plain((...)) end
  return
 end
 local args={...};local message,sender=plain(args[1]),plain(args[2]);if message=="" then return end
 local target,title
 if kind=="WHISPER" then target=sender;title=sender
 elseif kind=="BN_WHISPER" then
  local id=args[13];if issecretvalue and issecretvalue(id) then return end
  if type(id)~="number" or id==0 then return end
  target=id;title=sender
 elseif kind=="CHANNEL" then target=plain(args[9]);if target=="" then target=plain(args[4])end;title=target
 else title=labels[kind] end
 local r=room(kind,target,title)
 local outgoing=event:find("_INFORM",1,true)~=nil or sender==UnitName("player") or sender==GetUnitName("player",true)
 r.lines[#r.lines+1]={text=message,who=outgoing and "You" or sender,at=date("%H:%M"),mine=outgoing}
 while #r.lines>200 do table.remove(r.lines,1)end
 r.updated=GetTime()
 if S.visible and S.openKey==r.key then r.unread=0 elseif not outgoing then r.unread=r.unread+1 end
 recount()
end)
local function text(parent,value,size)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal");t:SetFont("Fonts\\FRIZQT__.TTF",size or 13,"");WoWU_Theme.TextColor(t,.96,.84,.60);t:SetText(value or "");t:SetJustifyH("LEFT");return t
end
local function button(parent,caption,w,fn)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(w or 120,34);b.label=text(b,caption,13);b.label:SetPoint("CENTER");WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",fn);return b
end
local function edit(parent,w,h)
 local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");e:SetSize(w,h or 32);e:SetAutoFocus(false);e:SetFontObject("ChatFontNormal");e:SetMaxLetters(255);e:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);return e
end
local function panel(parent)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");WoWU_Theme.Panel(f);return f
end
function WoWU_CreateSocial(parent,onBack)
 local view=CreateFrame("Frame",nil,parent);view:SetAllPoints();view:Hide()
 local heading=text(view,"Social",22);heading:SetPoint("TOPLEFT",20,-15)
 local status=text(view,"",12);status:SetPoint("BOTTOMLEFT",22,12);status:SetWidth(1100);status:SetHeight(26)
 local function notice(msg)status:SetText(msg or "")end
 local function action(fn,...)
  if type(fn)~="function" then notice("This action isn't available on this client.");return false end
  local ok,result=pcall(fn,...)
  if not ok or result==false then notice("The game could not complete that action. Check permissions or Blizzard's message.");return false end
  notice("Request sent to the game.");S.dirty=true;return true
 end
 local back=button(view,"Back to More",145,onBack);back:SetPoint("TOPRIGHT",-16,-9);back:Hide()
 local left=panel(view);left:SetPoint("TOPLEFT",14,-94);left:SetPoint("BOTTOMLEFT",14,48);left:SetWidth(350)
 local right=panel(view);right:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0);right:SetPoint("BOTTOMRIGHT",-14,48)
 local section="Friends";local selected;local refresh,drawConversation,showContact,keyboardLayout
 local tabs={}
 for i,name in ipairs({"Friends","Guild","Conversations","Group","Requests","Ignored"})do
  local tabName=name;local b=button(view,name,156,function() section=tabName;selected=nil;S.openKey=nil;refresh(true)end)
  b:SetPoint("TOPLEFT",16+(i-1)*164,-51);tabs[name]=b
 end
 local search=edit(left,220);search:SetPoint("TOPLEFT",14,-12)
 local online=CreateFrame("CheckButton",nil,left,"UICheckButtonTemplate");online:SetSize(26,26);online:SetPoint("TOPRIGHT",-79,-14)
 local onlineLabel=text(left,"Online",12);onlineLabel:SetPoint("LEFT",online,"RIGHT",2,0)
 online:SetScript("OnClick",function()refresh(true)end)
 local listScroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate");listScroll:SetPoint("TOPLEFT",9,-57);listScroll:SetPoint("BOTTOMRIGHT",-30,55)
 local listBody=CreateFrame("Frame",nil,listScroll);listBody:SetSize(305,1);listScroll:SetScrollChild(listBody);WoWU_EnableTouchScroll(listScroll);WoWU_Theme.Scrollbar(listScroll)
 local rows={}
 local manualRefresh=button(left,"Refresh",125,function()call(C_FriendList and C_FriendList.ShowFriends);call(C_GuildInfo and C_GuildInfo.GuildRoster);S.dirty=true;refresh()end);manualRefresh:SetPoint("BOTTOMLEFT",12,10)
 local listCount=text(left,"",12);listCount:SetPoint("BOTTOMRIGHT",-14,20)
 local title=text(right,"Welcome to Social",19);title:SetPoint("TOPLEFT",18,-15);title:SetWidth(760)
 local detail=text(right,"Select a friend, guild member or conversation.",13);detail:SetPoint("TOPLEFT",18,-46);detail:SetWidth(740);detail:SetHeight(68);detail:SetWordWrap(true);detail:SetJustifyV("TOP")
 local controls={}
 local function control(caption,fn)
  local b=button(right,caption,144,fn);controls[#controls+1]=b
  local i=#controls;b:SetPoint("TOPLEFT",18+((i-1)%5)*151,-124-math.floor((i-1)/5)*42);return b
 end
 local function currentRoom()return S.openKey and S.rooms[S.openKey]end
 local function openRoom(r)
  S.openKey=r.key;r.unread=0;recount();section="Conversations";selected=nil;refresh(true)
 end
 local function whisper()
  if not selected then return end
  if selected.bn then openRoom(room("BN_WHISPER",selected.bn,selected.name))
  elseif selected.name then openRoom(room("WHISPER",selected.name,selected.name)) end
 end
 local whisperButton=control("Whisper",whisper)
 local inviteButton=control("Invite to party",function()
  if not selected then return end
  if selected.gameID then action(C_BattleNet and C_BattleNet.InviteFriend,selected.gameID)
  elseif selected.bn then notice("No compatible game character is available to invite.")
  else action(C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit,selected.name)end
 end)
 local favoriteButton=control("Favourite",function()if selected then local fav=preferences().favorites;fav[selected.key]=not fav[selected.key];refresh()end end)
 local noteButton=control("Edit note",function()end)
 local removeButton=control("Remove friend",function()end)
 local guildInvite=control("Invite to guild",function()if selected and call(CanGuildInvite)then action(C_GuildInfo and C_GuildInfo.Invite,selected.name)end end)
 local promote=control("Promote",function()if selected then action(C_GuildInfo and C_GuildInfo.Promote,selected.name)end end)
 local demote=control("Demote",function()if selected then action(C_GuildInfo and C_GuildInfo.Demote,selected.name)end end)
 local leader=control("Make leader",function()if selected then action(C_PartyInfo and C_PartyInfo.PromoteToLeader,selected.name)end end)
 local kick=control("Remove member",function()end)
 -- Editors and confirmations stay within WoWU; no native social panels are opened.
 local dialog=panel(view);dialog:SetSize(540,185);dialog:SetPoint("CENTER");dialog:SetFrameLevel(view:GetFrameLevel()+100);dialog:EnableMouse(true);dialog:Hide()
 local prompt=text(dialog,"",15);prompt:SetPoint("TOPLEFT",18,-17);prompt:SetWidth(502);prompt:SetHeight(52);prompt:SetWordWrap(true)
 local input=edit(dialog,480);input:SetPoint("TOPLEFT",25,-81)
 local accept=button(dialog,"Confirm",150,function()end);accept:SetPoint("BOTTOMRIGHT",-18,16)
 local cancel=button(dialog,"Cancel",130,function()dialog:Hide()end);cancel:SetPoint("RIGHT",accept,"LEFT",-10,0)
 local function ask(caption,value,fn,noInput)
  prompt:SetText(caption);input:SetText(value or "");input:SetShown(not noInput)
  accept:SetScript("OnClick",function()local value=input:GetText();input:ClearFocus();dialog:Hide();fn(value)end)
  dialog:Show();if not noInput then input:SetFocus()end
 end
 noteButton:SetScript("OnClick",function()
  local c=selected;if not c then return end
  ask("Note for "..c.name,c.note,function(value)
   if c.guild then
    if not call(CanEditPublicNote)then notice("Your guild rank cannot edit public notes.");return end
    action(C_GuildInfo and C_GuildInfo.SetNote,c.guid,value,true)
   elseif c.bn then action(BNSetFriendNote,c.bn,value)
   else action(C_FriendList and C_FriendList.SetFriendNotes,c.name,value)end
  end)
 end)
 removeButton:SetScript("OnClick",function()
  local c=selected;if not c then return end
  ask("Remove "..c.name.." from your friends?",nil,function()
   if c.bn then action(BNRemoveFriend,c.bn)else action(C_FriendList and C_FriendList.RemoveFriend,c.name)end
   selected=nil;refresh()
  end,true)
 end)
 kick:SetScript("OnClick",function()
  local c=selected;if not c then return end
  ask("Remove "..c.name..(c.guild and " from the guild?" or " from the group?"),nil,function()
   if c.guild and c.guid and call(CanGuildRemove) then action(C_GuildInfo and C_GuildInfo.RemoveFromGuild,c.guid)
   elseif not c.guild and UnitIsGroupLeader("player")then action(C_PartyInfo and C_PartyInfo.UninviteUnit,c.name)end
  end,true)
 end)
 local toolbar={}
 local function tool(caption,fn)
  local b=button(right,caption,150,fn);toolbar[#toolbar+1]=b;b:SetPoint("BOTTOMLEFT",16+(#toolbar-1)*158,14);return b
 end
 local addFriend=tool("Add friend",function()ask("Enter a character name (Name-Realm if needed)","",function(value)
  value=value:match("^%s*(.-)%s*$");if value=="" then return end
  if call(C_FriendList and C_FriendList.IsLegacyFriendSystemEnabled)==false then action(C_BattleNet and C_BattleNet.SendTitleFriendInviteByName,value)
  else action(C_FriendList and C_FriendList.AddFriend,value)end
 end)end)
 local guildChat=tool("Guild chat",function()openRoom(room("GUILD",nil,"Guild"))end)
 local ready=tool("Ready check",function()action(C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck)end)
 local leave=tool("Leave group",function()ask("Leave your current group?",nil,function()action(C_PartyInfo and C_PartyInfo.LeaveParty or LeaveParty)end,true)end)
 local acceptInvite=tool("Accept request",function()local c=selected;if c and c.invite then action(BNAcceptFriendInvite,c.invite)end end)
 local declineInvite=tool("Decline request",function()local c=selected;if c and c.invite then action(BNDeclineFriendInvite,c.invite)end end)
 local unignore=tool("Unignore",function()local c=selected;if c then ask("Stop ignoring "..c.name.."?",nil,function()action(C_FriendList and C_FriendList.DelIgnore,c.name)end,true)end end)
 local ignore=tool("Ignore player",function()ask("Enter the character name to ignore","",function(value)if value~=""then action(C_FriendList and C_FriendList.AddIgnore,value)end end)end)
 local editMOTD=tool("Edit guild MOTD",function()
  if not call(CanEditMOTD)then return end
  ask("Guild message of the day",call(C_GuildInfo and C_GuildInfo.GetMOTD),function(value)
   if call(CanEditMOTD)then action(C_GuildInfo and C_GuildInfo.SetMOTD,value)end
  end)
 end)
 local officerNote=tool("Officer note",function()
  local c=selected;if not c or not c.guid or not call(C_GuildInfo and C_GuildInfo.CanEditOfficerNote)then return end
  ask("Officer note for "..c.name,c.officerNote,function(value)
   if call(C_GuildInfo and C_GuildInfo.CanEditOfficerNote)then action(C_GuildInfo.SetNote,c.guid,value,false)end
  end)
 end)
 local newWhisper=tool("New whisper",function()ask("Whisper which character?","",function(value)if value~=""then openRoom(room("WHISPER",value,value))end end)end)
 -- Conversation area uses a regular scroll child, allowing wheel and touch scrolling.
 local chatScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate");chatScroll:SetPoint("TOPLEFT",16,-119);chatScroll:SetPoint("BOTTOMRIGHT",-34,145)
 local chatBody=CreateFrame("Frame",nil,chatScroll);chatBody:SetSize(730,1);chatScroll:SetScrollChild(chatBody);WoWU_EnableTouchScroll(chatScroll);WoWU_Theme.Scrollbar(chatScroll)
 local messages={};local renderedKey,renderedLast
 local composer=edit(right,570,36);composer:SetPoint("BOTTOMLEFT",24,94);composer:SetMaxBytes(255)
 local composeKey,loadingDraft
 composer:SetScript("OnTextChanged",function(self)
  if not loadingDraft and composeKey and S.rooms[composeKey] then S.rooms[composeKey].draft=self:GetText() end
 end)
 local send=button(right,"Send",125,function()end);send:SetPoint("LEFT",composer,"RIGHT",14,0)
 local quick={}
 for i,caption in ipairs({"Hello!","Thank you!","On my way.","One moment, please."})do
  local value=caption;local b=button(right,caption,160,function()composer:SetText(value);composer:SetFocus()end);b:SetPoint("BOTTOMLEFT",18+(i-1)*170,52);quick[i]=b
 end
 local function sendMessage()
  local r=currentRoom();local value=composer:GetText();if not r or composeKey~=r.key or not value:find("%S")then return end
  local ok
  if r.kind=="BN_WHISPER"then ok=action(C_BattleNet and C_BattleNet.SendWhisper or BNSendWhisper,r.target,value)
  else
   local target=r.target
   if r.kind=="CHANNEL"then
    local id=call(GetChannelName,r.target)
    if not id or id==0 then notice("You are no longer in this channel.");return end
    target=tostring(id)
   elseif r.kind=="GUILD" and not IsInGuild()then notice("You are not in a guild.");return
   elseif r.kind=="PARTY" and not IsInGroup()then notice("You are not in a party.");return
   elseif r.kind=="RAID" and not IsInRaid()then notice("You are not in a raid.");return end
   ok=action(C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage,value,r.kind,nil,target)
  end
  if ok then composer:SetText("");composer:ClearFocus();notice("Message submitted. Delivery appears in the conversation or Blizzard's chat feedback.")end
 end
 send:SetScript("OnClick",sendMessage);composer:SetScript("OnEnterPressed",sendMessage)
 local function roster()
  local result={}
  if section=="Friends"then
   for i=1,(call(C_FriendList and C_FriendList.GetNumFriends) or 0)do
    local f=call(C_FriendList.GetFriendInfoByIndex,i)
    if f and plain(f.name)~=""then result[#result+1]={key="wow:"..f.name,name=f.name,online=f.connected,note=f.notes,info=(f.connected and "Online" or "Offline").." | "..(f.className or "").." "..(f.level or "").."\n"..(f.area or "")}end
   end
   for i=1,(call(BNGetNumFriends) or 0)do
    local f=call(C_BattleNet and C_BattleNet.GetFriendAccountInfo,i)
    if f then local g=f.gameAccountInfo or {};local bn=f.bnetAccountID
     if bn then result[#result+1]={key="bn:"..bn,bn=bn,gameID=g.gameAccountID,name=plain(f.battleTag)~="" and f.battleTag or plain(f.accountName),online=g.isOnline,note=f.note,info=(g.isOnline and "Online" or "Offline")..(f.isAFK and " | Away" or f.isDND and " | Busy" or "").."\n"..(g.characterName or "").." | "..(g.areaName or g.richPresence or g.clientProgram or "Battle.net")}end
    end
   end
  elseif section=="Guild"then
   for i=1,(call(GetNumGuildMembers) or 0)do
    local n,rank,_,level,class,zone,note,officer,connected,_,_,_,_,_,_,_,guid=call(GetGuildRosterInfo,i)
    if n then result[#result+1]={key="guild:"..n,name=n,guild=true,guid=guid,online=connected,note=note,officerNote=call(C_GuildInfo and C_GuildInfo.CanViewOfficerNote) and officer or nil,info=(rank or "").." | "..(class or "").." "..(level or "").."\n"..(connected and (zone or "Online") or "Offline")}end
   end
  elseif section=="Group"then
   local raid=IsInRaid();local count=raid and GetNumGroupMembers() or GetNumSubgroupMembers()
   for i=0,count do
    local unit=i==0 and "player" or (raid and "raid"..i or "party"..i)
    if UnitExists(unit) and not (raid and i==0)then
     local n=GetUnitName(unit,true);local class=UnitClass(unit);result[#result+1]={key="group:"..n,name=n,unit=unit,online=UnitIsConnected(unit),info=(UnitIsGroupLeader(unit)and "Leader | " or "")..(class or "").." | "..(UnitGroupRolesAssigned(unit)or "")}
    end
   end
  elseif section=="Requests"then
   for i=1,(call(BNGetNumFriendInvites)or 0)do local f=call(C_BattleNet and C_BattleNet.GetFriendInviteInfo,i);if f then result[#result+1]={key="invite:"..f.inviteID,name=plain(f.accountName),invite=f.inviteID,info="Pending friend request"}end end
  elseif section=="Ignored"then
   for i=1,(call(C_FriendList and C_FriendList.GetNumIgnores)or 0)do local n=call(C_FriendList.GetIgnoreName,i);if n then result[#result+1]={key="ignore:"..n,name=n,info="Ignored character"}end end
  else
   for kind,caption in pairs(labels)do
    if (kind~="GUILD" and kind~="OFFICER" or IsInGuild()) and (kind~="OFFICER" or call(C_GuildInfo and C_GuildInfo.IsGuildOfficer))then room(kind,nil,caption)end
   end
   local channels={}
   if type(GetChannelList)=="function"then
    local values={pcall(GetChannelList)};if values[1]then table.remove(values,1);channels=values end
   end
   for i=1,#channels,3 do if type(channels[i+1])=="string"then room("CHANNEL",channels[i+1],channels[i+1])end end
   for _,key in ipairs(S.order)do local r=S.rooms[key];result[#result+1]={key=key,name=r.title,room=r,info=(r.unread>0 and r.unread.." unread | " or "")..#r.lines.." messages this session"}end
  end
  local filtered={};local query=string.lower(search:GetText() or "");local fav=preferences().favorites
  for _,r in ipairs(result)do if (not online:GetChecked() or r.online or section~="Friends" and section~="Guild") and string.lower(r.name.." "..(r.info or "")):find(query,1,true)then filtered[#filtered+1]=r end end
  table.sort(filtered,function(a,b)
   if a.room and b.room and (a.room.unread>0)~=(b.room.unread>0)then return a.room.unread>0 end
   if not not fav[a.key]~=not not fav[b.key]then return not not fav[a.key]end
   if not not a.online~=not not b.online then return not not a.online end
   return string.lower(a.name)<string.lower(b.name)
  end)
  return filtered
 end
 drawConversation=function(force)
  local r=currentRoom();if not r then return end
  local last=r.lines[#r.lines]
  if not force and renderedKey==r.key and renderedLast==last then return end
  local atBottom=chatScroll:GetVerticalScroll()>=math.max(0,chatBody:GetHeight()-chatScroll:GetHeight())-15
  local width=math.max(300,chatScroll:GetWidth()-6);chatBody:SetWidth(width);local y=0
  for i,line in ipairs(r.lines)do
   local t=messages[i];if not t then t=text(chatBody,"",13);t:SetWordWrap(true);t:SetJustifyV("TOP");messages[i]=t end
   t:ClearAllPoints();t:SetPoint("TOPLEFT",3,-y);t:SetWidth(width-6)
   t:SetText((WoWU_Theme.light and "|cff66513a"or "|cffb9a575")..line.at.."|r "..(WoWU_Theme.light and (line.mine and "|cff174f80"or "|cff713b0e")or (line.mine and "|cff80cfff"or "|cffffd16b"))..line.who..":|r "..line.text)
   t:Show();y=y+t:GetStringHeight()+10
  end
  for i=#r.lines+1,#messages do messages[i]:Hide()end
  chatBody:SetHeight(math.max(chatScroll:GetHeight(),y+8))
  if force or atBottom then chatScroll:SetVerticalScroll(math.max(0,chatBody:GetHeight()-chatScroll:GetHeight()))end
  renderedKey=r.key;renderedLast=last;r.unread=0;recount()
 end
 showContact=function()
  for _,b in ipairs(controls)do b:Hide()end
  local c=selected
  title:SetText(c and c.name or section)
  local intro="Select a contact from the list."
  if section=="Guild"then intro=IsInGuild()and ((call(C_GuildInfo and C_GuildInfo.GetMOTD)or "").."\n"..(call(C_GuildInfo and C_GuildInfo.GetInfoText)or ""))or "You are not in a guild."
  elseif section=="Requests"then intro="Select an incoming friend request to accept or decline."
  elseif section=="Ignored"then intro="Manage ignored characters."
  elseif section=="Conversations"then intro="Choose a conversation. History is collected while WoWU is running and clears on reload."
  elseif section=="Group"then intro="Select a group member. Ready checks and leadership controls follow your group permissions."end
  detail:SetText(c and ((c.info or "")..(c.note and c.note~="" and "\nNote: "..c.note or ""))or intro)
  if c and c.officerNote and c.officerNote~="" then detail:SetText(detail:GetText().."\nOfficer note: "..c.officerNote) end
  if c and (section=="Friends" or section=="Guild" or section=="Group")then
   whisperButton:Show();inviteButton:Show();favoriteButton:Show();favoriteButton.label:SetText(preferences().favorites[c.key]and "Unfavourite"or "Favourite")
   noteButton:SetShown(section=="Friends"or c.guild and c.guid~=nil and call(CanEditPublicNote)==true)
   removeButton:SetShown(section=="Friends")
   guildInvite:SetShown(not c.bn and call(CanGuildInvite)==true)
   promote:SetShown(c.guild and call(CanGuildPromote)==true);demote:SetShown(c.guild and call(CanGuildDemote)==true)
   leader:SetShown(section=="Group"and UnitIsGroupLeader("player")and c.unit~="player")
   kick:SetShown(c.guild and c.guid~=nil and call(CanGuildRemove)==true or section=="Group"and UnitIsGroupLeader("player")and c.unit~="player")
  end
 end
 refresh=function(reset)
  if not view:IsShown()then return end
  for key,b in pairs(tabs)do WoWU_Theme.Tab(b,key==section)end
  online:SetShown(section=="Friends"or section=="Guild");onlineLabel:SetShown(online:IsShown())
  local data=roster();local found
  for i,c in ipairs(data)do
   if selected and c.key==selected.key then selected=c;found=true end
   local b=rows[i]
   if not b then
    b=button(listBody,"",305,function()end);b:SetHeight(60);b.label:Hide()
    b.name=text(b,"",14);b.name:SetPoint("TOPLEFT",9,-8);b.name:SetWidth(286)
    b.info=text(b,"",11);b.info:SetPoint("TOPLEFT",9,-29);b.info:SetWidth(286);b.info:SetHeight(25)
    b:SetScript("OnClick",function(self)
     if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(listScroll)then return end
     if self.contact.room then S.openKey=self.contact.key;self.contact.room.unread=0;recount();selected=nil else selected=self.contact;S.openKey=nil end
     refresh();drawConversation(true)
    end);rows[i]=b
   end
   b.contact=c;b:SetPoint("TOPLEFT",0,-(i-1)*65);b.name:SetText((preferences().favorites[c.key]and "[Fav] "or "")..c.name);b.info:SetText((c.info or ""):gsub("\n"," | "));b:Show()
   WoWU_Theme.Tab(b,(selected and selected.key==c.key)or S.openKey==c.key)
  end
  if selected and not found then selected=nil end
  for i=#data+1,#rows do rows[i]:Hide()end
  listCount:SetText(#data.." entries");listBody:SetHeight(math.max(1,#data*65));listScroll:SetVerticalScroll(reset and 0 or math.min(listScroll:GetVerticalScroll(),math.max(0,listBody:GetHeight()-listScroll:GetHeight())))
  showContact()
  local r=currentRoom();local chatting=section=="Conversations"and r~=nil
  chatScroll:SetShown(chatting);composer:SetShown(chatting);send:SetShown(chatting);for _,b in ipairs(quick)do b:SetShown(chatting)end
  if chatting and composeKey~=r.key then
   loadingDraft=true;composeKey=r.key;composer:SetText(r.draft or "");composer:ClearFocus();loadingDraft=false
  end
  if chatting then title:SetText(r.title);detail:SetText("Messages from this session. Quick replies fill the box; tap Send to send them.");drawConversation(reset)end
  for _,b in ipairs(toolbar)do b:Hide()end
  local shown={}
  if section=="Friends"then shown={addFriend,newWhisper}
  elseif section=="Guild"and IsInGuild()then
   shown={guildChat}
   if call(CanEditMOTD)then shown[#shown+1]=editMOTD end
   if selected and selected.guid and call(C_GuildInfo and C_GuildInfo.CanEditOfficerNote)then shown[#shown+1]=officerNote end
  elseif section=="Group"then shown={ready,leave};ready:SetEnabled(UnitIsGroupLeader("player")or UnitIsGroupAssistant("player"));leave:SetEnabled(IsInGroup())
  elseif section=="Requests"then shown={acceptInvite,declineInvite};acceptInvite:SetEnabled(selected~=nil);declineInvite:SetEnabled(selected~=nil)
  elseif section=="Ignored"then shown={ignore,unignore};unignore:SetEnabled(selected~=nil)
  elseif section=="Conversations"then shown={newWhisper}end
  for i,b in ipairs(shown)do b:ClearAllPoints();b:SetPoint("BOTTOMLEFT",16+(i-1)*158,12);b:Show()end
  heading:SetText("Social"..(S.unread>0 and "  |  "..S.unread.." unread"or ""))
  if keyboardLayout then keyboardLayout() end
 end
 local keyboard,keyboardRoom,lastKeyboardTarget,compact
 keyboard=WoWUKeyboard.Create(view,{changed=function()if refresh then refresh()end end})
 for _,entry in ipairs({search,input,composer})do
  local field=entry
  field:HookScript("OnEditFocusGained",function()
   lastKeyboardTarget=field
   if keyboard:IsShown()then keyboard:SetTarget(field,field==composer and sendMessage or nil,field==composer and "Send"or "Done")end
  end)
 end
 WoWUKeyboard.ToggleButton(view,function()
  if keyboard:IsShown()then keyboard:Hide();return end
  local field=section=="Conversations"and currentRoom()and composer or (lastKeyboardTarget and lastKeyboardTarget:IsShown()and lastKeyboardTarget or search)
  keyboard:Open(field,field==composer and sendMessage or nil,field==composer and "Send"or "Done")
 end)
 keyboardLayout=function()
  local conversation=keyboard:IsShown()and section=="Conversations"and currentRoom()~=nil
  local changed=compact~=conversation;compact=conversation
  left:SetShown(not conversation);heading:SetShown(not conversation)
  for _,b in pairs(tabs)do b:SetShown(not conversation)end
  if conversation then
   local r=currentRoom()
   if keyboardRoom~=r.key then keyboardRoom=r.key;keyboard:SetTarget(composer,sendMessage,"Send")end
   right:ClearAllPoints();right:SetPoint("TOPLEFT",view,"TOPLEFT",14,-8);right:SetPoint("BOTTOMRIGHT",keyboard,"TOPRIGHT",0,8)
   detail:Hide();for _,b in ipairs(controls)do b:Hide()end;for _,b in ipairs(toolbar)do b:Hide()end
   composer:Hide();send:Hide();for _,b in ipairs(quick)do b:Hide()end
   chatScroll:ClearAllPoints();chatScroll:SetPoint("TOPLEFT",right,"TOPLEFT",16,-43);chatScroll:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-34,12)
   title:SetText(r.title.." - conversation")
  else
   keyboardRoom=nil
   right:ClearAllPoints();right:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0);right:SetPoint("BOTTOMRIGHT",view,"BOTTOMRIGHT",-14,48)
   detail:Show();chatScroll:ClearAllPoints();chatScroll:SetPoint("TOPLEFT",16,-119);chatScroll:SetPoint("BOTTOMRIGHT",-34,145)
  end
  status:SetWidth(math.max(200,view:GetWidth()*.38))
  if changed and currentRoom()then drawConversation(true)end
 end
 search:SetScript("OnTextChanged",function()if refresh then refresh(true)end end)
 view:SetScript("OnShow",function()S.visible=true;call(C_FriendList and C_FriendList.ShowFriends);call(C_GuildInfo and C_GuildInfo.GuildRoster);refresh(true)end)
 view:SetScript("OnHide",function()S.visible=false;keyboard:Hide();dialog:Hide();composer:ClearFocus();search:ClearFocus();input:ClearFocus()end)
 local elapsed=0
 view:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.4 then return end;elapsed=0
  if S.dirty then S.dirty=false;refresh()end
  if S.feedback and S.feedback~=""then notice(S.feedback);S.feedback=nil end
 end)
 return view
end
