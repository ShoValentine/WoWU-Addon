-- Classic carried-bag sorting. One verified swap/move at a time; no native SortBags.
WoWUBagSort={};local S=WoWUBagSort;local job
local A=C_Container or {}
local pickup=A.PickupContainerItem or PickupContainerItem
local slots=A.GetContainerNumSlots or GetContainerNumSlots
local free=A.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local function combat()return InCombatLockdown and InCombatLockdown()end
local function cursor()return GetCursorInfo()end
local function info(bag,slot)
 local r
 if A.GetContainerItemInfo then r=A.GetContainerItemInfo(bag,slot)
 else
  local texture,count,locked,quality,_,_,link=GetContainerItemInfo(bag,slot)
  if texture then r={stackCount=count,isLocked=locked,quality=quality,hyperlink=link}end
 end
 if not r then return end
 local id=r.itemID or r.hyperlink and tonumber(r.hyperlink:match('item:(%d+)'))
 if not id then error('An item is still loading. Try Clean Up again.')end
 local key=r.hyperlink and r.hyperlink:match('(item:[^|]+)')or tostring(id)
 return {id=id,key=key,count=r.stackCount or 1,locked=r.isLocked==true or r.isLocked==1,link=r.hyperlink,quality=r.quality}
end
local function signature(r)return r and(r.key..'/'..r.count)or 'empty'end
local function finish(message)
 local callback=job and job.callback;job=nil
 if callback then pcall(callback,message)end
end
local function metadata(r)
 local m=job.meta[r.id];if m then return m end
 local name,_,quality,_,_,_,_,_,_,_,_,class,sub=GetItemInfo(r.id)
 m={class=class or 99,sub=sub or 99,quality=quality or r.quality or 0,name=string.lower(name or tostring(r.id))}
 job.meta[r.id]=m;return m
end
local function less(a,b)
 local x,y=metadata(a),metadata(b)
 if x.class~=y.class then return x.class<y.class end
 if x.sub~=y.sub then return x.sub<y.sub end
 if x.quality~=y.quality then return x.quality>y.quality end
 if x.name~=y.name then return x.name<y.name end
 if a.id~=b.id then return a.id<b.id end
 return a.key<b.key
end
local function plan()
 local groups={}
 for bag=0,WoWUClient.LastBag()do
  local _,family=free(bag);family=family or 0
  local group=groups[family]or {};groups[family]=group
  for slot=1,slots(bag)or 0 do
   local r=info(bag,slot)
   if r and r.locked then return nil,'locked'end
   group[#group+1]={bag=bag,slot=slot,item=r}
  end
 end
 local families={};for family in pairs(groups)do families[#families+1]=family end;table.sort(families)
 for _,family in ipairs(families)do
  local group=groups[family];local ordered={}
  for _,p in ipairs(group)do if p.item then ordered[#ordered+1]=p.item end end
  table.sort(ordered,less)
  for i,want in ipairs(ordered)do
   local target=group[i]
   if not target.item or target.item.key~=want.key then
    for j=i+1,#group do if group[j].item and group[j].item.key==want.key then return {source=group[j],target=target}end end
   end
  end
 end
end
local function recover()
 local tx=job.tx;local kind,id=cursor()
 if not kind then job.phase='settle';return end
 if kind~='item'or id~=job.heldID then finish('Sorting stopped: the cursor changed. Place the item in a bag.');return end
 local source=info(tx.source.bag,tx.source.slot)
 if not source then
  pickup(tx.source.bag,tx.source.slot)
  if not cursor()then job.phase='settle' end
 end
end
local function tick()
 if not job then return end
 if combat()then finish('Sorting stopped for combat. Place any held item back in a bag.');return end
 if GetTime()-job.started>120 or job.moves>800 then finish('Sorting stopped: inventory did not settle. Place any held item in a bag.');return end
 if job.phase=='recover'then
  if GetTime()-job.waitStarted>8 then finish('Sorting paused: place the held item back in a bag, then try again.');return end
  recover();return
 end
 if cursor()then finish('Sorting stopped because an item was picked up.');return end
 if job.cancel then finish('Bag sorting stopped.');return end
 if job.phase=='settle'then
  local tx=job.tx;local source=info(tx.source.bag,tx.source.slot);local target=info(tx.target.bag,tx.target.slot)
  if(source and source.locked)or(target and target.locked)then
   if GetTime()-job.waitStarted>8 then finish('Sorting stopped while waiting for an item lock.')end
   return
  end
  if signature(source)~=signature(tx.target.item)or signature(target)~=signature(tx.source.item)then
   if GetTime()-job.waitStarted>8 then finish('Inventory changed or the move was rejected. Sorting stopped.')end
   return
  end
  job.phase=nil;job.tx=nil;job.moves=job.moves+1
 end
 local tx,reason=plan()
 if reason=='locked'then
  job.lockedSince=job.lockedSince or GetTime()
  if GetTime()-job.lockedSince>8 then finish('Sorting stopped while waiting for an item lock.')end
  return
 end
 job.lockedSince=nil
 if not tx then finish('Bags sorted.');return end
 -- The full item/count signatures must still match immediately before moving.
 if signature(info(tx.source.bag,tx.source.slot))~=signature(tx.source.item)or signature(info(tx.target.bag,tx.target.slot))~=signature(tx.target.item)then return end
 job.tx=tx;job.waitStarted=GetTime();job.phase='recover';job.heldID=tx.source.item.id
 pickup(tx.source.bag,tx.source.slot)
 local kind,id=cursor()
 if kind~='item'or id~=job.heldID then finish('The game did not allow that item to be moved. Sorting stopped.');return end
 pickup(tx.target.bag,tx.target.slot)
 local held,heldID=cursor()
 if not held then job.phase='settle'
 elseif tx.target.item and held=='item'and heldID==tx.target.item.id then job.heldID=heldID;recover()
 else
  -- A rejected placement leaves the original source item on the cursor.
  job.heldID=tx.source.item.id;job.cancel=true;recover()
 end
end
function S.Start(callback)
 if job then job.cancel=true;return true,'Stopping bag sorting...'end
 if combat()then return false,'Sort bags outside combat.'end
 if cursor()then return false,'Place the held item in a bag before sorting.'end
 if not(pickup and slots and free and GetItemInfo)then return false,'Classic bag movement is unavailable.'end
 job={started=GetTime(),moves=0,meta={},callback=callback}
 return true,'Sorting bags... Press Clean Up again to stop.'
end
local driver=CreateFrame('Frame');local elapsed=0
driver:SetScript('OnUpdate',function(_,dt)
 if not job then return end
 elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
 local ok,err=pcall(tick)
 if not ok then finish('Sorting stopped: '..tostring(err)..'. Place any held item in a bag.')end
end)
