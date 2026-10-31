-- Compendium presentation and live client adapters. Bundled Forever records are
-- kept separately in CompendiumData.lua with their source and licence.
local P={};WoWUCompendium=P
local C=WoWUClient
local function call(fn,...)return C.Call(fn,...)end
local function locked()return InCombatLockdown and InCombatLockdown()end
local function clean(s)
 return (s or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t",""):gsub("|H.-|h(.-)|h","%1")
end
local function contains(s,q)return clean(s):lower():find(q,1,true)~=nil end
local function journalBusy()return EncounterJournal and EncounterJournal:IsShown()end
local function journal(fn)
 if locked()then return nil,"Browse the journal after combat."end
 if journalBusy()then return nil,"Close Blizzard's Adventure Guide to browse the Compendium."end
 local tier=call(EJ_GetCurrentTier);local difficulty=call(EJ_GetDifficulty)
 local class,spec=call(EJ_GetLootFilter)
 local slot=call(C_EncounterJournal and C_EncounterJournal.GetSlotFilter)
 local instance=EncounterJournal and EncounterJournal.instanceID
 local encounter=EncounterJournal and EncounterJournal.encounterID
 local ok,result=pcall(fn)
 if tier then call(EJ_SelectTier,tier)end
 if instance then call(EJ_SelectInstance,instance)end
 if difficulty then call(EJ_SetDifficulty,difficulty)end
 if encounter then call(EJ_SelectEncounter,encounter)end
 if class then call(EJ_SetLootFilter,class,spec or 0)end
 if slot then call(C_EncounterJournal and C_EncounterJournal.SetSlotFilter,slot)end
 return ok and result or nil,not ok and "Journal information is unavailable on this client."or nil
end
function P.Catalogue()
 local records={}
 if C.isForever then
  for _,r in ipairs(WoWUCompendiumData or {})do
   -- Resolve area names using the current client, retaining wing names.
   if r.areaID and not r.id:find("ScarletMonastery")and not r.id:find("DireMaul")then
    r.name=call(C_Map and C_Map.GetAreaInfo,r.areaID)or r.name
   end
   records[#records+1]=r
   local rare={}
   for _,b in ipairs(r.bosses)do if b.rare then rare[#rare+1]=b end end
   if #rare>0 then records[#records+1]={id="rare:"..r.id,name=r.name,category="Rares",expansion="Forever",bosses=rare,instanceID=r.instanceID}end
  end
 else
  local data,message=journal(function()
   local list,seen={},{}
   for tier=1,(call(EJ_GetNumTiers)or 0)do
    call(EJ_SelectTier,tier)
    for _,raid in ipairs({false,true})do
     for i=1,150 do
      local id,name,description,_,image,_,_,_,_,_,mapID=EJ_GetInstanceByIndex(i,raid)
      if not id then break end
      if not seen[id]then
       seen[id]=true;list[#list+1]={id=id,journal=true,tier=tier,name=name,description=description,mapID=mapID,
        category=raid and "Raids"or "Dungeons",expansion=call(EJ_GetTierInfo,tier)or "Retail",bosses={}}
      end
     end
    end
   end
   return list
  end)
  records=data or {};P.message=message
 end
 if WoWUExplorer and WoWUExplorer.RareSightings then
  for _,point in ipairs(WoWUExplorer.RareSightings())do
   local info=call(C_Map and C_Map.GetMapInfo,point.mapID)
   records[#records+1]={id="sighting:"..point.mapID..":"..point.name,name=point.name,
    category="Rares",expansion=C.name,mapID=point.mapID,point=point,
    bosses={{name=point.name,items={},description="Recorded sighting in "..(info and info.name or "this zone")..". This is a saved location, not a live spawn alert.",point=point}}}
  end
 end
 table.sort(records,function(a,b)return a.name<b.name end)
 return records
end
function P.Bosses(r)
 if not r.journal then return r.bosses end
 return journal(function()
  call(EJ_SelectTier,r.tier);call(EJ_SelectInstance,r.id)
  local bosses={}
  for i=1,100 do
   local name,description,id,section=call(EJ_GetEncounterInfoByIndex,i,r.id)
   if not id then break end
   bosses[#bosses+1]={name=name,id=id,description=description,section=section,items={}}
  end
  return bosses
 end)
end
function P.Loot(r,b,difficulty)
 if not r.journal then return b.items or {}end
 return journal(function()
  call(EJ_SelectTier,r.tier);call(EJ_SelectInstance,r.id)
  r.difficulties={}
  for id=1,40 do
   if call(C_EncounterJournal and C_EncounterJournal.InstanceHasDifficultyID,id)then
    local name=call(GetDifficultyInfo,id);if name then r.difficulties[#r.difficulties+1]={id=id,name=name}end
   end
  end
  local chosen=r.difficulties[1]
  for _,d in ipairs(r.difficulties)do if d.id==difficulty then chosen=d end end
  if chosen then call(EJ_SetDifficulty,chosen.id);r.difficulty=chosen.id end
  call(EJ_SelectEncounter,b.id);call(EJ_SetLootFilter,0,0)
  call(C_EncounterJournal and C_EncounterJournal.ResetSlotFilter)
  local list={}
  for i=1,math.min(500,call(EJ_GetNumLoot)or 0)do
   local item=call(C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex,i)
   if item and item.itemID then list[#list+1]={id=item.itemID,name=item.name,link=item.link,icon=item.icon}end
  end
  local sections,seen={},{}
  local function visit(id,depth)
   if not id or id==0 or seen[id]or #sections>=32 or depth>8 then return end
   seen[id]=true
   local s=call(C_EncounterJournal and C_EncounterJournal.GetSectionInfo,id)
   if not s then return end
   if not s.filteredByDifficulty then sections[#sections+1]=(s.title or "").."\n"..clean(s.description or "")end
   visit(s.firstChildSectionID,depth+1);visit(s.siblingSectionID,depth)
  end
  visit(b.section,0);b.abilities=table.concat(sections,"\n\n")
  return list
 end)
end
function P.Open(current)
 if locked()then print("WoWU: open the Compendium after combat.");return end
 P.currentRequested=current==true
 if WoWU_MainFrame then WoWU_MainFrame:Show()end
 if WoWU_ShowPage then WoWU_ShowPage("Compendium")end
end
local function text(p,value,size)
 local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal");t:SetFont("Fonts\\FRIZQT__.TTF",size or 14,"")
 WoWU_Theme.TextColor(t,.95,.82,.56);t:SetJustifyH("LEFT");t:SetText(value or "");return t
end
local function button(p,value,w,fn)
 local b=CreateFrame("Button",nil,p,"BackdropTemplate");b:SetSize(w,34)
 b.label=text(b,value,13);b.label:SetPoint("CENTER");b.label:SetWidth(w-12);b.label:SetJustifyH("CENTER")
 WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",fn);return b
end
local function list(p)
 local frame=CreateFrame("Frame",nil,p,"BackdropTemplate");WoWU_Theme.Panel(frame)
 local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",10,-10);scroll:SetPoint("BOTTOMRIGHT",-30,10)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(200,1);scroll:SetScrollChild(body)
 WoWU_EnableTouchScroll(scroll)
 return {frame=frame,scroll=scroll,body=body,rows={}}
end
local function fill(view,entries,selected,choose)
 local width=math.max(120,view.scroll:GetWidth());view.body:SetWidth(width)
 for i,e in ipairs(entries)do
  local b=view.rows[i]
  if not b then
   b=button(view.body,"",width,function()end);view.rows[i]=b
   b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(34,34);b.icon:SetPoint("LEFT",7,0)
   b.sub=text(b,"",11);b.sub:SetPoint("BOTTOMLEFT",10,8);b.sub:SetPoint("RIGHT",-8,0)
  end
  b:SetSize(width,64);b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(i-1)*68)
  b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",e.icon and 48 or 10,-9);b.label:SetPoint("RIGHT",-8,0)
  b.label:SetJustifyH("LEFT");b.label:SetHeight(30);b.label:SetText(e.name or "Loading...")
  b.icon:SetTexture(e.icon);b.sub:SetText(e.note or "")
  WoWU_Theme.Tab(b,e.key==selected)
  if e.quality then local r,g,blue=GetItemQualityColor(e.quality);WoWU_Theme.TextColor(b.label,r,g,blue)end
  b:SetScript("OnClick",function()if WoWU_TouchTapAllowed(view.scroll)then choose(e)end end);b:Show()
 end
 for i=#entries+1,#view.rows do view.rows[i]:Hide()end
 view.body:SetHeight(math.max(1,#entries*68))
 view.scroll:SetVerticalScroll(math.min(view.scroll:GetVerticalScroll(),math.max(0,view.body:GetHeight()-view.scroll:GetHeight())))
end
function WoWU_CreateCompendium(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();root:Hide()
 local title=text(root,"Compendium",24);title:SetPoint("TOPLEFT",16,-12)
 local crumb=text(root,"Choose a place, then an encounter.",12);crumb:SetPoint("TOPLEFT",16,-43);crumb:SetPoint("RIGHT",-14,0)
 local category="Dungeons";local query="";local expansion="All eras";local quality=0;local slot="All items"
 local records={};local selected,boss,loot,selectedItem;local refresh,selectPlace,selectBoss
 local requested={};local journalDirty=false;local journalRetries=0
 local tabs={}
 for i,name in ipairs({"Dungeons","Raids","World Bosses","Rares"})do
  local b=button(root,name,125,function()category=name;selected=nil;boss=nil;selectedItem=nil;refresh(true)end)
  b:SetPoint("TOPLEFT",16+(i-1)*132,-68);tabs[name]=b
 end
 local search=CreateFrame("EditBox",nil,root,"InputBoxTemplate");search:SetSize(265,30);search:SetPoint("TOPRIGHT",-20,-70);search:SetAutoFocus(false)
 local searchLabel=text(root,C.isForever and "Search places, bosses or loot"or "Search places / loaded bosses & loot",11);searchLabel:SetPoint("BOTTOMLEFT",search,"TOPLEFT",0,4)
 local source=text(root,C.isForever and "Forever loot reference | AtlasLoot 1.2.6 | future-phase entries may be listed"or "Retail | live Encounter Journal",11)
 source:SetPoint("BOTTOMLEFT",16,4);source:SetPoint("RIGHT",-16,0)
 local places,encounters,items=list(root),list(root),list(root)
 local info=CreateFrame("Frame",nil,root,"BackdropTemplate");WoWU_Theme.Panel(info)
 local infoTitle=text(info,"",18);infoTitle:SetPoint("TOPLEFT",12,-12);infoTitle:SetPoint("RIGHT",-12,0)
 local infoText=text(info,"",12);infoText:SetPoint("TOPLEFT",12,-42);infoText:SetPoint("RIGHT",-12,0);infoText:SetHeight(36)
 local message=text(items.frame,"",14);message:SetPoint("TOPLEFT",16,-14);message:SetPoint("RIGHT",-16,0)
 local detail=list(root);detail.frame:Hide()
 local detailText=text(detail.body,"",14);detailText:SetPoint("TOPLEFT",8,-8);detailText:SetWidth(300)
 local tip=CreateFrame("GameTooltip","WoWU_CompendiumTooltip",detail.body,"GameTooltipTemplate")
 tip:SetOwner(detail.body,"ANCHOR_NONE");tip:Hide()
 local detailMode=false
 local function showDetail(value)
  detailMode=value;detail.frame:SetShown(value);items.frame:SetShown(not value)
 end
 local function itemInfo(entry)
  local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
  local name,link,q,level,required,kind,subtype,_,equip,icon=fn(entry.link or entry.id)
  if not name and not requested[entry.id]and C_Item and C_Item.RequestLoadItemDataByID then requested[entry.id]=true;call(C_Item.RequestLoadItemDataByID,entry.id)end
  return {name=name or entry.name or ("Item "..entry.id),link=link or entry.link or ("item:"..entry.id),quality=q,level=level,required=required,kind=kind,subtype=subtype,equip=equip,icon=icon or entry.icon or 134400,id=entry.id}
 end
 local function inspect(entry)
  selectedItem=entry;showDetail(true);detailText:SetText("")
  local data=itemInfo(entry)
  tip:SetOwner(detail.body,"ANCHOR_NONE");tip:ClearAllPoints();tip:SetPoint("TOPLEFT",detail.body,"TOPLEFT",5,-8)
  tip:SetHyperlink(data.link);tip:Show()
  local note="Source: "..(boss and boss.name or "Unknown").."\nDrop chance: not verified."
  detailText:ClearAllPoints();detailText:SetPoint("TOPLEFT",5,-math.max(80,tip:GetHeight()+22));detailText:SetWidth(math.max(150,detail.scroll:GetWidth()-12));detailText:SetText(note)
  detail.body:SetHeight(math.max(150,tip:GetHeight()+100));detail.scroll:SetVerticalScroll(0)
 end
 local function overview()
  selectedItem=nil;showDetail(true);tip:Hide();detailText:ClearAllPoints();detailText:SetPoint("TOPLEFT",8,-8)
  local description=boss and boss.description or selected and selected.description
  local abilities=boss and boss.abilities
  detailText:SetWidth(math.max(150,detail.scroll:GetWidth()-16))
  detailText:SetText((description and description~=""and clean(description)or "No verified encounter strategy is included in this source.")..(abilities and abilities~=""and "\n\n"..abilities or "").."\n\n"..(C.isForever and "Forever reference snapshot. Loot can change between phases; unknown drop rates are intentionally omitted."or "Encounter information is supplied by this client for the selected difficulty."))
  detail.body:SetHeight(detailText:GetStringHeight()+24);detail.scroll:SetVerticalScroll(0)
 end
 local overviewButton=button(info,"Overview",100,overview);overviewButton:SetPoint("BOTTOMLEFT",10,9)
 local lootButton=button(info,"Loot",75,function()selectedItem=nil;showDetail(false)end);lootButton:SetPoint("LEFT",overviewButton,"RIGHT",6,0)
 local mapButton=button(info,"Map",75,function()
  local point=boss and boss.point or selected and selected.point
  local map=point and point.mapID or selected and selected.mapID
  if map then WoWU_ShowPage("Map");local frame=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame;if frame and frame.SetMapID then frame:SetMapID(map)end end
 end);mapButton:SetPoint("LEFT",lootButton,"RIGHT",6,0)
 local navigate=button(info,"Navigate",100,function()
  local point=boss and boss.point or selected and selected.point
  if point then local ok,msg=WoWUNavigation.SetDestination(point);infoText:SetText(msg or (ok and "Navigation started."or "Location unavailable."))end
 end);navigate:SetPoint("LEFT",mapButton,"RIGHT",6,0)
 local eraButton,qualityButton,slotButton,difficultyButton
 eraButton=button(root,"All eras",180,function()
  local list={"All eras"};local seen={}
  for _,r in ipairs(records)do if not seen[r.expansion]then seen[r.expansion]=true;list[#list+1]=r.expansion end end
  local index=1;for i,v in ipairs(list)do if v==expansion then index=i end end
  expansion=list[index%#list+1];eraButton.label:SetText(expansion);selected=nil;boss=nil;refresh(true)
 end);eraButton:SetPoint("TOPLEFT",16,-110)
 qualityButton=button(root,"Quality: All",140,function()
  quality=quality==0 and 2 or quality==4 and 0 or quality+1
  qualityButton.label:SetText(quality==0 and "Quality: All"or ("Quality: "..(_G["ITEM_QUALITY"..quality.."_DESC"]or quality).."+"));refresh()
 end);qualityButton:SetPoint("LEFT",eraButton,"RIGHT",8,0)
 local slots={"All items","Weapons","Armour","Jewellery"}
 slotButton=button(root,slot,135,function()
  local index=1;for i,v in ipairs(slots)do if v==slot then index=i end end
  slot=slots[index%#slots+1];slotButton.label:SetText(slot);refresh()
 end);slotButton:SetPoint("LEFT",qualityButton,"RIGHT",8,0)
 difficultyButton=button(root,"Difficulty: Normal",190,function()
  if not selected or not selected.journal or not boss then return end
  local list=selected.difficulties or {};if #list==0 then return end
  local index=1;for i,d in ipairs(list)do if d.id==selected.difficulty then index=i end end
  selected.difficulty=list[index%#list+1].id;selectBoss(boss)
 end);difficultyButton:SetPoint("LEFT",slotButton,"RIGHT",8,0)
 button(root,"Clear search",110,function()query="";search:SetText("");quality=0;slot="All items";qualityButton.label:SetText("Quality: All");slotButton.label:SetText(slot);refresh(true)end):SetPoint("TOPRIGHT",-16,-110)
 local function matches(r)
  if query==""or contains(r.name,query)then return true end
  for _,b in ipairs(r.bosses or {})do
   if contains(b.name,query)then return true end
   for _,e in ipairs(b.items or {})do if contains(e.name,query)or tostring(e.id)==query then return true end end
  end
  return false
 end
 selectBoss=function(b)
  boss=b;selectedItem=nil;journalRetries=0;showDetail(false)
  local data,msg=P.Loot(selected,b,selected.difficulty);loot=data or {};b.items=loot
  P.message=msg;items.scroll:SetVerticalScroll(0);refresh()
 end
 selectPlace=function(r)
  selected=r;boss=nil;loot={};selectedItem=nil;showDetail(false)
  local data,msg=P.Bosses(r);r.bosses=data or {};P.message=msg
  encounters.scroll:SetVerticalScroll(0)
  local first=r.bosses[1]
  if query~=""and not contains(r.name,query)then
   for _,candidate in ipairs(r.bosses)do
    local matched=contains(candidate.name,query)
    for _,e in ipairs(candidate.items or {})do if contains(e.name,query)or tostring(e.id)==query then matched=true end end
    if matched then first=candidate;break end
   end
  end
  if first then selectBoss(first)else refresh()end
 end
 refresh=function(reset)
  if not root:IsVisible()then return end
  if not selected then showDetail(false);tip:Hide()end
  for name,b in pairs(tabs)do WoWU_Theme.Tab(b,name==category)end
  local entries={}
  for _,r in ipairs(records)do
   if r.category==category and (expansion=="All eras"or r.expansion==expansion)and matches(r)then
    entries[#entries+1]={key=r.id,name=r.name,note=r.levels and ("Recommended "..r.levels[2].."-"..r.levels[3])or r.expansion,value=r}
   end
  end
  fill(places,entries,selected and selected.id,function(e)selectPlace(e.value)end)
  local bosses={}
  for i,b in ipairs(selected and selected.bosses or {})do
   local matched=query==""or contains(selected.name,query)or contains(b.name,query)
   for _,e in ipairs(b.items or {})do if contains(e.name,query)or tostring(e.id)==query then matched=true end end
   if matched then bosses[#bosses+1]={key=b,name=b.name,note=b.rare and "Rare encounter"or (b.npcID and "NPC "..b.npcID or "Encounter / loot source"),value=b}end
  end
  fill(encounters,bosses,boss,function(e)selectBoss(e.value)end)
  local drops={}
  if boss then for _,entry in ipairs(loot or {})do
   local e=itemInfo(entry)
   local slotOkay=slot=="All items"or slot=="Weapons"and e.kind==WEAPON or slot=="Armour"and e.kind==ARMOR or slot=="Jewellery"and (e.equip=="INVTYPE_NECK"or e.equip=="INVTYPE_FINGER"or e.equip=="INVTYPE_TRINKET")
   local searchOkay=query==""or contains(e.name,query)or tostring(e.id)==query or contains(boss.name,query)or contains(selected.name,query)
   if (quality==0 or not e.quality or e.quality>=quality)and (slotOkay or not e.equip)and searchOkay then
    drops[#drops+1]={key=e.id,name=e.name,quality=e.quality,icon=e.icon,value=entry,
     note=(e.equip and (_G[e.equip]or e.subtype or "")or "Loading item details...")..(e.required and " | Level "..e.required or "")}
   end
  end end
  fill(items,drops,selectedItem and selectedItem.id,function(e)inspect(e.value)end)
  local emptyMessage=not selected and (#entries==0 and (C.isRetail and category=="World Bosses"and "Retail world bosses are included with raids in the native journal."or "No matching records. Rare sightings appear after you record them in the world.")or "Choose a place to begin.")or not boss and "This location has no sourced encounter records yet."or "No matching loot records. Try clearing the filters."
  message:SetText(#drops==0 and (P.message or emptyMessage)or "")
  infoTitle:SetText(boss and boss.name or selected and selected.name or "Encounter & loot")
  infoText:SetText(selected and (#(loot or {}).." loot records | "..(selected.journal and "Client journal"or "Forever reference").." | Tap an item to inspect")or "Choose an encounter in the middle column.")
  crumb:SetText(category..(selected and " > "..selected.name or "")..(boss and " > "..boss.name or ""))
  local point=boss and boss.point or selected and selected.point
  mapButton:SetEnabled((point and point.mapID or selected and selected.mapID)~=nil);navigate:SetEnabled(point~=nil)
  difficultyButton:SetEnabled(selected and selected.journal and boss and true or false)
  difficultyButton.label:SetText(selected and selected.difficulty and (call(GetDifficultyInfo,selected.difficulty)or "Difficulty")or "Difficulty: reference")
  if reset then places.scroll:SetVerticalScroll(0)end
 end
 search:SetScript("OnTextChanged",function(self)query=self:GetText():lower();if refresh then refresh(true)end end)
 search:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
 search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
 local function layout()
  local w,h=root:GetWidth(),root:GetHeight();local left=math.floor(w*.22);local mid=math.floor(w*.23)
  places.frame:SetPoint("TOPLEFT",12,-154);places.frame:SetSize(left-12,math.max(100,h-180))
  encounters.frame:SetPoint("TOPLEFT",left+8,-154);encounters.frame:SetSize(mid-12,math.max(100,h-180))
  info:SetPoint("TOPLEFT",left+mid+8,-154);info:SetSize(w-left-mid-20,122)
  for _,v in ipairs({items,detail})do v.frame:SetPoint("TOPLEFT",left+mid+8,-284);v.frame:SetSize(w-left-mid-20,math.max(100,h-310))end
  if refresh then refresh()end
 end
 local function openCurrent()
  local name,_,_,_,_,_,_,instanceID=GetInstanceInfo()
  local journalID=call(C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap,instanceID)
  for _,r in ipairs(records)do
   if r.category~="Rares"and ((r.instanceID and r.instanceID==instanceID)or r.journal and journalID==r.id or r.name==name)then
    category=r.category;query="";search:SetText("");expansion="All eras";eraButton.label:SetText(expansion);selectPlace(r);return
   end
  end
  P.message="No matching instance record. Choose a location from the list.";refresh()
 end
 root:SetScript("OnShow",function()
  requested={};records=P.Catalogue();layout()
  if P.currentRequested then P.currentRequested=false;openCurrent()elseif selected then selectPlace(selected)else refresh()end
 end)
 root:SetScript("OnHide",function()tip:Hide();search:ClearFocus()end)
 root:SetScript("OnSizeChanged",layout)
 local events=CreateFrame("Frame",nil,root);local dirty=false
 for _,event in ipairs({"GET_ITEM_INFO_RECEIVED","EJ_LOOT_DATA_RECIEVED"})do pcall(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function(_,event)
  if root:IsVisible()then
   dirty=true
   if event=="EJ_LOOT_DATA_RECIEVED"and journalRetries<3 then journalDirty=true end
  end
 end)
 local elapsed=0
 root:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.35 then return end;elapsed=0
  if journalDirty and not locked()and selected and selected.journal and boss then
   journalDirty=false;journalRetries=journalRetries+1
   local data=P.Loot(selected,boss,selected.difficulty)
   if data then loot=data;boss.items=data end
  end
  if dirty then dirty=false;refresh();if selectedItem then inspect(selectedItem)end end
 end)
 return root
end
SLASH_WOWUCOMPENDIUM1="/wowucompendium"
SlashCmdList.WOWUCOMPENDIUM=function()P.Open(false)end
