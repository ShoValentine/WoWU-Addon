-- Retail catalogue. Native frame stays shown offscreen to retain the NPC session.
local A=WoWUAuctionAPI or C_AuctionHouse
local P=WoWUAuctionPrices
WoWUAuctionHouse={supported=A and A.SendBrowseQuery and A.GetBrowseResults and A.PostItem and true or false}
local function text(p,s,v)
 local t=p:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetFont('Fonts\\FRIZQT__.TTF',s,'');t:SetText(v or '');t:SetJustifyH('LEFT');return t
end
local function button(p,v,w,fn)local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate');b:SetSize(w,34);b:SetText(v);b:SetScript('OnClick',fn);return b end
local function money(n)return GetMoneyString(n or 0)end
local function number(v)local n=tonumber(v);return n and n==n and n>=0 and n<1e12 and math.floor(n)or nil end
local function sameKey(a,b)return a and b and a.itemID==b.itemID and a.itemLevel==b.itemLevel and a.itemSuffix==b.itemSuffix and a.battlePetSpeciesID==b.battlePetSpeciesID end
function WoWU_BuildAuctionHouse(parent,normalFrames)
 if not WoWUAuctionHouse.supported or not WoWUKeyboard then return end
 local opened,active,mode=false,false,'Buy'
 local chosen,key,commodity,waiting,pending,native
 local browseReady,resultsReady=false,false
 local page,rows,entries,capacity=1,{},{},8
 local refresh,detail,activate,deactivate,search
 local categoryData,layoutMode
 local refreshCategories,refreshPrices
 local function scanning()return P and P.IsBusy()end
 local view=CreateFrame('Frame',nil,parent);view:SetAllPoints();view:SetFrameLevel(parent:GetFrameLevel()+40);view:EnableMouse(true);view:Hide()
 local title=text(view,23,'Auction House');title:SetPoint('TOPLEFT',16,-13)
 local funds=text(view,14);funds:SetPoint('TOPRIGHT',-126,-20)
 local status=text(view,12);status:SetPoint('BOTTOMLEFT',16,10);status:SetPoint('BOTTOMRIGHT',-16,10);status:SetHeight(34);status:SetWordWrap(true)
 local function say(v)status:SetText(v or '')end
 local function nativeFrame()return A.isLegacy and AuctionFrame or AuctionHouseFrame end
 local function ready()local f=nativeFrame();return opened and active and parent:IsVisible()and f and f:IsShown()and not InCombatLockdown()end
 local function invoke(fn,...)
  if not ready()then say('Visit an auctioneer outside combat.');return false end
  local ok,result=pcall(fn,...);if not ok then waiting=nil;say('Auction House: '..tostring(result));return false end
  return true,result
 end
 local function request(fn,...)
  if waiting or pending or scanning()then say('Finish the current request, confirmation or price scan first.');return false end
  if A.IsThrottledMessageSystemReady and not A.IsThrottledMessageSystemReady()then say('The Auction House is busy. Try again in a moment.');return false end
  waiting=GetTime();say('Waiting for the Auction House...');return invoke(fn,...)
 end
 local close=button(view,'Close',94,function()if ready()then A.CloseAuctionHouse()end end);close:SetPoint('TOPRIGHT',-12,-10)
 local left=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(left);left:SetPoint('TOPLEFT',10,-108);left:SetPoint('BOTTOMRIGHT',-405,50)
 local right=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(right);right:SetPoint('TOPLEFT',left,'TOPRIGHT',10,0);right:SetPoint('BOTTOMRIGHT',-10,50)
 local categories=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(categories);categories:SetPoint('TOPLEFT',10,-108);categories:SetPoint('BOTTOMLEFT',10,50);categories:SetWidth(184);categories:Hide()
 local catScroll=CreateFrame('ScrollFrame',nil,categories,'UIPanelScrollFrameTemplate');catScroll:SetPoint('TOPLEFT',8,-10);catScroll:SetPoint('BOTTOMRIGHT',-26,12)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(catScroll)end
 local catBody=CreateFrame('Frame',nil,catScroll);catBody:SetSize(146,1);catScroll:SetScrollChild(catBody)
 local catButtons,expanded={},{}
 local pricePanel=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(pricePanel);pricePanel:SetPoint('TOPLEFT',10,-108);pricePanel:SetPoint('BOTTOMRIGHT',-10,50);pricePanel:Hide()
 local input=CreateFrame('EditBox',nil,view,'InputBoxTemplate');input:SetAutoFocus(false);input:SetSize(220,28);input:SetPoint('TOPRIGHT',-158,-67);input:SetMaxLetters(70)
 input:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
 local searchButton=button(view,'Search',88,function()search()end);searchButton:SetPoint('LEFT',input,'RIGHT',9,0)
 local keyboard=WoWUKeyboard.Create(view,{draggable=false})
 local editTarget=input
 local kb=WoWUKeyboard.ToggleButton(view,function()if keyboard:IsShown()then keyboard:Hide()else keyboard:Open(editTarget or input)end end)
 kb:ClearAllPoints();kb:SetPoint('TOPRIGHT',-12,-62)
 input:SetScript('OnEditFocusGained',function()editTarget=input end);input:SetScript('OnEnterPressed',function(s)s:ClearFocus();search()end)
 local tabs={}
 local function cancelPending()
  if pending and pending.kind=='quote'then pcall(A.CancelCommoditiesPurchase)end
  if pending and pending.kind=='postWarning'then pcall(A.CancelSell)end
  pending=nil
 end
 for i,v in ipairs({'Buy','Sell','Auctions','Bids','Prices'})do
  local b=button(view,v,108,function()
   if waiting or pending or scanning()then say('Finish the request, confirmation or scan first.');return end
   if A.ReleaseSellItem then A.ReleaseSellItem()end
   mode=v;chosen=nil;key=nil;page=1;keyboard:Hide();refresh()
   if v=='Auctions'then request(A.QueryOwnedAuctions,{})elseif v=='Bids'then request(A.QueryBids,{},{})end
  end);b:SetPoint('TOPLEFT',14+(i-1)*113,-63);tabs[v]=b
 end
 refreshCategories=function()
  local list={{name='All categories',depth=0}}
  local function append(nodes,depth)
   for _,d in ipairs(nodes or {})do
    local token=d.HasFlag and d:HasFlag('WOW_TOKEN_FLAG')
    list[#list+1]={name=d.name,data=d,depth=depth,token=token}
    if expanded[d]then append(d.subCategories,depth+1)end
   end
  end
  append(AuctionCategories,0)
  for i,d in ipairs(list)do
   local b=catButtons[i]
   if not b then
    b=CreateFrame('Button',nil,catBody,'BackdropTemplate');WoWU_Theme.Button(b);b:SetHeight(32);b:SetPoint('TOPLEFT',0,-(i-1)*35);b:SetPoint('RIGHT',0,0)
    b.label=text(b,12);b.label:SetPoint('LEFT',5,0);b.label:SetPoint('RIGHT',-4,0);b.label:SetJustifyH('LEFT');b.label:SetWordWrap(false)
    b:SetScript('OnClick',function(self)
     if waiting or pending or scanning()then say('Finish the current request or scan first.');return end
     local entry=self.entry
     if entry.token then say('WoW Token uses Blizzard\'s separate purchase interface.');return end
     categoryData=entry.data
     if categoryData and categoryData.subCategories then expanded[categoryData]=not expanded[categoryData]end
     input:SetText('');refreshCategories();search()
    end)
    b:SetScript('OnEnter',function(self)if self.entry then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.entry.name);if self.entry.token then GameTooltip:AddLine('WoW Token uses Blizzard\'s separate purchase interface.',1,.8,.3,true)end;GameTooltip:Show()end end)
    b:SetScript('OnLeave',function()GameTooltip:Hide()end);catButtons[i]=b;WoWUDetails.BindHover(b,false)
   end
   b.entry=d;local prefix=d.data and d.data.subCategories and (expanded[d.data]and '- 'or '+ ')or ''
   b.label:SetText(string.rep(' ',d.depth*2)..prefix..d.name);b.label:SetTextColor(categoryData==d.data and 1 or .85,categoryData==d.data and .82 or .72,.4)
   b:SetEnabled(not d.token);b:Show()
  end
  for i=#list+1,#catButtons do catButtons[i]:Hide()end
  catBody:SetHeight(math.max(1,#list*35));catBody:SetWidth(math.max(90,catScroll:GetWidth()))
 end
 local priceTitle=text(pricePanel,22,'Local Auction House Prices');priceTitle:SetPoint('TOPLEFT',24,-24)
 local priceHelp=text(pricePanel,15,'Scan the full auction catalogue to cache the lowest listed buyout per item and available quantities. Cached asking prices appear on item tooltips, even away from the Auction House.\n\nThis is a snapshot, not a completed-sale value. Equipment tooltips are marked \"any variant\" when item level or suffix can differ. Prices are kept separately for each client and realm.');priceHelp:SetPoint('TOPLEFT',24,-72);priceHelp:SetPoint('TOPRIGHT',-24,-72);priceHelp:SetHeight(138);priceHelp:SetWordWrap(true)
 local scanSummary=text(pricePanel,16);scanSummary:SetPoint('TOPLEFT',24,-235);scanSummary:SetPoint('TOPRIGHT',-24,-235);scanSummary:SetHeight(85);scanSummary:SetWordWrap(true)
 local scanProgress=text(pricePanel,14);scanProgress:SetPoint('TOPLEFT',24,-330);scanProgress:SetPoint('TOPRIGHT',-24,-330);scanProgress:SetHeight(54);scanProgress:SetWordWrap(true)
 local scanStart=button(pricePanel,'Full Scan',140,function()
  if not P then say('Price scanning is unavailable on this client.');return end
  if waiting or pending then say('Finish the current request or confirmation first.');return end
  local ok,message=P.Start(ready)
  if ok then chosen=nil;key=nil;browseReady=false;resultsReady=false end
  say(message);refreshPrices()
 end);scanStart:SetPoint('BOTTOMLEFT',24,24)
 local scanStop=button(pricePanel,'Stop Scan',140,function()if P then P.Stop();refreshPrices()end end);scanStop:SetPoint('LEFT',scanStart,'RIGHT',14,0)
 local tooltipToggle
 tooltipToggle=button(pricePanel,'Tooltip prices: On',190,function()if P then P.SetTooltips(not P.TooltipsEnabled());refreshPrices()end end);tooltipToggle:SetPoint('BOTTOMRIGHT',-24,24)
 refreshPrices=function()
  local snapshot=P and P.Snapshot()
  scanSummary:SetText(snapshot and ('Cached: '..snapshot.itemCount..' items / '..snapshot.variants..' variants\nLast complete scan: '..P.Age(snapshot.seen)..' | '..snapshot.realm)or 'No completed scan for this realm yet.\nVisit an auctioneer and press Full Scan to build the database.')
  scanProgress:SetText(P and P.Status()or 'Full catalogue scanning is unavailable on this client.')
  scanStart:SetEnabled(P~=nil and not scanning()and not waiting and not pending);scanStop:SetEnabled(scanning()and true or false)
  tooltipToggle:SetText('Tooltip prices: '..(P and P.TooltipsEnabled()and 'On'or 'Off'))
 end
 local icon=right:CreateTexture(nil,'ARTWORK');icon:SetSize(60,60);icon:SetPoint('TOPLEFT',18,-18)
 local name=text(right,18,'Select an item');name:SetPoint('TOPLEFT',90,-20);name:SetPoint('TOPRIGHT',-12,-20);name:SetHeight(65);name:SetWordWrap(true)
 local info=text(right,14);info:SetPoint('TOPLEFT',18,-100);info:SetPoint('TOPRIGHT',-18,-100);info:SetHeight(95);info:SetWordWrap(true)
 local function field(caption,y,initial)
  local l=text(right,13,caption);l:SetPoint('TOPLEFT',18,y)
  local e=CreateFrame('EditBox',nil,right,'InputBoxTemplate');e:SetSize(130,30);e:SetPoint('TOPRIGHT',-20,y+5);e:SetAutoFocus(false);e:SetMaxLetters(12);e:SetText(initial or '')
  e:SetScript('OnEditFocusGained',function()editTarget=e end);e:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
  e:SetScript('OnTextChanged',function()if detail then detail()end end);return e,l
 end
 local quantity,qLabel=field('Quantity',-215,'1')
 local price,pLabel=field('Buyout (gold)',-255,'')
 local silver,sLabel=field('Silver',-295,'0');silver:SetNumeric(true)
 local bid,bLabel=field('Starting bid (gold)',-335,'')
 local durationIndex=3;local durations={12,24,48}
 local function durationLabel(index)return A.DurationLabels and A.DurationLabels[index]or durations[index]..' hours'end
 local duration
 duration=button(right,durationLabel(3),140,function()durationIndex=durationIndex%3+1;duration:SetText(durationLabel(durationIndex));detail()end);duration:SetPoint('TOPLEFT',18,-375)
 local action=button(right,'Buy',160,function()end);action:SetPoint('BOTTOMLEFT',16,17)
 local secondary=button(right,'Bid',110,function()end);secondary:SetPoint('BOTTOMRIGHT',-16,17)
 local confirmation=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(confirmation);confirmation:SetFrameLevel(view:GetFrameLevel()+90);confirmation:SetSize(580,250);confirmation:SetPoint('CENTER');confirmation:EnableMouse(true);confirmation:Hide()
 local confirmationText=text(confirmation,16);confirmationText:SetPoint('TOPLEFT',22,-22);confirmationText:SetPoint('BOTTOMRIGHT',-22,75);confirmationText:SetWordWrap(true)
 local accept=button(confirmation,'Confirm',140,function()end);accept:SetPoint('BOTTOMLEFT',24,22)
 local reject=button(confirmation,'Cancel',140,function()cancelPending();confirmation:Hide();detail()end);reject:SetPoint('BOTTOMRIGHT',-24,22)
 local function confirm(message,fn)
  keyboard:Hide();confirmationText:SetText(message);accept:SetScript('OnClick',function()confirmation:Hide();fn()end);confirmation:Show()
 end
 local function itemInfo(k)local d=k and A.GetItemKeyInfo(k);return d or {itemName='Loading item...',iconFileID=134400}end
 local function carried(b,s)
  local d=C_Container.GetContainerItemInfo(b,s);if not d then return end
  local l=ItemLocation:CreateFromBagAndSlot(b,s)
  if not A.IsSellItemValid(l,false)then return end
  return {location=l,bag=b,slot=s,guid=C_Item.GetItemGUID(l),itemKey=A.GetItemKeyFromItem(l),quantity=d.stackCount,itemLink=d.hyperlink,locked=d.isLocked}
 end
 local function fill()
  entries={}
  if mode=='Prices'then return
  elseif mode=='Sell'then
   for b=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do for s=1,C_Container.GetContainerNumSlots(b)do local d=carried(b,s);if d then entries[#entries+1]=d end end end
  elseif mode=='Auctions'then entries=A.GetOwnedAuctions()or {}
  elseif mode=='Bids'then entries=A.GetBids()or {}
  elseif key and resultsReady then
   local count=commodity and A.GetNumCommoditySearchResults(key.itemID)or A.GetNumItemSearchResults(key)
   for i=1,count do local d=commodity and A.GetCommoditySearchResultInfo(key.itemID,i)or A.GetItemSearchResultInfo(key,i);if d then d.itemKey=d.itemKey or key;entries[#entries+1]=d end end
  elseif not key and browseReady then entries=A.GetBrowseResults()or {}end
 end
 local function selectEntry(d)
  if waiting or pending or scanning()then return end
  if mode=='Buy'and not key then
   local k=d.itemKey;if request(A.SendSearchQuery,k,{},true)then key=k;commodity=itemInfo(k).isCommodity;resultsReady=false;page=1;chosen=nil;refresh()end
  else
   if mode=='Sell'and A.SelectSellItem then local ok,err=A.SelectSellItem(d.location);if not ok then say(err);return end end
   chosen=d;quantity:SetText('1');price:SetText('');silver:SetText('0');bid:SetText('');detail()
  end
 end
 for i=1,8 do
  local row=CreateFrame('Button',nil,left,'BackdropTemplate');WoWU_Theme.Button(row);row:SetPoint('TOPLEFT',12,-12-(i-1)*59);row:SetPoint('TOPRIGHT',-12,-12-(i-1)*59);row:SetHeight(55)
  row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(38,38);row.icon:SetPoint('LEFT',8,0)
  row.label=text(row,14);row.label:SetPoint('TOPLEFT',54,-8);row.label:SetPoint('TOPRIGHT',-8,-8);row.label:SetHeight(20)
  row.cost=text(row,12);row.cost:SetPoint('BOTTOMLEFT',54,8)
  row:SetScript('OnClick',function(s)if s.entry then selectEntry(s.entry)end end)
  row:SetScript('OnEnter',function(s)if s.entry then GameTooltip:SetOwner(s,'ANCHOR_RIGHT');if s.entry.itemLink then GameTooltip:SetHyperlink(s.entry.itemLink)else GameTooltip:SetItemByID(s.entry.itemKey.itemID)end;GameTooltip:Show()end end)
  row:SetScript('OnLeave',function()GameTooltip:Hide()end);rows[i]=row;WoWUDetails.BindHover(row,false)
 end
 local pages=text(left,12);pages:SetPoint('BOTTOM',0,19)
 local prev=button(left,'<',44,function()
  if waiting or pending or scanning()then return end
  if page==1 and A.HasPreviousResults and A.HasPreviousResults(mode)then chosen=nil;request(A.PreviousResults,mode)else page=math.max(1,page-1);refresh()end
 end);prev:SetPoint('BOTTOMLEFT',12,9)
 local nextButton=button(left,'>',44,function()page=math.min(math.max(1,math.ceil(#entries/capacity)),page+1);refresh()end);nextButton:SetPoint('BOTTOMRIGHT',-12,9)
 local back=button(view,'Results',90,function()if waiting or pending or scanning()then return end;key=nil;chosen=nil;page=1;refresh()end);back:SetPoint('BOTTOMLEFT',14,9)
 local more=button(view,'Load more',110,function()
  if mode=='Buy'then if not key then request(A.RequestMoreBrowseResults)elseif commodity then request(A.RequestMoreCommoditySearchResults,key.itemID)else request(A.RequestMoreItemSearchResults,key)end
  elseif A.isLegacy and mode=='Auctions'then chosen=nil;request(A.RequestMoreOwned)
  elseif A.isLegacy and mode=='Bids'then chosen=nil;request(A.RequestMoreBids)end
 end);more:SetPoint('LEFT',back,'RIGHT',8,0)
 local reload=button(view,'Refresh',100,function()search()end);reload:SetPoint('LEFT',more,'RIGHT',8,0)
 local function buyoutPrice()local g=tonumber(price:GetText());local s=number(silver:GetText());if not g or g<0 or g>=1e8 or not s or s>99 then return end;return math.floor(g*10000+.5)+s*100 end
 local function postDetails(d)
  local current=d and carried(d.bag,d.slot);local n=number(quantity:GetText());local p=buyoutPrice();local b=tonumber(bid:GetText())
  if not current or current.guid~=d.guid or (current.locked and not(A.IsSelectedSellItem and A.IsSelectedSellItem(current.location)))or not n or n<1 or n>current.quantity or not p or p<1 then return end
  local c=itemInfo(current.itemKey).isCommodity
  if c and p%100~=0 then return end
  b=b and number(b*10000)or nil;if b and b>p then return end
  local deposit
  if A.CalculatePostDeposit then deposit=A.CalculatePostDeposit(current.location,durationIndex,n,b,p)else deposit=c and A.CalculateCommodityDeposit(current.itemKey.itemID,durationIndex,n)or A.CalculateItemDeposit(current.location,durationIndex,n)end
  if not deposit or deposit>GetMoney()then return end
  return {item=current,n=n,p=p,b=b,duration=durationIndex,commodity=c,deposit=deposit}
 end
 detail=function()
  local d=chosen;local data=itemInfo(d and d.itemKey or key);name:SetText((d or key)and data.itemName or 'Select an item');icon:SetTexture((d or key)and data.iconFileID or nil)
  funds:SetText(money(GetMoney()));action:Disable();secondary:Hide()
  quantity:SetShown(mode=='Sell'or(mode=='Buy'and commodity and key~=nil));qLabel:SetShown(quantity:IsShown())
  for _,f in ipairs({price,pLabel,silver,sLabel,bid,bLabel,duration})do f:SetShown(mode=='Sell')end
  info:SetText('Choose a category on the left or search for an item, then tap a result to see its auctions.\n\nUse the keyboard button to type into the last selected field.')
  if not d then return end
  info:SetText((d.itemLink or data.itemName)..'\n\nQuantity: '..(d.quantity or d.totalQuantity or 1)..'\n'..money(d.unitPrice or d.buyoutAmount or d.minPrice or d.bidAmount or 0))
  if mode=='Sell'then
   local c=data.isCommodity;pLabel:SetText(c and 'Unit price (gold)'or 'Buyout (gold)');bid:SetShown(not c);bLabel:SetShown(not c);action:SetText('Post Auction')
   local p=postDetails(d);if p then info:SetText(data.itemName..'\n\nDeposit: '..money(p.deposit)..'\nTotal buyout: '..money(p.commodity and p.p*p.n or p.p))end;action:SetEnabled(p~=nil and not waiting and not pending)
  elseif mode=='Auctions'then action:SetText('Cancel Auction');action:SetEnabled(A.CanCancelAuction(d.auctionID)and not waiting and not pending)
  elseif mode=='Bids'then action:SetText('Refresh bids')
  else
   action:SetText(commodity and 'Get purchase quote'or 'Buyout');action:SetEnabled(not d.containsOwnerItem and not d.containsAccountItem and (commodity or (d.buyoutAmount or 0)>0)and not waiting and not pending)
   if not commodity and d.minBid then secondary:Show();secondary:SetText('Bid');secondary:SetEnabled(not d.containsOwnerItem and not d.containsAccountItem and not waiting and not pending)end
  end
 end
 refresh=function()
  if not active then return end
  local isBuy=mode=='Buy';local isPrices=mode=='Prices'
  pricePanel:SetShown(isPrices);categories:SetShown(isBuy);left:SetShown(not isPrices);right:SetShown(not isPrices)
  input:SetShown(isBuy);searchButton:SetShown(isBuy);back:SetShown(isBuy and key~=nil);more:SetShown(isBuy);reload:SetShown(not isPrices)
  for v,b in pairs(tabs)do b:SetEnabled(v~=mode and not scanning())end
  if isPrices then refreshPrices();return end
  if layoutMode~=isBuy then
   layoutMode=isBuy;left:ClearAllPoints();left:SetPoint('TOPLEFT',isBuy and 202 or 10,-108);left:SetPoint('BOTTOMRIGHT',-405,50)
  end
  if isBuy then refreshCategories()end
  fill();capacity=math.max(1,math.min(8,math.floor((left:GetHeight()-62)/59)));page=math.min(page,math.max(1,math.ceil(#entries/capacity)))
  for i,r in ipairs(rows)do
   local d=i<=capacity and entries[(page-1)*capacity+i]or nil;r.entry=d;r:SetShown(d~=nil)
   if d then local data=itemInfo(d.itemKey);r.icon:SetTexture(data.iconFileID);r.label:SetText(data.itemName);r.cost:SetText('x'..(d.quantity or d.totalQuantity or 1)..'   '..(d.priceIsBidOnly and 'Bid from 'or '')..money(d.unitPrice or d.buyoutAmount or d.minPrice or d.bidAmount or 0))end
  end
  pages:SetText(#entries==0 and 'No results' or page..' / '..math.ceil(#entries/capacity));back:SetShown(mode=='Buy'and key~=nil);more:SetShown(mode=='Buy');input:SetShown(mode=='Buy');searchButton:SetShown(mode=='Buy')
  more:SetText(A.isLegacy and 'Next AH page'or 'Load more')
  for v,b in pairs(tabs)do b:SetEnabled(v~=mode)end;detail()
  local full=mode=='Buy'and (key and (commodity and A.HasFullCommoditySearchResults(key.itemID)or not commodity and A.HasFullItemSearchResults(key))or not key and A.HasFullBrowseResults())
  more:SetEnabled(mode=='Buy'and not full and not waiting and not pending)
  if A.isLegacy and (mode=='Auctions'or mode=='Bids')then more:Show();more:SetEnabled(A.HasMoreResults(mode)and not waiting and not pending)end
 end
 search=function()
  if waiting or pending or scanning()then say('Finish the current request, confirmation or scan first.');return end
  if mode=='Buy'then
   local filters={};if categoryData and categoryData.implicitFilter then filters[1]=categoryData.implicitFilter end
   request(A.SendBrowseQuery,{searchString=input:GetText(),sorts={},filters=filters,itemClassFilters=categoryData and categoryData.filters})
   key=nil;chosen=nil;page=1;browseReady=false;resultsReady=false;refresh()
  elseif mode=='Auctions'then request(A.QueryOwnedAuctions,{})elseif mode=='Bids'then request(A.QueryBids,{},{})elseif not waiting and not pending then chosen=nil;refresh()end
 end
 local function placeBid(d,amount)
  if not amount or amount<=0 or amount>GetMoney()then say('Insufficient money or invalid price.');return end
  pending={kind='bid'};detail()
  confirm('Buy / bid for '..(d.itemLink or itemInfo(d.itemKey).itemName)..'\n\nTotal: '..money(amount),function()
   pending=nil;local now=A.GetAuctionInfoByID(d.auctionID)
   if not ready()or not now or not sameKey(now.itemKey,d.itemKey)or now.buyoutAmount~=d.buyoutAmount or now.bidAmount~=d.bidAmount or now.minBid~=d.minBid then say('The auction changed. Refresh before buying or bidding.');detail();return end
   if amount>GetMoney()then say('Insufficient money.');return end
   request(A.PlaceBid,d.auctionID,amount);detail()
  end)
 end
 secondary:SetScript('OnClick',function()if ready()and chosen and not waiting and not pending and not scanning()then placeBid(chosen,chosen.minBid)end end)
 action:SetScript('OnClick',function()
  if not ready()or not chosen or waiting or pending or scanning()then return end
  local d=chosen
  if mode=='Buy'then
   if commodity then
    local n=number(quantity:GetText());if not n or n<1 then say('Enter a whole quantity greater than zero.');return end
    pending={kind='quote',id=key.itemID,n=n,at=GetTime()};say('Requesting a current purchase quote...');invoke(A.StartCommoditiesPurchase,key.itemID,n);detail()
   else placeBid(d,d.buyoutAmount)end
  elseif mode=='Auctions'then
   local cost=A.GetCancelCost(d.auctionID);pending={kind='cancel'};detail()
   confirm('Cancel '..(d.itemLink or itemInfo(d.itemKey).itemName)..'?\n\nCancellation fee: '..money(cost)..'\nThe deposit is not returned.',function()
    pending=nil;if ready()and A.CanCancelAuction(d.auctionID)and A.GetCancelCost(d.auctionID)==cost and cost<=GetMoney()then request(A.CancelAuction,d.auctionID)else say('The auction changed; refresh it first.')end;detail()
   end)
  elseif mode=='Sell'then
   local p=postDetails(d);if not p then say('Check the stack, quantity and prices.');return end
   pending={kind='post'};detail()
   confirm('Post '..p.n..' x '..itemInfo(d.itemKey).itemName..'?\n\nBuyout: '..money(p.commodity and p.p*p.n or p.p)..'\nDeposit: '..money(p.deposit)..'\nDuration: '..durationLabel(p.duration),function()
    pending=nil;local now=postDetails(d)
    if not ready()or not now or now.item.guid~=p.item.guid or now.n~=p.n or now.p~=p.p or now.b~=p.b or now.duration~=p.duration or now.deposit~=p.deposit then say('The item or posting details changed. Select it again.');detail();return end
    local args=p.commodity and {p.item.location,p.duration,p.n,p.p}or {p.item.location,p.duration,p.n,p.b,p.p}
    local ok,warning=invoke(p.commodity and A.PostCommodity or A.PostItem,unpack(args,1,p.commodity and 4 or 5))
    if ok and warning then
     pending={kind='postWarning'}
     confirm(A.PostWarningText or AUCTION_HOUSE_POST_WARNING or 'Posting removes this item\'s refund or trade eligibility. Continue?',function()
      pending=nil;if ready()and C_Item.GetItemGUID(p.item.location)==p.item.guid then waiting=GetTime();invoke(p.commodity and A.ConfirmPostCommodity or A.ConfirmPostItem,unpack(args,1,p.commodity and 4 or 5))end;detail()
     end)
    elseif ok then waiting=GetTime();say('Posting auction...')end;detail()
   end)
  end
 end)
 local function restore()
  local f=nativeFrame();if native and f then f:ClearAllPoints();for _,p in ipairs(native.points)do f:SetPoint(unpack(p))end;f:SetClampedToScreen(native.clamped)end;native=nil
 end
 local function park()
  local f=nativeFrame();if not f or not f:IsShown()then return end
  if not native then native={points={},clamped=f:IsClampedToScreen()};for i=1,f:GetNumPoints()do native.points[i]={f:GetPoint(i)}end end
  f:SetClampedToScreen(false);f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-5000)
 end
 deactivate=function()
  if not active then return end;if scanning()then P.Stop('Scan interrupted by leaving the Auction House page. Previous prices retained.',true)end;cancelPending();if A.ReleaseSellItem then A.ReleaseSellItem()end;waiting=nil;active=false;confirmation:Hide();keyboard:Hide();view:Hide();restore();for _,f in ipairs(normalFrames)do f:Show()end
 end
 activate=function()
  if not opened or InCombatLockdown()or not WoWU_MainFrame or not WoWU_MainFrame:IsVisible()then return end
  if WoWUInteractions then WoWUInteractions.Release()end
  if not parent:IsVisible()then WoWU_ShowPage('Bags')end
  local f=nativeFrame();if not parent:IsVisible()or not f or not f:IsShown()then return end
  if not active then
   if parent.WoWUDeactivateBank then parent.WoWUDeactivateBank()end;if parent.WoWUDeactivateMerchant then parent.WoWUDeactivateMerchant()end
   active=true;mode='Buy';key=nil;chosen=nil;waiting=nil;page=1;browseReady=false;resultsReady=false;for _,f in ipairs(normalFrames)do f:Hide()end;view:Show();say('Search for an item to begin. Purchases and posting require confirmation.')
  end;park();refresh()
 end
 parent:HookScript('OnHide',deactivate);parent:HookScript('OnShow',function()if opened then C_Timer.After(0,activate)end end)
 parent.WoWUDeactivateAuctionHouse=deactivate
 WoWUAuctionHouse.ShowOwned=function()
  if not opened or InCombatLockdown()then return false,'Visit an auctioneer outside combat to view your auctions.'end
  activate();if not active then return false,'The auctioneer session is no longer available.'end
  if waiting or pending or scanning()then say('Finish the request, confirmation or scan first.');return false,'Finish the current Auction House request first.'end
  if A.ReleaseSellItem then A.ReleaseSellItem()end
  mode='Auctions';chosen=nil;key=nil;page=1;keyboard:Hide();refresh();request(A.QueryOwnedAuctions,{})
  return true
 end
 WoWUAuctionHouse.Back=function()
  if not active then return false end
  if scanning()then P.Stop();refreshPrices();return true end
  if pending then cancelPending();confirmation:Hide();detail()else A.CloseAuctionHouse()end
  return true
 end
 local events=CreateFrame('Frame')
 for _,e in ipairs({'AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','AUCTION_HOUSE_BROWSE_RESULTS_UPDATED','AUCTION_HOUSE_BROWSE_RESULTS_ADDED','ITEM_SEARCH_RESULTS_UPDATED','ITEM_SEARCH_RESULTS_ADDED','COMMODITY_SEARCH_RESULTS_UPDATED','COMMODITY_SEARCH_RESULTS_ADDED','OWNED_AUCTIONS_UPDATED','BIDS_UPDATED','COMMODITY_PRICE_UPDATED','COMMODITY_PRICE_UNAVAILABLE','COMMODITY_PURCHASE_FAILED','COMMODITY_PURCHASE_SUCCEEDED','AUCTION_HOUSE_PURCHASE_COMPLETED','AUCTION_HOUSE_AUCTION_CREATED','AUCTION_CANCELED','BAG_UPDATE_DELAYED','PLAYER_MONEY','GET_ITEM_INFO_RECEIVED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','UI_ERROR_MESSAGE'})do pcall(events.RegisterEvent,events,e)end
 events:SetScript('OnEvent',function(_,e,a,b)
  if e=='AUCTION_HOUSE_SHOW'then opened=true;C_Timer.After(0,activate);return elseif e=='AUCTION_HOUSE_CLOSED'then opened=false;deactivate();return elseif e=='PLAYER_REGEN_DISABLED'then deactivate();return elseif e=='PLAYER_REGEN_ENABLED'then if opened then activate()end;return end
  if not active then return end
  if scanning()then if mode=='Prices'then refreshPrices()end;return end
  if e=='COMMODITY_PRICE_UPDATED'and pending and pending.kind=='quote'then
   local p=pending;p.unit=a;p.total=b;p.at=GetTime()
   confirm('Buy '..p.n..' x '..itemInfo(key).itemName..'?\n\nCurrent total: '..money(b)..'\nConfirm within 10 seconds.',function()
    if pending~=p or not ready()or GetTime()-p.at>10 or p.total>GetMoney()then cancelPending();say('Quote expired or insufficient money. Request another quote.');detail();return end
    pending=nil;waiting=GetTime();invoke(A.ConfirmCommoditiesPurchase,p.id,p.n);detail()
   end)
  elseif e=='COMMODITY_PRICE_UNAVAILABLE'or e=='COMMODITY_PURCHASE_FAILED'then cancelPending();waiting=nil;confirmation:Hide();say('Purchase unavailable. Refresh and request a new quote.')
  elseif e=='COMMODITY_PURCHASE_SUCCEEDED'or e=='AUCTION_HOUSE_PURCHASE_COMPLETED'then waiting=nil;chosen=nil;resultsReady=false;say('Purchase completed. Items arrive through the mail. Refresh to buy again.')
  elseif e=='AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'or e=='AUCTION_HOUSE_BROWSE_RESULTS_ADDED'then if mode=='Buy'and not key then browseReady=true;waiting=nil;say('Tap an item to view its auctions.')end
  elseif e=='ITEM_SEARCH_RESULTS_UPDATED'or e=='ITEM_SEARCH_RESULTS_ADDED'then if mode=='Buy'and sameKey(a,key)then resultsReady=true;waiting=nil;say('Select an auction. Prices are checked again before purchase.')end
  elseif e=='COMMODITY_SEARCH_RESULTS_UPDATED'or e=='COMMODITY_SEARCH_RESULTS_ADDED'then if key and key.itemID==a then resultsReady=true;waiting=nil;say('Select a price row, then enter the quantity to buy. The quote gives the actual total.')end
  elseif e=='OWNED_AUCTIONS_UPDATED'or e=='BIDS_UPDATED'then waiting=nil
  elseif e=='AUCTION_HOUSE_AUCTION_CREATED'or e=='AUCTION_CANCELED'then waiting=nil;chosen=nil;say('Auction updated. Refresh Auctions to see the latest listings.')
  elseif e=='AUCTION_HOUSE_BROWSE_FAILURE'then waiting=nil;chosen=nil;resultsReady=false;browseReady=false;say('The auction query was interrupted or timed out. Search or refresh again.')
  elseif e=='UI_ERROR_MESSAGE'then waiting=nil;if pending and pending.kind=='quote'then cancelPending();confirmation:Hide()end;say(tostring(b or a))end
  refresh()
 end)
 if A.Subscribe then A.Subscribe(events:GetScript('OnEvent'))end
 local elapsed=0
 left:HookScript('OnSizeChanged',function()if active then refresh()end end)
 view:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0
  if mode=='Prices'then refreshPrices();for v,b in pairs(tabs)do b:SetEnabled(v~=mode and not scanning())end end
  if waiting and GetTime()-waiting>15 then waiting=nil;say('No response yet. Refresh to check the result before trying again.');detail()end
  if pending and pending.kind=='quote'and GetTime()-pending.at>10 then cancelPending();confirmation:Hide();say('Purchase quote expired. Request another quote.');detail()end
 end)
end
