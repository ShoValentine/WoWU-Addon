-- Classic module fallbacks host the client's own controls inside WoWU.
-- Talent trees and profession systems differ between Era/TBC and progression.
if not (WoWUClient and WoWUClient.isClassic)then return end
WoWUClassicModules={}
local H=WoWUClassicModules
local function text(p,size,value)local t=p:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetFont('Fonts\\FRIZQT__.TTF',size,'');t:SetText(value or '');return t end
local function button(p,name,w,fn)local b=CreateFrame('Button',nil,p,'UIPanelButtonTemplate');b:SetText(name);b:SetSize(w,36);b:SetScript('OnClick',fn);return b end
local function load(name)if C_AddOns and C_AddOns.LoadAddOn then return pcall(C_AddOns.LoadAddOn,name)elseif LoadAddOn then return pcall(LoadAddOn,name)end end
local function snapshot(f)
 local s={frame=f,parent=f:GetParent(),scale=f:GetScale(),ignore=f.IsIgnoringParentScale and f:IsIgnoringParentScale(),clamped=f:IsClampedToScreen(),points={}}
 for i=1,f:GetNumPoints()do s.points[i]={f:GetPoint(i)}end;return s
end
function H.Host(parent,title,addons,names,open)
 local root=CreateFrame('Frame',nil,parent);root:SetAllPoints();root:Hide()
 local heading=text(root,21,title);heading:SetPoint('TOPLEFT',20,-14)
 local status=text(root,13,'Classic native controls, fitted to the WoWU screen.');status:SetPoint('TOPLEFT',20,-45)
 local area=CreateFrame('Frame',nil,root);area:SetPoint('TOPLEFT',12,-86);area:SetPoint('BOTTOMRIGHT',-12,12)
 if WoWUKeyboard then
  local keyboard=WoWUKeyboard.Create(root,{draggable=false})
  local key=WoWUKeyboard.ToggleButton(root,function()
   if keyboard:IsShown()then keyboard:Hide();return end
   local edit=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
   if edit and edit.GetText and edit.SetText then keyboard:Open(edit)else status:SetText('Tap a text or quantity field, then tap Keyboard.')end
  end);key:ClearAllPoints();key:SetPoint('TOPRIGHT',-16,-12)
 end
 local saved,internal,deferred
 local function release()
  if not saved or internal then return end
  local f=saved.frame;if InCombatLockdown()and f:IsProtected()then deferred=true;return end
  internal=true;local s=saved;saved=nil
  if HideUIPanel then HideUIPanel(f)else f:Hide()end
  f:SetParent(s.parent);f:SetScale(s.scale);if s.ignore~=nil then f:SetIgnoreParentScale(s.ignore)end;f:SetClampedToScreen(s.clamped)
  f:ClearAllPoints();for _,p in ipairs(s.points)do f:SetPoint(unpack(p))end
  internal=false;deferred=nil
 end
 local function fit()
  if not saved or not root:IsVisible()or InCombatLockdown()then return end
  local f=saved.frame
  f:SetClampedToScreen(false);if f.SetIgnoreParentScale then f:SetIgnoreParentScale(false)end
  f:SetScale(math.min(1.6,area:GetWidth()/math.max(1,f:GetWidth()),area:GetHeight()/math.max(1,f:GetHeight())))
  f:ClearAllPoints();f:SetPoint('CENTER',area,'CENTER',0,0)
 end
 local function attach(f)
  if not f or InCombatLockdown()or(f.IsForbidden and f:IsForbidden())then return false end
  if saved and saved.frame~=f then release()end
  if not saved then saved=snapshot(f);f:SetParent(area)end
  f:Show();fit();return true
 end
 local function findShown()for _,name in ipairs(names)do local f=_G[name];if f and f:IsShown()then return f end end end
 local function show()
  if InCombatLockdown()then status:SetText('Open this module after combat.');return end
  for _,addon in ipairs(addons)do load(addon)end
  local f=findShown()
  if not f and open then local ok,err=pcall(open);if not ok then status:SetText(tostring(err))end;f=findShown()end
  if f then attach(f)else status:SetText(title=='Professions'and 'Choose a profession above, or open one from Spells.'or 'Open the native '..title..' window to display it here.')end
 end
 root:HookScript('OnShow',function()C_Timer.After(0,show)end);root:HookScript('OnHide',release)
 local elapsed=0;root:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed<.3 then return end;elapsed=0;local f=findShown();if f then attach(f)end end)
 root:RegisterEvent('PLAYER_REGEN_ENABLED');root:SetScript('OnEvent',function()if deferred then release()end;if root:IsVisible()then show()end end)
 root.WoWUAttach=attach;root.WoWUFind=findShown;root.WoWURelease=release
 root.WoWUStatus=status
 return root
end
function H.Talents(panel)
 local view=H.Host(panel,'Talents',{'Blizzard_TalentUI'},{'PlayerTalentFrame','TalentFrame'},function()
  if ToggleTalentFrame then ToggleTalentFrame()elseif PlayerTalentFrame then ShowUIPanel(PlayerTalentFrame)elseif TalentFrame then ShowUIPanel(TalentFrame)end
 end)
 panel:HookScript('OnShow',function()view:Show()end);panel:HookScript('OnHide',function()view:Hide()end)
 return view
end
function H.Professions(parent)
 local view=H.Host(parent,'Professions',{'Blizzard_TradeSkillUI','Blizzard_CraftUI','Blizzard_ArchaeologyUI'},{'TradeSkillFrame','CraftFrame','ArchaeologyFrame'})
 local selectors={}
 local function list()
  view.WoWUStatus:SetText('')
  local records=WoWUClient.Professions();local count=0
  for _,d in ipairs(records)do
   local spellID=d.skillLine==186 and 2656 or d.spellID
   if spellID and d.skillLine~=182 and d.skillLine~=393 and d.skillLine~=356 then
    count=count+1;local b=selectors[count]
    if not b then b=CreateFrame('Button',nil,view,'SecureActionButtonTemplate,UIPanelButtonTemplate');b:SetSize(180,34);b:SetPoint('TOPLEFT',16+(count-1)*188,-48);b:RegisterForClicks('AnyUp','AnyDown');selectors[count]=b end
    b:SetText(d.name);b:SetAttribute('type','spell');b:SetAttribute('spell',spellID);b:Show()
   end
  end
  for i=count+1,#selectors do selectors[i]:Hide()end
 end
 view:HookScript('OnShow',function()if not InCombatLockdown()then list()end end)
 local events=CreateFrame('Frame');for _,e in ipairs({'TRADE_SKILL_SHOW','CRAFT_SHOW'})do pcall(events.RegisterEvent,events,e)end
 events:SetScript('OnEvent',function()
  if not WoWU_MainFrame or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
  if view:IsVisible()then C_Timer.After(0,function()local f=view.WoWUFind();if f then view.WoWUAttach(f)end end);return end
  if WoWU_ShowPage then WoWU_ShowPage('More')end;if WoWU_OpenMoreModule then WoWU_OpenMoreModule('Professions')end
  C_Timer.After(0,function()local f=view.WoWUFind();if f and view:IsVisible()then view.WoWUAttach(f)end end)
 end)
 return view
end
function H.Guide(parent)return H.Host(parent,'Adventure Guide',{'Blizzard_EncounterJournal'},{'EncounterJournal'},function()if ToggleEncounterJournal then ToggleEncounterJournal()elseif EncounterJournal then ShowUIPanel(EncounterJournal)end end)end
function H.GroupFinder(parent)return H.Host(parent,'Dungeon Finder',{'Blizzard_GroupFinder','Blizzard_LookingForGroupUI'},{'PVEFrame','LFGParentFrame','LFDParentFrame','LookingForGroupFrame'},function()if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame()elseif ToggleLFGParentFrame then ToggleLFGParentFrame()elseif LFGParentFrame then ShowUIPanel(LFGParentFrame)end end)end
function H.InventoryCollections(parent)
 local root=CreateFrame('Frame',nil,parent);root:SetAllPoints();root:Hide()
 local heading=text(root,22,'Mounts & Companions');heading:SetPoint('TOPLEFT',22,-20)
 local hint=text(root,13,'Classic mounts and companions are inventory items or learned companion spells.');hint:SetPoint('TOPLEFT',22,-53)
 local scroll=CreateFrame('ScrollFrame',nil,root,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',16,-88);scroll:SetPoint('BOTTOMRIGHT',-430,22)
 local body=CreateFrame('Frame',nil,scroll);body:SetSize(650,1);scroll:SetScrollChild(body);if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 local right=CreateFrame('Frame',nil,root,'BackdropTemplate');WoWU_Theme.Panel(right);right:SetPoint('TOPLEFT',scroll,'TOPRIGHT',34,0);right:SetPoint('BOTTOMRIGHT',-16,22)
 local name=text(right,19,'Choose a mount or companion');name:SetPoint('TOPLEFT',20,-20);name:SetPoint('TOPRIGHT',-20,-20);name:SetHeight(70);name:SetWordWrap(true)
 local icon=right:CreateTexture(nil,'ARTWORK');icon:SetSize(84,84);icon:SetPoint('TOP',0,-105)
 local status=text(right,13);status:SetPoint('TOPLEFT',20,-220);status:SetPoint('TOPRIGHT',-20,-220);status:SetHeight(100);status:SetWordWrap(true)
 local selected,rows=nil,{}
 local use=CreateFrame('Button',nil,right,'SecureActionButtonTemplate,UIPanelButtonTemplate');use:SetText('Summon / Use');use:SetSize(180,38);use:SetPoint('BOTTOM',0,110);use:RegisterForClicks('AnyUp','AnyDown')
 local dashboard=button(right,'+ Dashboard',180,function()if selected then local ok=WoWU_AddShortcut(selected.kind,selected.id,selected.name,selected.icon);status:SetText(ok and 'Added to Dashboard.'or 'Dashboard is full.')end end);dashboard:SetPoint('BOTTOM',0,62)
 local pad=button(right,'+ Pad',180,function()if selected and WoWUController then local ok,message=WoWUController.BeginAssignment(selected.kind,selected.id,selected.name,selected.icon);status:SetText(message or (ok and 'Press the controller combination to assign.'or 'Enable controller overlay first.'))end end);pad:SetPoint('BOTTOM',0,14)
 local function choose(d)
  if InCombatLockdown()then return end;selected=d;name:SetText(d.name);icon:SetTexture(d.icon);status:SetText(d.kind=='item'and 'Uses the item from your bags. Classic mount items must remain in your inventory.'or 'Summons the learned companion spell.')
  use:SetAttribute('type',d.kind);use:SetAttribute('item',d.kind=='item'and 'item:'..d.id or nil);use:SetAttribute('spell',d.kind=='spell'and d.id or nil);use:Enable()
 end
 local function refresh()
  if not root:IsVisible()or InCombatLockdown()then return end
  local entries,seen={},{}
  for bag=0,NUM_BAG_SLOTS or 4 do for slot=1,C_Container.GetContainerNumSlots(bag)do
   local d=C_Container.GetContainerItemInfo(bag,slot)
   if d and not seen[d.itemID]then
    local _,_,_,_,_,class,subclass=C_Item.GetItemInfoInstant(d.itemID)
    if class==15 and (subclass==5 or subclass==2)then
     local n=C_Item.GetItemNameByID and C_Item.GetItemNameByID(d.itemID)or GetItemInfo(d.itemID)
     entries[#entries+1]={kind='item',id=d.itemID,name=n or d.hyperlink,icon=d.iconFileID};seen[d.itemID]=true
    end
   end
  end end
  if GetNumCompanions and GetCompanionInfo then
   for _,kind in ipairs({'MOUNT','CRITTER'})do for i=1,GetNumCompanions(kind)do
    local _,n,id,texture=GetCompanionInfo(kind,i)
    if id and not seen['s'..id]then entries[#entries+1]={kind='spell',id=id,name=n,icon=texture};seen['s'..id]=true end
   end end
  end
  table.sort(entries,function(a,b)return (a.name or '')<(b.name or '')end)
  for i,d in ipairs(entries)do
   local row=rows[i]
   if not row then
    row=button(body,'',600,function(self)choose(self.entry)end);row:SetHeight(54);row:SetPoint('TOPLEFT',8,-(i-1)*61);row:SetPoint('TOPRIGHT',-8,-(i-1)*61)
    row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(40,40);row.icon:SetPoint('LEFT',8,0);rows[i]=row
   end
   row.entry=d;row:SetText(d.name);row.icon:SetTexture(d.icon);row:Show()
  end
  for i=#entries+1,#rows do rows[i]:Hide()end;body:SetHeight(math.max(1,#entries*61));body:SetWidth(math.max(1,scroll:GetWidth()))
  if #entries==0 then status:SetText('No mount or companion items found in your bags. Learned mounts and pets appear here when this client exposes the companion spell list.')end
  use:SetEnabled(selected~=nil)
 end
 root:HookScript('OnShow',refresh)
 for _,e in ipairs({'BAG_UPDATE_DELAYED','COMPANION_LEARNED','COMPANION_UPDATE','PLAYER_REGEN_ENABLED'})do pcall(root.RegisterEvent,root,e)end
 root:SetScript('OnEvent',refresh);return root
end
