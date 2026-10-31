-- WoWU-local backend for current Blizzard Classic clients. Never replaces API globals.
WoWUAuctionAPI=C_AuctionHouse
if not (WoWUClient and WoWUClient.isClassic and type(QueryAuctionItems)=='function')then return end
local A={isLegacy=true}
A.DurationLabels={AUCTION_DURATION_ONE or 'Short',AUCTION_DURATION_TWO or 'Medium',AUCTION_DURATION_THREE or 'Long'}
A.PostWarningText=CONFIRM_AUCTION_POSTING_TEXT and CONFIRM_AUCTION_POSTING_TEXT:gsub('|n','\n')or 'Scheduled Auction House maintenance may return this auction early without refunding its deposit. Continue?'
WoWUAuctionAPI=A
local listeners,metadata,tokens={},{},{}
local serial,inside=0,false
local generation={list=0,owner=0,bidder=0}
local results,groups,seenPages={},{},{}
local query,request,pollAt=nil,nil,0
local currentRows,hasFull={},false
local selectedSell,postError
local ownerPage,bidPage=0,0
local function emit(name,...)
 for _,fn in ipairs(listeners)do local ok,err=pcall(fn,nil,name,...);if not ok and not A.reported then A.reported=true;print('WoWU Classic auctions: '..tostring(err))end end
end
function A.Subscribe(fn)listeners[#listeners+1]=fn end
local function keyID(k)return table.concat({k.itemID,k.itemLevel or 0,k.itemSuffix or 0,k.battlePetSpeciesID or 0},':')end
local function itemKey(id,link)
 local suffix=link and tonumber(link:match('item:%d+:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]+)'))or 0
 return {itemID=id,itemLevel=0,itemSuffix=suffix or 0,battlePetSpeciesID=0}
end
local function info(kind,index)
 local name,icon,count,quality,usable,level,header,minBid,increment,buyout,bid,highBidder,bidder,owner,ownerFull,status,id,complete=GetAuctionItemInfo(kind,index)
 local link=GetAuctionItemLink(kind,index)
 if not name or not id or not link or not count or count<1 or complete==false then return end
 local k=itemKey(id,link);metadata[keyID(k)]={itemName=name,iconFileID=icon,quality=quality,isCommodity=false,itemID=id}
 local player=UnitName('player');local full=GetUnitName and GetUnitName('player',true)or player
 local own=owner==player or ownerFull==full
 local d={itemKey=k,itemLink=link,quantity=count,minBid=(bid or 0)>0 and bid+(increment or 0)or minBid,bidAmount=bid,buyoutAmount=buyout,containsOwnerItem=not not own,containsAccountItem=false,status=status,owner=ownerFull or owner,bidder=bidder,highBidder=highBidder,index=index,kind=kind}
 d.fingerprint=table.concat({link,count,minBid or 0,increment or 0,buyout or 0,bid or 0,d.owner or '',status or 0},'|')
 return d
end
local function token(d)
 serial=serial+1;d.auctionID=serial
 tokens[serial]={kind=d.kind,index=d.index,generation=generation[d.kind],fingerprint=d.fingerprint}
 return d
end
local function resolve(id)
 local t=tokens[id];if not t or t.generation~=generation[t.kind]or request then return end
 local d=info(t.kind,t.index);if d and d.fingerprint==t.fingerprint then return d end
end
local function call(fn,...)
 inside=true;local ok,result=pcall(fn,...);inside=false
 if not ok then error(result)end
 return result
end
local function send(page)
 if not query then error('Choose a search first.')end
 if not CanSendAuctionQuery()then error('The Auction House is busy. Try again shortly.')end
 generation.list=generation.list+1
 query.page=page;request={sent=GetTime(),updated=nil};pollAt=0
 local ok,err=pcall(call,QueryAuctionItems,query.text,query.min,query.max,page,false,nil,false,query.exact,query.filters)
 if not ok then request=nil;error(err)end
end
function A.SendBrowseQuery(q)
 query={text=q.searchString or '',min=q.minLevel,max=q.maxLevel,filters=q.itemClassFilters,page=0,exact=false,kind='browse'}
 results,groups,seenPages,currentRows={},{},{},{};hasFull=false
 send(0)
end
function A.SendSearchQuery(k)
 local m=A.GetItemKeyInfo(k)
 local base=C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(k.itemID)
 query={text=base or m.itemName,exact=true,page=0,kind='items',key=k};currentRows={};hasFull=false
 send(0)
end
function A.RequestMoreBrowseResults()send((query and query.page or 0)+1)end
A.RequestMoreItemSearchResults=A.RequestMoreBrowseResults
function A.HasFullBrowseResults()return hasFull end
function A.HasFullItemSearchResults()return hasFull end
function A.GetBrowseResults()return results end
function A.GetNumItemSearchResults()return #currentRows end
function A.GetItemSearchResultInfo(_,index)return currentRows[index]end
function A.IsThrottledMessageSystemReady()return request==nil and not not CanSendAuctionQuery()end
function A.PreviousResults(mode)
 if mode=='Auctions'then ownerPage=math.max(0,ownerPage-1);generation.owner=generation.owner+1;call(GetOwnerAuctionItems,ownerPage)
 elseif mode=='Bids'then bidPage=math.max(0,bidPage-1);generation.bidder=generation.bidder+1;call(GetBidderAuctionItems,bidPage)
 elseif query and query.page>0 then send(query.page-1)end
end
function A.HasPreviousResults(mode)return mode=='Auctions'and ownerPage>0 or mode=='Bids'and bidPage>0 or mode=='Buy'and query and query.page>0 end
function A.HasMoreResults(mode)
 local kind=mode=='Auctions'and 'owner'or 'bidder';local _,total=GetNumAuctionItems(kind)
 return ((mode=='Auctions'and ownerPage or bidPage)+1)*50<(total or 0)
end
function A.RequestMoreOwned()ownerPage=ownerPage+1;generation.owner=generation.owner+1;call(GetOwnerAuctionItems,ownerPage)end
function A.RequestMoreBids()bidPage=bidPage+1;generation.bidder=generation.bidder+1;call(GetBidderAuctionItems,bidPage)end
function A.GetItemKeyInfo(k)
 local m=metadata[keyID(k)];if m then return m end
 local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
 local n,_,q,_,_,_,_,_,_,icon=fn(k.itemID)
 return {itemName=n or 'Loading item...',iconFileID=icon or 134400,quality=q,isCommodity=false,itemID=k.itemID}
end
function A.GetItemKeyFromItem(loc)
 local b,s=loc:GetBagAndSlot();local d=C_Container.GetContainerItemInfo(b,s)
 return d and itemKey(d.itemID,d.hyperlink)
end
function A.GetAuctionInfoByID(id)return resolve(id)end
function A.PlaceBid(id,amount)
 local d=resolve(id);if not d or d.kind~='list'or d.containsOwnerItem or d.highBidder then error('The auction list changed. Select the auction again.')end
 if amount~=d.buyoutAmount and amount~=d.minBid then error('The auction price changed. Select it again.')end
 if amount<=0 or amount>GetMoney()then error('Insufficient money or invalid bid.')end
 call(PlaceAuctionBid,'list',d.index,amount)
end
local function list(kind)
 local rows={};for i=1,GetNumAuctionItems(kind)do local d=info(kind,i);if d then rows[#rows+1]=token(d)end end;return rows
end
function A.QueryOwnedAuctions()ownerPage=0;generation.owner=generation.owner+1;call(GetOwnerAuctionItems,0)end
function A.QueryBids()bidPage=0;generation.bidder=generation.bidder+1;call(GetBidderAuctionItems,0)end
function A.GetOwnedAuctions()return list('owner')end
function A.GetBids()return list('bidder')end
function A.CanCancelAuction(id)local d=resolve(id);return d and d.kind=='owner'and not not CanCancelAuction(d.index)or false end
function A.GetCancelCost(id)local d=resolve(id);return d and math.floor((d.bidAmount or 0)*.05)or 0 end
function A.CancelAuction(id)
 local d=resolve(id);if not d or d.kind~='owner'or not CanCancelAuction(d.index)then error('The auction changed. Refresh Auctions first.')end
 call(CancelAuction,d.index)
end
function A.IsSellItemValid(loc)
 local b,s=loc:GetBagAndSlot();local d=C_Container.GetContainerItemInfo(b,s)
 if not d or d.hasLoot or (C_Item.IsBound and C_Item.IsBound(loc))then return false end
 return true
end
function A.IsSelectedSellItem(loc)
 return selectedSell and C_Item.GetItemGUID(loc)==selectedSell.guid and select(10,GetAuctionSellItemInfo())==selectedSell.id
end
function A.SelectSellItem(loc)
 if CursorHasItem()then return false,'Place the item you are holding before choosing a sell item.'end
 if selectedSell then A.ReleaseSellItem()end
 local b,s=loc:GetBagAndSlot();local d=C_Container.GetContainerItemInfo(b,s)
 if not d or d.isLocked or not A.IsSellItemValid(loc)then return false,'This item cannot be selected for sale.'end
 C_Container.PickupContainerItem(b,s)
 if not CursorHasItem()then return false,'The item could not be picked up.'end
 ClickAuctionSellItemButton()
 if CursorHasItem()then ClearCursor();return false,'This item cannot be put up for auction.'end
 if select(10,GetAuctionSellItemInfo())~=d.itemID then return false,'The auction sell slot did not accept that item.'end
 selectedSell={guid=C_Item.GetItemGUID(loc),id=d.itemID};return true
end
function A.ReleaseSellItem()
 if selectedSell and not CursorHasItem()and GetAuctionSellItemInfo()then ClickAuctionSellItemButton();if CursorHasItem()then ClearCursor()end end
 selectedSell=nil
end
function A.CalculatePostDeposit(loc,duration,n,bid,buyout)
 if not A.IsSelectedSellItem(loc)then return end
 return GetAuctionDeposit(duration,bid or buyout,buyout,n,1)
end
function A.PostItem(loc,duration,n,bid,buyout,confirmed)
 if not A.IsSelectedSellItem(loc)then error('Select the item for sale again.')end
 local b,s=loc:GetBagAndSlot();local d=C_Container.GetContainerItemInfo(b,s)
 if not d or n<1 or n>d.stackCount then error('The inventory stack changed.')end
 postError=nil;local success=call(PostAuction,bid or buyout,buyout,duration,n,1,not not confirmed)
 if postError then error('The server rejected this auction.')end
 if not success then StaticPopup_Hide('AUCTION_HOUSE_POST_WARNING')end
 return not success
end
function A.ConfirmPostItem(loc,duration,n,bid,buyout)return A.PostItem(loc,duration,n,bid,buyout,true)end
function A.CancelSell()if CancelSell then CancelSell()end end
function A.CloseAuctionHouse()CloseAuctionHouse()end
function A.PriceScope()
 if not AuctionFrame or not AuctionFrame:IsShown()then return end
 local guid=UnitGUID('npc');local id=guid and select(6,strsplit('-',guid))
 local zone=C_Map and C_Map.GetBestMapForUnit('player')or GetRealZoneText()
 return id and 'npc:'..id or 'zone:'..tostring(zone),UnitName('npc')or GetRealZoneText()
end
-- Both Classic families use 50-auction server pages. Read only after data settles.
local frame=CreateFrame('Frame')
for _,name in ipairs({'AUCTION_ITEM_LIST_UPDATE','AUCTION_OWNED_LIST_UPDATE','AUCTION_BIDDER_LIST_UPDATE','AUCTION_HOUSE_CLOSED','AUCTION_HOUSE_POST_ERROR','AUCTION_MULTISELL_UPDATE','AUCTION_MULTISELL_FAILURE'})do pcall(frame.RegisterEvent,frame,name)end
frame:SetScript('OnEvent',function(_,name)
 if name=='AUCTION_ITEM_LIST_UPDATE'then
  if request then request.updated=GetTime()else generation.list=generation.list+1;if query and query.kind=='items'then request={sent=GetTime(),updated=GetTime()}end end
 elseif name=='AUCTION_OWNED_LIST_UPDATE'then generation.owner=generation.owner+1;emit('OWNED_AUCTIONS_UPDATED')
 elseif name=='AUCTION_BIDDER_LIST_UPDATE'then generation.bidder=generation.bidder+1;emit('BIDS_UPDATED')
 elseif name=='AUCTION_HOUSE_CLOSED'then request=nil;query=nil;tokens={};selectedSell=nil;generation.list=generation.list+1
 elseif name=='AUCTION_HOUSE_POST_ERROR'then postError=true
 elseif name=='AUCTION_MULTISELL_UPDATE'then emit('AUCTION_HOUSE_AUCTION_CREATED')
 elseif name=='AUCTION_MULTISELL_FAILURE'then emit('UI_ERROR_MESSAGE',nil,'The server could not post this auction.')end
end)
local function readPage()
 local batch,total=GetNumAuctionItems('list');batch,total=batch or 0,total or 0
 if batch==0 and total>(query.page*50)then return end
 local pageRows={}
 for i=1,batch do local d=info('list',i);if not d then return end;pageRows[#pageRows+1]=d end
 hasFull=(query.page+1)*50>=total
 if query.kind=='browse'then
  if not seenPages[query.page]then
   seenPages[query.page]=true
   for _,d in ipairs(pageRows)do
    local hasBuyout=d.buyoutAmount and d.buyoutAmount>0
    local id=keyID(d.itemKey);local unit=math.ceil((hasBuyout and d.buyoutAmount or d.minBid or 0)/d.quantity);local g=groups[id]
    if not g then g={itemKey=d.itemKey,minPrice=unit,totalQuantity=0,containsOwnerItem=false,priceIsBidOnly=not hasBuyout};groups[id]=g;results[#results+1]=g end
    if hasBuyout then g.minPrice=g.priceIsBidOnly and unit or math.min(g.minPrice,unit);g.priceIsBidOnly=false
    elseif g.priceIsBidOnly then g.minPrice=math.min(g.minPrice,unit)end
    g.totalQuantity=g.totalQuantity+d.quantity;g.containsOwnerItem=g.containsOwnerItem or d.containsOwnerItem
   end
  end
  request=nil;emit('AUCTION_HOUSE_BROWSE_RESULTS_UPDATED')
 else
  currentRows={}
  for _,d in ipairs(pageRows)do if keyID(d.itemKey)==keyID(query.key)then currentRows[#currentRows+1]=token(d)end end
  request=nil;emit('ITEM_SEARCH_RESULTS_UPDATED',query.key)
 end
end
frame:SetScript('OnUpdate',function()
 if not request then return end
 if GetTime()-request.sent>35 then request=nil;emit('AUCTION_HOUSE_BROWSE_FAILURE');return end
 if not request.updated or GetTime()-request.updated<.25 or GetTime()<pollAt then return end
 pollAt=GetTime()+.2
 local ok,err=pcall(readPage);if not ok then request=nil;emit('AUCTION_HOUSE_BROWSE_FAILURE');if not A.reported then A.reported=true;print('WoWU Classic auction data: '..tostring(err))end end
end)
hooksecurefunc('QueryAuctionItems',function()
 if not inside then request=nil;query=nil;generation.list=generation.list+1;emit('AUCTION_HOUSE_BROWSE_FAILURE')end
end)
if SortAuctionItems then hooksecurefunc('SortAuctionItems',function()generation.list=generation.list+1;if request then request=nil;emit('AUCTION_HOUSE_BROWSE_FAILURE')end end)end
