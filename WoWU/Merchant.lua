-- Independent WoWU merchant catalogue; preserves the native vendor interaction offscreen.
local function call(fn,...)
 if type(fn)~='function'then return end
 local function pack(...)return {n=select('#',...),...}end
 local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local function text(p,size,value)
 local t=p:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetFont('Fonts\\FRIZQT__.TTF',size,'');WoWU_Theme.TextColor(t,.95,.82,.56);t:SetText(value or '');t:SetJustifyH('LEFT');return t
end
local function panel(p)local f=CreateFrame('Frame',nil,p,'BackdropTemplate');WoWU_Theme.Panel(f);return f end
local function button(p,name,w,fn)
 local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate');b:SetSize(w,34);b:SetText(name);b:SetScript('OnClick',fn);return b
end
local function money(n)return GetMoneyString and GetMoneyString(n or 0)or tostring(n or 0)..' copper'end
local equipSlots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_2HWEAPON={16,17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17}}
local prompts={'CONFIRM_PURCHASE_NONREFUNDABLE_ITEM','CONFIRM_HIGH_COST_ITEM','CONFIRM_PURCHASE_TOKEN_ITEM','CONFIRM_PURCHASE_ITEM_DELAYED','CONFIRM_REFUND_TOKEN_ITEM','CONFIRM_REFUND_MAX_HONOR','CONFIRM_REFUND_MAX_ARENA_POINTS','CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL'}
function WoWU_BuildMerchant(parent,normalFrames)
 if not C_Container or not GetMerchantNumItems then return end
 local opened,active,mode=false,false,'Buy'
 local selected,multi,query=nil,false,''
 local choices,entries,rows={},{},{}
 local session,serial,cooldown=0,0,0
 local job,pending,native
 local refresh,detail,activate,deactivate,startSales,saleStep
 local view=CreateFrame('Frame',nil,parent);view:SetAllPoints();view:SetFrameLevel(parent:GetFrameLevel()+30);view:Hide()
 local portrait=view:CreateTexture(nil,'ARTWORK');portrait:SetPoint('TOPLEFT',18,-10);portrait:SetSize(52,52)
 local npc=text(view,22,'Merchant');npc:SetPoint('TOPLEFT',82,-13);npc:SetWidth(590)
 local hint=text(view,12,'Browse wares, sell items and recover recent sales.');hint:SetPoint('TOPLEFT',82,-43)
 local funds=text(view,15);funds:SetPoint('TOPRIGHT',-125,-20)
 local status=text(view,12);status:SetPoint('BOTTOMLEFT',18,10);status:SetPoint('BOTTOMRIGHT',-18,10);status:SetHeight(32);status:SetWordWrap(true)
 local function say(s)status:SetText(s or '')end
 local function nativePrompt()for _,n in ipairs(prompts)do if call(StaticPopup_FindVisible,n)then return true end end;return call(StaticPopup_FindVisible,'WOWU_MERCHANT_SELL')~=nil or call(StaticPopup_FindVisible,'WOWU_MERCHANT_REPAIR')~=nil end
 local function busy()return job~=nil or GetTime()<cooldown or nativePrompt()end
 local function ready()return opened and active and parent:IsVisible()and MerchantFrame and MerchantFrame:IsShown()and not InCombatLockdown()and not CursorHasItem()and not call(InRepairMode)end
 local function pause()if WoWUQoL and WoWUQoL.PauseMerchantWork then WoWUQoL.PauseMerchantWork()end end
 local function stop(s)job,pending=nil,nil;serial=serial+1;if s then say(s)end end
 local function loc(b,s)return ItemLocation and ItemLocation:CreateFromBagAndSlot(b,s)end
 local function item(b,s)return call(C_Container.GetContainerItemInfo,b,s)end
 local function protected(id)return WoWUQoL and WoWUQoL.IsProtected(id)or false end
 local function stock(i)
  local d=call(C_MerchantFrame and C_MerchantFrame.GetItemInfo,i)
  if type(d)~='table'then
   local n,t,p,c,a,b,u,e=call(GetMerchantItemInfo,i);if not n then return end
   d={name=n,texture=t,price=p,stackCount=c,numAvailable=a,isPurchasable=b,isUsable=u,hasExtendedCost=e}
  end
  if d.currencyID and CurrencyContainerUtil then
   local n,t,a=call(CurrencyContainerUtil.GetCurrencyContainerInfo,d.currencyID,d.numAvailable,d.name,d.texture,nil)
   d.name=n or d.name;d.texture=t or d.texture;d.numAvailable=a or d.numAvailable
  end
  d.name=d.name or 'Vendor item '..i
  d.kind='Buy';d.key='Buy:'..i;d.index=i;d.link=call(GetMerchantItemLink,i);d.stackCount=math.max(1,d.stackCount or 1);d.price=d.price or 0
  d.costs={};local signature={tostring(d.price),tostring(d.stackCount),tostring(d.hasExtendedCost)}
  for j=1,call(GetMerchantItemCostInfo,i)or 0 do
   local t,c,l,n=call(GetMerchantItemCostItem,i,j);d.costs[#d.costs+1]={texture=t,count=c or 0,link=l,name=n};signature[#signature+1]=tostring(c)..':'..tostring(l)..':'..tostring(n)
  end
  d.signature=table.concat(signature,'|');return d
 end
 local function buyback(i)
  local n,t,p,c=call(GetBuybackItemInfo,i);if not n then return end
  return {kind='Buyback',key='Buyback:'..i,index=i,name=n,texture=t,price=p or 0,stackCount=c or 1,link=call(GetBuybackItemLink,i)}
 end
 local function carried(b,s)
  local d=item(b,s);if not d or not d.itemID then return end
  local n,l,q,_,_,_,_,_,_,_,p=call(C_Item and C_Item.GetItemInfo or GetItemInfo,d.hyperlink or d.itemID)
  return {kind='Sell',key=b..':'..s,bag=b,slot=s,id=d.itemID,name=n or 'Loading item...',link=d.hyperlink or l,texture=d.iconFileID,stackCount=d.stackCount or 1,quality=d.quality or q,unitPrice=p,price=(p or 0)*(d.stackCount or 1),locked=d.isLocked,guid=call(C_Item and C_Item.GetItemGUID,loc(b,s)),refund=d.isRefundable or call(C_Item and C_Item.CanBeRefunded,loc(b,s)),hasLoot=d.hasLoot,hasNoValue=d.hasNoValue}
 end
 local function same(a,b)return a and b and a.kind==b.kind and a.name==b.name and a.texture==b.texture and a.currencyID==b.currencyID and a.spellID==b.spellID and a.link==b.link and a.stackCount==b.stackCount and a.price==b.price and a.signature==b.signature and a.id==b.id and a.guid==b.guid end
 local function sellable(d,bulk)
  if not d or not d.link or d.locked or protected(d.id)or d.hasNoValue or d.hasLoot or not d.unitPrice or d.unitPrice<=0 then return false end
  local q=call(C_Container.GetContainerItemQuestInfo,d.bag,d.slot);if q and(q.isQuestItem or q.questID)then return false end
  return not bulk or not d.refund
 end
 local function cost(d,n)
  local lines={};if d.price>0 then lines[#lines+1]=money(d.price*(n or 1))end
  for _,c in ipairs(d.costs or {})do lines[#lines+1]=(c.texture and '|T'..c.texture..':14:14|t 'or '')..(c.count*(n or 1))..' '..(c.name or c.link or 'Required item')end
  return #lines>0 and table.concat(lines,' + ')or 'Free'
 end
 local function closePrompts()
  for _,n in ipairs(prompts)do StaticPopup_Hide(n)end
  StaticPopup_Hide('WOWU_MERCHANT_SELL');StaticPopup_Hide('WOWU_MERCHANT_REPAIR')
 end
 local function anchorPrompts()for _,n in ipairs(prompts)do local f=call(StaticPopup_FindVisible,n);if f then f:ClearAllPoints();f:SetPoint('CENTER',view,'CENTER',0,0)end end end
 local function park()
  local f=MerchantFrame;if not f or not f:IsShown()then return end
  if not native then native={points={},clamped=f:IsClampedToScreen(),tab=f.selectedTab};for i=1,f:GetNumPoints()do native.points[i]={f:GetPoint(i)}end end
  f:SetClampedToScreen(false);f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-3000)
 end
 local function restore()
  local s=native;native=nil;if not s or not MerchantFrame then return end
  MerchantFrame:ClearAllPoints();for _,p in ipairs(s.points)do MerchantFrame:SetPoint(unpack(p))end;MerchantFrame:SetClampedToScreen(s.clamped)
  if s.tab then MerchantFrame.selectedTab=s.tab;call(PanelTemplates_SetTab,MerchantFrame,s.tab);call(MerchantFrame_Update)end
 end
 local close=button(view,'Close',95,function()stop();CloseMerchant()end);close:SetPoint('TOPRIGHT',-14,-10)
 local catalogue=panel(view);catalogue:SetPoint('TOPLEFT',10,-104);catalogue:SetPoint('BOTTOMRIGHT',-391,104)
 local inspector=panel(view);inspector:SetPoint('TOPLEFT',catalogue,'TOPRIGHT',9,0);inspector:SetPoint('BOTTOMRIGHT',-10,104)
 local modeButtons={}
 local search
 for i,name in ipairs({'Buy','Sell','Buyback'})do
  local b=CreateFrame('Button',nil,view,'BackdropTemplate');b:SetSize(130,34);b:SetPoint('TOPLEFT',14+(i-1)*138,-65);b.label=text(b,15,name);b.label:SetPoint('CENTER');WoWU_Theme.Button(b)
  b:SetScript('OnClick',function()
   if busy()then say('Finish the current action or confirmation first.');return end
   closePrompts();mode=name;selected=nil;multi=false;wipe(choices)
   MerchantFrame.selectedTab=name=='Buyback'and 2 or 1;call(PanelTemplates_SetTab,MerchantFrame,MerchantFrame.selectedTab)
   search:SetText('');refresh();say(name=='Sell'and 'Select a stack or enable Select Items for several stacks.'or 'Select an item to inspect it.')
  end);modeButtons[name]=b
 end
 search=CreateFrame('EditBox',nil,view,'InputBoxTemplate');search:SetSize(225,28);search:SetPoint('TOPRIGHT',catalogue,'TOPRIGHT',-14,34);search:SetAutoFocus(false);search:SetMaxLetters(70)
 local searchHint=text(search,12,'Search items...');searchHint:SetPoint('LEFT',5,0)
 search:SetScript('OnTextChanged',function(self)query=string.lower(self:GetText()or '');searchHint:SetShown(query=='');if refresh then refresh()end end)
 search:SetScript('OnEscapePressed',function(self)self:ClearFocus()end);search:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 local scroll=CreateFrame('ScrollFrame',nil,catalogue,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',12,-15);scroll:SetPoint('BOTTOMRIGHT',-32,51);if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 local body=CreateFrame('Frame',nil,scroll);body:SetSize(700,1);scroll:SetScrollChild(body)
 local empty=text(catalogue,15);empty:SetPoint('TOPLEFT',26,-26);empty:SetPoint('RIGHT',-40,0);empty:SetWordWrap(true)
 local summary=text(catalogue,12);summary:SetPoint('BOTTOMLEFT',16,18);summary:SetWidth(420)
 local selectButton=button(catalogue,'Select Items',140,function()if not busy()then pause();multi=not multi;wipe(choices);refresh()end end);selectButton:SetPoint('BOTTOMRIGHT',-12,9)
 local icon=inspector:CreateTexture(nil,'ARTWORK');icon:SetSize(48,48);icon:SetPoint('TOPLEFT',16,-15)
 local name=text(inspector,17,'Select an item');name:SetPoint('TOPLEFT',76,-16);name:SetPoint('TOPRIGHT',-14,-16);name:SetHeight(50);name:SetWordWrap(true)
 local ts=CreateFrame('ScrollFrame',nil,inspector,'UIPanelScrollFrameTemplate');ts:SetPoint('TOPLEFT',12,-79);ts:SetPoint('BOTTOMRIGHT',-32,147);if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(ts)end
 local tb=CreateFrame('Frame',nil,ts);tb:SetSize(300,1);ts:SetScrollChild(tb)
 local tip=CreateFrame('GameTooltip','WoWU_MerchantTooltip',tb,'GameTooltipTemplate');tip:SetOwner(tb,'ANCHOR_NONE');tip:SetPoint('TOPLEFT');tip:Hide()
 local comparisons={}
 for i=1,2 do local t=CreateFrame('GameTooltip','WoWU_MerchantEquippedTooltip'..i,tb,'GameTooltipTemplate');t:SetOwner(tb,'ANCHOR_NONE');t:Hide();local h=text(tb,12,'Currently equipped');h:Hide();comparisons[i]={tip=t,heading=h}end
 local bundles=1
 local qLabel=text(inspector,12,'Quantity');qLabel:SetPoint('BOTTOMLEFT',16,119)
 local quantity=CreateFrame('EditBox',nil,inspector,'InputBoxTemplate');quantity:SetSize(65,28);quantity:SetPoint('BOTTOMLEFT',128,108);quantity:SetAutoFocus(false);quantity:SetNumeric(true);quantity:SetMaxLetters(5)
 local minus=button(inspector,'-',28,function()bundles=math.max(1,bundles-1);detail()end);minus:SetPoint('RIGHT',quantity,'LEFT',-9,0)
 local plus=button(inspector,'+',28,function()bundles=bundles+1;detail()end);plus:SetPoint('LEFT',quantity,'RIGHT',8,0)
 local max=button(inspector,'Max',52,function()bundles=10000;detail()end);max:SetPoint('LEFT',plus,'RIGHT',5,0)
 local total=text(inspector,12);total:SetPoint('BOTTOMLEFT',16,57);total:SetPoint('BOTTOMRIGHT',-14,57);total:SetHeight(43);total:SetWordWrap(true)
 local action=button(inspector,'Buy',168,function()end);action:SetPoint('BOTTOMLEFT',14,13)
 local protect=button(inspector,'Protect Item',142,function()if not busy()and selected and mode=='Sell'then pause();WoWUQoL.Protect(selected.id,not protected(selected.id));wipe(choices);refresh()end end);protect:SetPoint('BOTTOMRIGHT',-14,13)
 local function sellList()
  local list={};if multi then for _,d in pairs(choices)do list[#list+1]=d end elseif selected then list[1]=selected end
  table.sort(list,function(a,b)return a.bag==b.bag and a.slot<b.slot or a.bag<b.bag end);return list
 end
 local function limit(d)
  local cap=math.max(1,math.floor((call(GetMerchantItemMaxStack,d.index)or d.stackCount)/d.stackCount))
  if d.numAvailable and d.numAvailable>=0 then cap=math.min(cap,math.floor(d.numAvailable/d.stackCount))end
  if d.price>0 then cap=math.min(cap,math.floor(GetMoney()/d.price))end
  for _,c in ipairs(d.costs or {})do if c.count>0 and c.link then
   local id=c.link:match('currency:(%d+)');local owned
   if id then local currency=call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,tonumber(id));owned=currency and currency.quantity
   else owned=call(C_Item and C_Item.GetItemCount or GetItemCount,c.link,false,false,true)end
   if type(owned)=='number'then cap=math.min(cap,math.floor(owned/c.count))end
  end end
  return math.max(0,cap)
 end
 local function fit(t,y)
  t:SetScale(math.min(1,math.max(1,ts:GetWidth()-3)/math.max(1,t:GetWidth())));t:ClearAllPoints();t:SetPoint('TOPLEFT',tb,'TOPLEFT',0,-y/t:GetScale());return y+t:GetHeight()*t:GetScale()
 end
 detail=function()
  tip:Hide();for _,c in ipairs(comparisons)do c.tip:Hide();c.heading:Hide()end
  icon:SetTexture(selected and selected.texture);name:SetText(selected and selected.name or 'Select an item')
  local buying=mode=='Buy'and selected~=nil
  for _,c in ipairs({qLabel,quantity,minus,plus,max})do c:SetShown(buying)end
  protect:SetShown(mode=='Sell'and selected~=nil);protect:SetText(selected and protected(selected.id)and 'Unprotect'or 'Protect Item');protect:SetEnabled(not busy())
  if not selected then total:SetText('');action:Disable();tb:SetHeight(1);return end
  tip:SetOwner(tb,'ANCHOR_NONE');tip:ClearLines()
  if mode=='Buy'then call(tip.SetMerchantItem,tip,selected.index)elseif mode=='Buyback'then call(tip.SetBuybackItem,tip,selected.index)else call(tip.SetBagItem,tip,selected.bag,selected.slot)end
  tip:Show();local height=fit(tip,0)
  local equip=selected.link and select(9,call(C_Item and C_Item.GetItemInfo or GetItemInfo,selected.link))
  for i,slot in ipairs(equipSlots[equip]or {})do
   local c=comparisons[i]
   if c and call(GetInventoryItemLink,'player',slot)then
    height=height+22;c.heading:ClearAllPoints();c.heading:SetPoint('TOPLEFT',tb,'TOPLEFT',4,-height);c.heading:SetText('Currently equipped'..((slot==11 or slot==12)and ' - ring '..(slot-10)or ''));c.heading:Show();height=height+23
    c.tip:SetOwner(tb,'ANCHOR_NONE');c.tip:ClearLines();c.tip:SetInventoryItem('player',slot);c.tip:Show();height=fit(c.tip,height)
   end
  end
  tb:SetWidth(math.max(1,ts:GetWidth()));tb:SetHeight(height+12);ts:SetVerticalScroll(math.min(ts:GetVerticalScroll(),math.max(0,tb:GetHeight()-ts:GetHeight())))
  if buying then
   local cap=limit(selected);bundles=math.max(1,math.min(bundles,math.max(1,cap)));if not quantity:HasFocus()then quantity:SetText(tostring(bundles))end;qLabel:SetText(selected.stackCount>1 and 'Packs of '..selected.stackCount or 'Quantity')
   total:SetText('Total ('..(bundles*selected.stackCount)..' items): '..cost(selected,bundles));minus:SetEnabled(bundles>1 and not busy());plus:SetEnabled(bundles<cap and not busy());max:SetEnabled(cap>0 and not busy());quantity:SetEnabled(not busy())
   action:SetText('Buy');action:SetEnabled(ready()and not busy()and cap>0 and selected.isPurchasable~=false and selected.numAvailable~=0)
  elseif mode=='Buyback'then total:SetText('Entire stack ('..selected.stackCount..'): '..money(selected.price));action:SetText('Buy Back');action:SetEnabled(ready()and not busy()and GetMoney()>=selected.price)
  else
   local price,count=0,0;for _,d in ipairs(sellList())do if sellable(d,false)then price=price+d.price;count=count+1 end end
   total:SetText(protected(selected.id)and 'Protected from selling. Unprotect to sell this item.'or count..' stack(s) selected: '..money(price));action:SetText(multi and 'Sell Selected'or 'Sell Stack');action:SetEnabled(ready()and not busy()and count>0)
  end
 end
 quantity:SetScript('OnEnterPressed',function(self)bundles=math.floor(tonumber(self:GetText())or 1);self:ClearFocus();detail()end)
 quantity:SetScript('OnEditFocusLost',function(self)bundles=math.floor(tonumber(self:GetText())or bundles);detail()end)
 quantity:SetScript('OnEscapePressed',function(self)self:ClearFocus();detail()end)
 local function draw()
  local width=math.max(1,scroll:GetWidth());body:SetWidth(width);local columns=width>=550 and 2 or 1;local w=(width-(columns-1)*10)/columns;local count=0
  for _,d in ipairs(entries)do if query==''or string.find(string.lower(d.name or ''),query,1,true)then
   count=count+1;local b=rows[count]
   if not b then
    b=CreateFrame('Button',nil,body,'BackdropTemplate');WoWU_Theme.Backdrop(b,{bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});WoWU_Theme.Color(b,.14,.17,.18,1)
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',10,-12);b.icon:SetSize(52,52)
    b.name=text(b,14);b.name:SetPoint('TOPLEFT',73,-12);b.name:SetPoint('TOPRIGHT',-12,-12);b.name:SetHeight(35);b.name:SetWordWrap(true)
    b.price=text(b,11);b.price:SetPoint('TOPLEFT',73,-52);b.price:SetPoint('TOPRIGHT',-10,-52);b.price:SetHeight(34);b.price:SetWordWrap(true)
    b.stock=text(b,10);b.stock:SetPoint('BOTTOMLEFT',11,9)
    b.check=b:CreateTexture(nil,'OVERLAY');b.check:SetSize(24,24);b.check:SetPoint('BOTTOMRIGHT',-8,8);b.check:SetTexture('Interface\\RaidFrame\\ReadyCheck-Ready')
    b:SetScript('OnClick',function(self)
     if busy()or(WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll))then return end
     local data=self.data;if data.kind=='Sell'then pause()end
     local previous=selected and selected.key;selected=data;bundles=1
     if multi and mode=='Sell'then if choices[data.key]then choices[data.key]=nil else choices[data.key]=data end end
     if previous~=data.key then ts:SetVerticalScroll(0)end;refresh()
    end);rows[count]=b
   end
   b.data=d;b:SetSize(w,111);b:ClearAllPoints();b:SetPoint('TOPLEFT',((count-1)%columns)*(w+10),-math.floor((count-1)/columns)*120)
   b.icon:SetTexture(d.texture);b.name:SetText(d.name);b.price:SetText(d.kind=='Buy'and cost(d,1)or money(d.price))
   b.stock:SetText(d.kind=='Buy'and('Pack: '..d.stackCount..'  |  Stock: '..((d.numAvailable or -1)<0 and 'Unlimited'or tostring(d.numAvailable)))or(d.stackCount..' items'..(d.kind=='Sell'and protected(d.id)and '  |  Protected'or '')))
   b.check:SetShown(choices[d.key]~=nil);local focused=selected and selected.key==d.key;WoWU_Theme.Border(b,focused and 1 or .45,focused and .82 or .4,focused and .35 or .3,1);b:SetAlpha(d.locked and .5 or 1);b:Show()
  end end
  for i=count+1,#rows do rows[i]:Hide()end
  body:SetHeight(math.max(1,math.ceil(count/columns)*120));scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
  empty:SetShown(count==0);empty:SetText(query~=''and 'No items match your search.'or mode=='Buyback'and 'No recently sold items are available to buy back.'or 'No items to display.')
  local n=0;for _ in pairs(choices)do n=n+1 end;summary:SetText(count..' item(s)'..(mode=='Sell'and multi and '  |  '..n..' selected'or ''))
  selectButton:SetShown(mode=='Sell');selectButton:SetText(multi and 'Select Items: ON'or 'Select Items');selectButton:SetEnabled(not busy())
 end
 local repairText=text(view,12);repairText:SetPoint('BOTTOMLEFT',582,67);repairText:SetPoint('BOTTOMRIGHT',-18,67)
 local repair,guild,junk,stopButton
 local function guildAllowed(cost)
  local funds=call(GetGuildBankMoney);local limit=call(GetGuildBankWithdrawMoney)
  return call(CanGuildBankRepair)and type(funds)=='number'and funds>=cost and type(limit)=='number'and(limit==-1 or limit>=cost)
 end
 local function requestRepair(useGuild)
  if busy()or not ready()then return end
  pause();local cost,needed=call(GetRepairAllCost)
  if not needed or not cost or cost<=0 then say('No repairs are needed.');return end
  if not(useGuild and guildAllowed(cost)or not useGuild and GetMoney()>=cost)then say('Insufficient repair funds.');return end
  StaticPopup_Show('WOWU_MERCHANT_REPAIR',money(cost),useGuild and 'Using guild funds.'or 'Using your money.',{cost=cost,guild=useGuild,session=session})
 end
 junk=button(view,'Sell Junk',135,function()
  if busy()or not ready()then return end
  pause();local items={}
  for bag=0,WoWUClient.LastBag()do for slot=1,call(C_Container.GetContainerNumSlots,bag)or 0 do local d=carried(bag,slot);if d and d.quality==0 and sellable(d,true)then items[#items+1]=d end end end
  startSales(items)
 end);junk:SetPoint('BOTTOMLEFT',16,53)
 stopButton=button(view,'Stop Selling',112,function()stop('Selling stopped. Completed sales remain in Buyback while available.');refresh()end);stopButton:SetPoint('BOTTOMLEFT',159,53)
 repair=button(view,'Repair All',140,function()requestRepair(false)end);repair:SetPoint('BOTTOMLEFT',279,53)
 guild=button(view,'Guild Repair',146,function()requestRepair(true)end);guild:SetPoint('BOTTOMLEFT',427,53)
 refresh=function()
  if not active then return end
  local old=selected;entries={}
  if mode=='Buy'then for i=1,call(GetMerchantNumItems)or 0 do local d=stock(i);if d then entries[#entries+1]=d end end
  elseif mode=='Buyback'then for i=1,call(GetNumBuybackItems)or 0 do local d=buyback(i);if d then entries[#entries+1]=d end end
  else for bag=0,WoWUClient.LastBag()do for slot=1,call(C_Container.GetContainerNumSlots,bag)or 0 do local d=carried(bag,slot);if d then entries[#entries+1]=d end end end end
  selected=nil;local found={}
  for _,d in ipairs(entries)do
   found[d.key]=true
   if old and old.key==d.key and(old.kind~='Sell'or old.id==d.id and old.guid==d.guid)then selected=d end
   if choices[d.key]and not same(choices[d.key],d)and not job then choices[d.key]=nil end
  end
  if mode=='Sell'and not job then for key in pairs(choices)do if not found[key]then choices[key]=nil end end end
  for name,b in pairs(modeButtons)do b:SetEnabled(not busy());WoWU_Theme.Tab(b,name==mode)end
  funds:SetText(money(call(GetMoney)));stopButton:SetEnabled(job~=nil);junk:SetEnabled(ready()and not busy())
  local cost,needed=call(GetRepairAllCost);local canRepair=call(CanMerchantRepair)==true
  repair:SetShown(canRepair);guild:SetShown(canRepair and call(CanGuildBankRepair)==true)
  repair:SetEnabled(ready()and not busy()and needed and cost and cost>0 and GetMoney()>=cost);guild:SetEnabled(ready()and not busy()and needed and cost and cost>0 and guildAllowed(cost))
  repairText:SetText(canRepair and('Repairs: '..money(cost))or 'This merchant does not offer repairs.');draw();detail()
 end
 local proxy=CreateFrame('Button',nil,view);proxy.GetSlotAndBagID=function(self)return self.slot,self.bag end;proxy.GetBagID=function(self)return self.bag end
 local function buy()
  if not ready()or busy()or not selected then return end
  pause();bundles=math.floor(tonumber(quantity:GetText())or bundles);local d=stock(selected.index)
  if not same(selected,d)then say('This offer changed. Review its new price before buying.');refresh();return end
  local cap=limit(d);if bundles<1 or bundles>cap or d.isPurchasable==false or d.numAvailable==0 then say('Choose an available quantity you can afford.');detail();return end
  local units=bundles*d.stackCount
  proxy:SetID(d.index);proxy.price=d.price;proxy.count=d.stackCount;proxy.name=d.name;proxy.link=d.link;proxy.texture=d.texture;proxy.extendedCost=d.hasExtendedCost
  proxy.showNonrefundablePrompt=call(C_MerchantFrame and C_MerchantFrame.IsMerchantItemRefundable,d.index)==false
  cooldown=GetTime()+.8;local ok,err
  if d.hasExtendedCost then
   if not MerchantFrame_ConfirmExtendedItemCost then say('Use Blizzard merchant controls to confirm this special purchase.');cooldown=0;return end
   ok,err=pcall(MerchantFrame_ConfirmExtendedItemCost,proxy,units)
  elseif d.price*bundles>=(MERCHANT_HIGH_PRICE_COST or 1500000)and MerchantFrame_ConfirmHighCostItem then ok,err=pcall(MerchantFrame_ConfirmHighCostItem,proxy,units)
  elseif proxy.showNonrefundablePrompt then
   if not MerchantFrame_ConfirmExtendedItemCost then say('Use Blizzard merchant controls to confirm this purchase.');cooldown=0;return end
   ok,err=pcall(MerchantFrame_ConfirmExtendedItemCost,proxy,units)
  else ok,err=pcall(BuyMerchantItem,d.index,units)end
  anchorPrompts();say(ok and 'Purchase requested. Follow any confirmation.'or 'Purchase blocked: '..tostring(err));refresh()
 end
 action:SetScript('OnClick',function()
  if not ready()or busy()or not selected then return end
  pause()
  if mode=='Buy'then buy()
  elseif mode=='Buyback'then
   local d=buyback(selected.index);if not same(selected,d)then say('The Buyback list changed. Select the item again.');refresh();return end
   if GetMoney()<d.price then say('Not enough money.');return end
   cooldown=GetTime()+.8;local ok,err=pcall(BuybackItem,d.index);say(ok and 'Buyback requested.'or 'Buyback blocked: '..tostring(err));selected=nil;refresh()
  else startSales(sellList())end
 end)
 local function acknowledge()
  if job and pending and not item(pending.bag,pending.slot)then
   job.sold=job.sold+1;choices[pending.key]=nil;pending=nil;local generation=serial
   C_Timer.After(.15,function()if generation==serial then saleStep()end end)
  end
 end
 saleStep=function()
  if not job or pending then return end
  if not ready()or MerchantFrame.selectedTab==2 then stop('Selling stopped: merchant access changed.');refresh();return end
  local expected=table.remove(job.items,1)
  if not expected then stop('Sold '..job.sold..' stack(s).'..(job.skipped>0 and ' Skipped '..job.skipped..' changed or protected stack(s).'or ''));refresh();return end
  local current=carried(expected.bag,expected.slot)
  if not same(expected,current)or not sellable(current,true)then
   job.skipped=job.skipped+1;local generation=serial;C_Timer.After(.05,function()if generation==serial then saleStep()end end);return
  end
  pending=expected;local ok,err=pcall(C_Container.UseContainerItem,current.bag,current.slot)
  if not ok then stop('Selling blocked: '..tostring(err));refresh();return end
  local generation=serial
  C_Timer.After(.2,function()if generation==serial then acknowledge()end end)
  C_Timer.After(4,function()if generation==serial and pending==expected then stop('Selling paused: the game did not confirm this sale.');refresh()end end)
 end
 startSales=function(items)
  if not ready()or busy()then return end
  pause();local candidates={}
  for _,d in ipairs(items)do if sellable(d,false)then candidates[#candidates+1]=d end end
  if #candidates==0 then say('No sellable items selected. Protected and quest items are excluded.');return end
  if #candidates==1 and candidates[1].refund then
   local d=candidates[1];if not same(d,carried(d.bag,d.slot))then say('The selected item changed. Select it again.');refresh();return end
   if not ContainerFrame_GetExtendedPriceString then say('Use Blizzard merchant controls to refund this item.');return end
   proxy.bag=d.bag;proxy.slot=d.slot;proxy.count=d.stackCount;proxy:SetID(d.slot)
   local ok,shown=pcall(ContainerFrame_GetExtendedPriceString,proxy)
   if not ok or not shown then say('This refundable item needs Blizzard merchant refund controls.');return end
   anchorPrompts();return
  end
  local safe,price={},0
  for _,d in ipairs(candidates)do if not d.refund then safe[#safe+1]=d;price=price+d.price end end
  if #safe==0 then say('Refundable items are excluded from bulk selling. Select them individually to refund.');return end
  StaticPopup_Show('WOWU_MERCHANT_SELL',#safe,money(price),{items=safe,session=session})
 end
 StaticPopupDialogs.WOWU_MERCHANT_SELL={
  text='Sell %s selected stack(s) for %s?\n\nBuyback only keeps a limited number of recent sales. Refundable items are excluded.',button1='Sell',button2=CANCEL or 'Cancel',timeout=0,whileDead=false,hideOnEscape=true,
  OnShow=function(f)f:ClearAllPoints();f:SetPoint('CENTER',view,'CENTER',0,0)end,
  OnAccept=function(_,data)
   if not data or data.session~=session or not ready()or job then return end
   pause();serial=serial+1;job={items=data.items,sold=0,skipped=0};pending=nil
   mode='Sell';MerchantFrame.selectedTab=1;call(PanelTemplates_SetTab,MerchantFrame,1);search:SetText('');saleStep();refresh()
  end,
 }
 StaticPopupDialogs.WOWU_MERCHANT_REPAIR={
  text='Repair all equipped and carried gear for %s?\n\n%s',button1='Repair',button2=CANCEL or 'Cancel',timeout=0,whileDead=false,hideOnEscape=true,
  OnShow=function(f)f:ClearAllPoints();f:SetPoint('CENTER',view,'CENTER',0,0)end,
  OnAccept=function(_,data)
   if not data or data.session~=session or not ready()or job then return end
   local cost,needed=call(GetRepairAllCost)
   if not needed or cost~=data.cost or not(data.guild and guildAllowed(cost)or not data.guild and GetMoney()>=cost)then say('Repair cost or funds changed. Review the cost again.');refresh();return end
   pause();local ok,err=pcall(RepairAllItems,data.guild);say(ok and 'Repair requested.'or 'Repair blocked: '..tostring(err));refresh()
  end,
 }
 deactivate=function()
  if not active then return end
  stop();closePrompts();active=false;view:Hide();restore();wipe(choices);tip:Hide()
  for _,c in ipairs(comparisons)do c.tip:Hide();c.heading:Hide()end
  for _,f in ipairs(normalFrames)do f:Show()end
 end
 activate=function()
  if not opened or InCombatLockdown()or not WoWU_MainFrame or not WoWU_MainFrame:IsVisible()then return end
  if WoWUInteractions then WoWUInteractions.Release()end
        if not parent:IsVisible()then WoWU_ShowPage('Bags')end
  if not parent:IsVisible()then return end
  if active then refresh();return end
  if parent.WoWUDeactivateBank then parent.WoWUDeactivateBank()end
  active=true;mode='Buy';selected=nil;wipe(choices);multi=false;bundles=1;cooldown=0
  for _,f in ipairs(normalFrames)do f:Hide()end
  view:Show();park();if CloseAllBags then CloseAllBags(MerchantFrame)end
  npc:SetText(call(UnitName,'npc')or 'Merchant');if SetPortraitTexture then SetPortraitTexture(portrait,'npc')end
  MerchantFrame.selectedTab=1;call(PanelTemplates_SetTab,MerchantFrame,1)
  search:SetText('');scroll:SetVerticalScroll(0);refresh();say('Select an item to inspect it. Purchases require the Buy button.')
 end
 local dirty,previousBusy=false,false
 local events=CreateFrame('Frame')
 for _,e in ipairs({'MERCHANT_SHOW','MERCHANT_CLOSED','MERCHANT_UPDATE','MERCHANT_FILTER_ITEM_UPDATE','BAG_UPDATE_DELAYED','ITEM_LOCK_CHANGED','GET_ITEM_INFO_RECEIVED','PLAYER_MONEY','CURRENCY_DISPLAY_UPDATE','GUILDBANK_UPDATE_MONEY','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','UI_ERROR_MESSAGE','MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL'})do pcall(events.RegisterEvent,events,e)end
 events:SetScript('OnEvent',function(_,event,_,message)
  if event=='MERCHANT_SHOW'then opened=true;session=session+1;C_Timer.After(0,function()if opened then activate()end end)
  elseif event=='MERCHANT_CLOSED'then opened=false;session=session+1;deactivate()
  elseif event=='PLAYER_REGEN_DISABLED'then if active then stop('Merchant actions paused during combat.');closePrompts();dirty=true end
  elseif event=='PLAYER_REGEN_ENABLED'then if opened and parent:IsVisible()then activate()end
  elseif active then
   if event=='UI_ERROR_MESSAGE'then stop('Merchant action stopped: '..tostring(message or 'the game rejected the action'))
   elseif event=='MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL'then stop('Selling paused for Blizzard refund/trade confirmation.');anchorPrompts()
   else acknowledge()end
   dirty=true
  end
 end)
 events:SetScript('OnUpdate',function()
  if active then local b=busy();if b~=previousBusy then previousBusy=b;dirty=true end;if dirty then dirty=false;refresh()end end
 end)
 parent:HookScript('OnHide',deactivate)
 parent:HookScript('OnShow',function()if opened then C_Timer.After(0,function()if parent:IsVisible()then activate()end end)end end)
 view:HookScript('OnSizeChanged',function()if active then dirty=true end end)
 parent.WoWUDeactivateMerchant=deactivate
 parent.WoWURefreshMerchant=function()if active then refresh()end end
end
