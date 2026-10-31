-- Retail talent presentation owned by WoWU. Native frames are never embedded.
-- Coordinates, currency ordering and artwork follow Blizzard's ClassTalents UI.
if not WoWUClient.isRetail then return end
local function call(fn,...)
 if type(fn)~="function"then return end
 local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
local function text(parent,size)
 local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 f:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(f,.96,.84,.6);f:SetJustifyH("LEFT");return f
end
local function button(parent,width,caption)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(width,34)
 b.label=text(b,13);b.label:SetPoint("CENTER");b.label:SetText(caption)
 WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);return b
end
local function redButton(parent,width,caption)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width,40);b:SetText(caption);b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",17,"");return b
end
local function atlas(texture,name)
 if name and call(C_Texture and C_Texture.GetAtlasInfo,name)then texture:SetAtlas(name);texture:Show();return true end
 texture:Hide();return false
end
local function isChoice(node)
 return node.type==Enum.TraitNodeType.Selection or node.type==Enum.TraitNodeType.SubTreeSelection
end
local function entryInfo(config,id)
 local entry=call(C_Traits.GetEntryInfo,config,id)or {}
 local def=entry.definitionID and call(C_Traits.GetDefinitionInfo,entry.definitionID)or {}
 local spell=def.overriddenSpellID or def.spellID
 local info=spell and call(C_Spell.GetSpellInfo,spell)or {}
 local sub=entry.subTreeID and call(C_Traits.GetSubTreeInfo,config,entry.subTreeID)
 return {id=id,name=def.overrideName or info.name or (sub and sub.name)or "Loading talent...",
  icon=def.overrideIcon or info.iconID or 134400,spell=spell,entryType=entry.type,
  description=def.overrideDescription or (sub and sub.description)or (spell and call(C_Spell.GetSpellDescription,spell))or "",
  subTreeID=entry.subTreeID}
end

function WoWU_BuildRetailTalents(panel)
 local config,selected,selectedEntry,refresh,detailRefresh
 local treeTab=1
 local nodes,partitions,currencies={},{ {},{} },{}
 local heroPoints=0
 local nodeButtons,edges,gates={},{},{}
 local scrollPositions={0,0}
 local lastConfig,lastSpec,dirty,notice,committing
 local title=text(panel,22);title:SetPoint("TOPLEFT",18,-12)
 local status=text(panel,13);status:SetPoint("TOPLEFT",18,-43);status:SetPoint("RIGHT",panel,"RIGHT",-275,0)
 local native=redButton(panel,238,"Loadouts / Hero talents / PvP");native:SetPoint("TOPRIGHT",-18,-14)
 native:SetScript("OnClick",function()local ok,msg=WoWU_OpenRetailTalents();if not ok then notice=msg;dirty=true end end)
 local specialization=redButton(panel,170,"Specialization");specialization:SetPoint("TOPRIGHT",native,"BOTTOMRIGHT",0,-12)
 specialization:SetScript("OnClick",WoWU_BuildRetailSpecializations(panel))
 local tabs={}
 for i=1,2 do
  local index=i;local b=button(panel,230,"");b:SetPoint("TOPLEFT",18+(i-1)*238,-66);tabs[i]=b
  b:SetScript("OnClick",function()
   scrollPositions[treeTab]=panel.retailTalentScroll:GetVerticalScroll()
   treeTab=index;selected=nil;selectedEntry=nil;refresh();panel.retailTalentScroll:SetVerticalScroll(scrollPositions[index]or 0)
  end)
 end
 local viewport=CreateFrame("Frame",nil,panel,"BackdropTemplate")
 viewport:SetPoint("TOPLEFT",14,-107);viewport:SetPoint("BOTTOMRIGHT",-14,190);WoWU_Theme.Panel(viewport)
 local background=viewport:CreateTexture(nil,"BACKGROUND",nil,1);background:SetPoint("TOPLEFT",4,-4);background:SetPoint("BOTTOMRIGHT",-4,4)
 local shade=viewport:CreateTexture(nil,"BACKGROUND",nil,2);shade:SetAllPoints(background);shade:SetColorTexture(0,0,0,.27)
 local scroll=CreateFrame("ScrollFrame",nil,viewport,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",8,-8);scroll:SetPoint("BOTTOMRIGHT",-29,8);panel.retailTalentScroll=scroll
 local body=CreateFrame("Frame",nil,scroll);body.WoWUKeepLight=true;body:SetSize(1100,1000);scroll:SetScrollChild(body)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 local heroTitle=text(body,19)
 local empty=text(body,17);empty:SetPoint("TOP",0,-55);empty:SetWidth(900);empty:SetJustifyH("CENTER")
 local detail=CreateFrame("Frame",nil,panel,"BackdropTemplate");detail:SetPoint("BOTTOMLEFT",14,12);detail:SetPoint("BOTTOMRIGHT",-14,12);detail:SetHeight(168);WoWU_Theme.Panel(detail)
 local icon=detail:CreateTexture(nil,"ARTWORK");icon:SetSize(52,52);icon:SetPoint("TOPLEFT",12,-12)
 local name=text(detail,21);name:SetPoint("TOPLEFT",icon,"TOPRIGHT",10,0);name:SetPoint("RIGHT",detail,"RIGHT",-440,0)
 local detailScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate");detailScroll:SetPoint("TOPLEFT",74,-44);detailScroll:SetPoint("BOTTOMRIGHT",-456,12)
 local detailBody=CreateFrame("Frame",nil,detailScroll);detailBody:SetSize(500,1);detailScroll:SetScrollChild(detailBody);WoWU_EnableTouchScroll(detailScroll)
 local desc=text(detailBody,18);desc:SetPoint("TOPLEFT");desc:SetPoint("TOPRIGHT",-4,0);desc:SetJustifyV("TOP");desc:SetWordWrap(true)
 local function setDescription(value)
  detailBody:SetWidth(math.max(1,detailScroll:GetWidth()));desc:SetText(value or "");detailBody:SetHeight(math.max(1,desc:GetStringHeight()+10));detailScroll:SetVerticalScroll(0)
 end
 detailScroll:HookScript("OnSizeChanged",function()detailBody:SetWidth(math.max(1,detailScroll:GetWidth()));detailBody:SetHeight(math.max(1,desc:GetStringHeight()+10))end)
 local spend=redButton(detail,126,"Spend point");spend:SetPoint("TOPRIGHT",-12,-10)
 local choice=redButton(detail,126,"Next choice");choice:SetPoint("RIGHT",spend,"LEFT",-8,0)
 local refund=redButton(detail,126,"Refund point");refund:SetPoint("RIGHT",choice,"LEFT",-8,0)
 local apply=redButton(detail,180,"Apply changes");apply:SetPoint("BOTTOMRIGHT",-12,10)
 local undo=redButton(detail,180,"Undo pending");undo:SetPoint("RIGHT",apply,"LEFT",-8,0)
 local function editable()
  return config and config==call(C_ClassTalents.GetActiveConfigID)and not InCombatLockdown()and not UnitIsDeadOrGhost("player")and not committing and call(C_Traits.CanEditConfig,config)~=false
 end
 detailRefresh=function()
  local node=nodes[selected]
  local pending=config and call(C_Traits.ConfigHasStagedChanges,config)
  apply:SetEnabled(editable()and pending==true);undo:SetEnabled(editable()and pending==true)
  native:SetEnabled(not InCombatLockdown());refund:Disable();spend:Disable();choice:Hide()
  if not node then
   icon:Hide();name:SetText("Select a talent")
   setDescription("Scroll to explore the tree. Select a node to read its details, spend or refund a point. Apply changes when ready. Both tabs share the active build's pending changes.");return
  end
  selectedEntry=selectedEntry or (node.type==Enum.TraitNodeType.Tiered and node.nextEntry and node.nextEntry.entryID)or (node.activeEntry and node.activeEntry.entryID)or node.entryIDs[1]
  local info=entryInfo(config,selectedEntry)
  icon:Show();icon:SetTexture(info.icon)
  name:SetText(info.name..(info.subTreeID and ""or "  "..(node.currentRank or 0).."/"..(node.totalMaxRanks or node.maxRanks or 1)))
  local requirements={}
  for _,id in ipairs(node.conditionIDs or {})do
   local c=call(C_Traits.GetConditionInfo,config,id)
   if c and c.isMet==false then
    if c.spentAmountRequired then requirements[#requirements+1]="Spend "..c.spentAmountRequired.." points in this tree."
    elseif c.playerLevel then requirements[#requirements+1]="Requires level "..c.playerLevel.."."end
   end
  end
  setDescription(info.description..(#requirements>0 and "\n|cffffa050"..table.concat(requirements," ").."|r"or ""))
  choice:SetShown(isChoice(node)and #node.entryIDs>1);choice:SetEnabled(not committing)
  local changingChoice=isChoice(node)and node.activeEntry and node.activeEntry.entryID~=selectedEntry
  spend.label:SetText(info.subTreeID and "Choose tree"or changingChoice and "Choose talent"or "Spend point")
  spend:SetEnabled(editable()and ((info.subTreeID or changingChoice)and node.isAvailable~=false or call(C_Traits.CanPurchaseRank,config,node.ID,selectedEntry)==true))
  refund:SetEnabled(editable()and not info.subTreeID and call(C_Traits.CanRefundRank,config,node.ID)==true)
 end
 choice:SetScript("OnClick",function()
  local n=nodes[selected];if not n then return end
  local index=1;for i,id in ipairs(n.entryIDs)do if id==selectedEntry then index=i%#n.entryIDs+1;break end end
  selectedEntry=n.entryIDs[index];detailRefresh()
 end)
 spend:SetScript("OnClick",function()
  if not editable()then return end
  local n=nodes[selected];if not n or not selectedEntry then return end
  local info=entryInfo(config,selectedEntry);local ok
  if info.subTreeID then ok=call(C_Traits.SetSelection,config,n.ID,selectedEntry)
  else
   local changingChoice=isChoice(n)and n.activeEntry and n.activeEntry.entryID~=selectedEntry
   if not changingChoice and not call(C_Traits.CanPurchaseRank,config,n.ID,selectedEntry)then notice="This talent's requirements are not met.";dirty=true;return end
   if isChoice(n)and (not n.activeEntry or n.activeEntry.entryID~=selectedEntry)then
    ok=call(C_Traits.SetSelection,config,n.ID,selectedEntry)
    if not ok then notice="This choice cannot be selected yet.";dirty=true;return end
    local updated=call(C_Traits.GetNodeInfo,config,n.ID)
    if changingChoice or (updated and updated.currentRank>(n.currentRank or 0))then dirty=true;notice=nil;return end
   end
   ok=call(C_Traits.PurchaseRank,config,n.ID)
  end
  if ok then selectedEntry=nil end
  notice=not ok and "The game could not stage this change. Check the talent requirements."or nil;dirty=true
 end)
 refund:SetScript("OnClick",function()
  if not editable()or not selected then return end
  local ok=call(C_Traits.CanRefundRank,config,selected)and call(C_Traits.RefundRank,config,selected)
  if ok then selectedEntry=nil end
  notice=not ok and "Refund would break a dependent talent or point requirement."or nil;dirty=true
 end)
 apply:SetScript("OnClick",function()
  if not editable()then return end
  local allowed,canAdd,reason=call(C_ClassTalents.CanChangeTalents)
  if allowed==false and not canAdd then notice=reason or "Talents cannot be applied right now.";dirty=true;return end
  local ok=call(C_ClassTalents.CommitConfig)
  if ok then committing=GetTime()+15;notice="Applying talent changes..."else notice="The game could not apply changes. Your pending choices remain."end
  dirty=true
 end)
 undo:SetScript("OnClick",function()if editable()then call(C_Traits.RollbackConfig,config);notice=nil;dirty=true end end)

 local function makeNode(index)
  local b=CreateFrame("Button",nil,body);b:SetSize(56,56);b:RegisterForClicks("LeftButtonUp")
  b.shadow=b:CreateTexture(nil,"BACKGROUND");b.shadow:SetPoint("CENTER");b.shadow:SetSize(70,70)
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(43,43);b.icon:SetPoint("CENTER")
  b.mask=b:CreateMaskTexture();b.mask:SetSize(44,44);b.mask:SetPoint("CENTER")
  b.rim=b:CreateTexture(nil,"OVERLAY");b.rim:SetPoint("CENTER");b.rim:SetSize(61,61)
  b.glow=b:CreateTexture(nil,"OVERLAY",nil,1);b.glow:SetPoint("CENTER");b.glow:SetSize(72,72);b.glow:SetBlendMode("ADD")
  b.rank=text(b,14);b.rank:SetPoint("BOTTOMRIGHT",2,0);b.rank:SetShadowOffset(1,-1)
  b.arrow=text(b,14);b.arrow:SetPoint("TOPRIGHT",6,5);b.arrow:SetText("+")
  b:SetScript("OnClick",function(self)
   if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll)then return end
   selected=self.node.ID;selectedEntry=nil;notice=nil;detailRefresh();dirty=true
  end)
  b:SetScript("OnEnter",function(self)
   GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
   if self.info.spell then GameTooltip:SetSpellByID(self.info.spell)else GameTooltip:SetText(self.info.name);GameTooltip:AddLine(self.info.description,1,1,1,true)end
   GameTooltip:AddLine("Select to view talent and allocate points.",.5,1,.5,true);GameTooltip:Show()
  end)
  b:SetScript("OnLeave",function()GameTooltip:Hide()end);WoWUDetails.BindHover(b,true)
  nodeButtons[index]=b;return b
 end
 local function collect()
  nodes={};partitions={{},{}};currencies={};heroPoints=0;local treeIDs={};local costs,belongs,allCurrencies={},{},{}
  local ci=config and call(C_Traits.GetConfigInfo,config)
  for _,tree in ipairs(ci and ci.treeIDs or {})do
   treeIDs[#treeIDs+1]=tree
   local money=call(C_Traits.GetTreeCurrencyInfo,config,tree,false)or {}
   for _,currency in ipairs(money)do allCurrencies[currency.traitCurrencyID]=currency end
   -- Blizzard displays currency [1] as class points and [2] as spec points.
   for i=1,2 do if money[i]then currencies[i]=money[i]end end
   for _,id in ipairs(call(C_Traits.GetTreeNodes,tree)or {})do
    local n=call(C_Traits.GetNodeInfo,config,id)
    if n and n.isVisible~=false and #(n.entryIDs or {})>0 then nodes[id]=n;costs[id]=call(C_Traits.GetNodeCost,config,id)or {}end
   end
  end
  local seenHero={}
  for _,n in pairs(nodes)do if n.subTreeID and n.subTreeActive and not seenHero[n.subTreeID]then
   seenHero[n.subTreeID]=true
   local sub=call(C_Traits.GetSubTreeInfo,config,n.subTreeID)
   local currency=sub and allCurrencies[sub.traitCurrencyID]
   heroPoints=heroPoints+math.max(0,currency and currency.quantity or 0)
  end end
  for id,n in pairs(nodes)do
   if n.subTreeID or n.type==Enum.TraitNodeType.SubTreeSelection then belongs[id]=2
   else for _,cost in ipairs(costs[id])do for i=1,2 do if currencies[i]and cost.ID==currencies[i].traitCurrencyID then belongs[id]=i end end end end
  end
  -- Granted starter nodes may have no cost; follow their real edges first.
  for pass=1,4 do
   for id,n in pairs(nodes)do for _,edge in ipairs(n.visibleEdges or {})do
    local other=nodes[edge.targetNode]
    if other and not n.subTreeID and not other.subTreeID then
     if not belongs[id]then belongs[id]=belongs[other.ID]elseif not belongs[other.ID]then belongs[other.ID]=belongs[id]end
    end
   end end
  end
  for id,n in pairs(nodes)do
   local side=belongs[id]
   if not side then
    local distance=math.huge
    for otherID,candidate in pairs(nodes)do if belongs[otherID]and not candidate.subTreeID then
     local d=math.abs(n.posX-candidate.posX)+math.abs(n.posY-candidate.posY)
     if d<distance then distance=d;side=belongs[otherID]end
    end end
   end
   side=side or 1
   if not n.subTreeID or n.subTreeActive then partitions[side][#partitions[side]+1]=n end
  end
  return ci,treeIDs
 end

 refresh=function()
  if not panel:IsShown()then return end
  dirty=nil
  config=call(C_ClassTalents.GetActiveConfigID)
  local spec=call(GetSpecialization);local specID,specName=call(GetSpecializationInfo,spec)
  local className=UnitClass("player")
  if config~=lastConfig or specID~=lastSpec then
   selected=nil;selectedEntry=nil;scrollPositions={0,0};scroll:SetVerticalScroll(0);notice=nil;committing=nil
  end
  lastConfig,lastSpec=config,specID
  local ci,treeIDs=collect()
  title:SetText((specName or className or "Retail").." - Talents")
  for i,b in ipairs(tabs)do
   local amount=math.max(0,currencies[i]and currencies[i].quantity or 0)+(i==2 and heroPoints or 0)
   b.label:SetText((i==1 and className or specName or "Specialization")..(amount>0 and " |cff80ff80("..amount..")|r"or ""));WoWU_Theme.Tab(b,i==treeTab)
  end
  -- Load definitions only; the native panel remains closed and independent.
  if not ClassTalentUtil and not InCombatLockdown()then call(C_AddOns and C_AddOns.LoadAddOn,"Blizzard_PlayerSpells")end
  local visuals=ClassTalentUtil and call(ClassTalentUtil.GetVisualsForSpecID,specID)
  if not atlas(background,visuals and visuals.background)then background:SetTexture(WoWU_Theme.assets.marble);background:Show()end
  for _,b in ipairs(nodeButtons)do b:Hide()end
  for _,e in ipairs(edges)do e:Hide();if e.arrow1 then e.arrow1:Hide();e.arrow2:Hide()end end
  for _,g in ipairs(gates)do g.line:Hide();g.label:Hide()end
  heroTitle:Hide();empty:Hide()
  local groups={{},{},{}}
  for _,n in ipairs(partitions[treeTab])do
   local group=n.subTreeID and 3 or n.type==Enum.TraitNodeType.SubTreeSelection and 2 or 1
   groups[group][#groups[group]+1]=n
  end
  local width=math.max(400,scroll:GetWidth());body:SetWidth(width)
  local placed,total,height={},0,24
  for group,list in ipairs(groups)do
   if #list>0 then
    if group==2 or (group==3 and #groups[2]==0)then heroTitle:ClearAllPoints();heroTitle:SetPoint("TOP",0,-height);heroTitle:SetText("Hero Talents"..(heroPoints>0 and " ("..heroPoints..")"or ""));heroTitle:Show();height=height+48 end
    local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
    local ys={}
    for _,n in ipairs(list)do minX=math.min(minX,n.posX);maxX=math.max(maxX,n.posX);minY=math.min(minY,n.posY);maxY=math.max(maxY,n.posY);ys[#ys+1]=n.posY end
    table.sort(ys);local gap=math.huge;for i=2,#ys do if ys[i]>ys[i-1]then gap=math.min(gap,ys[i]-ys[i-1])end end
    local scale=math.min((width-130)/math.max(1,maxX-minX),gap<math.huge and 92/gap or .15)
    local offset=(width-(maxX-minX)*scale)/2
    for _,n in ipairs(list)do
     total=total+1;local b=nodeButtons[total]or makeNode(total)
     local x=group==2 and width*(total-#groups[1])/(#list+1)or offset+(n.posX-minX)*scale
     local y=height+28+(group==2 and 0 or (n.posY-minY)*scale)
     b:ClearAllPoints();b:SetPoint("CENTER",body,"TOPLEFT",x,-y);b.node=n
     local entryID=n.activeEntry and n.activeEntry.entryID or n.entryIDs[1];local info=entryInfo(config,entryID);b.info=info
     local types=Enum.TraitNodeEntryType
     local shape=isChoice(n)and "choice"or (info.entryType==types.SpendCircle or info.entryType==types.SpendCapstoneCircle)and "circle"or "square"
     b.icon:RemoveMaskTexture(b.mask)
     if shape~="square"and atlas(b.mask,"talents-node-"..shape.."-mask")then b.icon:AddMaskTexture(b.mask)end
     b.icon:SetTexture(info.icon);local rank=n.currentRank or 0
     b.icon:SetDesaturated(rank==0);b.icon:SetAlpha(n.isAvailable==false and rank==0 and .45 or 1)
     local state=rank>0 and "yellow"or n.canPurchaseRank and "green"or "gray"
     atlas(b.rim,"talents-node-"..shape.."-"..state);atlas(b.shadow,"talents-node-"..shape.."-shadow")
     atlas(b.glow,"talents-node-"..shape.."-greenglow");b.glow:SetShown(selected==n.ID);b.glow:SetAlpha(.7)
     b.rank:SetText(group==2 and ""or rank.."/"..(n.totalMaxRanks or n.maxRanks or 1));b.arrow:SetShown(isChoice(n));b:Show()
     placed[n.ID]={x=x,y=y,node=n}
    end
    height=height+56+(group==2 and 0 or (maxY-minY)*scale)+52
   end
  end
  body:SetHeight(math.max(scroll:GetHeight(),height))
  local count=0
  for _,p in pairs(placed)do for _,edge in ipairs(p.node.visibleEdges or {})do
   local dest=placed[edge.targetNode]
   if dest then
    count=count+1;local line=edges[count]or body:CreateLine(nil,"BACKGROUND");edges[count]=line
    local dx,dy=dest.x-p.x,dest.y-p.y;local distance=math.sqrt(dx*dx+dy*dy)
    if distance>56 then
     dx,dy=dx/distance*29,dy/distance*29
     line:SetStartPoint("TOPLEFT",p.x+dx,-p.y-dy);line:SetEndPoint("TOPLEFT",dest.x-dx,-dest.y+dy)
     line:SetThickness(2);line:SetColorTexture(edge.isActive and .95 or .6,edge.isActive and .8 or .6,edge.isActive and .2 or .6,edge.isActive and .95 or .4);line:Show()
     if not line.arrow1 then line.arrow1=body:CreateLine(nil,"BACKGROUND");line.arrow2=body:CreateLine(nil,"BACKGROUND")end
     local ux,uy=dx/29,dy/29;local tipX,tipY=dest.x-dx,dest.y-dy
     for i,arrow in ipairs({line.arrow1,line.arrow2})do
      local sign=i==1 and 1 or -1
      arrow:SetStartPoint("TOPLEFT",tipX,-tipY)
      arrow:SetEndPoint("TOPLEFT",tipX-ux*9-uy*4*sign,-tipY+uy*9-ux*4*sign)
      arrow:SetThickness(2);arrow:SetColorTexture(edge.isActive and .95 or .6,edge.isActive and .8 or .6,edge.isActive and .2 or .6,edge.isActive and .95 or .4);arrow:Show()
     end
    end
   end
  end end
  local gateCount=0
  for _,tree in ipairs(treeIDs)do
   local info=call(C_Traits.GetTreeInfo,config,tree)or {}
   for _,gate in ipairs(info.gates or {})do
    local p=placed[gate.topLeftNodeID];local cond=call(C_Traits.GetConditionInfo,config,gate.conditionID)
    if p and cond and cond.spentAmountRequired then
     gateCount=gateCount+1;local g=gates[gateCount]
     if not g then g={line=body:CreateLine(nil,"BACKGROUND"),label=text(body,12)};gates[gateCount]=g end
     local y=p.y-41;g.line:SetStartPoint("TOPLEFT",105,-y);g.line:SetEndPoint("TOPLEFT",width-15,-y);g.line:SetThickness(1);g.line:SetColorTexture(.8,.65,.3,.35);g.line:Show()
     g.label:ClearAllPoints();g.label:SetPoint("TOPLEFT",12,-y+7);g.label:SetText(cond.spentAmountRequired.." points");g.label:SetTextColor(cond.isMet and .8 or 1,cond.isMet and .7 or .4,.3);g.label:Show()
    end
   end
  end
  if total==0 then empty:SetText(ci and "No talents are available in this tree yet."or "Choose a specialization to unlock your talent trees.");empty:Show()end
  if not nodes[selected]then selected=nil;selectedEntry=nil end
  local pending=config and call(C_Traits.ConfigHasStagedChanges,config)
  status:SetText(notice or (InCombatLockdown()and "View only during combat."or (ci and ci.name or "Active build")..(pending and "  |  Changes pending - Apply when ready"or "  |  Scroll to explore")))
  scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
  detailRefresh()
 end
 local events=CreateFrame("Frame",nil,panel)
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED","ACTIVE_COMBAT_CONFIG_CHANGED","TRAIT_CONFIG_UPDATED","TRAIT_NODE_CHANGED","TRAIT_NODE_CHANGED_PARTIAL","TRAIT_NODE_ENTRY_UPDATED","TRAIT_COND_INFO_CHANGED","TRAIT_SUB_TREE_CHANGED","TRAIT_CONFIG_COMMIT_FAILED","CONFIG_COMMIT_FAILED","TRAIT_TREE_CHANGED","TRAIT_TREE_CURRENCY_INFO_UPDATED","PLAYER_TALENT_UPDATE","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SPELL_DATA_LOAD_RESULT"})do call(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function(_,event)
  dirty=true
  if event=="TRAIT_CONFIG_COMMIT_FAILED"or event=="CONFIG_COMMIT_FAILED"then committing=nil;notice="The game could not apply changes. Your pending choices remain."
  elseif event=="TRAIT_CONFIG_UPDATED"then committing=nil;notice=nil end
 end)
 local elapsed=0
 panel:HookScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.12 then return end;elapsed=0
  if committing and (GetTime()>committing or not call(C_Traits.ConfigHasStagedChanges,config))then committing=nil;notice=nil;dirty=true end
  if dirty then refresh()end
 end)
 scroll:SetScript("OnSizeChanged",function()dirty=true end)
 panel:HookScript("OnShow",function()dirty=true;refresh()end)
 panel:HookScript("OnHide",function()scrollPositions[treeTab]=scroll:GetVerticalScroll();GameTooltip:Hide()end)
end
