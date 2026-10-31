-- Tap shoulders to cycle; hold to select without firing the underlying pad action.
WoWUControllerShoulders={}
local S=WoWUControllerShoulders
local root
function S.Initialize(owner,slots,refreshIcon)
 root=owner
 S.root=root;S.slots=slots;S.restoreIcon=refreshIcon
 local function action(name,kind,value)
  local b=CreateFrame('Button','WoWUPad'..name,root,'SecureActionButtonTemplate')
  b:RegisterForClicks('AnyDown','AnyUp');b:SetAttribute('useOnKeyDown',true)
  b:SetAttribute('type',kind);b:SetAttribute(kind=='target'and 'unit'or kind=='macro'and 'macrotext'or kind,value)
  root:SetFrameRef(name,b);return b
 end
 for _,entry in ipairs({{'ShoulderLB','lb','/targetfriend\n/target [@softinteract,exists,help,nodead]'},{'ShoulderRB','rb','/targetenemy'}})do
  local b=action(entry[1],'macro',entry[3]);b:SetAttribute('side',entry[2]);b:SetAttribute('useOnKeyDown',false)
  SecureHandlerWrapScript(b,'PreClick',root,[[
   local side=self:GetAttribute('side')
   if down then
    control:SetAttribute('pad-'..side,true)
    control:SetAttribute('pad-'..side..'-used',false)
    local other=side=='lb'and 'rb'or 'lb'
    if control:GetAttribute('pad-'..other)then
     control:SetAttribute('pad-lb-used',true);control:SetAttribute('pad-rb-used',true)
    end
    self:SetAttribute('type',nil)
   else
    if control:GetAttribute('pad-'..side..'-used')then self:SetAttribute('type',nil)else self:SetAttribute('type','macro')end
    control:SetAttribute('pad-'..side,false)
   end
   control:RunAttribute('_refreshbindings')
  ]])
  b:HookScript('PostClick',function()if WoWUControllerTargeting then WoWUControllerTargeting.LeaveCursor()end end)
 end
 local held=[[
  local key=self:GetAttribute('target-key')
  if down then
   if control:GetAttribute('pad-lb')then control:SetAttribute('pad-lb-used',true)end
   if control:GetAttribute('pad-rb')then control:SetAttribute('pad-rb-used',true)end
  end
  control:SetAttribute('target-held-'..key,down and self:GetName()or nil)
  control:RunAttribute('_refreshbindings')
 ]]
 for _,entry in ipairs({{'AllyUp',-1,'PADDUP'},{'AllyDown',1,'PADDDOWN'}})do
  local b=action(entry[1],'target','player');b:SetAttribute('step',entry[2]);b:SetAttribute('target-key',entry[3])
  SecureHandlerWrapScript(b,'PreClick',root,[[
   if down then
   local count=control:GetAttribute('ally-count')or 1
   local index=((control:GetAttribute('ally-index')or 0)+self:GetAttribute('step'))%count
   control:SetAttribute('ally-index',index)
   local raid=control:GetAttribute('ally-raid')
   local unit=raid and ('raid'..(index+1))or(index==0 and 'player'or('party'..index))
   self:SetAttribute('unit',unit)
   control:SetAttribute('pad-lb-used',true)
   end
  ]]..held)
 end
 for _,entry in ipairs({
  {'FriendPrevious','/targetfriend 1','PADDLEFT'},{'FriendNext','/targetfriend','PADDRIGHT'},
  {'EnemyPrevious','/targetenemy 1','PADDLEFT'},{'EnemyNext','/targetenemy','PADDRIGHT'},
  {'TargetOfTarget','/target [@targettarget,exists]','PADDUP'},{'LastEnemy','/targetlastenemy','PADDDOWN'},
  {'TargetSelf','/target [@player]','PAD3'},{'TargetAssist','/assist [@target,exists]','PAD4'},
  {'SetFocus','/focus [@target,exists]','PAD3'},{'TargetFocus','/target [@focus,exists]','PAD4'},
 })do
  local b=action(entry[1],'macro',entry[2]);b:SetAttribute('target-key',entry[3])
  SecureHandlerWrapScript(b,'PreClick',root,held)
 end
 local confirm=action('TargetConfirm','macro','')
 local cancel=action('TargetCancel','macro','/cleartarget')
 confirm:SetAttribute('useOnKeyDown',false);confirm:SetAttribute('target-key','PAD1')
 cancel:SetAttribute('target-key','PAD2')
 local finish=[[
  local key=self:GetAttribute('target-key')
  control:SetAttribute('pad-lb-used',true);control:SetAttribute('pad-rb-used',true)
  if down then control:SetAttribute('target-held-'..key,self:GetName());control:RunAttribute('_refreshbindings');return end
  control:SetAttribute('target-held-'..key,nil)
  control:SetAttribute('pad-lb-used',true);control:SetAttribute('pad-rb-used',true)
  control:SetAttribute('pad-lb',false);control:SetAttribute('pad-rb',false)
  control:RunAttribute('_refreshbindings')
 ]]
 SecureHandlerWrapScript(confirm,'PreClick',root,finish)
 SecureHandlerWrapScript(cancel,'PreClick',root,held)
 -- Trigger casts mark the shoulder used without clearing its held state.
 -- Its targeting layer returns when the trigger is released.
 for _,b in ipairs(slots or {})do
  SecureHandlerWrapScript(b,'PreClick',root,[[
   if down and(control:GetAttribute('pad-lb')or control:GetAttribute('pad-rb'))then
    control:SetAttribute('pad-lb-used',true);control:SetAttribute('pad-rb-used',true)
   end
  ]])
 end
 -- Full party/raid coverage, including roster changes in combat, through a state
 -- driver. No insecure target changes or protected attribute writes in combat.
 local roster={}
 for i=40,1,-1 do roster[#roster+1]='[group:raid,@raid'..i..',exists] r'..i end
 for i=4,1,-1 do roster[#roster+1]='[@party'..i..',exists] p'..(i+1)end
 roster[#roster+1]='p1'
 root:SetAttribute('_onstate-allyroster',[[
  self:SetAttribute('ally-raid',newstate:sub(1,1)=='r')
  self:SetAttribute('ally-count',tonumber(newstate:sub(2))or 1)
  self:SetAttribute('ally-index',0)
 ]])
 RegisterStateDriver(root,'allyroster',table.concat(roster,'; '))
 -- Match the exact slot order used by Controller.lua. The main secure binder
 -- selects one final command per key instead of registering replacements.
 for i,key in ipairs({'PADDLEFT','PADDUP','PADDRIGHT','PADDDOWN','PAD3','PAD4','PAD2','PAD1'})do root:SetAttribute('target-key'..i,key)end
 local mapping={
  lb={'FriendPrevious','AllyUp','FriendNext','AllyDown','TargetSelf','TargetAssist','TargetCancel','TargetConfirm'},
  rb={'EnemyPrevious','TargetOfTarget','EnemyNext','LastEnemy','SetFocus','TargetFocus','TargetCancel','TargetConfirm'},
 }
 for side,entries in pairs(mapping)do
  for i,name in ipairs(entries)do root:SetAttribute('shoulder-'..side..i,'WoWUPad'..name)end
 end
end
local arrow='Interface\\Buttons\\UI-SpellbookIcon-'
local visualLayers={
 lb={arrow..'PrevPage-Up','Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up',arrow..'NextPage-Up','Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up',
  'Interface\\Icons\\Spell_Holy_Heal','Interface\\Icons\\Ability_Hunter_SniperShot','Interface\\Buttons\\UI-GroupLoot-Pass-Up','Interface\\Buttons\\UI-CheckBox-Check'},
 rb={arrow..'PrevPage-Up','Interface\\Icons\\Ability_Hunter_SniperShot',arrow..'NextPage-Up','Interface\\Icons\\Ability_Hunter_MarkedForDeath',
  'Interface\\Icons\\Spell_Holy_MindVision','Interface\\Icons\\Ability_Hunter_EagleEye','Interface\\Buttons\\UI-GroupLoot-Pass-Up','Interface\\Buttons\\UI-CheckBox-Check'},
}
local lastVisualMode
function S.VisualMode()
 local context=root and root:GetAttribute('state-context')
 if not root or not WoWUController.active or root:GetAttribute('pad-capturing')or root:GetAttribute('pad-editing')
  or (tonumber(context)~=0 and context~='flight')or IsShiftKeyDown()or IsControlKeyDown()or IsAltKeyDown()then return end
 if root:GetAttribute('pad-rb')then return 'rb'elseif root:GetAttribute('pad-lb')then return 'lb'end
end
function S.RefreshVisuals()
 if not S.slots then return end
 local mode=S.VisualMode()
 if mode and mode~=lastVisualMode then GameTooltip:Hide()end
 for i=1,8 do
  local b=S.slots[i]
  if mode then
   b.icon:SetTexture(visualLayers[mode][i]);b.cd:Hide()
   if b.emptyLabel then b.emptyLabel:Hide()end
  elseif lastVisualMode then
   S.restoreIcon(b,b.slotData);b.cd:Show()
   if b:GetAttribute('type')=='action'then
    local texture=C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture
    if texture then b.icon:SetTexture(texture(b:GetAttribute('action')))end
   end
  end
 end
 lastVisualMode=mode
end
function S.Reset()
 if root and not InCombatLockdown()then
  for _,key in ipairs({'pad-lb','pad-rb','pad-lb-used','pad-rb-used'})do root:SetAttribute(key,false)end
  for i=1,8 do local key=root:GetAttribute('target-key'..i);if key then root:SetAttribute('target-held-'..key,nil)end end
 end
 if S.RefreshVisuals then S.RefreshVisuals()end
end
