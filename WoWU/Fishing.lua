-- Fishing Companion: user-triggered casts/clicks; never detects or reels bites automatically.
WoWUFishing={active=false}
local F=WoWUFishing
local function call(fn,...)
 if type(fn)~='function'then return end
 local ok,a,b,c,d,e,f,g,h,i,j,k,l,m=pcall(fn,...)
 if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
end
local fishingIDs={[131474]=true,[131476]=true,[7620]=true,[7731]=true,[7732]=true,[18248]=true,[33095]=true,[51294]=true,[88868]=true,[110410]=true}
function F.CastName()
 -- Bind by the native localized cast name, never a profession/rank training ID.
 for _,id in ipairs({131474,131476,7620})do
  local name=call(C_Spell and C_Spell.GetSpellName,id)or call(GetSpellInfo,id)
  if type(name)=='string'and name~=''then return name end
 end
end
function F.IsFishingSpell(id)
 if fishingIDs[id]then return true end
 local name=id and (call(C_Spell and C_Spell.GetSpellName,id)or call(GetSpellInfo,id))
 return name and name==F.CastName()
end
local function combat()return InCombatLockdown and InCombatLockdown()end
local function copy(t)local r={};for k,v in pairs(t or {})do r[k]=type(v)=='table'and copy(v)or v end;return r end
local function get(n)return call(C_CVar and C_CVar.GetCVar or GetCVar,n)end
local function set(n,v)local fn=C_CVar and C_CVar.SetCVar or SetCVar;if fn and get(n)~=nil then fn(n,tostring(v))end end
local view,refresh,feedback
local function db()
 WoWUDB.fishing=WoWUDB.fishing or {characters={}}
 local key=UnitGUID('player')or UnitName('player')
 local d=WoWUDB.fishing.characters;d[key]=d[key]or {items={},casts=0,total=0}
 return d[key]
end
function F.Restore()
 if WoWUClient.isRetail then return true end
 local r=WoWUDB and WoWUDB.fishingRecovery
 if not r then return true end
 local failures={}
 local function restorePart(fn)
  local ok,err=pcall(fn);if not ok then failures[#failures+1]=tostring(err)end
 end
 restorePart(function()
  if r.hadConfig then C_GamePad.SetConfig(r.config)else C_GamePad.DeleteConfig(r.id)end
  C_GamePad.ApplyConfigs()
 end)
 -- Restore clicks/cursor even if a client temporarily refuses configuration changes.
 for n,v in pairs(r.cvars)do restorePart(function()set(n,v)end)end
 restorePart(function()if SetGamePadCursorControl then SetGamePadCursorControl(r.cursor)end end)
 restorePart(function()if SetGamePadFreeLook then SetGamePadFreeLook(r.freelook)end end)
 local ok=#failures==0
 if ok then WoWUDB.fishingRecovery=nil else F.lastError=table.concat(failures,'; ');if feedback then feedback('Fishing controls need restoration; retry after combat. '..F.lastError,true)end end
 return ok
end
function F.UpdateClick()
 if not F.active then return end
 local modified=IsShiftKeyDown()or IsControlKeyDown()or IsAltKeyDown()
 local value=(modified or F.cameraMode)and 'none'or 'PAD3'
 if get('GamePadCursorRightClick')~=value then pcall(set,'GamePadCursorRightClick',value)end
end
function F.Stop()
 if WoWUClient.isRetail then F.active=false;return true end
 F.active=false;F.cursorReady=false;F.cursorDeadline=nil;F.cameraMode=nil;F.cameraUntil=nil
 if WoWUController and WoWUController.SetFishing then WoWUController.SetFishing(false)end
 local restored=F.Restore();if refresh then refresh()end
 if restored and feedback then feedback('Fishing controls released. Press Start Fishing when you are ready.')end
 return restored
end
function F.Start()
 if WoWUClient.isRetail then return false,'Retail fishing keeps your native controls.'end
 if combat()then return false,'Start fishing outside combat.'end
 if UnitIsDeadOrGhost('player')then return false,'You cannot fish while dead.'end
 if SpellIsTargeting and SpellIsTargeting()then return false,'Clear the targeting cursor before fishing.'end
 if not WoWUController or not WoWUController.active or not WoWUController.SetFishing then return false,'Enable WoWU controller mode first.'end
 local G=C_GamePad
 if not G or not G.GetConfig or not G.SetConfig or not G.DeleteConfig or not G.ApplyConfigs then return false,'This client cannot temporarily remap fishing sticks.'end
 if not F.Restore()then return false,'Previous fishing controls could not be restored.'end
 local deviceID=call(G.GetActiveDeviceID)
 local raw=call(G.GetDeviceRawState,deviceID)
 if not raw or not raw.vendorID or not raw.productID then
  raw=nil
  for _,device in ipairs(call(G.GetAllDeviceIDs)or {})do
   local state=call(G.GetDeviceRawState,device)
   if state and state.vendorID and state.productID then raw=state;deviceID=device;break end
  end
 end
 if not raw then return false,'No controller was found. Connect one, move a stick, then press Start Fishing.'end
 local castName=F.CastName();if not castName then return false,'Fishing spell data is unavailable. Open your spellbook and try again.'end
 F.deviceID=deviceID
 local id={vendorID=raw.vendorID,productID=raw.productID}
 local previous=call(G.GetConfig,id)
 local config=previous and copy(previous)or {configID=id,rawButtonMappings={},rawAxisMappings={},axisConfigs={},stickConfigs={}}
 config.configID=id;config.stickConfigs=config.stickConfigs or {}
 local sticks={};for _,s in ipairs(config.stickConfigs)do if s.stick~='Cursor'and s.stick~='Movement'and s.stick~='Camera'then sticks[#sticks+1]=s end end
 sticks[#sticks+1]={stick='Cursor',axisX='LStickX',axisY='LStickY'}
 -- Give Movement a constant-zero input pair. A maximum deadzone on the
 -- physical left stick is not a disconnection and can leak native movement.
 -- Pad axes are temporarily reserved as neutral inputs; physical left/right
 -- axes are untouched so cursor and camera remain independently usable.
 config.axisConfigs=config.axisConfigs or {}
 for _,axis in ipairs({'PStickX','PStickY'})do
  local entry
  for _,candidate in ipairs(config.axisConfigs)do if candidate.axis==axis then entry=candidate;break end end
  if not entry then entry={axis=axis};config.axisConfigs[#config.axisConfigs+1]=entry end
  entry.scale=0;entry.shift=0;entry.deadzone=0
 end
 sticks[#sticks+1]={stick='Movement',axisX='PStickX',axisY='PStickY',deadzone=0,deadzoneX=0,deadzoneY=0}
 sticks[#sticks+1]={stick='Camera',axisX='RStickX',axisY='RStickY',deadzone=.2}
 config.stickConfigs=sticks
 local r={id=id,hadConfig=previous~=nil,config=previous and copy(previous),cvars={},cursor=not not call(IsGamePadCursorControlEnabled),freelook=not not call(IsGamePadFreelookEnabled)}
 local vars={GamePadCursorLeftClick='none',GamePadCursorRightClick='none',GamePadCursorAutoDisableJump='0',GamePadCursorAutoDisableSticks='0',GamePadCursorCentering='0',GamePadCursorPushCamera='0'}
 for n in pairs(vars)do r.cvars[n]=get(n)end
 WoWUDB.fishingRecovery=r
 local ok,err=pcall(function()
  G.SetConfig(config);G.ApplyConfigs()
  for n,v in pairs(vars)do set(n,v)end
  -- ApplyConfigs rebuilds native input state. Request cursor control after that
  -- update; do not force free look or require synchronous acknowledgement.
  -- GetConfig is the additive profile; verify that the stored cursor overlay matches.
  local applied=G.GetConfig(id);local found=false;local movementLocked=false
  for _,stick in ipairs(applied and applied.stickConfigs or {})do
   if stick.stick=='Cursor'and stick.axisX=='LStickX'and stick.axisY=='LStickY'then found=true end
   if stick.stick=='Movement'and stick.axisX=='PStickX'and stick.axisY=='PStickY'then movementLocked=true end
  end
  if not found then error('The game did not retain the left-stick cursor mapping.',0)end
  local zeroAxes={}
  for _,axis in ipairs(applied and applied.axisConfigs or {})do
   if axis.scale==0 and axis.shift==0 then zeroAxes[axis.axis]=true end
  end
  if not movementLocked or not zeroAxes.PStickX or not zeroAxes.PStickY then error('The game did not retain the fishing movement lock.',0)end
  local accepted,message=WoWUController.SetFishing(true)
  if not accepted then error(message or 'Fishing controls unavailable.',0)end
 end)
 if not ok then F.Stop();return false,'Could not enter fishing mode: '..tostring(err)end
 F.active=true;F.lastError=nil;F.cursorReady=false;F.cursorDeadline=GetTime()+5
 F.UpdateClick();if refresh then refresh()end
 return true,'Preparing the left-stick cursor. Move the left stick; Stop Fishing cancels.'
end
local function label(parent,text,size)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal');f:SetFont('Fonts\\FRIZQT__.TTF',size or 17,'');f:SetText(text);f:SetJustifyH('LEFT');return f
end
local function button(parent,text,secure)
 local b=CreateFrame('Button',nil,parent,secure and 'UIPanelButtonTemplate,SecureActionButtonTemplate'or 'UIPanelButtonTemplate');b:SetSize(210,38);b:SetText(text)
 if secure then b:RegisterForClicks('AnyDown','AnyUp');b:SetAttribute('useOnKeyDown',false)end
 return b
end
local function pole()
 for bag=0,WoWUClient.LastBag()do for slot=1,call(C_Container and C_Container.GetContainerNumSlots,bag)or 0 do
  local info=call(C_Container.GetContainerItemInfo,bag,slot)
  if info then local _,_,_,_,_,_,_,_,_,_,_,class,sub=call(C_Item and C_Item.GetItemInfo or GetItemInfo,info.itemID)
   if class==2 and sub==20 and not info.isLocked then return info.itemID end
  end
 end end
end
local function retailRodSlot()
 local profession=Enum and Enum.Profession and Enum.Profession.Fishing
 local slots=profession and call(C_TradeSkillUI and C_TradeSkillUI.GetProfessionSlots,profession)
 if type(slots)~='table'then return end
 for _,slot in ipairs(slots)do
  local id=GetInventoryItemID('player',slot)
  local _,_,_,_,_,_,_,_,_,_,_,class,sub=call(C_Item and C_Item.GetItemInfo or GetItemInfo,id or 0)
  if class==2 and sub==20 then return slot end
 end
 return slots[1]
end
function F.Create(parent,onBack)
 local root=CreateFrame('Frame',nil,parent);root:SetAllPoints();root:Hide();view=root
 F.IsOpen=function()return root:IsVisible()end
 local title=label(root,'Fishing Companion',27);title:SetPoint('TOPLEFT',26,-22)
 local stop=button(root,'Start Fishing');stop:SetPoint('TOPRIGHT',-24,-14);stop:SetSize(360,78)
 stop:GetFontString():SetFont('Fonts\\FRIZQT__.TTF',27,'')
 local back=button(root,'Professions');back:SetPoint('RIGHT',stop,'LEFT',-12,0);back:SetScript('OnClick',function()F.Stop();root:Hide();onBack()end)
 if WoWUClient.isRetail then stop:Hide();back:ClearAllPoints();back:SetPoint('TOPRIGHT',-24,-22)end
 local left=CreateFrame('Frame',nil,root,'BackdropTemplate');left:SetPoint('TOPLEFT',20,-112);left:SetPoint('BOTTOMLEFT',20,20);left:SetWidth(400);WoWU_Theme.Panel(left)
 local heading=label(left,'Fishing controls',22);heading:SetPoint('TOPLEFT',22,-22)
 local controls=label(left,'A  Cast your line\n\nX  Reel in (right-click under cursor)\n\nLeft stick  Aim at the bobber\nRight stick  Look around (release to aim)\n\nB  Stop fishing',18);controls:SetPoint('TOPLEFT',22,-66);controls:SetWidth(355)
 local cast
 if WoWUClient.isRetail then
  heading:SetText('Fishing Session')
  controls:SetText('Use Cast to throw your line. Reel in with your normal Interact key when the bobber splashes.\n\nYour session starts on its first cast. Your normal movement and camera controls stay active.')
  cast=button(root,'Cast',true);cast:SetPoint('TOPRIGHT',-24,-14);cast:SetSize(360,78);cast:GetFontString():SetFont('Fonts\\FRIZQT__.TTF',27,'')
  cast:SetAttribute('useOnKeyDown',false);cast:SetAttribute('type1','spell');cast:SetAttribute('spell1',F.CastName())
  back:ClearAllPoints();back:SetPoint('RIGHT',cast,'LEFT',-12,0)
 end
 local status=label(left,'',15);status:SetPoint('TOPLEFT',22,-263);status:SetWidth(355);status:SetWordWrap(true)
 feedback=function(s,isError)
  status:SetText(s or '')
  status:SetTextColor(isError and 1 or .96,isError and .4 or .82,isError and .3 or .54)
 end
 local equipment=button(left,'Equip Fishing Rod',true);equipment:SetPoint('TOPLEFT',22,-345);equipment:SetWidth(355)
 local lureHeading=label(left,'Lures in your bags',18);lureHeading:SetPoint('TOPLEFT',22,-400)
 local lureButtons={}
 for i,id in ipairs({6529,6530,6532,6533,34861,46006})do
  local b=button(left,'',true);b:SetSize(170,32);b:SetPoint('TOPLEFT',22+((i-1)%2)*183,-430-math.floor((i-1)/2)*36)
  b:SetAttribute('type1','item');b:SetAttribute('item1','item:'..id);b:SetAttribute('target-slot',16);b.itemID=id;lureButtons[i]=b
 end
 local net=CreateFrame('Frame',nil,root,'BackdropTemplate');net:SetPoint('TOPLEFT',left,'TOPRIGHT',14,0);net:SetPoint('BOTTOMRIGHT',-20,20);WoWU_Theme.Panel(net)
 local netTitle=label(net,'Your Catch Net',24);netTitle:SetPoint('TOPLEFT',22,-22)
 local totals=label(net,'',16);totals:SetPoint('TOPLEFT',22,-60)
 local scroll=CreateFrame('ScrollFrame',nil,net,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',18,-100);scroll:SetPoint('BOTTOMRIGHT',-36,66)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 local body=CreateFrame('Frame',nil,scroll);body:SetSize(650,400);scroll:SetScrollChild(body)
 local rows={}
 local reset=button(net,'Reset Session');reset:SetPoint('BOTTOMRIGHT',-20,18);reset:SetScript('OnClick',function()
  if F.active then feedback('Stop fishing before resetting your session.');return end
  local d=db();d.started=nil;d.items={};d.casts=0;d.total=0;refresh()
 end)
 local pendingWeapons
 equipment:SetScript('PreClick',function(self,_,down)
  if down or combat()then return end
  self:SetAttribute('type1',nil)
  local d=db()
  if WoWUClient.isRetail then
   local slot=retailRodSlot();local id=pole()
   if not slot then feedback('Fishing equipment slots are unavailable. Use the native profession equipment panel.');return end
   if not id then feedback('Put a fishing rod in your bags first.');return end
   self:SetAttribute('macrotext1','/equipslot '..slot..' item:'..id);self:SetAttribute('type1','macro');return
  end
  if d.weapons then
   local macro='';for _,slot in ipairs({16,17})do local id=d.weapons[slot];if id then macro=macro..'/equipslot '..slot..' item:'..id..'\n'end end
   self:SetAttribute('macrotext1',macro);self:SetAttribute('type1','macro');return
  end
  local id=pole();if not id then feedback('Put a fishing rod in your bags first.');return end
  pendingWeapons={rod=id,[16]=GetInventoryItemID('player',16),[17]=GetInventoryItemID('player',17)}
  self:SetAttribute('macrotext1','/equipslot 16 item:'..id);self:SetAttribute('type1','macro')
 end)
 refresh=function()
  local d=db()
  totals:SetText((d.total or 0)..' items caught  |  '..(d.casts or 0)..' casts'..(d.started and '  |  Started '..date('%H:%M',d.started)or '  |  Session starts on your first cast'))
  stop:SetText(F.active and 'Stop Fishing'or 'Start Fishing')
  if WoWUClient.isRetail then
   local key=GetBindingKey('INTERACTTARGET')
   local bind=key and (GetBindingText and GetBindingText(key,'KEY_')or key)or 'not bound'
   controls:SetText('Cast using the button above.\n\nReel in: '..bind..' (Interact)\n\nPress Interact when the bobber splashes. Your normal movement and camera controls stay active.')
  end
  if not combat()then
   equipment:SetEnabled(not WoWUClient.isRetail or retailRodSlot()~=nil);equipment:SetText(not WoWUClient.isRetail and d.weapons and 'Restore Weapons'or 'Equip Fishing Rod')
   if cast then cast:SetEnabled(F.CastName()~=nil);cast:SetAttribute('spell1',F.CastName())end
   for _,b in ipairs(lureButtons)do
    local count=call(C_Item and C_Item.GetItemCount or GetItemCount,b.itemID)or 0
    local name=call(C_Item and C_Item.GetItemNameByID,b.itemID)or call(GetItemInfo,b.itemID)
    b:SetText((name or 'Lure')..' ('..count..')');b:SetShown(count>0)
    local slot=WoWUClient.isRetail and retailRodSlot()or 16
    b:SetAttribute('target-slot',slot)
    local id=slot and GetInventoryItemID('player',slot);local _,_,_,_,_,_,_,_,_,_,_,class,sub=call(C_Item and C_Item.GetItemInfo or GetItemInfo,id or 0)
    b:SetEnabled(class==2 and sub==20)
   end
  end
  for _,row in ipairs(rows)do row:Hide()end
  local items={};for id,item in pairs(d.items)do items[#items+1]={id=id,data=item}end
  table.sort(items,function(a,b)return (a.data.name or '')<(b.data.name or '')end)
  for i,item in ipairs(items)do
   local row=rows[i]
   if not row then row=CreateFrame('Button',nil,body);row:SetSize(650,54);row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(44,44);row.icon:SetPoint('LEFT',3,0);row.text=label(row,'',18);row.text:SetPoint('LEFT',row.icon,'RIGHT',14,0);rows[i]=row
    row:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetHyperlink('item:'..self.itemID);GameTooltip:Show()end)
    row:SetScript('OnLeave',function()GameTooltip:Hide()end);WoWUDetails.BindHover(row,false)
   end
   row.itemID=item.id;row:SetPoint('TOPLEFT',0,-(i-1)*58);row.icon:SetTexture(item.data.icon or 134400);row.text:SetText((item.data.link or item.data.name or 'Catch')..'  x'..item.data.count);row:Show()
  end
  body:SetHeight(math.max(400,#items*58))
 end
 stop:SetScript('OnClick',function()
  if F.active then
   if F.Stop()then feedback('Fishing controls released. Your catch net is retained.')end
  else
   local ok,msg=F.Start()
   if not ok then F.lastError=msg;feedback(msg,true)
   else feedback(msg or 'Fishing controls active: A casts, X right-clicks the bobber. B or Stop Fishing restores normal controls.')end
   refresh()
  end
 end)
 root:HookScript('OnShow',function()
  refresh()
  if WoWUClient.isRetail then feedback('Native Retail fishing: no control takeover. Cast and catch tracking run automatically for your session.')
  elseif WoWUDB and WoWUDB.fishingRecovery then feedback('Previous fishing controls need restoration. Press Start Fishing to retry.',true)
  else feedback('Press Start Fishing to take over the no-trigger controls. Your session begins on the first cast.')end
 end)
 root:HookScript('OnHide',F.Stop)
 root.WoWUEquipmentChanged=function()
  local d=db();local current=GetInventoryItemID('player',16)
  if pendingWeapons and current==pendingWeapons.rod then d.weapons=pendingWeapons;pendingWeapons=nil end
  if d.weapons and current==d.weapons[16]and (not d.weapons[17]or GetInventoryItemID('player',17)==d.weapons[17])then d.weapons=nil end
 end
 return root
end
local loot,lootOpen={},false
local events=CreateFrame('Frame')
for _,event in ipairs({'UI_ERROR_MESSAGE','MODIFIER_STATE_CHANGED','PLAYER_LOGIN','PLAYER_LOGOUT','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_DEAD','PLAYER_ENTERING_WORLD','GAME_PAD_DISCONNECTED','UNIT_SPELLCAST_CHANNEL_START','LOOT_READY','LOOT_OPENED','LOOT_SLOT_CLEARED','LOOT_CLOSED','PLAYER_EQUIPMENT_CHANGED','BAG_UPDATE_DELAYED'})do pcall(events.RegisterEvent,events,event)end
events:SetScript('OnEvent',function(_,event,...)
 if event=='UI_ERROR_MESSAGE'then
  if F.active then local _,text=...;if type(text)=='string'then F.lastError=text;if feedback then feedback(text,true)end end end;return
 end
 if event=='MODIFIER_STATE_CHANGED'then F.UpdateClick();return end
 if event=='PLAYER_LOGIN'then F.Restore();return end
 if event=='PLAYER_REGEN_DISABLED'or event=='PLAYER_DEAD'or event=='PLAYER_ENTERING_WORLD'or event=='GAME_PAD_DISCONNECTED'or event=='PLAYER_LOGOUT'then F.Stop();return end
 if event=='PLAYER_REGEN_ENABLED'then F.Restore()end
 if not WoWUDB then return end
 if event=='PLAYER_EQUIPMENT_CHANGED'and view then view.WoWUEquipmentChanged()end
 if event=='UNIT_SPELLCAST_CHANNEL_START'and (F.active or WoWUClient.isRetail) then
  local unit,_,id=...
  if unit=='player'and F.IsFishingSpell(id)then local d=db();d.started=d.started or time();d.casts=d.casts+1 end
 elseif (event=='LOOT_READY'or event=='LOOT_OPENED')and (F.active or WoWUClient.isRetail)and not lootOpen and call(IsFishingLoot)then
  lootOpen=true;loot={}
  for slot=1,call(GetNumLootItems)or 0 do
   local link=call(GetLootSlotLink,slot);local id=link and tonumber(link:match('item:(%d+)'))
   if id then local icon,name,count=call(GetLootSlotInfo,slot);loot[slot]={id=id,link=link,name=name,icon=icon,count=count or 1}end
  end
 elseif event=='LOOT_SLOT_CLEARED'and lootOpen then
  local slot=...;local item=loot[slot];local d=db()
  if item and d.started then
   local previous=d.items[item.id]or {name=item.name,icon=item.icon,link=item.link,count=0};d.items[item.id]=previous
   previous.count=previous.count+item.count;d.total=d.total+item.count;loot[slot]=nil
  end
 elseif event=='LOOT_CLOSED'then loot={};lootOpen=false end
 if refresh and view and view:IsVisible()then refresh()end
end)

-- Native UI may leave cursor control after casting/opening loot. Reassert only
-- while this explicit possession is active; never cast or click from this timer.
local function rightStickHeld()
 local G=C_GamePad
 local state=G and call(G.GetDeviceMappedState,F.deviceID)
 if not state or type(state.sticks)~='table'then return false end
 local base=state.sticks[0]~=nil and 0 or 1
 local fallback
 for i=0,(state.stickCount or #state.sticks)-1 do
  local name=call(G.StickIndexToConfigName,i)
  local stick=state.sticks[i+base]
  if stick and (name=='Camera'or name=='Right'or name=='RightStick')then
   local x,y=tonumber(stick.x)or 0,tonumber(stick.y)or 0
   local length=tonumber(stick.len)or math.sqrt(x*x+y*y)
   if name=='Right'or name=='RightStick'then return length>(F.cameraMode and .02 or .08)end
   fallback=length>(F.cameraMode and .02 or .08)
  end
 end
 return fallback or false
end
-- Native cursor mode suppresses the normal Camera input path on this client.
-- Select one native input mode from actual stick input; never drive camera motion,
-- cast, click or detect a bobber from the update handler.
events:HookScript('OnUpdate',function()
 if not F.active then return end
 if combat()or not view or not view:IsVisible()or not WoWUController.active then F.Stop();return end
 local now=GetTime()
 if rightStickHeld()then F.cameraUntil=now+.10 end
 local camera=F.cameraUntil and now<F.cameraUntil or false
 if F.cameraMode~=camera then
  F.cameraMode=camera;F.cursorReady=false;F.cursorDeadline=camera and nil or now+5
  local ok,err=pcall(function()
   if camera then
    SetGamePadCursorControl(false)
    if SetGamePadFreeLook then SetGamePadFreeLook(true)end
   else
    if SetGamePadFreeLook then SetGamePadFreeLook(false)end
    SetGamePadCursorControl(true)
   end
  end)
  if not ok then
   F.Stop();F.lastError=tostring(err);if feedback then feedback('Fishing input mode failed: '..tostring(err),true)end;return
  end
 end
 if camera then
  F.UpdateClick();return
 end
 if call(IsGamePadCursorControlEnabled)then
  if not F.cursorReady then
   F.cursorReady=true;F.cursorDeadline=nil
   if feedback then feedback('A casts; X reels in. Left stick aims. Right stick looks around; release it to return to aiming.')end
  end
 else
  F.cursorDeadline=F.cursorDeadline or now+5
  local ok,err=pcall(SetGamePadCursorControl,true)
  if not ok or now>=F.cursorDeadline then
   local reason=not ok and tostring(err)or ('Cursor activation timed out. CanGamePadControlCursor='..tostring(call(CanGamePadControlCursor))..'; native active device='..tostring(call(C_GamePad.GetActiveDeviceID)))
   F.Stop();F.lastError=reason
   if feedback then feedback(reason..' Normal controls have been requested. Use /wowufishingdebug for details.',true)end
   return
  end
 end
 F.UpdateClick()
end)
SLASH_WOWUFISHINGDEBUG1='/wowufishingdebug'
SlashCmdList.WOWUFISHINGDEBUG=function()
 print('WoWU Fishing: active='..tostring(F.active)..'; cast='..tostring(F.CastName()))
 print('Right stick held='..tostring(rightStickHeld())..'; camera mode='..tostring(F.cameraMode))
 print('Cursor ready='..tostring(F.cursorReady)..'; cursor permitted='..tostring(call(CanGamePadControlCursor)))
 print('Cursor='..tostring(call(IsGamePadCursorControlEnabled))..'; free look='..tostring(call(IsGamePadFreelookEnabled))..'; device='..tostring(F.deviceID))
 print('A='..tostring(call(GetBindingAction,'PAD1',true))..'; X='..tostring(call(GetBindingAction,'PAD3',true)))
 print('Right-click emulation='..tostring(get('GamePadCursorRightClick')))
 local r=WoWUDB and WoWUDB.fishingRecovery
 local config=r and call(C_GamePad.GetConfig,r.id)
 for _,s in ipairs(config and config.stickConfigs or {})do
  if s.stick=='Cursor'or s.stick=='Camera'or s.stick=='Movement'then print(s.stick..': '..tostring(s.axisX)..' / '..tostring(s.axisY)..'; deadzone='..tostring(s.deadzone))end
 end
 for _,axis in ipairs(config and config.axisConfigs or {})do
  if axis.axis=='PStickX'or axis.axis=='PStickY'then print('Movement neutral input '..axis.axis..': scale='..tostring(axis.scale)..'; shift='..tostring(axis.shift))end
 end
 if F.lastError then print('Last fishing error: '..F.lastError)end
end
