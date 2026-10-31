-- On-demand reagent facts. Prices remain scoped by the AuctionPrices module.
WoWUReagents={};local R=WoWUReagents;local C=WoWUClient
local function call(fn,...)
 if type(fn)~='function'then return end
 local ok,a,b,c,d,e,f,g,h,i,j,k,l,m=pcall(fn,...);if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
end
local function db()
 WoWUDB=WoWUDB or {}
 WoWUDB.reagentKnowledge=WoWUDB.reagentKnowledge or {}
 local all=WoWUDB.reagentKnowledge;local key=C.name;all[key]=all[key]or {vendors={},crafts={}};all[key].loot=all[key].loot or {};return all[key]
end
function R.RememberCraft(id,name,profession)
 if type(id)=='number'and type(name)=='string'then db().crafts[id]={name=name,profession=profession}end
end
local hints={
 [5]='Cloth is commonly obtained from humanoid enemies; the exact creatures and zones depend on the cloth.',
 [6]='Leather is commonly gathered with Skinning. Some leather materials are processed by Leatherworking.',
 [7]='Ore and stone commonly come from Mining nodes. Bars are usually produced by Smelting.',
 [9]='Herbs commonly come from Herbalism nodes. Required skill and zones depend on the herb.',
 [10]='Elemental materials can come from elemental enemies, gathering or crafting; the exact source varies.',
 [12]='Enchanting materials commonly come from disenchanting suitable equipment. Material type depends on the equipment.'}
local function sections(id,required,owned,alternative)
 local result={};local lines={};local seen={}
 local faction=UnitFactionGroup('player')=='Horde'and 'H'or 'A'
 local function add(s)if not seen[s]then seen[s]=true;lines[#lines+1]=s end end
 for _,s in ipairs((WoWUReagentSources or {})[id]or {})do
  if s[1]~='vendor'or s[4]:find(faction,1,true)then
   local info=s[3]>0 and call(C_Map and C_Map.GetMapInfo,s[3]);local area=info and info.name
   local prefix=({vendor='Sold by',object='Gathered or looted from',creature='Creature source (loot or gathering)',container='Found in container'})[s[1]]or 'Source'
   add(prefix..': '..s[2]..(area and (' - '..area)or ''))
  end
 end
 for _,s in ipairs(db().vendors[id]or {})do add('Vendor you visited: '..s.name..(s.zone and (' - '..s.zone)or ''))end
 for _,s in ipairs(db().loot[id]or {})do add('Observed loot source: '..s.name..(s.zone and (' - '..s.zone)or ''))end
 local craft=db().crafts[id];if craft then add('Crafted with '..(craft.profession or 'a profession')..': '..craft.name)end
 local hasKnown=#lines>0
 local _,_,_,_,_,_,_,_,_,_,_,class,sub=call(C_Item and C_Item.GetItemInfo or GetItemInfo,id)
 if class==7 and hints[sub]then add('General gathering hint: '..hints[sub])end
 if not hasKnown then
  add('No exact source is recorded for this item on this client.')
  add('Sources learned from vendors, identifiable loot you view and recipes you inspect will appear here.')
 end
 result[#result+1]={title='Where to find it',text=table.concat(lines,'\n\n')..'\n\nKnown examples only; stock, drops and phases can vary.'}
 local price,snapshot
 if WoWUAuctionPrices then price,snapshot=WoWUAuctionPrices.Lookup(id)end
 local money=GetMoneyString or function(v)return tostring(v)..' copper'end
 if price and snapshot then
  local quote='Lowest scanned asking price: '..money(price.price)..' each.'
  if required and required>1 then quote=quote..'\n'..required..' required: '..money(price.price*required)..' at that unit price.'end
  result[#result+1]={title='Auction House - last scan',text=quote..'\nScanned '..date('%d %b %Y %H:%M',snapshot.seen)..'.\nCached asking price, not a live quote. Quality and variants may differ.'}
 else result[#result+1]={title='Auction House - last scan',text='No cached price for this item in your current market. Run a scan at the Auction House to record asking prices.'}end
 if required then result[#result+1]={title='Recipe requirement',text=tostring(required)..' for one craft; '..tostring(owned or '?')..' in your bags.'..(alternative and '\nThis is one of the listed reagent choices, not an extra requirement for every quality.'or '')}end
 return result
end
function R.Show(id,owner,required,owned,alternative)
 if not id or not WoWUDetails then return end
 WoWUDetails.Show({link='item:'..id,sections=function()return sections(id,required,owned,alternative)end},owner)
end
local e=CreateFrame('Frame');e:RegisterEvent('MERCHANT_SHOW');e:RegisterEvent('MERCHANT_UPDATE')
local scheduled=false
e:SetScript('OnEvent',function()
 if scheduled then return end;scheduled=true
 C_Timer.After(.25,function()
  scheduled=false;if not MerchantFrame or not MerchantFrame:IsShown()then return end
  local name=call(UnitName,'npc');if not name then return end
  local map=call(C_Map and C_Map.GetBestMapForUnit,'player');local info=map and call(C_Map.GetMapInfo,map)
  for i=1,math.min(call(GetMerchantNumItems)or 0,200)do
   local link=call(GetMerchantItemLink,i);local id=type(link)=='string'and tonumber(link:match('item:(%d+)'))
   if id then
    local list=db().vendors[id]or {};db().vendors[id]=list;local found=false
    for _,s in ipairs(list)do if s.name==name and s.zone==(info and info.name)then found=true;break end end
    if not found then list[#list+1]={name=name,zone=info and info.name};if #list>5 then table.remove(list,1)end end
   end
  end
 end)
end)
-- Learn only attributable loot. An unrelated selected target is never assumed
-- to be the source: its readable GUID must match the slot's actual source GUID.
local loot=CreateFrame('Frame');loot:RegisterEvent('LOOT_OPENED');loot:RegisterEvent('LOOT_READY')
loot:SetScript('OnEvent',function()
 local target=call(UnitGUID,'target');local name=call(UnitName,'target')
 local valid=C.Public(target)and type(target)=='string'and C.Public(name)and type(name)=='string'
 local fishing=call(IsFishingLoot)==true
 local map=call(C_Map and C_Map.GetBestMapForUnit,'player');local info=map and call(C_Map.GetMapInfo,map)
 for slot=1,math.min(call(GetNumLootItems)or 0,100)do
  local link=call(GetLootSlotLink,slot)
  local id=C.Public(link)and type(link)=='string'and tonumber(link:match('item:(%d+)'))
  local sourceName=fishing and 'Fishing'or nil
  if valid and not fishing then
   local sources={call(GetLootSourceInfo,slot)}
   for _,guid in pairs(sources)do if C.Public(guid)and type(guid)=='string'and guid==target then sourceName=name;break end end
  end
  if id and sourceName then
   local list=db().loot[id]or {};db().loot[id]=list;local found=false
   for _,s in ipairs(list)do if s.name==sourceName and s.zone==(info and info.name)then found=true;break end end
   if not found then list[#list+1]={name=sourceName,zone=info and info.name};if #list>5 then table.remove(list,1)end end
  end
 end
end)
