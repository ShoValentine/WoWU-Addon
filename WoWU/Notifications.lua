-- Event receipts and history. Never accepts invitations, casts or purchases automatically.
local A,C=WoWUAdventure,WoWUClient
local M={pending={}};WoWUNotifications=M
local call=C.Call
local session=tostring(time())..':'..tostring(GetTime());local receiptSerial=0
local function combat()return InCombatLockdown and InCombatLockdown()end
local function state()
 local s=A.State();s.history=s.history or {};return s
end
local function text(v)return C.Public(v)and type(v)=='string'and v or nil end
function M.Push(key,title,detail,category,icon,action)
 if not A.GetOption(category)then return end
 local previous=M.pending[key]
 if previous and previous.expires<GetTime()then previous=nil end
 if not previous then receiptSerial=receiptSerial+1 end
 M.pending[key]={key=previous and previous.key or key..':'..session..':'..receiptSerial,title=title,detail=detail,kind=category,categoryOption=category,icon=icon,action=action,
  actionText=action=='auctions'and 'View Auctions'or action=='fishing'and 'Open Fishing'or action=='calendar'and 'View Calendar'or 'Open Professions',
  popup=title,priority=20,expires=GetTime()+90,quiet=false,count=(previous and previous.count or 0)+1}
 M.Observe({M.pending[key]})
 local count=0;local oldest,oldestAt
 for id,r in pairs(M.pending)do
  if r.expires<GetTime()then M.pending[id]=nil else count=count+1;if not oldestAt or r.expires<oldestAt then oldest,oldestAt=id,r.expires end end
 end
 if count>64 and oldest then M.pending[oldest]=nil end
end
function M.Dismiss(key)
 local s=state();s.dismissed[key]=true;for id,r in pairs(M.pending)do if r.key==key then M.pending[id]=nil end end
 for _,r in ipairs(s.history)do if r.key==key then r.read=true end end
end
function M.Observe(alerts)
 local s=state();local byKey={}
 for _,r in ipairs(s.history)do byKey[r.key]=r end
 for _,a in ipairs(alerts)do
  if a.key and not a.archiveDisabled then
   local r=byKey[a.key]
   if not r then
    r={key=a.key,title=a.title,detail=a.detail,icon=a.icon,kind=a.kind or 'reminder',at=time(),read=false}
    table.insert(s.history,1,r);byKey[a.key]=r
    if not a.quiet and A.GetOption('sounds')and GetTime()-(M.lastSound or -10)>5 and not(A.GetOption('quietCombat')and combat())and WoWU_MainFrame and WoWU_MainFrame:IsVisible()then M.lastSound=GetTime();call(PlaySound,SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856,'Master')end
   else r.title=a.title;r.detail=a.detail;r.icon=a.icon end
  end
 end
 while #s.history>100 do local r=table.remove(s.history);s.dismissed[r.key]=nil;s.notified[r.key]=nil end
end
function M.Unread()
 local n=0;for _,r in ipairs(state().history)do if not r.read then n=n+1 end end;return n
end
function M.MarkRead()
 for _,r in ipairs(state().history)do r.read=true end
end
function M.History()
 local out={}
 for _,r in ipairs(state().history)do out[#out+1]={title=r.title,detail=date('%d %b %H:%M',r.at)..' - '..(r.detail or ''),icon=r.icon,history=true}end
 if #out==0 then out[1]={title='Your notification history is empty',detail='The latest 100 notifications are kept for this character.'}end
 return out
end
function M.ClearHistory()state().history={};M.MarkRead()end
local lastCalendar=0
local function calendar()
 if GetTime()-lastCalendar<60 or not A.GetOption('calendar')then return end;lastCalendar=GetTime()
 local dateInfo=call(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)or call(C_Calendar and C_Calendar.GetDate)
 if type(dateInfo)~='table'or not dateInfo.monthDay then return end
 if not M.calendarRequested and C_Calendar and C_Calendar.OpenCalendar then M.calendarRequested=true;call(C_Calendar.OpenCalendar)end
 local month=call(C_Calendar and C_Calendar.GetMonthInfo,0)
 local offset=type(month)=='table'and month.month and month.year and ((dateInfo.year-month.year)*12+dateInfo.month-month.month)or 0
 local get=C_Calendar and C_Calendar.GetDayEvent
 local count=call(C_Calendar and C_Calendar.GetNumDayEvents,offset,dateInfo.monthDay)
 if not get or type(count)~='number'then return end
 for i=1,math.min(count,100)do
  local r=call(get,offset,dateInfo.monthDay,i)
  if type(r)=='table'and (r.calendarType=='PLAYER'or r.calendarType=='GUILD_EVENT'or r.calendarType=='COMMUNITY_EVENT')and r.inviteStatus~=2 and r.inviteStatus~=4 and r.inviteStatus~=7 then
   local t=r.startTime;local title=text(r.title)
   if type(t)=='table'and type(t.hour)=='number'and type(t.minute)=='number'and title then
    local minutes=t.hour*60+t.minute-(dateInfo.hour*60+dateInfo.minute)
    if minutes>=0 and minutes<=15 then
     local key='calendar:'..dateInfo.year..':'..dateInfo.month..':'..dateInfo.monthDay..':'..(r.eventID or title)..':'..t.hour..':'..t.minute
     M.Push(key,'Event starting soon: '..title,'Starts in '..minutes..' minutes. Open Calendar for the event details.','calendar',134377,'calendar')
    end
   end
  end
 end
 -- Include the next day's first quarter-hour when a reminder crosses midnight.
 if dateInfo.hour==23 and dateInfo.minute>=45 then
  local currentMonth=call(C_Calendar.GetMonthInfo,offset)
  local tomorrow=dateInfo.monthDay+1;local nextOffset=offset
  if currentMonth and currentMonth.numDays and tomorrow>currentMonth.numDays then tomorrow=1;nextOffset=offset+1 end
  local nextMonth=call(C_Calendar.GetMonthInfo,nextOffset)
  local n=call(C_Calendar.GetNumDayEvents,nextOffset,tomorrow)or 0
  for i=1,math.min(n,100)do
   local r=call(get,nextOffset,tomorrow,i);local t=r and r.startTime
   if r and type(t)=='table'and type(t.hour)=='number'and type(t.minute)=='number'and (r.calendarType=='PLAYER'or r.calendarType=='GUILD_EVENT'or r.calendarType=='COMMUNITY_EVENT')and r.inviteStatus~=2 and r.inviteStatus~=4 and r.inviteStatus~=7 and text(r.title)then
    local minutes=1440+t.hour*60+t.minute-(dateInfo.hour*60+dateInfo.minute)
    if minutes>=0 and minutes<=15 then
     local key='calendar:'..(nextMonth and nextMonth.year or dateInfo.year)..':'..(nextMonth and nextMonth.month or dateInfo.month)..':'..tomorrow..':'..(r.eventID or r.title)..':'..t.hour..':'..t.minute
     M.Push(key,'Event starting soon: '..r.title,'Starts in '..minutes..' minutes. Open Calendar for the event details.','calendar',134377,'calendar')
    end
   end
  end
 end
end
function M.Collect(add)
 local now=GetTime()
 for key,r in pairs(M.pending)do
  if r.expires<now then M.pending[key]=nil elseif A.GetOption(r.categoryOption)then add(r)end
 end
 if WoWUCompanionPrompts and A.GetOption('requests')then
  for _,r in ipairs(WoWUCompanionPrompts.Notifications())do add(r)end
 end
end
function M.Tick()calendar()end
local function openCalendar()
 call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,'Blizzard_Calendar')
 if CalendarFrame then if not CalendarFrame:IsShown()then ShowUIPanel(CalendarFrame)end elseif ToggleCalendar then ToggleCalendar()end
end
function M.Act(a)
 if combat()then return false,'Use this action after combat. Active game prompts remain available.'end
 if a.prompt then return WoWUCompanionPrompts.Focus(a.prompt,a.promptToken)end
 if a.action=='calendar'then openCalendar();return true
 elseif a.action=='fishing'then
  WoWU_ShowPage('Professions');if WoWU_OpenFishing then WoWU_OpenFishing()end;return true
 elseif a.action=='auctions'then
  if not M.auctionOpen then return false,'Visit an auctioneer to view your auctions.'end
  WoWU_ShowPage('Bags');if WoWUAuctionHouse and WoWUAuctionHouse.ShowOwned then return WoWUAuctionHouse.ShowOwned()end;return true
 elseif a.action=='mail'then
  if not M.mailOpen then return false,'Visit a mailbox to read or collect your mail.'end
  WoWU_ShowPage('Bags');return true
 elseif a.action=='professions'then WoWU_ShowPage('Professions');return true end
 return false,'This notification no longer has an available action.'
end
-- Localized system-message matching; no English-only auction guessing.
local function matches(message,format)
 if not text(message)or not text(format)then return false end
 local p=format:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1'):gsub('%%%%s','.-'):gsub('%%%%d','%%d+')
 return message:match('^'..p..'$')~=nil
end
local function auctionMessage(message)
 for _,format in ipairs({ERR_AUCTION_SOLD_S or '',ERR_AUCTION_EXPIRED_S or '',ERR_AUCTION_OUTBID_S or '',ERR_AUCTION_WON_S or '',ERR_AUCTION_REMOVED_S or ''})do
  if format~=''and matches(message,format)then M.Push('auction:'..message,'Auction update',message,'auctions',133784,'auctions');return end
 end
end
local craft
function M.BeginCraft(id,count,name)
 craft={id=id,left=count or 1,name=name or 'Crafting',done=0,deadline=GetTime()+900}
end
local craftSerial=0
local function crafted(id)
 if not craft or GetTime()>craft.deadline then return end
 if not C.Public(id)then return end
 local name=call(C_Spell and C_Spell.GetSpellName,id)or call(GetSpellInfo,id)
 if craft.id~=id and craft.name~=name then return end
 craft.done=craft.done+1;craft.left=craft.left-1
 if craft.left<=0 then
  craftSerial=craftSerial+1;M.Push('craft:'..craftSerial,'Crafting finished',craft.name..': '..craft.done..' successful craft(s).','crafting',134400,'professions');craft=nil
 end
end
local serial=0;local lureWasActive=false;local fishing=false
local function lureState()
 if not(WoWUFishing and (WoWUFishing.active or WoWUFishing.IsOpen and WoWUFishing.IsOpen()))then return end
 local main=call(GetWeaponEnchantInfo)
 local now=main==true or main==1
 if lureWasActive and not now and fishing then
  serial=serial+1;M.Push('lure:'..serial,'Your fishing lure has expired','Open Fishing to choose and apply another lure.','fishing',134335,'fishing')
 end
 lureWasActive=now
end
local events=CreateFrame('Frame')
for _,e in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_REGEN_DISABLED','MAIL_SHOW','MAIL_CLOSED','AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','AUCTION_HOUSE_SHOW_NOTIFICATION','AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION','AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION','CHAT_MSG_SYSTEM','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_CHANNEL_START','UNIT_INVENTORY_CHANGED','PLAYER_EQUIPMENT_CHANGED','CALENDAR_UPDATE_EVENT_LIST','CALENDAR_UPDATE_INVITE_LIST'})do pcall(events.RegisterEvent,events,e)end
events:SetScript('OnEvent',function(_,e,a,b,c)
 if e=='AUCTION_HOUSE_SHOW'then M.auctionOpen=true
 elseif e=='AUCTION_HOUSE_CLOSED'then M.auctionOpen=false
 elseif e=='MAIL_SHOW'then M.mailOpen=true
 elseif e=='MAIL_CLOSED'then M.mailOpen=false
 elseif e=='CHAT_MSG_SYSTEM'then auctionMessage(a)
 elseif e=='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'or e=='AUCTION_HOUSE_SHOW_NOTIFICATION'then
  local message=call(ChatFrameUtil and ChatFrameUtil.GetAuctionHouseNotificationText,a,b)
  if text(message)and message~=''then M.Push('auction:'..message,'Auction update',message,'auctions',133784,'auctions')end
 elseif e=='AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION'then
  serial=serial+1;M.Push('auction:won:'..serial,'Auction purchase completed','Your purchased commodities will arrive by mail.','auctions',133784,'auctions')
 elseif e=='UNIT_SPELLCAST_SUCCEEDED'and a=='player'then crafted(c)
 elseif (e=='UNIT_SPELLCAST_INTERRUPTED'or e=='UNIT_SPELLCAST_FAILED')and a=='player'then craft=nil
 elseif e=='UNIT_SPELLCAST_CHANNEL_START'and a=='player'then
  if not C.Public(c)then return end
  local id=call(GetInventoryItemID,'player',16)
  local _,_,_,_,_,class,sub=call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,id or 0)
  fishing=class==2 and sub==20 and WoWUFishing and WoWUFishing.IsFishingSpell(c)or false
  if fishing then lureWasActive=call(GetWeaponEnchantInfo)and true or false end
 elseif e=='UNIT_INVENTORY_CHANGED'and a=='player'then lureState()
 elseif e=='PLAYER_EQUIPMENT_CHANGED'then
  -- Removing/swapping a rod is not a lure-expiration event.
  lureWasActive=false;fishing=false
 elseif e=='PLAYER_ENTERING_WORLD'then lastCalendar=0;M.calendarRequested=false;fishing=false;lureWasActive=false;craft=nil
 elseif e=='PLAYER_REGEN_DISABLED'then craft=nil
 elseif e=='CALENDAR_UPDATE_EVENT_LIST'or e=='CALENDAR_UPDATE_INVITE_LIST'then lastCalendar=0 end
end)
if C_TradeSkillUI and type(C_TradeSkillUI.CraftRecipe)=='function'then
 hooksecurefunc(C_TradeSkillUI,'CraftRecipe',function(id,count)
  local r=call(C_TradeSkillUI.GetRecipeInfo,id);M.BeginCraft(id,count,r and r.name)
 end)
end
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt;if elapsed<2 then return end;elapsed=0
 if WoWU_MainFrame and WoWU_MainFrame:IsVisible()and A.dashboard and not A.dashboard:IsVisible()then M.Tick();A.Poll()end
end)
