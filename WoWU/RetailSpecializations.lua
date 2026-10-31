-- Retail specialization selection; no trainer fees or legacy talent-group logic.
if not WoWUClient.isRetail then return end
local function call(fn,...)
 if type(fn)~='function'then return end
 local function pack(...)return {n=select('#',...),...}end
 local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local function label(parent,size)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
 f:SetFont('Fonts\\FRIZQT__.TTF',size,'');f:SetJustifyH('CENTER');f:SetWordWrap(true)
 WoWU_Theme.TextColor(f,.96,.82,.5);return f
end
function WoWU_BuildRetailSpecializations(panel)
 local view=CreateFrame('Frame',nil,panel,'BackdropTemplate');view:SetAllPoints(panel)
 view:SetFrameLevel(panel:GetFrameLevel()+60);view:EnableMouse(true);WoWU_Theme.Panel(view);view:Hide()
 local heading=label(view,23);heading:SetPoint('TOP',0,-17);heading:SetText('Specialization')
 local status=label(view,13);status:SetPoint('BOTTOMLEFT',14,12);status:SetPoint('BOTTOMRIGHT',-14,12);status:SetHeight(22)
 local close=CreateFrame('Button',nil,view,'UIPanelCloseButton');WoWU_Theme.CloseButton(close);close:SetPoint('TOPRIGHT',-5,-5);close:SetScript('OnClick',function()view:Hide()end)
 local cards={};local pending,untilTime,message;local refresh
 local function allowed()
  if InCombatLockdown()then return false,'Change specialization after combat.'end
  if UnitIsDeadOrGhost('player')then return false,'Change specialization while alive.'end
  if pending then return false,'Changing specialization... Stay still until the cast finishes.'end
  local config=call(C_ClassTalents.GetActiveConfigID)
  if config and call(C_Traits.ConfigHasStagedChanges,config)then return false,'Apply or undo pending talent changes first.'end
  local usable,reason=call(C_SpecializationInfo.CanPlayerUseTalentSpecUI)
  if usable==false then return false,reason or 'Specializations are not available yet.'end
  return true
 end
 refresh=function()
  if not view:IsVisible()then return end
  local count=call(GetNumSpecializations,false,false)or 0
  local current=call(C_SpecializationInfo.GetSpecialization or GetSpecialization)
  if pending and current==pending then pending=nil;untilTime=nil;message='Specialization activated.'end
  if untilTime and GetTime()>untilTime then pending=nil;untilTime=nil;message='Change did not complete. You can try again.'end
  local enabled,reason=allowed()
  status:SetText(reason or message or 'Choose your specialization. Changing specialization is free.')
  if count==0 then status:SetText('Specialization data is not available yet.');return end
  local width=(view:GetWidth()-32-(count-1)*8)/count
  local height=math.max(260,view:GetHeight()-100)
  for index=1,count do
   local id,name,description,icon,role,primaryStat=call(C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo,index,false,false,nil,UnitSex('player'))
   local card=cards[index]
   if not card then
    card=CreateFrame('Frame',nil,view,'BackdropTemplate');WoWU_Theme.Panel(card);cards[index]=card
    card.art=card:CreateTexture(nil,'ARTWORK');card.art:SetPoint('TOPLEFT',12,-12);card.art:SetPoint('TOPRIGHT',-12,-12)
    card.name=label(card,22);card.role=label(card,14);card.desc=label(card,13)
    card.samples=label(card,13);card.samples:SetText('Sample Abilities')
    card.spells={}
    for k=1,2 do
     local b=CreateFrame('Button',nil,card);b:SetSize(40,40)
     b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints();b.icon:SetTexCoord(.08,.92,.08,.92)
     b:SetScript('OnEnter',function(self)if self.spell then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetSpellByID(self.spell);GameTooltip:Show()end end)
     b:SetScript('OnLeave',function()GameTooltip:Hide()end);card.spells[k]=b;WoWUDetails.BindHover(b,false)
    end
    card.activate=CreateFrame('Button',nil,card,'UIPanelButtonTemplate');card.activate:SetHeight(30);card.activate:SetPoint('BOTTOM',0,14)
    card.activate:SetScript('OnClick',function()
     local can,why=allowed();if not can then message=why;refresh();return end
     local ok,success=pcall(C_SpecializationInfo.SetSpecialization or SetSpecialization,index)
     if ok and success~=false then pending=index;untilTime=GetTime()+15;message=nil
     else message=ok and 'The game cannot change specialization right now.'or tostring(success)end
     refresh()
    end)
   end
   card:ClearAllPoints();card:SetPoint('TOPLEFT',16+(index-1)*(width+8),-53);card:SetSize(width,height);card:Show()
   local imageHeight=math.min(height*.32,(width-24)*.62)
   card.art:SetHeight(imageHeight)
   local key=SPEC_FORMAT_STRINGS and SPEC_FORMAT_STRINGS[id]
   local art=key and 'spec-thumbnail-'..key
   if art and call(C_Texture.GetAtlasInfo,art)then card.art:SetAtlas(art)else card.art:SetTexture(icon or 134400)end
   card.name:ClearAllPoints();card.name:SetPoint('TOPLEFT',12,-imageHeight-29);card.name:SetWidth(width-24);card.name:SetHeight(32);card.name:SetText(name or 'Loading...')
   card.role:ClearAllPoints();card.role:SetPoint('TOP',card.name,'BOTTOM',0,-5);card.role:SetWidth(width-24);card.role:SetText(_G[role or '']or role or '')
   card.desc:ClearAllPoints();card.desc:SetPoint('TOPLEFT',14,-imageHeight-103);card.desc:SetPoint('BOTTOMRIGHT',-14,145);card.desc:SetJustifyV('TOP')
   local stat=primaryStat and _G[({'SPELL_STAT1_NAME','SPELL_STAT2_NAME','SPELL_STAT3_NAME','SPELL_STAT4_NAME'})[primaryStat]or '']
   card.desc:SetText((description or '')..(stat and '\n\nPrimary Stat: '..stat or ''))
   card.samples:ClearAllPoints();card.samples:SetPoint('BOTTOM',0,114)
   local spells=call(C_SpecializationInfo.GetSpellsDisplay,id)or {}
   for k,b in ipairs(card.spells)do
    b.spell=spells[k==1 and 1 or 6]or spells[k];b:SetShown(b.spell~=nil)
    b:ClearAllPoints();b:SetPoint('BOTTOM',card,'BOTTOM',(k==1 and -25 or 25),65)
    b.icon:SetTexture(b.spell and call(C_Spell.GetSpellTexture,b.spell))
   end
   card.activate:SetWidth(math.min(170,width-24));card.activate:SetText(index==current and 'Active'or pending==index and 'Activating...'or 'Activate')
   card.activate:SetEnabled(enabled and index~=current and id~=nil)
   WoWU_Theme.Border(card,index==current and 1 or .5,index==current and .8 or .4,.2,1)
  end
  for index=count+1,#cards do cards[index]:Hide()end
 end
 view:SetScript('OnShow',function()
  if C_AddOns and C_AddOns.LoadAddOn then call(C_AddOns.LoadAddOn,'Blizzard_PlayerSpells')end
  message=nil;refresh()
 end)
 view:SetScript('OnSizeChanged',refresh)
 local elapsed=0;view:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=.2 then elapsed=0;refresh()end end)
 view:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED');view:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED');view:RegisterEvent('UNIT_SPELLCAST_FAILED')
 view:SetScript('OnEvent',function(_,event,unit,_,spellID)
  if unit and unit~='player'then return end
  if event~='PLAYER_SPECIALIZATION_CHANGED'and pending and IsSpecializationActivateSpell and IsSpecializationActivateSpell(spellID)then pending=nil;untilTime=nil;message='Specialization change interrupted.'end
  refresh()
 end)
 panel:HookScript('OnHide',function()view:Hide();GameTooltip:Hide()end)
 return function()view:Show()end
end
