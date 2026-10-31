-- Mists' six choice rows and specialization groups. No Retail trait-tree calls.
if not WoWUClient or WoWUClient.classicMajor~=5 then return end
WoWUMistsTalents={}
local M=WoWUMistsTalents
local function call(fn,...)
 if type(fn)~='function'then return end
 local function pack(...)return {n=select('#',...),...}end
 local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local S=C_SpecializationInfo or {}
local function activeGroup()return call(S.GetActiveSpecGroup)or call(GetActiveTalentGroup)or 1 end
local function specialization(group)
 local index=call(S.GetSpecialization or GetSpecialization,false,false,group)
 local count=call(GetNumSpecializations,false,false)
 if not index or index==0 or call(IsInitialSpec,index)or (count and count>0 and index>count)then return nil end
 return index
end
local function info(tier,column,group)
 -- Mists uses class rows queried for a configured talent group, not Retail trees.
 return call(S.GetTalentInfo,{tier=tier,column=column,groupIndex=group,isInspect=false,target='player'})
end
local function tierInfo(tier,group)
 local available,selected,level=call(GetTalentTierInfo,tier,group,false,'player')
 return available,selected or 0,level or tier*15
end
function M.AvailablePoints(group)
 group=group or activeGroup()
 local native=group==activeGroup()and call(GetNumUnspentTalents)
 if type(native)=='number'then return native end
 if not specialization(group)then return 0 end
 local count=0;for tier=1,6 do local available,selected=tierInfo(tier,group);if available and selected==0 then count=count+1 end end
 return count
end
local function label(parent,size)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal');f:SetFont('Fonts\\FRIZQT__.TTF',size or 16,'');f:SetJustifyH('LEFT');f:SetWordWrap(true);WoWU_Theme.TextColor(f,.96,.82,.54);f:SetShadowColor(0,0,0,.9);f:SetShadowOffset(1,-1);return f
end
local function button(parent,text,w)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w or 170,40);b:SetText(text);b:GetFontString():SetFont('Fonts\\FRIZQT__.TTF',17,'');return b
end
local function panel(parent)
 local f=CreateFrame('Frame',nil,parent,'BackdropTemplate');WoWU_Theme.Panel(f);return f
end
function M.Build(root)
 local group=activeGroup();local preview=specialization(group)or 1
 local page='talents';local picked,armed,request,message
 local specs,rows,groups={},{},{}
 local refresh,showPage
 local sidebar=panel(root);sidebar:SetPoint('TOPLEFT',14,-14);sidebar:SetPoint('BOTTOMLEFT',14,14);sidebar:SetWidth(245)
 local title=label(sidebar,23);title:SetPoint('TOPLEFT',18,-18);title:SetText('Specializations')
 local groupText=label(sidebar,13);groupText:SetPoint('TOPLEFT',18,-55);groupText:SetWidth(210)
 for i=1,2 do
  local n=i;local b=button(sidebar,i==1 and 'Primary'or 'Secondary',103);b:SetPoint('TOPLEFT',16+(i-1)*110,-78);groups[i]=b
  b:SetScript('OnClick',function()group=n;preview=specialization(group)or 1;picked=nil;armed=nil;message=nil;refresh()end)
 end
 local talentTab=button(root,'Talents',185);talentTab:SetPoint('TOPLEFT',sidebar,'TOPRIGHT',16,-2)
 local specTab=button(root,'Specialization',185);specTab:SetPoint('LEFT',talentTab,'RIGHT',10,0)
 local activate=button(root,'Activate build',240);activate:SetPoint('TOPRIGHT',-18,-16)
 local heading=label(root,20);heading:SetPoint('TOPLEFT',sidebar,'TOPRIGHT',22,-51);heading:SetWidth(850)
 local talentView=CreateFrame('Frame',nil,root);talentView:SetPoint('TOPLEFT',sidebar,'TOPRIGHT',15,-83);talentView:SetPoint('BOTTOMRIGHT',-16,218)
 local scroll=CreateFrame('ScrollFrame',nil,talentView,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',0,0);scroll:SetPoint('BOTTOMRIGHT',-27,0)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 local body=CreateFrame('Frame',nil,scroll);body:SetSize(900,492);scroll:SetScrollChild(body)
 local detail=panel(root);detail:SetPoint('TOPLEFT',sidebar,'BOTTOMRIGHT',15,190);detail:SetPoint('BOTTOMRIGHT',-16,14)
 local pickedName=label(detail,23);pickedName:SetPoint('TOPLEFT',16,-12);pickedName:SetPoint('TOPRIGHT',-255,-12)
 local description=label(detail,17);description:SetPoint('TOPLEFT',16,-40);description:SetPoint('BOTTOMRIGHT',-255,50);description:SetJustifyV('TOP')
 local status=label(detail,17);status:SetPoint('BOTTOMLEFT',16,10);status:SetPoint('BOTTOMRIGHT',-255,10);status:SetHeight(28)
 local learn=button(detail,'Learn talent',220);learn:SetPoint('TOPRIGHT',-16,-16)
 local cancel=button(detail,'Cancel selection',220);cancel:SetPoint('TOPRIGHT',-16,-59)
 cancel:SetScript('OnClick',function()picked=nil;armed=nil;message=nil;refresh()end)
 local specView=panel(root);specView:SetPoint('TOPLEFT',sidebar,'TOPRIGHT',15,-83);specView:SetPoint('BOTTOMRIGHT',-16,218)
 local specScroll=CreateFrame('ScrollFrame',nil,specView,'UIPanelScrollFrameTemplate')
 specScroll:SetPoint('TOPLEFT',10,-10);specScroll:SetPoint('BOTTOMRIGHT',-30,10)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(specScroll)end
 local specBody=CreateFrame('Frame',nil,specScroll);specBody:SetSize(750,460);specScroll:SetScrollChild(specBody)
 local specIcon=specBody:CreateTexture(nil,'ARTWORK');specIcon:SetSize(76,76);specIcon:SetPoint('TOPLEFT',25,-24)
 local specName=label(specBody,29);specName:SetPoint('LEFT',specIcon,'RIGHT',20,14);specName:SetTextColor(1,.84,.45)
 local specRole=label(specBody,17);specRole:SetPoint('LEFT',specIcon,'RIGHT',20,-20);specRole:SetTextColor(.88,.84,.72)
 local specDescription=label(specBody,18);specDescription:SetPoint('TOPLEFT',25,-126);specDescription:SetPoint('TOPRIGHT',-25,-126);specDescription:SetTextColor(.96,.92,.81)
 local samples={}
 for i=1,6 do
  local b=CreateFrame('Button',nil,specBody);b:SetSize(330,60);b:SetPoint('TOPLEFT',25+((i-1)%2)*365,-226-math.floor((i-1)/2)*76)
  b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(48,48);b.icon:SetPoint('LEFT');b.label=label(b,16);b.label:SetPoint('LEFT',b.icon,'RIGHT',12,0);b.label:SetWidth(265);b.label:SetTextColor(.96,.92,.81)
  b:SetScript('OnEnter',function(self)if self.spell then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetSpellByID(self.spell);GameTooltip:Show()end end)
  b:SetScript('OnLeave',function()GameTooltip:Hide()end);samples[i]=b;WoWUDetails.BindHover(b,true)
 end
 local function canChange()
  if InCombatLockdown()then return false,'Make changes after combat.'end
  if UnitIsDeadOrGhost('player')then return false,'Make changes while alive.'end
  if request then return false,'Waiting for the game to finish the change.'end
  return true
 end
 local function previewOnly()return specialization(group)~=preview end
 local function editable()
  local ok,why=canChange();if not ok then return false,why end
  if group~=activeGroup()then return false,'Activate this build before spending points.'end
  if previewOnly()then return false,'This is a preview. Activate or learn this specialization first.'end
  return true
 end
 local function selectedInfo(tier)
  local _,column=tierInfo(tier,group);return column>0 and info(tier,column,group)or nil
 end
 local function requestChange(fn,...)
  if type(fn)~='function'then message='This action is unavailable on this client.';return end
  local token={};request=token;message='Change requested; waiting for the game.'
  local ok,result=pcall(fn,...)
  if not ok or result==false then request=nil;message=ok and 'The game could not apply that change.'or tostring(result);return end
  C_Timer.After(12,function()if request==token then request=nil;message='The change did not complete. Check the game requirements and try again.';if root:IsVisible()then refresh()end end end)
 end
 local function selectionValid()
  if not picked or picked.group~=group or picked.preview~=preview then return end
  local current=info(picked.tier,picked.column,group)
  if current and current.talentID==picked.id then return current end
 end
 learn:SetScript('OnClick',function()
  local ok,why=editable();if not ok then message=why;refresh();return end
  local current=selectionValid();if not current then message='Talent data changed. Select the talent again.';picked=nil;armed=nil;refresh();return end
  local available,_,level=tierInfo(picked.tier,group)
  if UnitLevel('player')<level or not available then message='This row unlocks at level '..level..'.';refresh();return end
  local old=selectedInfo(picked.tier)
  if current.selected then return end
  if old then
   local resource,count,_,_,cost=call(GetTalentClearInfo);cost=tonumber(cost)
   if cost==nil then message='The game has not provided the talent removal requirements.';refresh();return end
   if (count or 0)<cost then message='Requires '..cost..' '..(resource or 'talent-removal reagent')..'.';refresh();return end
   if not armed or armed.oldID~=old.talentID or armed.newID~=current.talentID or armed.cost~=cost then
    armed={oldID=old.talentID,newID=current.talentID,cost=cost};message='Replace '..old.name..'? Unlearning costs '..cost..' '..(resource or 'reagent')..'. Confirm to unlearn; then click Learn for the replacement.'
   else
    armed=nil;requestChange(RemoveTalent,old.talentID)
   end
  elseif current.available then
   armed=nil;requestChange(LearnTalents,current.talentID)
  else message='This talent is not currently available to learn.'end
  refresh()
 end)
 activate:SetScript('OnClick',function()
  local ok,why=canChange();if not ok then message=why;refresh();return end
  if group~=activeGroup()then
   if not armed or armed.mode~='group'or armed.group~=group then armed={mode='group',group=group};message='Confirm switching to the '..(group==1 and 'primary'or 'secondary')..' build.'
   else armed=nil;requestChange(S.SetActiveSpecGroup or SetActiveTalentGroup,group)end
  elseif not specialization(group)then
   if not armed or armed.mode~='spec'or armed.preview~=preview then armed={mode='spec',preview=preview};message='Confirm learning the selected specialization.'
   else armed=nil;requestChange(S.SetSpecialization or SetSpecialization,preview,false)end
  else message='Changing this build to another specialization requires a class-trainer reset.'end
  refresh()
 end)
 for tier=1,6 do
  local t=tier;local row=panel(body);row:SetHeight(74);row:SetPoint('TOPLEFT',0,-(tier-1)*82);row:SetPoint('TOPRIGHT',0,-(tier-1)*82)
  row.level=label(row,24);row.level:SetPoint('LEFT',12,0);row.level:SetWidth(52);row.buttons={}
  for column=1,3 do
   local c=column;local b=CreateFrame('Button',nil,row,'BackdropTemplate');WoWU_Theme.Panel(b);row.buttons[c]=b
   b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(44,44);b.icon:SetPoint('LEFT',9,0)
   b.name=label(b,15);b.name:SetPoint('LEFT',b.icon,'RIGHT',10,8);b.name:SetPoint('RIGHT',-8,8)
   b.state=label(b,11);b.state:SetPoint('TOPLEFT',b.name,'BOTTOMLEFT',0,-5)
   b:SetScript('OnClick',function()
    local item=info(t,c,group);if not item then return end
    picked={tier=t,column=c,id=item.talentID,group=group,preview=preview};armed=nil;message=nil;refresh()
   end)
   b:SetScript('OnEnter',function(self)
    if not self.data then return end
    GameTooltip:SetOwner(self,'ANCHOR_RIGHT');local ok=pcall(GameTooltip.SetTalent,GameTooltip,self.data.talentID,false,group)
    if not ok and self.data.spellID then GameTooltip:SetSpellByID(self.data.spellID)end;GameTooltip:Show()
   end)
   b:SetScript('OnLeave',function()GameTooltip:Hide()end);WoWUDetails.BindHover(b,true)
  end
  rows[t]=row
 end
 local function layout()
  local specWidth=math.max(400,specScroll:GetWidth());specBody:SetWidth(specWidth)
  local sampleWidth=(specWidth-62)/2
  for i,b in ipairs(samples)do
   b:ClearAllPoints();b:SetPoint('TOPLEFT',25+((i-1)%2)*(sampleWidth+12),-215-math.floor((i-1)/2)*74)
   b:SetWidth(sampleWidth);b.label:SetWidth(math.max(60,sampleWidth-68))
  end
  local width=math.max(400,scroll:GetWidth());body:SetWidth(width)
  local cell=(width-82-16)/3
  for _,row in ipairs(rows)do for c,b in ipairs(row.buttons)do b:ClearAllPoints();b:SetPoint('TOPLEFT',74+(c-1)*(cell+6),-5);b:SetSize(cell,64)end end
 end
 scroll:HookScript('OnSizeChanged',layout)
 specScroll:HookScript('OnSizeChanged',layout)
 showPage=function(name)picked=nil;armed=nil;page=name;talentView:SetShown(name=='talents');specView:SetShown(name=='spec');GameTooltip:Hide();refresh()end
 talentTab:SetScript('OnClick',function()showPage('talents')end);specTab:SetScript('OnClick',function()showPage('spec')end)
 refresh=function()
  layout()
  local numGroups=call(GetNumSpecGroups,false)or 1
  if group>numGroups then group=activeGroup();preview=specialization(group)or 1;picked=nil;armed=nil end
  local current=activeGroup();local activeIndex=specialization(group)
  groupText:SetText('Viewing '..(group==1 and 'primary'or 'secondary')..(group==current and ' - active'or ' - inactive'))
  groups[2]:SetShown(numGroups>1)
  local num=call(GetNumSpecializations,false,false)or 0
  for i=1,num do
   local index=i;local id,name,desc,icon,role=call(S.GetSpecializationInfo or GetSpecializationInfo,index,false,false,nil,UnitSex('player'))
   local b=specs[i]
   if not b then
    b=CreateFrame('Button',nil,sidebar,'BackdropTemplate');b:SetSize(213,91);b:SetPoint('TOPLEFT',16,-129-(i-1)*101);WoWU_Theme.Panel(b)
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(48,48);b.icon:SetPoint('LEFT',10,0);b.name=label(b,16);b.name:SetPoint('TOPLEFT',b.icon,'TOPRIGHT',10,0);b.name:SetWidth(130)
    b.role=label(b,12);b.role:SetPoint('TOPLEFT',b.name,'BOTTOMLEFT',0,-8);b.role:SetWidth(130);specs[i]=b
    b:SetScript('OnClick',function()
     preview=index;picked=nil;armed=nil;message=nil;specScroll:SetVerticalScroll(0)
     if specialization(group)~=index then for g=1,call(GetNumSpecGroups,false)or 1 do if specialization(g)==index then group=g;break end end end
     refresh()
    end)
   end
   b:Show();b.icon:SetTexture(icon or 134400);b.name:SetText(name or 'Loading...');b.role:SetText((_G[role or '']or role or '')..(activeIndex==index and '\nConfigured'or ''))
   WoWU_Theme.Border(b,preview==index and 1 or .5,preview==index and .8 or .4,.2,1)
  end
  for i=num+1,#specs do specs[i]:Hide()end
  local id,name,desc,icon,role=call(S.GetSpecializationInfo or GetSpecializationInfo,preview,false,false,nil,UnitSex('player'))
  heading:SetText((name or 'Choose a specialization')..(previewOnly()and ' - class talent preview'or ' - '..M.AvailablePoints(group)..' unspent talent(s)'))
  talentTab:SetText('Talents'..(not previewOnly()and M.AvailablePoints(group)>0 and ' ('..M.AvailablePoints(group)..')'or ''))
  local can,reason=canChange()
  if group~=current then activate:SetText(armed and armed.mode=='group'and 'Confirm build switch'or 'Activate '..(group==1 and 'primary'or 'secondary'));activate:SetEnabled(can)
  elseif not activeIndex then
   local usable=call(S.CanPlayerUseTalentSpecUI);activate:SetText(armed and armed.mode=='spec'and 'Confirm specialization'or 'Learn specialization');activate:SetEnabled(can and usable~=false and type(id)=='number'and id>0)
  else activate:SetText(activeIndex==preview and 'Active specialization'or 'Trainer reset required');activate:Disable()end
  specIcon:SetTexture(icon or 134400);specName:SetText(name or 'Specialization');specRole:SetText(_G[role or '']or role or '');specDescription:SetText(desc or '')
  local spells=SPEC_SPELLS_DISPLAY and SPEC_SPELLS_DISPLAY[id]or {}
  for i,b in ipairs(samples)do
   b.spell=spells[(i-1)*2+1];b:SetShown(b.spell~=nil)
   if b.spell then b.icon:SetTexture(call(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture,b.spell));b.label:SetText(call(C_Spell and C_Spell.GetSpellName,b.spell)or call(GetSpellInfo,b.spell)or '')end
  end
  for t,row in ipairs(rows)do
   local available,_,level=tierInfo(t,group);local locked=UnitLevel('player')<level
   row.level:SetText(level);row.level:SetTextColor(locked and .5 or 1,locked and .5 or .82,locked and .5 or .1)
   for c,b in ipairs(row.buttons)do
    local data=info(t,c,group);b.data=data;b:SetShown(data~=nil)
    if data then
     b.icon:SetTexture(data.icon or 134400);b.icon:SetDesaturated(locked or false);b.name:SetText(data.name or 'Loading...')
     local learned=not previewOnly()and data.selected;local chosen=picked and picked.tier==t and picked.column==c
     b.state:SetText(locked and 'Level '..level or learned and 'Learned'or chosen and 'Selected'or previewOnly()and 'Preview'or '')
     WoWU_Theme.Border(b,chosen and 1 or learned and .25 or .45,chosen and .8 or learned and .9 or .36,chosen and .2 or learned and .35 or .2,1)
    end
   end
  end
  local data=selectionValid();local enabled,why=editable()
  if data then
   pickedName:SetText(data.name or 'Talent')
   description:SetText(call(C_Spell and C_Spell.GetSpellDescription or GetSpellDescription,data.spellID)or 'Hover over this choice to read its full talent tooltip.')
   local available,_,level=tierInfo(picked.tier,group);local old=selectedInfo(picked.tier)
   local replace=old and not data.selected
   learn:SetText(data.selected and 'Already learned'or replace and (armed and armed.oldID and 'Confirm unlearn'or 'Replace talent')or 'Learn talent')
   learn:SetEnabled(enabled and available and UnitLevel('player')>=level and not data.selected and (replace or data.available)and true or false)
  else pickedName:SetText(page=='spec'and 'Specialization overview'or 'Choose one talent per unlocked row');description:SetText(previewOnly()and 'Preview only. Mists supplies class talent rows; activate a configured build to view its learned choices and spend points.'or 'Tap a talent to inspect it, then press Learn. Changing a learned choice uses the game\'s removal requirements.');learn:Disable();learn:SetText('Learn talent')end
  local text=message or reason or why or 'One talent per row. Row levels come from the game.'
  if request then text='Change requested; waiting for the game.'end
  status:SetText(text);cancel:SetEnabled(picked~=nil or armed~=nil)
 end
 local events=CreateFrame('Frame',nil,root)
 for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_TALENT_UPDATE','ACTIVE_TALENT_GROUP_CHANGED','PLAYER_SPECIALIZATION_CHANGED','PLAYER_LEVEL_UP','SPELLS_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','BAG_UPDATE_DELAYED','UI_ERROR_MESSAGE'})do pcall(events.RegisterEvent,events,event)end
 local queued=false
 events:SetScript('OnEvent',function(_,event,...)
  if event=='UI_ERROR_MESSAGE'and request then local _,text=...;if type(text)=='string'then message=text;request=nil end end
  if event=='PLAYER_TALENT_UPDATE'or event=='ACTIVE_TALENT_GROUP_CHANGED'or event=='PLAYER_SPECIALIZATION_CHANGED'then if request then message='Talent data updated.'end;request=nil;armed=nil end
  if not root:IsVisible()or queued then return end
  queued=true;C_Timer.After(0,function()queued=false;if root:IsVisible()then refresh()end end)
 end)
 root:HookScript('OnShow',function()
  if not InCombatLockdown()then call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,'Blizzard_TalentUI')end
  group=activeGroup();preview=specialization(group)or 1;picked=nil;armed=nil;message=nil
  showPage(specialization(group)and 'talents'or 'spec')
 end)
 root:HookScript('OnHide',function()picked=nil;armed=nil;GameTooltip:Hide()end)
 return root
end
