-- Forever class talents: named trees, bundled artwork and explicit point allocation.
local function call(fn,...)
 if type(fn)~="function" then return end
 local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
local function activeConfig()
 return call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
end
function WoWU_GetAvailableTalentPoints()
 if WoWUMistsTalents then return WoWUMistsTalents.AvailablePoints()end
 if WoWUClient.isClassic then return tonumber(call(GetUnspentTalentPoints)or call(UnitCharacterPoints,'player'))or 0 end
 local config=activeConfig();local ci=call(C_Traits and C_Traits.GetConfigInfo,config)
 if not ci then return 0 end
 local count,seen=0,{}
 for _,tree in ipairs(ci.treeIDs or {}) do
  for _,currency in ipairs(call(C_Traits.GetTreeCurrencyInfo,config,tree,false) or {}) do
   if not seen[currency.traitCurrencyID] then
    seen[currency.traitCurrencyID]=true;count=count+math.max(0,currency.quantity or 0)
   end
  end
 end
 return count
end
local art={
 WARRIOR={"WarriorArms","WarriorFury","WarriorProtection"},
 PALADIN={"PALADINHOLY","PALADINPROTECTION","PALADINCOMBAT"},
 HUNTER={"HunterBeastMastery","HunterMarksmanship","HunterSurvival"},
 ROGUE={"RogueAssassination","RogueCombat","RogueSubtlety"},
 PRIEST={"PriestDiscipline","PriestHoly","PriestShadow"},
 SHAMAN={"ShamanElementalCombat","ShamanEnhancement","ShamanRestoration"},
 MAGE={"MageArcane","MageFire","MageFrost"},
 WARLOCK={"WarlockCurses","WarlockSummoning","WarlockDestruction"},
 DRUID={"DruidBalance","DruidFeralCombat","DruidRestoration"},
}
local function text(p,n)
 local f=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
 f:SetFont("Fonts\\FRIZQT__.TTF",n,"");WoWU_Theme.TextColor(f,.96,.82,.54);return f
end
local function button(p,w,h,caption)
 local b=CreateFrame("Button",nil,p,"BackdropTemplate");b:SetSize(w,h)
 b.label=text(b,13);b.label:SetPoint("CENTER");b.label:SetText(caption or "")
 WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);return b
end
local function redButton(p,w,h,caption)
 local b=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");b:SetSize(w,math.max(40,h));b:SetText(caption);b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",17,"");return b
end
local function describe(config,entryID)
 local entry=call(C_Traits.GetEntryInfo,config,entryID)
 local def=entry and call(C_Traits.GetDefinitionInfo,entry.definitionID) or {}
 local spell=def.spellID or def.overriddenSpellID
 local info=spell and call(C_Spell and C_Spell.GetSpellInfo,spell)
 local name=def.overrideName or (info and info.name) or call(GetSpellInfo,spell) or "Loading talent..."
 return name,def.overrideIcon or (info and info.iconID) or 134400,spell,def.overrideDescription
end
function WoWU_BuildTalents(panel)
 if WoWUMistsTalents then return WoWUMistsTalents.Build(panel)end
 if WoWUClient.isClassic and WoWUClassicModules then return WoWUClassicModules.Talents(panel)end
 local group=call(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or 1
 local config,selected,selectedEntry,refresh
 local cards,buttons,lines={},{},{}
 local status=text(panel,14);status:SetPoint("TOPRIGHT",-20,-18);status:SetWidth(850);status:SetJustifyH("RIGHT")
 local tabs={}
 for i,caption in ipairs({DUAL_SPEC_PRIMARY or "Primary",DUAL_SPEC_SECONDARY or "Secondary"}) do
  local index=i;local b=button(panel,135,34,caption);b:SetPoint("TOPLEFT",12+(i-1)*142,-7)
  b:SetScript("OnClick",function() group=index;selected=nil;refresh() end);tabs[i]=b
 end
 local detail=CreateFrame("Frame",nil,panel,"BackdropTemplate");detail:SetPoint("BOTTOMLEFT",12,12);detail:SetPoint("BOTTOMRIGHT",-12,12);detail:SetHeight(160);WoWU_Theme.Panel(detail)
 local name=text(detail,21);name:SetPoint("TOPLEFT",14,-12);name:SetWidth(760);name:SetJustifyH("LEFT")
 local description=text(detail,17);description:SetPoint("TOPLEFT",14,-38);description:SetWidth(760);description:SetHeight(106);description:SetWordWrap(true);description:SetJustifyH("LEFT");description:SetJustifyV("TOP")
 local spend=redButton(detail,170,34,"Spend 1 point");spend:SetPoint("TOPRIGHT",-14,-10)
 local apply=redButton(detail,170,34,"Apply changes");apply:SetPoint("BOTTOMRIGHT",-14,10)
 local undo=redButton(detail,135,34,"Undo pending");undo:SetPoint("RIGHT",apply,"LEFT",-8,0)
 local choice=redButton(detail,135,34,"Next choice");choice:SetPoint("RIGHT",spend,"LEFT",-8,0);choice:Hide()
 for i=1,3 do
  local f=CreateFrame("Frame",nil,panel,"BackdropTemplate")
  f:SetPoint("TOPLEFT",12+(i-1)*394,-53);f:SetPoint("BOTTOMLEFT",12+(i-1)*394,182);f:SetWidth(386);WoWU_Theme.Panel(f)
  local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetPoint("TOPLEFT",5,-46);bg:SetPoint("BOTTOMRIGHT",-5,5);bg:SetAlpha(.7)
  local shade=f:CreateTexture(nil,"BACKGROUND",nil,1);shade:SetAllPoints(bg);shade:SetColorTexture(0,0,0,.28)
  local title=text(f,19);title:SetPoint("TOP",0,-13);title:SetWidth(370)
  local scroll=CreateFrame("ScrollFrame",nil,f);scroll:SetPoint("TOPLEFT",7,-50);scroll:SetPoint("BOTTOMRIGHT",-7,8)
  local body=CreateFrame("Frame",nil,scroll);body.WoWUKeepLight=true;body:SetSize(372,520);scroll:SetScrollChild(body)
  if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
  scroll:EnableMouseWheel(true);scroll:SetScript("OnMouseWheel",function(self,delta)self:SetVerticalScroll(math.max(0,math.min(math.max(0,body:GetHeight()-self:GetHeight()),self:GetVerticalScroll()-delta*40)))end)
  cards[i]={frame=f,bg=bg,title=title,scroll=scroll,body=body}
 end
 local function editable()
  return config and config==activeConfig() and not (InCombatLockdown and InCombatLockdown()) and not UnitIsDeadOrGhost("player")
 end
 local function detailRefresh()
  local node=selected and call(C_Traits.GetNodeInfo,config,selected)
  if node then
   selectedEntry=selectedEntry or (node.activeEntry and node.activeEntry.entryID) or node.entryIDs[1]
   local title,_,spell,desc=describe(config,selectedEntry)
   name:SetText(title.."  "..(node.currentRank or 0).."/"..(node.maxRanks or 1))
   description:SetText(desc or call(C_Spell and C_Spell.GetSpellDescription,spell) or "Select Spend 1 point to allocate a rank, then Apply changes.")
   spend:SetEnabled(editable() and call(C_Traits.CanPurchaseRank,config,selected,selectedEntry)==true)
   choice:SetShown(#(node.entryIDs or {})>1)
  else
   name:SetText("Select a talent to see its name and details")
   description:SetText("Select a talent, spend points, then Apply changes. Green borders mark talents you can learn. Undo pending discards all unapplied changes in this build.")
   spend:Disable();choice:Hide()
  end
  local pending=config and call(C_Traits.ConfigHasStagedChanges,config)
  apply:SetEnabled(editable() and pending==true);undo:SetEnabled(editable() and pending==true)
 end
 choice:SetScript("OnClick",function()
  local n=selected and call(C_Traits.GetNodeInfo,config,selected);if not n then return end
  local index=1;for i,id in ipairs(n.entryIDs) do if id==selectedEntry then index=i%#n.entryIDs+1;break end end
  selectedEntry=n.entryIDs[index];detailRefresh()
 end)
 spend:SetScript("OnClick",function()
  if not editable() or not selected then return end
  if not call(C_Traits.CanPurchaseRank,config,selected,selectedEntry) then status:SetText("This talent's requirements are not met.");return end
  local n=call(C_Traits.GetNodeInfo,config,selected)
  if n and #n.entryIDs>1 and (not n.activeEntry or n.activeEntry.entryID~=selectedEntry) then
   if not call(C_Traits.SetSelection,config,selected,selectedEntry) then status:SetText("The game could not select that talent.");return end
   -- Selecting a choice may itself allocate its first rank.
   local updated=call(C_Traits.GetNodeInfo,config,selected)
   if updated and updated.currentRank>n.currentRank then refresh();return end
  end
  local ok=call(C_Traits.PurchaseRank,config,selected);refresh()
  if not ok then status:SetText("The game could not allocate this point. Check talent requirements.") end
 end)
 apply:SetScript("OnClick",function()
  if not editable() then return end
  local allowed,canAdd,reason=call(C_ClassTalents and C_ClassTalents.CanChangeTalents)
  if allowed==false and not canAdd then status:SetText(reason or "Talents cannot be applied right now.");return end
  local ok=call(C_ClassTalents and C_ClassTalents.CommitConfig)
  refresh();status:SetText(ok and "Talent changes submitted." or "The game could not apply changes. Your pending choices remain.")
 end)
 undo:SetScript("OnClick",function()if editable() then call(C_Traits.RollbackConfig,config);refresh() end end)
 refresh=function()
  for _,b in ipairs(buttons) do b:Hide() end
  for _,l in ipairs(lines) do l:Hide() end
  for i,b in ipairs(tabs) do WoWU_Theme.Tab(b,i==group);b:SetEnabled(i==1 or (call(GetNumSpecGroups) or 1)>1) end
  config=call(C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup,group)
  if not config and group==(call(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or 1) then config=activeConfig() end
  local ci=call(C_Traits and C_Traits.GetConfigInfo,config)
  if not ci then status:SetText("Talent information is not available yet.");detailRefresh();return end
  local display,all,seen={},{},{}
  for _,tree in ipairs(ci.treeIDs or {}) do
   for _,d in ipairs(call(C_Traits.GetGroupDisplayInfoByTreeID,tree) or {}) do display[#display+1]=d end
   for _,id in ipairs(call(C_Traits.GetTreeNodes,tree) or {}) do
    local n=call(C_Traits.GetNodeInfo,config,id)
    if not seen[id] and n and n.isVisible~=false and #n.entryIDs>0 then seen[id]=true;all[#all+1]=n end
   end
  end
  table.sort(display,function(a,b)return a.orderIndex<b.orderIndex end)
  local _,class=UnitClass("player");local groupToCol={};local columns={{},{},{}}
  for i=1,3 do
   local d=display[i];if d then groupToCol[d.groupID]=i end
   cards[i].title:SetText(d and d.displayName or "Talents")
   cards[i].bg:SetTexture(art[class] and ("Interface\\AddOns\\WoWU\\Media\\Talents\\"..art[class][i]) or WoWU_Theme.assets.marble)
  end
  local minX,maxX=math.huge,-math.huge
  for _,n in ipairs(all) do minX=math.min(minX,n.posX);maxX=math.max(maxX,n.posX) end
  for _,n in ipairs(all) do
   local col;for _,id in ipairs(n.groupIDs or {}) do col=groupToCol[id] or col end
   col=col or math.min(3,math.floor((n.posX-minX)/math.max(1,maxX-minX)*3)+1)
   table.insert(columns[col],n)
  end
  local count,lineCount=0,0
  for col,sub in ipairs(columns) do
   local card=cards[col];local xs,ys,xseen,yseen={},{},{},{}
   for _,n in ipairs(sub) do if not xseen[n.posX] then xs[#xs+1]=n.posX;xseen[n.posX]=true end;if not yseen[n.posY] then ys[#ys+1]=n.posY;yseen[n.posY]=true end end
   table.sort(xs);table.sort(ys);for i,x in ipairs(xs)do xseen[x]=i end;for i,y in ipairs(ys)do yseen[y]=i end
   card.body:SetHeight(math.max(1,#ys*96+12));local placed={}
   for _,n in ipairs(sub) do
    count=count+1;local b=buttons[count]
    if not b then
     b=button(card.body,42,42);b.label:Hide()
     b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("TOPLEFT",4,-4);b.icon:SetPoint("BOTTOMRIGHT",-4,4)
     b.rank=text(b,12);b.rank:SetPoint("BOTTOMRIGHT",2,-2);b.rank:SetShadowOffset(1,-1)
     b.name=text(b,10);b.name:SetPoint("TOP",b,"BOTTOM",0,-3);b.name:SetSize(86,34);b.name:SetWordWrap(true);b.name:SetJustifyV("TOP")
     b:SetScript("OnClick",function(self)if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(self.scroll)then return end;selected=self.node.ID;selectedEntry=nil;detailRefresh()end)
     b:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_RIGHT");if self.spell then GameTooltip:SetSpellByID(self.spell) else GameTooltip:SetText(self.name:GetText()) end;GameTooltip:Show()end)
     b:SetScript("OnLeave",function()GameTooltip:Hide()end);buttons[count]=b;WoWUDetails.BindHover(b,true)
    end
    b:SetParent(card.body);b:ClearAllPoints()
    local x=(xseen[n.posX]-.5)*372/math.max(1,#xs)-21;local y=12+(yseen[n.posY]-1)*96
    b:SetPoint("TOPLEFT",x,-y);b.node=n;b.scroll=card.scroll
    local entry=(n.activeEntry and n.activeEntry.entryID) or n.entryIDs[1]
    local title,icon,spell=describe(config,entry);b.spell=spell;b.icon:SetTexture(icon);b.name:SetText(title)
    b.rank:SetText((n.currentRank or 0).."/"..(n.maxRanks or 1));b.icon:SetDesaturated((n.currentRank or 0)==0 and not n.canPurchaseRank)
    local available=editable() and n.canPurchaseRank;WoWU_Theme.Border(b,available and .3 or .8,available and 1 or .65,.25,1)
    b:Show();placed[n.ID]={x=x+21,y=y+21,node=n}
   end
   for _,p in pairs(placed)do for _,edge in ipairs(p.node.visibleEdges or {})do
    local dest=placed[edge.targetNode]
    if dest then
     lineCount=lineCount+1;local l=lines[lineCount]
     -- Lines are kept with their original scroll child; allocate per refresh when needed.
     if not l or l.owner~=card.body then if l then l:Hide() end;l=card.body:CreateLine(nil,"BACKGROUND");l.owner=card.body;lines[lineCount]=l end
     l:SetThickness(2);l:SetColorTexture(.8,.65,.3,edge.isActive and .8 or .3)
     l:SetStartPoint("TOPLEFT",p.x,-p.y);l:SetEndPoint("TOPLEFT",dest.x,-dest.y);l:Show()
    end
   end end
   card.scroll:SetVerticalScroll(math.min(card.scroll:GetVerticalScroll(),math.max(0,card.body:GetHeight()-card.scroll:GetHeight())))
  end
  status:SetText(WoWU_GetAvailableTalentPoints().." talent points available"..(config~=activeConfig() and "  |  Inactive build (view only)" or call(C_Traits.ConfigHasStagedChanges,config) and "  |  Changes pending - Apply when ready" or ""))
  detailRefresh()
 end
 local ev=CreateFrame("Frame",nil,panel)
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TALENT_UPDATE","TRAIT_CONFIG_UPDATED","TRAIT_NODE_CHANGED","TRAIT_CONFIG_COMMIT_FAILED","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"})do pcall(ev.RegisterEvent,ev,event)end
 ev:SetScript("OnEvent",function(_,event)if event=="ACTIVE_TALENT_GROUP_CHANGED" then group=call(C_SpecializationInfo.GetActiveSpecGroup) or 1;selected=nil end;if panel:IsShown() then refresh();if event=="TRAIT_CONFIG_COMMIT_FAILED" then status:SetText("The game could not apply the pending talent changes.") end end end)
 panel:HookScript("OnShow",refresh);panel:HookScript("OnHide",function()GameTooltip:Hide()end)
 refresh()
end
