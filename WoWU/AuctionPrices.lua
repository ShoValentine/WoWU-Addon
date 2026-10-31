-- User-started, paged modern-AH catalogue scans. Prices are asking prices, not sales.
WoWUAuctionPrices={}
local P=WoWUAuctionPrices
local A=WoWUAuctionAPI or C_AuctionHouse
local job,lastAttempt,lastMessage=nil,nil,'No scan started this session.'
local sending=false
local function public(v)return not issecretvalue or not issecretvalue(v)end
local function numeric(v)return public(v)and type(v)=='number'and v==v and v>=0 and v<1e15 end
local function db()
 if type(WoWUPricesDB)~='table'then WoWUPricesDB={}end
 if WoWUPricesDB.version~=1 then WoWUPricesDB={version=1,markets={},tooltips=true}end
 if type(WoWUPricesDB.markets)~='table'then WoWUPricesDB.markets={}end
 return WoWUPricesDB
end
local function market()
 local region=GetCurrentRegion and GetCurrentRegion()or 0
 local realm=GetNormalizedRealmName and GetNormalizedRealmName()or GetRealmName()or 'Unknown'
 local flavor=WoWUClient and WoWUClient.name or tostring(WOW_PROJECT_ID or 0)
 local faction=WoWUClient and WoWUClient.isRetail and 'shared'or (UnitFactionGroup('player')or 'Unknown')
 local base=table.concat({flavor,tostring(region),realm,faction},'|')
 if A and A.isLegacy and A.PriceScope then
  local scope,label=A.PriceScope();local root=db();root.lastMarkets=root.lastMarkets or {}
  if scope then root.lastMarkets[base]={scope=scope,label=label}else local saved=root.lastMarkets[base];scope=saved and saved.scope;label=saved and saved.label end
  if scope then return base..'|'..scope,realm..' / '..(label or 'Auctioneer')end
 end
 return base,realm
end
function P.Age(stamp)
 local age=math.max(0,time()-(stamp or 0))
 if age<60 then return 'just now'elseif age<3600 then return math.floor(age/60)..' min ago'elseif age<86400 then return math.floor(age/3600)..' hr ago'else return math.floor(age/86400)..' days ago'end
end
function P.Snapshot()local id=market();return db().markets[id]end
function P.TooltipsEnabled()return db().tooltips~=false end
function P.SetTooltips(value)db().tooltips=not not value end
function P.IsBusy()return job~=nil end
function P.Status()
 if not job then return lastMessage end
 if job.cancel then return 'Stopping scan; waiting for the outstanding response...'end
 if job.phase=='processing'then return 'Caching prices: '..math.min(job.index-1,#job.rows)..' / '..#job.rows..' item variants'end
 return 'Fetching the full catalogue - '..job.pages..' responses received. Waiting for the Auction House...'
end
local function finish(message)
 job=nil;lastMessage=message
end
function P.Stop(message,immediate)
 if not job then return end
 if immediate or job.phase=='processing'or not job.awaiting then finish(message or 'Scan cancelled. Previous prices retained.')
 else job.cancel=message or 'Scan cancelled. Previous prices retained.'end
end
local function send(fn,...)
 if not job then return false end
 sending=true;job.awaiting=true;job.sent=GetTime()
 local ok,err=pcall(fn,...);sending=false
 if not ok then finish('Scan stopped: '..tostring(err)..'. Previous prices retained.');return false end
 return true
end
function P.Start(ready)
 if job then return false,'A scan is already running.'end
 if type(ready)~='function'or not ready()then return false,'Visit an auctioneer outside combat to scan.'end
 if not A or not A.SendBrowseQuery or not A.HasFullBrowseResults then return false,'Full catalogue scans are unavailable on this client.'end
 if lastAttempt and GetTime()-lastAttempt<60 then return false,'Wait '..math.ceil(60-(GetTime()-lastAttempt))..' seconds before starting another scan.'end
 if A.IsThrottledMessageSystemReady and not A.IsThrottledMessageSystemReady()then return false,'The Auction House is busy. Try the scan again shortly.'end
 local id,realm=market();lastAttempt=GetTime()
 job={market=id,realm=realm,ready=ready,phase='fetching',started=GetTime(),pages=0,nextRequest=0,awaiting=false}
 if not send(A.SendBrowseQuery,{searchString='',sorts={},filters={}})then return false,lastMessage end
 return true,P.Status()
end
local function addRow(j,d)
 local k=d.itemKey
 if not k or d.priceIsBidOnly or not numeric(k.itemID)or k.itemID<1 or not numeric(d.minPrice)or d.minPrice<=0 or not numeric(d.totalQuantity)then return end
 local variant=table.concat({k.itemID,k.itemLevel or 0,k.itemSuffix or 0,k.battlePetSpeciesID or 0},':')
 if j.records[variant]then return end
 local price=math.floor(d.minPrice)
 j.records[variant]={price=price,quantity=d.totalQuantity};j.variants=j.variants+1
 local item=j.items[k.itemID]
 if not item then item={price=price,quantity=0,variants=0};j.items[k.itemID]=item;j.itemCount=j.itemCount+1 end
 item.price=math.min(item.price,price);item.quantity=item.quantity+d.totalQuantity;item.variants=item.variants+1
 if (k.itemLevel or 0)~=0 or (k.itemSuffix or 0)~=0 then item.varied=true end
 if (k.battlePetSpeciesID or 0)~=0 then item.pet=true end
end
local function event(_,name)
 if not job then return end
 if name=='AUCTION_HOUSE_CLOSED'or name=='PLAYER_REGEN_DISABLED'or name=='PLAYER_LOGOUT'then P.Stop('Scan interrupted. Previous prices retained.',true);return end
 if name=='AUCTION_HOUSE_BROWSE_FAILURE'or name=='AUCTION_HOUSE_DISABLED'or name=='AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED'then P.Stop('The Auction House could not complete the scan. Previous prices retained.',true);return end
 if (name=='AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'or name=='AUCTION_HOUSE_BROWSE_RESULTS_ADDED')and job.phase=='fetching'then
  if job.cancel then finish(job.cancel);return end
  job.awaiting=false;job.pages=job.pages+1;job.nextRequest=GetTime()+1
  if A.HasFullBrowseResults()then
   job.phase='processing';job.rows=A.GetBrowseResults()or {};job.index=1;job.records={};job.items={};job.variants=0;job.itemCount=0
  end
 end
end
local events=CreateFrame('Frame')
for _,e in ipairs({'AUCTION_HOUSE_CLOSED','PLAYER_REGEN_DISABLED','PLAYER_LOGOUT','AUCTION_HOUSE_BROWSE_RESULTS_UPDATED','AUCTION_HOUSE_BROWSE_RESULTS_ADDED','AUCTION_HOUSE_BROWSE_FAILURE','AUCTION_HOUSE_DISABLED','AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED'})do pcall(events.RegisterEvent,events,e)end
events:SetScript('OnEvent',function(...)
 local ok,err=pcall(event,...);if not ok then finish('Scan stopped: '..tostring(err)..'. Previous prices retained.')end
end)
if A and A.Subscribe then A.Subscribe(events:GetScript('OnEvent'))end
local function update()
 local j=job;if not j then return end
 if not j.ready()or market()~=j.market then P.Stop('Scan interrupted. Previous prices retained.',true);return end
 if GetTime()-j.started>(A.isLegacy and 7200 or 600)or (j.awaiting and GetTime()-j.sent>40)then finish('Scan timed out. Previous prices retained; try again later.');return end
 if j.phase=='processing'then
  -- At most 100 rows and about 3 ms of Lua work per frame. No model/item loads.
  local start=debugprofilestop and debugprofilestop()or 0
  for _=1,100 do
   local d=j.rows[j.index]
   if not d then
    local snapshot={seen=time(),realm=j.realm,records=j.records,items=j.items,variants=j.variants,itemCount=j.itemCount,source='browse'}
    db().markets[j.market]=snapshot
    finish('Scan complete: '..j.itemCount..' items / '..j.variants..' variants cached.');return
   end
   addRow(j,d);j.index=j.index+1
   if debugprofilestop and debugprofilestop()-start>=3 then break end
  end
 elseif not j.awaiting and GetTime()>=j.nextRequest and (not A.IsThrottledMessageSystemReady or A.IsThrottledMessageSystemReady())then send(A.RequestMoreBrowseResults)end
end
events:SetScript('OnUpdate',function()
 if not job then return end
 local ok,err=pcall(update);if not ok then finish('Scan stopped: '..tostring(err)..'. Previous prices retained.')end
end)
-- A different addon's query changes the shared result set. Never publish a mixed scan.
if A and hooksecurefunc then
 for _,name in ipairs({'SendBrowseQuery','SendSearchQuery','SendSellSearchQuery','SearchForFavorites','SearchForItemKeys','ReplicateItems'})do
  if type(A[name])=='function'then hooksecurefunc(A,name,function()if job and not sending then P.Stop('Scan interrupted by another Auction House query. Previous prices retained.',true)end end)end
 end
end
function P.Lookup(itemID)
 local s=P.Snapshot();local d=s and s.items and s.items[itemID]
 -- Pet cages share an item ID across different species. Do not misprice them.
 if d and not d.pet and numeric(d.price)and d.price>0 then return d,s end
end
local hooked=setmetatable({},{__mode='k'})
local function tooltip(t,data)
 if not P.TooltipsEnabled()or not t or not t.AddDoubleLine then return end
 if data and t.GetPrimaryTooltipData and t:GetPrimaryTooltipData()~=data then return end
 local _,link=t:GetItem()
 if not public(link)or type(link)~='string'then return end
 local id=tonumber(link:match('item:(%d+)'));if not id then return end
 local d,s=P.Lookup(id);if not d then return end
 if not hooked[t]then
  local ok=pcall(t.HookScript,t,'OnTooltipCleared',function(self)self.WoWUAHPriceStamp=nil end);hooked[t]=ok
 end
 local stamp=id..':'..s.seen
 if t.WoWUAHPriceStamp==stamp then return end
 t.WoWUAHPriceStamp=stamp
 t:AddDoubleLine(d.varied and 'WoWU AH low (any variant)'or 'WoWU AH low (each)',GetMoneyString(d.price),1,.82,.3,1,1,1)
 local stale=time()-s.seen>=86400
 t:AddLine('Scanned '..P.Age(s.seen)..(stale and ' - stale price'or '')..' | '..s.realm,.65,.65,.65,true)
end
-- Only enrich existing item tooltips. Tooltip reads never issue Auction House queries.
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
 TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(t,d)pcall(tooltip,t,d)end)
else
 function P.AttachTooltip(t)if t and not hooked[t]then t:HookScript('OnTooltipSetItem',function(self)pcall(tooltip,self)end);t:HookScript('OnTooltipCleared',function(self)self.WoWUAHPriceStamp=nil end);hooked[t]=true end end
 P.AttachTooltip(GameTooltip);P.AttachTooltip(ItemRefTooltip)
end
