if WoWUClient.classicMajor~=5 then return end
local U=WoWUMistsUI
local J=C_EncounterJournal or {}
function WoWU_CreateMistsGuide(parent,goHome)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();root:Hide()
 local mode="Dungeons";local tier,instance,encounter,difficulty,lootPage=1,nil,nil,1,1
 local refresh,renderDetail,saved,dirty
 local selectedInstance,selectedBoss
 local journalTier,journalInstance,journalEncounter
 local title=U.Text(root,27);title:SetPoint("TOPLEFT",18,-14);title:SetText("Dungeon Journal")
 local back=U.Button(root,110,"Back",goHome);back:SetPoint("TOPRIGHT",-18,-12)
 local message=U.Message(root)
 local tabs={}
 for i,label in ipairs({"Dungeons","Raids"})do
  local value=label;local b=U.Button(root,190,label,function()mode=value;instance=nil;encounter=nil;selectedInstance=nil;selectedBoss=nil;refresh()end)
  b:SetPoint("TOPLEFT",18+(i-1)*202,-57);b:SetHeight(54);b.label:SetFont("Fonts\\FRIZQT__.TTF",19,"");tabs[label]=b
 end
 local expansion=U.Menu(root,280,"Expansion");expansion:SetPoint("TOPRIGHT",-18,-57);expansion:SetHeight(54);expansion.label:SetFont("Fonts\\FRIZQT__.TTF",17,"")
 expansion.OnSelect=function(value)tier=value;instance=nil;encounter=nil;selectedInstance=nil;selectedBoss=nil;refresh()end
 local left=U.Panel(root);left:SetPoint("TOPLEFT",14,-132);left:SetPoint("BOTTOMLEFT",14,42);left:SetWidth(280)
 local instances=U.List(left);instances:SetPoint("TOPLEFT",7,-47);instances:SetPoint("BOTTOMRIGHT",-28,7)
 local middle=U.Panel(root);middle:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0);middle:SetPoint("BOTTOMLEFT",left,"BOTTOMRIGHT",10,0);middle:SetWidth(260)
 local bosses=U.List(middle);bosses:SetPoint("TOPLEFT",7,-47);bosses:SetPoint("BOTTOMRIGHT",-28,7)
 local right=U.Panel(root);right:SetPoint("TOPLEFT",middle,"TOPRIGHT",10,0);right:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-14,42)
 local instanceLabel=U.Text(left,19);instanceLabel:SetPoint("TOPLEFT",17,-15);instanceLabel:SetText("Instances")
 local bossLabel=U.Text(middle,19);bossLabel:SetPoint("TOPLEFT",17,-15);bossLabel:SetText("Encounters")
 instances.rowHeight=90;bosses.rowHeight=94
 local artwork=right:CreateTexture(nil,"BACKGROUND",nil,1);artwork:SetPoint("TOPLEFT",6,-6);artwork:SetPoint("BOTTOMRIGHT",-6,6);artwork:SetAlpha(.12)
 local banner=right:CreateTexture(nil,"BACKGROUND",nil,2);banner:SetPoint("TOPLEFT",7,-7);banner:SetPoint("TOPRIGHT",-7,-7);banner:SetHeight(122);banner:SetTexCoord(0,1,.12,.72);banner:SetAlpha(.65)
 local shade=right:CreateTexture(nil,"BACKGROUND",nil,3);shade:SetAllPoints(banner);shade:SetColorTexture(0,0,0,.5)
 local heading=U.Text(right,26);heading:SetPoint("TOPLEFT",22,-22);heading:SetPoint("TOPRIGHT",-22,-22);heading:SetHeight(60)
 local subtitle=U.Text(right,16);subtitle:SetPoint("TOPLEFT",22,-94);subtitle:SetPoint("TOPRIGHT",-22,-94)
 local empty=U.Text(right,20);empty:SetPoint("CENTER",0,0);empty:SetWidth(400);empty:SetJustifyH("CENTER");empty:SetText("Choose a dungeon or raid, then select an encounter to view abilities and loot.")
 local function redButton(width,caption,handler)
  local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate");b:SetSize(width,50);b:SetText(caption);b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",17,"");b:SetScript("OnClick",handler);return b
 end
 local diff=U.Menu(right,230,"Difficulty");diff:SetPoint("BOTTOMLEFT",18,14);diff:SetHeight(50);diff:SetOpenUp(true);diff.label:SetFont("Fonts\\FRIZQT__.TTF",17,"")
 local detailMode="Abilities"
 local toggle=redButton(220,"Show loot",function()detailMode=detailMode=="Abilities"and "Loot"or "Abilities";lootPage=1;renderDetail()end);toggle:SetPoint("BOTTOMRIGHT",-18,14)
 local content,body=U.Scroll(right);content:SetPoint("TOPLEFT",18,-148);content:SetPoint("BOTTOMRIGHT",-31,79)
 local loot=U.List(right);loot:SetPoint("TOPLEFT",18,-148);loot:SetPoint("BOTTOMRIGHT",-31,138);loot.rowHeight=92;loot:Hide()
 local prev=redButton(160,"Previous",function()lootPage=math.max(1,lootPage-1);renderDetail()end);prev:SetPoint("BOTTOMLEFT",14,10)
 local nextPage=redButton(160,"Next",function()lootPage=lootPage+1;renderDetail()end);nextPage:SetPoint("BOTTOMRIGHT",-14,10)
 local pageText=U.Text(right,16);pageText:SetPoint("BOTTOM",0,28)
 local paragraphs={}
 local function writeParagraph(index,caption,description,y,depth,icon)
  local p=paragraphs[index]
  if not p then p={title=U.Text(body,21),body=U.Text(body,17),icon=body:CreateTexture(nil,"ARTWORK")};paragraphs[index]=p end
  local indent=(depth or 0)*10
  p.icon:ClearAllPoints();p.icon:SetPoint("TOPLEFT",indent,-y);p.icon:SetSize(40,40);p.icon:SetTexture(icon);p.icon:SetShown(icon~=nil and icon~=0)
  if icon and icon~=0 then indent=indent+52 end
  local width=math.max(120,content:GetWidth()-12-indent)
  p.title:ClearAllPoints();p.title:SetPoint("TOPLEFT",indent,-y);p.title:SetWidth(width);p.title:SetText(caption or "");p.title:Show()
  local h=math.max(icon and icon~=0 and 42 or 25,p.title:GetStringHeight());y=y+h+5
  p.body:ClearAllPoints();p.body:SetPoint("TOPLEFT",indent,-y);p.body:SetWidth(width);p.body:SetText(description or "");p.body:Show()
  return y+math.max(16,p.body:GetStringHeight())+19
 end
 local function selectJournal()
  if EncounterJournal and EncounterJournal:IsShown()then message:SetText("Close Blizzard's Dungeon Journal to continue browsing here.");return false end
  if journalTier~=tier then U.Call(EJ_SelectTier,tier);journalTier=tier;journalInstance=nil;journalEncounter=nil end
  if instance then
   if journalInstance~=instance or (journalEncounter and not encounter)then U.Call(EJ_SelectInstance,instance);journalInstance=instance;journalEncounter=nil end
   if U.Call(EJ_GetDifficulty)~=difficulty then U.Call(EJ_SetDifficulty,difficulty)end
  end
  if encounter and journalEncounter~=encounter then U.Call(EJ_SelectEncounter,encounter);journalEncounter=encounter end
  return true
 end
 diff.OnSelect=function(value)difficulty=value;lootPage=1;renderDetail()end
 renderDetail=function()
  if not instance then return end
  if not selectJournal()then return end
  empty:Hide();diff:Show();toggle:Show()
  local image=selectedInstance and selectedInstance.artwork or "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL"
  if not banner:SetTexture(image)then banner:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL")end;artwork:SetTexture(image)
  subtitle:SetText(selectedBoss and selectedInstance.name or "Instance overview")
  heading:SetText(selectedBoss and selectedBoss.name or selectedInstance and selectedInstance.name or "Select an encounter")
  toggle.label:SetText(detailMode=="Abilities"and "Show loot"or "Show abilities")
  local showLoot=detailMode=="Loot"
  diff:ClearAllPoints();diff:SetPoint("BOTTOMLEFT",18,showLoot and 77 or 14)
  toggle:ClearAllPoints();toggle:SetPoint("BOTTOMRIGHT",-18,showLoot and 77 or 14)
  content:SetShown(not showLoot);loot:SetShown(showLoot);prev:SetShown(showLoot);nextPage:SetShown(showLoot);pageText:SetShown(showLoot)
  for _,p in ipairs(paragraphs)do p.title:Hide();p.body:Hide();p.icon:Hide()end
  if showLoot then
   -- Native journal filters are shared. Save and restore them on leaving this view.
   U.Call(EJ_SetLootFilter,0,0);U.Call(J.SetSlotFilter,Enum.ItemSlotFilterType and Enum.ItemSlotFilterType.NoFilter or 15)
   local count=U.Call(EJ_GetNumLoot)or 0;local pages=math.max(1,math.ceil(count/12));lootPage=math.max(1,math.min(pages,lootPage));local data={}
   for i=(lootPage-1)*12+1,math.min(count,lootPage*12)do
    local item=U.Call(J.GetLootInfoByIndex,i)
    if item then data[#data+1]={id=item.itemID,name=item.name or "Loading item...",icon=item.icon or 134400,largeIcon=true,journal=true,link=item.link,sub=table.concat({item.slot or "",item.armorType or ""}," ")}end
   end
   if #data==0 then data[1]={name="No loot for this selection",sub="Try another encounter or difficulty."}end
   loot:SetData(data,function(d)if d.link then WoWUDetails.ShowLink(d.link,loot)end end)
   prev:SetEnabled(lootPage>1);nextPage:SetEnabled(lootPage<pages);pageText:SetText(lootPage.." / "..pages)
  else
   local y,index=0,0
   local function add(caption,description,depth,icon)index=index+1;y=writeParagraph(index,caption,description,y,depth,icon)end
   if selectedBoss then
    add(selectedBoss.name,selectedBoss.description,0,selectedBoss.icon)
    local visited={}
    local function walk(id,depth)
     while id and id>0 and not visited[id]and index<250 do
      visited[id]=true;local section=U.Call(J.GetSectionInfo,id);if not section then break end
      if not section.filteredByDifficulty then
       add(section.title,section.description,math.min(depth,5),section.abilityIcon)
       if section.firstChildSectionID and depth<12 then walk(section.firstChildSectionID,depth+1)end
      end
      id=section.siblingSectionID
     end
    end
    walk(selectedBoss.section,0)
   else add(selectedInstance and selectedInstance.name or "Dungeon Journal",selectedInstance and selectedInstance.description or "Select a dungeon or raid.")end
   body:SetHeight(math.max(1,y))
   content:SetVerticalScroll(math.min(content:GetVerticalScroll(),math.max(0,y-content:GetHeight())))
  end
 end
 local function chooseInstance(d)
  instance=d.id;encounter=nil;selectedInstance=d;selectedBoss=nil;lootPage=1;content:SetVerticalScroll(0);loot:SetVerticalScroll(0);selectJournal()
  local available={};local seen={}
  for _,id in pairs(Enum.Difficulty or {1,2,3,4,5,6,7,9})do
   if type(id)=="number"and U.Call(EJ_IsValidInstanceDifficulty,id)and U.Call(J.InstanceHasDifficultyID,id)~=false then
    local base=U.Call(J.GetBaseDifficultyID,id)or id
    if not seen[base]then seen[base]=true;available[#available+1]={id=base,name=U.Call(GetEJDifficultyString,id)or U.Call(GetDifficultyInfo,id)or ("Difficulty "..id)}end
   end
  end
  table.sort(available,function(a,b)return a.id<b.id end)
  local valid=false;for _,e in ipairs(available)do if e.id==difficulty then valid=true end end
  if not valid and available[1]then difficulty=available[1].id end
  diff:SetOptions(available,difficulty);selectJournal()
  local data={{id=0,name="Instance overview",journal=true,sub="Description and all loot"}}
  for i=1,100 do
   local name,description,id,section=U.Call(EJ_GetEncounterInfoByIndex,i,instance)
   if not id then break end
   local _,_,_,_,icon=U.Call(EJ_GetCreatureInfo,1,id)
   data[#data+1]={id=id,name=name,description=description,section=section,icon=icon,largeIcon=true,journal=true,sub="Encounter guide"}
  end
  bosses:SetData(data,function(d)
   encounter=d.id~=0 and d.id or nil;selectedBoss=encounter and d or nil;lootPage=1;content:SetVerticalScroll(0);loot:SetVerticalScroll(0);renderDetail()
  end,encounter or 0)
  right:Show();renderDetail()
 end
 refresh=function()
  dirty=nil
  if not root:IsShown()then return end
  local ok,reason=U.Load("Blizzard_EncounterJournal");if not ok then message:SetText(reason);return end
  if EncounterJournal and EncounterJournal:IsShown()then message:SetText("Close Blizzard's Dungeon Journal, then select a WoWU tab to continue browsing here.");return end
  if not saved then
   local class,spec=U.Call(EJ_GetLootFilter)
   saved={tier=U.Call(EJ_GetCurrentTier),difficulty=U.Call(EJ_GetDifficulty),instance=EncounterJournal and EncounterJournal.instanceID,encounter=EncounterJournal and EncounterJournal.encounterID,class=class,spec=spec,slot=U.Call(J.GetSlotFilter)}
   tier=saved.tier or U.Call(EJ_GetNumTiers)or 1
  end
  for name,b in pairs(tabs)do WoWU_Theme.Tab(b,name==mode)end
  left:Show();middle:Show();right:Show();expansion:Show()
  local tiers={};for i=1,(U.Call(EJ_GetNumTiers)or 0)do tiers[#tiers+1]={id=i,name=U.Call(EJ_GetTierInfo,i)or "Expansion"}end;expansion:SetOptions(tiers,tier)
  if journalTier~=tier then U.Call(EJ_SelectTier,tier);journalTier=tier;journalInstance=nil;journalEncounter=nil end
  local data={}
  for i=1,200 do
   local id,name,description,background,image=U.Call(EJ_GetInstanceByIndex,i,mode=="Raids")
   if not id then break end
   data[#data+1]={id=id,name=name,description=description,artwork=background or image,journal=true,sub=mode=="Raids"and "Raid"or "Dungeon"}
  end
  instances:SetData(data,chooseInstance,instance)
  message:SetText(#data==0 and "No journal entries in this expansion."or "Select an instance, then an encounter. Loot loads one page at a time.")
  if instance then renderDetail()else
   bosses:SetData({{name="Select an instance",sub="Encounters will appear here.",journal=true}})
   heading:SetText("Dungeon Journal");subtitle:SetText("Dungeons and raids");empty:Show()
   banner:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL");artwork:SetTexture(nil)
   for _,f in ipairs({content,loot,diff,toggle,prev,nextPage,pageText})do f:Hide()end
  end
 end
 local events=CreateFrame("Frame",nil,root)
 for _,event in ipairs({"EJ_LOOT_DATA_RECIEVED","EJ_DIFFICULTY_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"})do U.Call(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function()if root:IsShown()then dirty=true end end)
 local elapsed=0;root:SetScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if elapsed>.25 then elapsed=0;if dirty then refresh()end end end)
 root:SetScript("OnShow",function()refresh()end)
 root:SetScript("OnHide",function()
  GameTooltip:Hide();expansion:Close();diff:Close()
  if saved and not (EncounterJournal and EncounterJournal:IsShown())then
   U.Call(EJ_SelectTier,saved.tier);if saved.instance then U.Call(EJ_SelectInstance,saved.instance)end
   if saved.encounter then U.Call(EJ_SelectEncounter,saved.encounter)end
   U.Call(EJ_SetDifficulty,saved.difficulty);U.Call(EJ_SetLootFilter,saved.class,saved.spec);U.Call(J.SetSlotFilter,saved.slot)
  end
  saved=nil;journalTier=nil;journalInstance=nil;journalEncounter=nil
 end)
 return root
end
