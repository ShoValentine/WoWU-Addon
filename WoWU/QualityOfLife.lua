-- Optional, bounded convenience actions. Never confirms purchases, binding,
-- deletion, COD or protected actions on the player's behalf.
local Q={};WoWUQoL=Q
local C=WoWUClient
local call=C.Call
local defaults={fastLoot=false,floatingLoot=false,autoSell=false,autoRepair=false,
 guildRepair=false,openMail=true,bagWarning=true,camera=false,cameraFactor=2.6,
 lootDuration=1.6,lootScale=1,lootX=150,lootY=20}
local function db()
 WoWUDB=WoWUDB or {};WoWUDB.qol=WoWUDB.qol or {}
 local d=WoWUDB.qol;d.protected=d.protected or {};return d
end
function Q.Get(key)local value=db()[key];if value==nil then return defaults[key]end;return value end
local function message(value)print("|cffebc36bWoWU:|r "..value)end
local function combat()return InCombatLockdown and InCombatLockdown()end
local function number(value)return C.Number(value)end
function Q.IsProtected(id)return id and db().protected[id]==true or false end
function Q.Protect(id,value)
 if not number(id)then return false end
 db().protected[id]=value and true or nil
 return true
end
local function info(bag,slot)return call(C_Container and C_Container.GetContainerItemInfo,bag,slot)end
local function countSlots(bag)return call(C_Container and C_Container.GetContainerNumSlots,bag)or 0 end
local function generalFree()
 local free,total=0,0
 for bag=0,C.LastBag()do
  local n,family=call(C_Container and C_Container.GetContainerNumFreeSlots,bag)
  if number(n)and (bag==0 or family==0)then free=free+n;total=total+countSlots(bag)end
 end
 return free,total
end

-- One alert per full-inventory episode, independent of the old near-full hint.
local full,fullSerial,failedLoot=false,0,false
local session=tostring(time())..":"..tostring(GetTime())
function Q.BagChanged()
 local free,total=generalFree()
 local now=total>0 and free==0
 if free>0 then failedLoot=false end
 now=now or failedLoot
 if now and not full then fullSerial=fullSerial+1 end
 full=now
 if WoWUAdventure then WoWUAdventure.dirty=true end
end
function Q.BagAlert()
 if not Q.Get("bagWarning")or not full then return end
 return {key="qol:full:"..session..":"..fullSerial,kind="bagfull",priority=50,page="Bags",
  title="Inventory Full! No free general-purpose bag slots remaining.",
  popup=failedLoot and "Inventory Full! A loot item could not fit."or "Inventory Full! No free general-purpose bag slots remaining.",
  detail="Open Bags to make room. Existing stacks or specialised bags may still accept matching items.",
  icon="Interface\\Icons\\INV_Misc_Bag_08"}
end

-- Fast loot follows the resolved auto-loot mode; no confirmations or forced close.
local lootHandled=false
local function fastLoot(auto)
 if lootHandled or not Q.Get("fastLoot")or combat()or type(LootSlot)~="function"then return end
 if auto==nil then
  auto=call(C_CVar and C_CVar.GetCVarBool or GetCVarBool,"autoLootDefault")
  if call(IsModifiedClick,"AUTOLOOTTOGGLE")then auto=not auto end
 end
 if auto~=true and auto~=1 then return end
 lootHandled=true
 for slot=(call(GetNumLootItems)or 0),1,-1 do
  if not pcall(LootSlot,slot)then break end
 end
end

-- Actual self-acquisition messages only; never infer pickup from LootSlot.
local floatHost,active,pool,patterns=nil,{},{},nil
local function mainCenter()
 local api=Offhand and Offhand.API
 local r=call(api and api.GetMainhandRect)
 if type(r)~="table"then
  local viewport=Offhand and Offhand.Viewport
  local m=call(viewport and viewport.GetMetrics,viewport)
  if Offhand and Offhand.db and Offhand.db.enabled and m and m.isSpanned then
   r={left=m.gameLeft,right=m.gameRight,bottom=m.gameBottom,top=m.gameTop}
  end
 end
 if r then
  if number(r.left)and number(r.right)and number(r.bottom)and number(r.top)then return (r.left+r.right)/2,(r.bottom+r.top)/2 end
  return
 end
 return UIParent:GetWidth()/2,UIParent:GetHeight()/2
end
local function hideFloats()
 for i=#active,1,-1 do local f=table.remove(active,i);f:Hide();pool[#pool+1]=f end
 if floatHost then floatHost:SetScript("OnUpdate",nil)end
end
local function animate(_,dt)
 for i=#active,1,-1 do
  local f=active[i];f.age=f.age+dt
  local t=f.age/f.duration
  if t>=1 then f:Hide();table.remove(active,i);pool[#pool+1]=f
  else
   f:ClearAllPoints();f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",f.x,f.y+42*t)
   f:SetAlpha(t<.4 and 1 or (1-t)/.6)
  end
 end
 if #active==0 then floatHost:SetScript("OnUpdate",nil)end
end
local function floatLoot(link,quantity)
 if not Q.Get("floatingLoot")then return end
 local x,y=mainCenter();if not x then return end
 local id=tonumber(link:match("item:(%d+)"));if not id then return end
 local name=link:match("|h%[(.-)%]|h")or link:match("|h(.-)|h")or "Item"
 local hex=link:match("|c(%x%x%x%x%x%x%x%x)")or "ffffffff"
 local function caption(n)return "+"..n.." |c"..hex.."["..name.."]|r"end
 for _,f in ipairs(active)do
  if f.link==link and f.age<.3 then f.quantity=f.quantity+quantity;f.text:SetText(caption(f.quantity));return end
 end
 if not floatHost then floatHost=CreateFrame("Frame",nil,UIParent);floatHost:SetFrameStrata("HIGH");floatHost:EnableMouse(false)end
 if #active>=6 then local f=table.remove(active,1);f:Hide();pool[#pool+1]=f end
 local f=table.remove(pool)
 if not f then
  f=CreateFrame("Frame",nil,floatHost);f:SetSize(460,32);f:EnableMouse(false)
  f.text=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.text:SetPoint("LEFT");f.text:SetJustifyH("LEFT");f.text:SetShadowOffset(1,-1)
 end
 local size=18*Q.Get("lootScale")
 for _,previous in ipairs(active)do previous.y=previous.y+size+10 end
 f.text:SetFont("Fonts\\FRIZQT__.TTF",size,"OUTLINE");f.text:SetText(caption(quantity))
 f.x=x+Q.Get("lootX");f.y=y+Q.Get("lootY");f.age=0;f.duration=Q.Get("lootDuration");f.link=link;f.quantity=quantity
 f:SetAlpha(1);f:ClearAllPoints();f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",f.x,f.y);f:Show()
 active[#active+1]=f;floatHost:SetScript("OnUpdate",animate)
end
local function parseLoot(text)
 if not Q.Get("floatingLoot")or not C.Public(text)or type(text)~="string"then return end
 if not patterns then
  patterns={}
  for _,key in ipairs({"LOOT_ITEM_SELF_MULTIPLE","LOOT_ITEM_SELF","LOOT_ITEM_CREATED_SELF_MULTIPLE","LOOT_ITEM_CREATED_SELF","LOOT_ITEM_PUSHED_SELF_MULTIPLE","LOOT_ITEM_PUSHED_SELF"})do
   local format=_G[key]
   if type(format)=="string"then
    local pattern=format:gsub("%%(%d+)%$([sd])","%%%2")
    pattern=pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"):gsub("%%%%s","(.-)"):gsub("%%%%d","(%%d+)")
    patterns[#patterns+1]="^"..pattern.."$"
   end
  end
 end
 local link=text:match("(|c%x+|Hitem:.-|h.-|h|r)")or text:match("(|Hitem:.-|h.-|h)")
 if not link then return end
 for _,p in ipairs(patterns)do
  local a,b=text:match(p)
  if a then floatLoot(link,tonumber(a)or tonumber(b)or 1);return end
 end
end

-- Merchant work is sequential and bounded. Re-read a candidate just before sale.
local merchant,sale,repairPending,repairTried=false,nil,nil,false
local attempted,sales,merchantGeneration={},0,0
local saleStopped=false
local saleStep
local function stopSales(reason)
 sale=nil;attempted={};sales=0;saleStopped=true
 if reason then message(reason)end
end
-- Manual catalogue actions take ownership for this visit without changing saved preferences.
function Q.PauseMerchantWork()
 stopSales();repairPending=nil;repairTried=true
end
local function canSell(bag,slot)
 local d=info(bag,slot)
 if not d or not d.itemID or d.isLocked or d.quality~=0 or d.hasNoValue or d.isRefundable or d.hasLoot or Q.IsProtected(d.itemID)then return end
 local q=call(C_Container and C_Container.GetContainerItemQuestInfo,bag,slot)
 if q and (q.isQuestItem or q.questID)then return end
 local location=ItemLocation and ItemLocation:CreateFromBagAndSlot(bag,slot)
 if location and call(C_Item and C_Item.CanBeRefunded,location)then return end
 -- C.Call returns eight values; use a direct protected read for vendor price.
 local get=C_Item and C_Item.GetItemInfo or GetItemInfo
 local ok,_,_,quality,_,_,_,_,_,_,_,price=pcall(get,d.hyperlink or d.itemID)
 if not ok or quality~=0 or not number(price)or price<=0 then return end
 return d
end
local function merchantUsable()
 return merchant and not combat()and MerchantFrame and MerchantFrame:IsShown()
  and MerchantFrame.selectedTab~=2 and not call(InRepairMode)and not call(CursorHasItem)
end
saleStep=function()
 if saleStopped or not merchantUsable()or not Q.Get("autoSell")or sales>=100 then return end
 if sale then
  local d=info(sale.bag,sale.slot)
  if not d or d.itemID~=sale.id or (d.stackCount or 0)<sale.count then sale=nil
  elseif GetTime()-sale.at>=3 then stopSales("Junk selling paused: the last sale was not confirmed.");return
  else return end
 end
 for bag=0,C.LastBag()do
  for slot=1,countSlots(bag)do
   local d=canSell(bag,slot)
   local key=bag..":"..slot..":"..tostring(d and d.itemID)
   if d and not attempted[key]then
    attempted[key]=true;sales=sales+1
    sale={bag=bag,slot=slot,id=d.itemID,count=d.stackCount or 1,at=GetTime()}
    local ok=pcall(C_Container.UseContainerItem,bag,slot)
    if not ok then stopSales("Automatic selling is unavailable here; use the merchant window.");return end
    local generation=merchantGeneration
    C_Timer.After(3.1,function()if generation==merchantGeneration and sale then saleStep()end end)
    return
   end
  end
 end
end
local function personalRepair(cost)
 if number(call(GetMoney))and GetMoney()>=cost then
  local ok=pcall(RepairAllItems,false)
  if not ok then message("Automatic repair was blocked; use the merchant's repair button.")end
 else message("Not enough personal funds to repair.")end
end
local function repair()
 if repairTried or not Q.Get("autoRepair")or not merchantUsable()or not call(CanMerchantRepair)or type(RepairAllItems)~="function"then return end
 repairTried=true
 local cost,needed=call(GetRepairAllCost)
 if not needed or not number(cost)or cost<=0 then return end
 local allowance=number(call(GetGuildBankWithdrawMoney));local funds=number(call(GetGuildBankMoney))
 if Q.Get("guildRepair")and call(CanGuildBankRepair)and allowance and funds and funds>=cost and (allowance==-1 or allowance>=cost)then
  local ok=pcall(RepairAllItems,true)
  if not ok then personalRepair(cost);return end
  local generation=merchantGeneration
  repairPending=true
  C_Timer.After(2,function()
   if generation~=merchantGeneration or not repairPending then return end
   repairPending=nil
   if not Q.Get("autoRepair")or not merchantUsable()then return end
   local remaining,stillNeeded=call(GetRepairAllCost)
   if stillNeeded and number(remaining)and remaining>0 then personalRepair(remaining)end
  end)
 else personalRepair(cost)end
end

-- Open All takes one attachment or money transfer at a time. Never pays COD,
-- deletes mail, takes body text, or confirms exceptional mail.
local mailbox,mailJob,mailPanel=false,nil,nil
local mailGeneration=0
local function mailStatus(value)
 if mailPanel then mailPanel.status:SetText(value or "");mailPanel.button.label:SetText(mailJob and "Stop collection"or "Open All")end
end
function Q.StopMail(reason)
 mailJob=nil;mailGeneration=mailGeneration+1;mailStatus(reason or "Stopped.")
end
local function header(index)
 local v={pcall(GetInboxHeaderInfo,index)}
 if not v[1]or not v[4]or not number(v[7])then return end
 return {sender=v[4],subject=v[5],money=number(v[6])or 0,cod=number(v[7])or 0,items=number(v[9])or (v[9]and 1 or 0),gm=v[14]}
end
local function sameMail(a,b)return a and b and a.sender==b.sender and a.subject==b.subject and a.cod==b.cod end
local mailStep
mailStep=function()
 if not mailJob then return end
 if not mailbox or not Q.Get("openMail")or combat()or not MailFrame or not MailFrame:IsShown()then Q.StopMail("Collection stopped.");return end
 local job=mailJob;local count=call(GetInboxNumItems)or 0
 if job.pending then
  local p=job.pending;local h=header(p.index);local changed=count~=p.inbox or not sameMail(h,p.header)
  if not changed then
   if p.slot then
    local _,id,_,qty=call(GetInboxItem,p.index,p.slot)
    changed=id~=p.id or qty~=p.qty
   else changed=h.money<p.header.money end
  end
  if changed then job.pending=nil;job.done=job.done+1
  elseif GetTime()-p.at>=4 then Q.StopMail("Paused: no collection response. Check bags and the mailbox, then tap Open All again.");return
  else return end
 end
 if job.done>=200 then Q.StopMail("Collected 200 transfers. Tap Open All to continue.");return end
 for index=count,1,-1 do
  local h=header(index)
  if h and number(h.cod)and h.cod==0 and not h.gm then
   local slot,itemID,quantity
   if h.money==0 and h.items>0 then
    for j=1,(ATTACHMENTS_MAX_RECEIVE or 16)do
     local name,id,_,qty=call(GetInboxItem,index,j)
     if name and id then slot,itemID,quantity=j,id,qty;break end
    end
    if not slot then Q.StopMail("Attachments are still loading. Tap Open All again shortly.");return end
   end
   if h.money>0 or slot then
    local fn=slot and TakeInboxItem or TakeInboxMoney
    if type(fn)~="function"then Q.StopMail("Mail collection is unavailable on this client.");return end
    job.pending={index=index,slot=slot,id=itemID,qty=quantity,header=h,inbox=count,at=GetTime()}
    local ok
    if slot then ok=pcall(fn,index,slot)else ok=pcall(fn,index)end
    if not ok then Q.StopMail("The game blocked collection. Use the mailbox manually.");return end
    mailStatus("Collected "..job.done.." transfers. Waiting for the mailbox...")
    local generation=mailGeneration
    C_Timer.After(4.1,function()if generation==mailGeneration then mailStep()end end)
    return
   end
  end
 end
 local _,total=call(GetInboxNumItems)
 Q.StopMail("Collected "..job.done.." transfers. COD/GM mail skipped."..(total and total>count and " More mail is not loaded yet; wait, then tap Open All again."or ""))
end
function Q.StartMail()
 if mailJob then Q.StopMail();return end
 if not mailbox or not Q.Get("openMail")or combat()then return end
 mailGeneration=mailGeneration+1;mailJob={done=0};mailStatus("Starting collection...");mailStep()
end
local function showMail()
 if Q.mailHosted then return end
 if not Q.Get("openMail")or not MailFrame then return end
 if not mailPanel then
  mailPanel=CreateFrame("Frame",nil,MailFrame,"BackdropTemplate");mailPanel:SetSize(310,112)
  mailPanel:SetPoint("TOPLEFT",MailFrame,"TOPRIGHT",6,0);mailPanel:SetClampedToScreen(true);WoWU_Theme.Panel(mailPanel)
  local b=CreateFrame("Button",nil,mailPanel,"BackdropTemplate");b:SetPoint("TOP",0,-10);b:SetSize(285,44)
  b.label=b:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");b.label:SetPoint("CENTER");b.label:SetText("Open All")
  WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)
  b:SetScript("OnClick",Q.StartMail);mailPanel.button=b
  mailPanel.status=mailPanel:CreateFontString(nil,"OVERLAY","GameFontNormal");mailPanel.status:SetPoint("TOPLEFT",12,-62);mailPanel.status:SetWidth(285);mailPanel.status:SetJustifyH("LEFT")
 end
 mailStatus("Collect attachments and money. COD mail is always skipped.");mailPanel:Show()
end

function Q.SetMailHosted(value)
 Q.mailHosted=value
 if value then if mailPanel then mailPanel:Hide()end
 elseif mailbox and Q.Get("openMail")then showMail()end
end

-- Set a supported limit, not a forced zoom position. Restore only our own value.
local cameraName="cameraDistanceMaxZoomFactor"
function Q.ApplyCamera()
 if not Q.Get("camera")then return true end
 local get=C_CVar and C_CVar.GetCVar or GetCVar;local set=C_CVar and C_CVar.SetCVar or SetCVar
 local current=tonumber(call(get,cameraName))
 if not current or type(set)~="function"then return false,"Extended camera distance is unavailable on this client."end
 local d=db();d.cameraOriginal=d.cameraOriginal or current
 local wanted=math.max(1,math.min(2.6,tonumber(Q.Get("cameraFactor"))or 2.6))
 local ok=pcall(set,cameraName,wanted)
 local actual=tonumber(call(get,cameraName))
 if not ok or not actual then return false,"The game did not accept the camera setting."end
 d.cameraLast=actual
 return true,"Camera limit: "..actual.."x. Zoom out normally to use it; client limits still apply."
end
function Q.Set(key,value)
 local limits={cameraFactor={1,2.6},lootDuration={1,10},lootScale={.7,1.6},lootX={-800,800},lootY={-500,500}}
 if defaults[key]==nil then return false,"Unknown setting."end
 if limits[key]then
  if not number(value)or value<limits[key][1]or value>limits[key][2]then return false,"Value outside the allowed range."end
 elseif type(value)~="boolean"then return false,"Expected a checkbox value."end
 db()[key]=value
 if key=="floatingLoot"and not value then hideFloats()
 elseif key=="openMail"then if not value then Q.StopMail("Disabled.");if mailPanel then mailPanel:Hide()end elseif mailbox then showMail()end
 elseif key=="autoSell"and not value then stopSales()
 elseif key=="autoRepair"and not value then repairPending=nil
 elseif key=="camera"and not value then
  local d=db();local current=tonumber(call(C_CVar and C_CVar.GetCVar or GetCVar,cameraName))
  if current and current==d.cameraLast and d.cameraOriginal then call(C_CVar and C_CVar.SetCVar or SetCVar,cameraName,d.cameraOriginal)end
  d.cameraOriginal=nil;d.cameraLast=nil
 elseif key=="camera"or key=="cameraFactor"then return Q.ApplyCamera()end
 if WoWUAdventure then WoWUAdventure.dirty=true end
 return true,"Saved."
end

local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","LOOT_OPENED","LOOT_CLOSED","CHAT_MSG_LOOT","MERCHANT_SHOW","MERCHANT_CLOSED","MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL","MAIL_SHOW","MAIL_CLOSED","MAIL_INBOX_UPDATE","MAIL_FAILED","MAIL_SUCCESS","BAG_UPDATE_DELAYED","UI_ERROR_MESSAGE","PLAYER_REGEN_DISABLED"})do pcall(events.RegisterEvent,events,e)end
events:SetScript("OnEvent",function(_,event,...)
 if event=="PLAYER_LOGIN"then
  local current=tonumber(call(C_CVar and C_CVar.GetCVar or GetCVar,cameraName))
  if not db().cameraLast or current==db().cameraLast then Q.ApplyCamera()end
 elseif event=="PLAYER_ENTERING_WORLD"then Q.BagChanged()
 elseif event=="LOOT_OPENED"then fastLoot((...))
 elseif event=="LOOT_CLOSED"then lootHandled=false
 elseif event=="CHAT_MSG_LOOT"then parseLoot((...))
 elseif event=="MERCHANT_SHOW"then
  merchant=true;merchantGeneration=merchantGeneration+1;attempted={};sales=0;sale=nil;repairTried=false;saleStopped=false
  local generation=merchantGeneration
  C_Timer.After(.2,function()if generation==merchantGeneration then repair();saleStep()end end)
 elseif event=="MERCHANT_CLOSED"then merchant=false;merchantGeneration=merchantGeneration+1;repairPending=nil;stopSales()
 elseif event=="MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL"then stopSales("Automatic selling stopped for a merchant confirmation.")
 elseif event=="MAIL_SHOW"then mailbox=true;showMail()
 elseif event=="MAIL_CLOSED"then mailbox=false;Q.StopMail();if mailPanel then mailPanel:Hide()end
 elseif event=="MAIL_FAILED"then if mailJob then Q.StopMail("Mail collection failed. Check the mailbox before trying again.")end
 elseif event=="MAIL_INBOX_UPDATE"or event=="MAIL_SUCCESS"then
  local generation=mailGeneration;C_Timer.After(.25,function()if generation==mailGeneration then mailStep()end end)
 elseif event=="BAG_UPDATE_DELAYED"then
  Q.BagChanged()
  local generation=merchantGeneration;C_Timer.After(.2,function()if generation==merchantGeneration then saleStep()end end)
 elseif event=="PLAYER_REGEN_DISABLED"then Q.StopMail("Paused for combat.");stopSales();repairPending=nil
 elseif event=="UI_ERROR_MESSAGE"then
  local _,text=...
  if not C.Public(text)then return end
  if text and (text==ERR_INV_FULL or text==ERR_BAG_FULL)then
   if not full then fullSerial=fullSerial+1 end;failedLoot=true;full=true
   if WoWUAdventure then WoWUAdventure.dirty=true end
  end
  if mailJob then Q.StopMail("Paused: "..(type(text)=="string"and text or "the game reported an error."))end
  if sale then stopSales("Junk selling paused after a game error.")end
 end
end)
