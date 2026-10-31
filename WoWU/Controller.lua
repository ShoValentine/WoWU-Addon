-- Independent controller actions. Never reserve native action slots or save keybindings.
WoWUController={active=false}
local P=WoWUController
local root,editor,profile,profileKey
local manual=false
local ready=false
local suppressed=false
local pendingStop=false
local pendingProfile=false
local buttons,groups={},{}
local modeListeners={}
local capture
function P.AddModeListener(fn)modeListeners[#modeListeners+1]=fn end
local function modeChanged()
 if WoWU_ApplyBlizzardVisibility then WoWU_ApplyBlizzardVisibility()end
 for _,fn in ipairs(modeListeners)do pcall(fn)end
end
local keys={"PADDLEFT","PADDUP","PADDRIGHT","PADDDOWN","PAD3","PAD4","PAD2","PAD1"}
local labels={"Left","Up","Right","Down","X","Y","B","A"}
local prefixes={"","SHIFT-","CTRL-","CTRL-SHIFT-"}
local layers={"No trigger","Left trigger","Right trigger","Both triggers"}
-- Slot order is Left, Up, Right, Down, X, Y, B, A in each layer.
local flightSpells={[16]=425782,[21]=372608,[22]=361584,[23]=403092,[24]=372610}
local utility={
 {"PADLSHOULDER","shoulder-left","Friendly target"},
 {"PADRSHOULDER","shoulder-right","Enemy target"},
 {"PADLSTICK","TOGGLEAUTORUN","Auto-run"},
 {"PADRSTICK","INTERACTTARGET","Interact / exit vehicle"},
 {"PADFORWARD","TOGGLEGAMEMENU","Game menu"},
 {"ALT-PAD4","cursor","Mouse cursor"},
 {"ALT-PADDUP","CAMERAZOOMIN","Zoom in"},
 {"ALT-PADDDOWN","CAMERAZOOMOUT","Zoom out"},
}
local cvars={GamePadEnable="1",GamePadEmulateShift="PADLTRIGGER",GamePadEmulateCtrl="PADRTRIGGER",
 GamePadEmulateAlt="PADBACK",GamePadEmulateEsc="none",GamePadAnalogMovement="1",
 GamePadCursorLeftClick="none",GamePadCursorRightClick="none",GamePadCursorAutoEnable="0",GamePadCursorCentering="0",
 GamePadCursorAutoDisableJump="1",GamePadCursorAutoDisableSticks="0",GamePadCursorForTargeting="2",
 SoftTargetEnemy="1",SoftTargetInteract="1"}
local function combat()return InCombatLockdown and InCombatLockdown()end
local function say(s)print("WoWU controller: "..tostring(s))end
local function call(fn,...)if type(fn)=="function"then local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end end end
local function getvar(n)return call(C_CVar and C_CVar.GetCVar or GetCVar,n)end
local function setvar(n,v)
 local fn=C_CVar and C_CVar.SetCVar or SetCVar
 if not fn then error("Controller settings are unavailable.")end
 fn(n,v)
 if getvar(n)~=tostring(v)then error("The client did not accept "..n..".")end
end
local function charKey()return UnitGUID("player")or ((UnitName("player")or "Player").."-"..GetRealmName())end
local function specKey()
 local index=call(GetSpecialization)
 local id=index and call(GetSpecializationInfo,index)
 return tostring(id or call(GetActiveTalentGroup)or 1)
end
local function getProfile()
 WoWUDB.controller=WoWUDB.controller or {characters={}}
 local db=WoWUDB.controller;db.characters=db.characters or {}
 local key=charKey()..":"..specKey()
 if not db.characters[key]then
  -- The four unmodified face buttons start as utility controls, as in Forever.
  db.characters[key]={slots={
   [5]={kind="binding",id="INTERACTTARGET",name="Interact"},
   [6]={kind="binding",id="WOWUPAD_INSPECT",name="Inspect"},
   [7]={kind="binding",id="WOWUPAD_BACK",name="Back"},
   [8]={kind="binding",id="JUMP",name="Jump"}}}
 end
 local p=db.characters[key]
 if not p.interactDefaultMigrated then
  local x=p.slots[5]
  if x and x.kind=="binding"and x.id=="ATTACKTARGET"then p.slots[5]={kind="binding",id="INTERACTTARGET",name="Interact"}end
  p.interactDefaultMigrated=true
 end
 if not p.inspectDefaultMigrated then
  local y=p.slots[6]
  if y and y.kind=="binding"and y.id=="TOGGLEWORLDMAP"then p.slots[6]={kind="binding",id="WOWUPAD_INSPECT",name="Inspect"}end
  p.inspectDefaultMigrated=true
 end
 if not p.backDefaultMigrated then
  p.previousUnmodifiedB=p.slots[7]
  p.slots[7]={kind="binding",id="WOWUPAD_BACK",name="Back"};p.backDefaultMigrated=true
 end
 return db.characters[key],key
end
local function text(parent,value,size)
 local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 f:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"");f:SetText(value)
 WoWU_Theme.TextColor(f,.94,.82,.57);return f
end
local function simple(parent,value,w,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(w,28);b:SetText(value);b:SetScript("OnClick",fn);return b
end
local function spellInfo(id)
 local info=call(C_Spell and C_Spell.GetSpellInfo,id)
 if info then return info.name,info.iconID end
 local name,_,icon=call(GetSpellInfo,id);return name,icon
end
local function macroIndex(s)
 -- A deleted macro must not silently turn into whichever macro inherits its index.
 local found
 for i=1,138 do
  local name,_,body=GetMacroInfo(i)
  if name==s.name and body==s.body then if found then return end;found=i end
 end
 return found
end
local function describe(s)
 if not s then return "Empty slot",nil end
 if s.kind=="spell"then local n,t=spellInfo(s.id);return n or s.name or "Unavailable spell",t
 elseif s.kind=="item"then
  local n=call(C_Item and C_Item.GetItemNameByID,s.id)or call(GetItemInfo,s.id)
  return n or s.name or ("Item "..s.id),call(C_Item and C_Item.GetItemIconByID or GetItemIcon,s.id)
 elseif s.kind=="macro"then local i=macroIndex(s);if i then return GetMacroInfo(i)end;return (s.name or "Macro").." (missing or changed)",nil
 elseif s.kind=="binding"then return s.name or s.id,"Interface\\Icons\\INV_Misc_Gear_01" end
 return "Unsupported action",nil
end
local function refreshIcon(b,s)
 local n,icon=describe(s)
 if s and s.kind=="binding"then icon=({JUMP="Ability_HeroicLeap",ATTACKTARGET="Ability_MeleeDamage",WOWUPAD_BACK="Ability_Rogue_FeignDeath",WOWUPAD_INSPECT="Spell_Holy_MindVision",TOGGLEWORLDMAP="INV_Misc_Map_01",INTERACTTARGET="INV_Misc_Gear_01"})[s.id];icon=icon and "Interface\\Icons\\"..icon end
 b.icon:SetTexture(icon or b.emptyDirection or "Interface\\AddOns\\WoWU\\Media\\Controller\\empty-circle.tga")
 if b.emptyLabel then b.emptyLabel:SetShown(not s)end
 b.caption=n;b.slotData=s
end
-- Repetition is performed by the client's native UseAction/ReleaseAction pair.
-- No timers, synthetic input or action-bar mutations are used to cast spells.
local heldCVar="ActionButtonUseKeyHeldSpell"
function P.SupportsHoldToCast()return getvar(heldCVar)~=nil and type(ReleaseAction)=="function"end
function P.HoldToCast()return WoWUDB and WoWUDB.controller and WoWUDB.controller.holdToCast==true or false end
local function holdingAction()
 for _,b in ipairs(buttons)do if b:GetAttribute("pad-cast-held")then return true end end
 return false
end
local function applyHoldPreference()
 if not P.SupportsHoldToCast()then return end
 local recovery=WoWUDB.controllerRecovery
 if P.HoldToCast()then
  recovery=recovery or {};WoWUDB.controllerRecovery=recovery
  if recovery[heldCVar]==nil then recovery[heldCVar]=getvar(heldCVar)end
  setvar(heldCVar,"1")
 elseif recovery and recovery[heldCVar]~=nil then
  setvar(heldCVar,recovery[heldCVar]);recovery[heldCVar]=nil
 end
end
local function spellActionSlots()
 local slots={}
 if not P.HoldToCast()or not P.SupportsHoldToCast()then return slots end
 for index=1,180 do
  local kind,id=call(GetActionInfo,index)
  if WoWUClient.Public(kind)and WoWUClient.Number(id)and kind=="spell"then
   slots[id]=slots[id]or index
   local override=call(C_Spell and C_Spell.GetOverrideSpell or FindSpellOverrideByID,id)
   if WoWUClient.Number(override)and override>0 then slots[override]=slots[override]or index end
  end
 end
 return slots
end
function P.IsAutomatic()return not WoWUDB or not WoWUDB.controller or WoWUDB.controller.automatic~=false end
function P.ShowActionBars()return WoWUDB and WoWUDB.controller and WoWUDB.controller.showActionBars==true or false end
function P.SetShowActionBars(value)
 WoWUDB.controller=WoWUDB.controller or {characters={}};WoWUDB.controller.showActionBars=value
 if WoWU_ApplyBlizzardVisibility then WoWU_ApplyBlizzardVisibility()end
 return true,combat()and "Saved. Action bars will update after combat."or "Saved."
end
function P.SetAutomatic(value)
 WoWUDB.controller=WoWUDB.controller or {characters={}};WoWUDB.controller.automatic=value
 suppressed=false
 if not value and P.active and not manual then return P.Stop()end
 return true,"Saved. Applies when companion mode is active."
end
function P.RestoreSettings()
 local saved=WoWUDB and WoWUDB.controllerRecovery
 if not saved then return true end
 if combat()then return false,"Controller restoration waits for combat to end."end
 local failures={}
 for n,v in pairs(saved)do
  local ok=pcall(setvar,n,v)
  if ok then saved[n]=nil else failures[#failures+1]=n end
 end
 if next(saved)==nil then WoWUDB.controllerRecovery=nil;return true end
 return false,"Could not restore "..table.concat(failures,", ")..". The recovery record has been retained."
end
local function snapshotSettings()
 WoWUDB.controllerRecovery=WoWUDB.controllerRecovery or {}
 for n in pairs(cvars)do
  local v=getvar(n)
  if v~=nil and WoWUDB.controllerRecovery[n]==nil then WoWUDB.controllerRecovery[n]=v end
 end
end
local function position()
 if not root or combat()then return end
 local r=WoWUViewport and WoWUViewport.GetGameplayRect()
 r=r or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
 local db=WoWUDB.controller or {};local pos=db.position
 local x=pos and (r.left+pos.x*(r.right-r.left))or (r.left+r.right)/2
 local scale=WoWUControllerLayout and WoWUControllerLayout.GetScale()or 1
 local y=pos and (r.bottom+pos.y*(r.top-r.bottom))or r.bottom+235*scale
 local ratio=UIParent:GetEffectiveScale()/root:GetEffectiveScale()
 root:ClearAllPoints();root:SetPoint("CENTER",UIParent,"BOTTOMLEFT",math.max(r.left+370*scale,math.min(r.right-370*scale,x))*ratio,math.max(r.bottom+225*scale,math.min(r.top-175*scale,y))*ratio)
end
P.PositionHUD=position
-- This handler runs in the restricted environment, including vehicle transitions in combat.
local contextSnippet=[[
 self:RunAttribute("_refreshlayout")
 self:ClearBindings()
 local flight=newstate=="flight"
 if flight then newstate=0 end
 self:SetAttribute("pad-flight",flight)
 self:SetAttribute("pad-actionpage",tonumber(newstate)or 0)
 local back=self:GetFrameRef("back");if back then back:SetAttribute("type","macro")end
 if not self:GetAttribute("pad-active") then return end
 if self:GetAttribute("pad-capturing") or self:GetAttribute("pad-editing") then
  self:SetAttribute("pad-lb",false);self:SetAttribute("pad-rb",false)
  self:SetAttribute("pad-lb-used",true);self:SetAttribute("pad-rb-used",true)
  for i=1,8 do local key=self:GetAttribute("target-key"..i);if key then self:SetAttribute("target-held-"..key,nil)end end
  for i=1,self:GetAttribute("key-count") do self:SetBindingClick(true,self:GetAttribute("key"..i),"WoWUPadNoop","LeftButton")end
  return
 end
 if newstate=="battle"or(tonumber(newstate)or 0)>0 then
  self:SetAttribute("pad-lb",false);self:SetAttribute("pad-rb",false)
  self:SetAttribute("pad-lb-used",true);self:SetAttribute("pad-rb-used",true)
  for i=1,8 do local key=self:GetAttribute("target-key"..i);if key then self:SetAttribute("target-held-"..key,nil)end end
 end
 if newstate=="battle" then self:Hide();return end
 self:Show()
 local page=tonumber(newstate) or 0
 local fishing=self:GetAttribute("pad-fishing")and page==0
 local shoulder=self:GetAttribute('pad-rb')and 'rb'or self:GetAttribute('pad-lb')and 'lb'
 for i=1,32 do
  local b=self:GetFrameRef("slot"..i)
  local kind=b:GetAttribute("pad-kind")
  local flightSpell=flight and b:GetAttribute("pad-flight-spell")
  if not b:GetAttribute("pad-cast-held")then
  b:SetAttribute("macro",not flightSpell and b:GetAttribute("pad-base-macro")or nil)
  b:SetAttribute("macrotext",flightSpell and b:GetAttribute("pad-flight-macrotext")or b:GetAttribute("pad-base-macrotext"))
  b:SetAttribute("spell",flightSpell or b:GetAttribute("pad-base-spell"))
  if page>0 then
   b:SetAttribute("type","action")
   b:SetAttribute("action",(page-1)*12+((i-1)%12)+1)
  elseif flightSpell then
   b:SetAttribute("type",b:GetAttribute("pad-flight-macrotext")and "macro"or "spell")
  elseif b:GetAttribute("pad-repeat-action")then
   b:SetAttribute("type","action");b:SetAttribute("action",b:GetAttribute("pad-repeat-action"))
  else
   b:SetAttribute("type",kind~="binding" and kind or nil)
  end
  local repeating=self:GetAttribute("pad-hold-enabled")and b:GetAttribute("type")=="action"
  b:SetAttribute("pressAndHoldAction",repeating or false)
  b:SetAttribute("typerelease",repeating and "actionrelease"or nil)
  end
  local key=self:GetAttribute("key"..i)
  local baseKey=self:GetAttribute('target-key'..((i-1)%8+1))
  local held=baseKey and self:GetAttribute('target-held-'..baseKey)
  local targetButton=page==0 and (held or (i<=8 and shoulder and self:GetAttribute('shoulder-'..shoulder..i)))
  local castHeld=baseKey and self:GetAttribute("cast-held-"..baseKey)
  if castHeld then self:SetBindingClick(true,key,castHeld,"LeftButton")
  elseif fishing and i<=8 then
   b:SetAttribute("type",nil)
   b:SetAttribute("pressAndHoldAction",false);b:SetAttribute("typerelease",nil)
   if i==8 then
    local castName=self:GetAttribute("pad-fishing-spell")
    if castName then b:SetAttribute("type","spell");b:SetAttribute("spell",castName);self:SetBindingSpell(true,key,castName)end
   elseif i==5 then self:SetBinding(true,key,"TURNORACTION")
   elseif i==7 then b:SetAttribute("type","click");self:SetBindingClick(true,key,"WoWUPadFishingStop","LeftButton")
   else self:SetBindingClick(true,key,"WoWUPadNoop","LeftButton")end
  elseif targetButton then self:SetBindingClick(true,key,targetButton,"LeftButton")
  elseif page==0 and i==7 then self:SetBindingClick(true,key,"WoWUPadBack","LeftButton")
  elseif page==0 and not flightSpell and kind=="binding" then
   local command=b:GetAttribute("pad-command")
   if command=="WOWUPAD_BACK"then self:SetBindingClick(true,key,"WoWUPadBack","LeftButton")
   elseif command=="WOWUPAD_INSPECT"then self:SetBindingClick(true,key,"WoWUPadInspect","LeftButton")
   else self:SetBinding(true,key,command)end
  else self:SetBindingClick(true,key,b:GetName(),"LeftButton")end
 end
 for i=33,self:GetAttribute("key-count") do
  local key=self:GetAttribute("key"..i)
  local cmd=self:GetAttribute("cmd"..i)
  if fishing and cmd=="TOGGLEAUTORUN"then self:SetBindingClick(true,key,"WoWUPadNoop","LeftButton")
  elseif cmd=="shoulder-left"then self:SetBindingClick(true,key,"WoWUPadShoulderLB","LeftButton")
  elseif cmd=="shoulder-right"then self:SetBindingClick(true,key,"WoWUPadShoulderRB","LeftButton")
  elseif cmd=="cursor" then self:SetBindingClick(true,key,"WoWUPadCursor","LeftButton")
  elseif page>0 and not flight and cmd=="INTERACTTARGET" then self:SetBinding(true,key,"VEHICLEEXIT")
  else self:SetBinding(true,key,cmd)end
 end
]]
local function contextDriver()
 local ab=C_ActionBar or {}
 local vehicle=call(ab.GetVehicleBarIndex or GetVehicleBarIndex)
 local override=call(ab.GetOverrideBarIndex or GetOverrideBarIndex)
 local temporary=call(ab.GetTempShapeshiftBarIndex or GetTempShapeshiftBarIndex)
 local clauses={"[petbattle] battle"}
 if vehicle then clauses[#clauses+1]="[vehicleui] "..vehicle;clauses[#clauses+1]="[possessbar] "..vehicle end
 if override then clauses[#clauses+1]="[overridebar] "..override end
 if temporary then clauses[#clauses+1]="[shapeshift] "..temporary end
 -- Skyriding supplies a bonus action bar, including while still on the ground.
 -- Resolve its actual page inside the secure handler at transition time.
 if WoWUClient.isRetail then clauses[#clauses+1]="[bonusbar:5] flight"end
 clauses[#clauses+1]="0";return table.concat(clauses,"; ")
end
local function build()
 if root then return end
 if WoWUControllerTargeting then WoWUControllerTargeting.Initialize()end
 root=CreateFrame("Frame","WoWUControllerHUD",UIParent,"SecureHandlerStateTemplate")
 root:SetSize(720,330);root:SetMovable(true);root:SetClampedToScreen(true);root:SetFrameStrata("MEDIUM");root:Hide()
 -- Keep every action button shown so the existing secure bindings remain usable.
 -- Only presentation and mouse hit-testing change when a trigger is held.
 root:SetAttribute("_refreshlayout",[[
  local compact=self:GetAttribute("pad-compact")
  local layer=self:GetAttribute("pad-editing")and 1 or tonumber(self:GetAttribute("state-padlayer"))or 1
  for i=1,4 do
   local visible=not compact or i==layer
   local group=self:GetFrameRef("group"..i)
   if group then group:SetAlpha(visible and 1 or 0)end
   for k=1,8 do
    local button=self:GetFrameRef("slot"..((i-1)*8+k))
    if button then button:EnableMouse(visible)end
   end
  end
 ]])
 root:SetAttribute("_onstate-padlayer",[[self:RunAttribute("_refreshlayout")]])
 root:SetAttribute("_onstate-context",contextSnippet)
 root:SetAttribute("_refreshbindings","local newstate=self:GetAttribute('state-context') or '0'; "..contextSnippet)
 root:SetAttribute("_onstate-capturecombat",[[
  if newstate=="combat" and self:GetAttribute("pad-fishing")then self:SetAttribute("pad-fishing",false);self:RunAttribute("_refreshbindings")end
  if newstate=="combat" then local back=self:GetFrameRef("back");if back then back:SetAttribute("type","macro")end end
  if newstate=="combat" and (self:GetAttribute("pad-capturing") or self:GetAttribute("pad-editing")) then
   self:SetAttribute("pad-capturing",false)
   self:SetAttribute("pad-editing",false)
   self:RunAttribute("_refreshbindings")
  end
 ]])
 RegisterStateDriver(root,"capturecombat","[combat] combat; peace")
 WoWUControllerLayout.Attach(root)
 for layer=1,4 do
  local g=WoWUControllerLayout.CreateGroup(layer);groups[layer]=g;root:SetFrameRef("group"..layer,g)
  for k=1,8 do
   local index=(layer-1)*8+k
   local b=CreateFrame("Button","WoWUPadSlot"..index,g,"SecureActionButtonTemplate")
   WoWUControllerLayout.PlaceButton(b,layer,k)
   b:RegisterForClicks("AnyDown","AnyUp");b:SetAttribute("useOnKeyDown",true)
   b:SetAttribute("pad-physical-key",keys[k])
   -- Keep all trigger variants routed to the pressed button until key-up.
   -- PostClick releases the latch only after native ReleaseAction has run.
   SecureHandlerWrapScript(b,"PreClick",root,[[
    if down and self:GetAttribute("pressAndHoldAction")and self:GetAttribute("type")=="action"then
     self:SetAttribute("pad-cast-held",true)
     control:SetAttribute("cast-held-"..self:GetAttribute("pad-physical-key"),self:GetName())
     control:RunAttribute("_refreshbindings")
    end
   ]])
   SecureHandlerWrapScript(b,"PostClick",root,[[
    if not down and self:GetAttribute("pad-cast-held")then
     self:SetAttribute("pad-cast-held",false)
     control:SetAttribute("cast-held-"..self:GetAttribute("pad-physical-key"),nil)
     control:RunAttribute("_refreshbindings")
    end
   ]])
   -- Trigger modifiers select the layer, not self-cast / focus-cast targets.
   b:SetAttribute("checkselfcast",false);b:SetAttribute("checkfocuscast",false)
   b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2");b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
   b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
   b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("TOPLEFT",3,-3);b.icon:SetPoint("BOTTOMRIGHT",-3,3);b.icon:SetTexCoord(.08,.92,.08,.92)
   b.cd=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate");b.cd:SetAllPoints(b.icon)
   b.key=text(b,labels[k],10);b.key:SetPoint("BOTTOMRIGHT",4,-3)
   WoWUControllerLayout.StyleButton(b,k)
   WoWUControllerEffects.Attach(b,k>4,keys[k],layer)
   b:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_RIGHT");local s=self.slotData
    if P.fishing and index<=8 then GameTooltip:SetText(index==8 and "Cast Fishing"or index==5 and "Reel In - right-click the bobber under the cursor"or index==7 and "Stop Fishing"or "Unused while fishing");GameTooltip:Show();return end
    if index<=8 and WoWUControllerShoulders and WoWUControllerShoulders.VisualMode()then GameTooltip:Hide();return end
    if root:GetAttribute("pad-flight")and self:GetAttribute("pad-flight-spell")then GameTooltip:SetSpellByID(self:GetAttribute("pad-flight-spell"))
    elseif self:GetAttribute("type")=="action"then GameTooltip:SetAction(self:GetAttribute("action"))
    elseif s and s.kind=="spell"then GameTooltip:SetSpellByID(s.id)
    elseif s and s.kind=="item"then GameTooltip:SetItemByID(s.id)
    else GameTooltip:SetText(self.caption or "Empty slot")end
    if s and s.kind=="spell"and P.HoldToCast()then
     GameTooltip:AddLine(self:GetAttribute("pad-repeat-action")and "Hold to Cast: release the button to stop repeating."or "Hold to Cast: requires this spell on an existing action bar.",.9,.77,.45,true)
    end
    GameTooltip:AddLine("Use + Pad in Spellbook or Bags to assign an action.",.7,.7,.7);GameTooltip:Show()
   end)
   b:SetScript("OnLeave",function()GameTooltip:Hide()end)
   b:HookScript("PostClick",function()if WoWUControllerTargeting then WoWUControllerTargeting.Sync(true)end end)
   root:SetFrameRef("slot"..index,b);root:SetAttribute("key"..index,prefixes[layer]..keys[k]);buttons[index]=b
  end
 end
 local fishingStop=CreateFrame("Button","WoWUPadFishingStop",root);fishingStop:RegisterForClicks("AnyUp")
 fishingStop:SetScript("OnClick",function()if WoWUFishing then WoWUFishing.Stop()end end)
 root:SetFrameRef("fishing-stop",fishingStop)
 buttons[7]:SetAttribute("clickbutton",fishingStop)
 local cursor=CreateFrame("Button","WoWUPadCursor",root);cursor:RegisterForClicks("AnyUp")
 cursor:SetScript("OnClick",function()
  if WoWUControllerTargeting then WoWUControllerTargeting.ToggleCursor()end
 end)
 local noop=CreateFrame("Button","WoWUPadNoop",root,"SecureActionButtonTemplate");noop:RegisterForClicks("AnyDown","AnyUp")
 local aim=text(root,"Ground targeting: right stick aims  |  A places  |  B cancels",15)
 aim:SetPoint("BOTTOM",root,"TOP",0,12);aim:Hide()
 local aimWatcher=CreateFrame("Frame",nil,UIParent);local aimElapsed=0
 aimWatcher:SetScript("OnUpdate",function(_,dt)
  aimElapsed=aimElapsed+dt;if aimElapsed<.1 then return end;aimElapsed=0
  local status=WoWUControllerTargeting and WoWUControllerTargeting.Status()
  aim:SetText(status or "");aim:SetShown(status~=nil)
 end)
 local inspectButton=CreateFrame("Button","WoWUPadInspect",root,"SecureActionButtonTemplate")
 inspectButton:RegisterForClicks("AnyDown","AnyUp");inspectButton:SetAttribute("useOnKeyDown",false)
 inspectButton:SetAttribute("type","togglemenu");inspectButton:SetAttribute("unit","target")
 inspectButton:SetScript("PreClick",function(self,_,down)
  if not down and not combat()then self:SetAttribute("type",nil)end
 end)
 inspectButton:SetScript("PostClick",function(self,_,down)
  if down or combat()then return end
  if UnitExists("target")then WoWUPadNavigation.TargetMenu()else say("Select a target first.")end
  self:SetAttribute("type","togglemenu")
 end)
 local back=CreateFrame("Button","WoWUPadBack",root,"SecureActionButtonTemplate")
 back:RegisterForClicks("AnyDown","AnyUp");back:SetAttribute("useOnKeyDown",false)
 back:SetAttribute("type","macro");back:SetAttribute("macrotext","/stopspelltarget\n/cleartarget")
 back:SetScript("PreClick",function(self,_,down)
  if down or combat()then return end
  local targeting=SpellIsTargeting and SpellIsTargeting()
  local consumed=not targeting and WoWUPadNavigation and WoWUPadNavigation.Back()
  if consumed then self:SetAttribute("type",nil)else self:SetAttribute("type","macro")end
 end)
 -- The restricted state handler ensures Back still works if combat starts during a dialog.
 root:SetFrameRef("back",back)
 if WoWUControllerShoulders then WoWUControllerShoulders.Initialize(root,buttons,refreshIcon)end
 local count=32
 for _,prefix in ipairs(prefixes)do for _,u in ipairs(utility)do
  count=count+1;root:SetAttribute("key"..count,u[1]:find("ALT-",1,true)and ("ALT-"..prefix..u[1]:sub(5))or prefix..u[1]);root:SetAttribute("cmd"..count,u[2])
 end end
 -- A tapped trigger must not fall through to an old native action binding.
 for _,prefix in ipairs(prefixes)do for _,key in ipairs({"PADLTRIGGER","PADRTRIGGER","PADBACK"})do
  count=count+1;root:SetAttribute("key"..count,prefix..key);root:SetAttribute("cmd"..count,"CLICK WoWUPadNoop:LeftButton")
 end end
 root:SetAttribute("key-count",count)
 RegisterStateDriver(root,"padlayer","[mod:ctrl,mod:shift] 4; [mod:ctrl] 3; [mod:shift] 2; 1")
 WoWUControllerLayout.Apply()
end
local function applyProfile()
 if holdingAction()then pendingProfile=true;return end
 pendingProfile=false
 profile,profileKey=getProfile()
 -- Native possessed bars also need ReleaseAction when the user's own setting
 -- was already enabled, even if WoWU's optional independent-slot mode is off.
 root:SetAttribute("pad-hold-enabled",P.SupportsHoldToCast()and getvar(heldCVar)=="1")
 local repeatSlots=spellActionSlots()
 for i,b in ipairs(buttons)do
  local s=profile.slots[i];local kind=s and s.kind
  for _,attr in ipairs({"type","spell","item","macro","macrotext","action","pad-command","pad-kind","pad-repeat-action","pressAndHoldAction","typerelease"})do b:SetAttribute(attr,nil)end
  if kind=="spell"and WoWUQuickAccess.MountID(s)then
   s.mountID=WoWUQuickAccess.MountID(s)
   local name=call(C_MountJournal.GetMountInfoByID,s.mountID)
   -- Journal mounts aren't ordinary spellbook spells. Resolve the native
   -- localized cast name outside combat and execute via the secure button.
   if type(name)=="string"and name~=""then
    kind="macro";b:SetAttribute("macrotext","/cast [nomounted] "..name:gsub('[\r\n]','').."\n/dismount [mounted]")
   else b:SetAttribute("spell",s.id)end
  elseif kind=="spell"then
   local action=repeatSlots[s.id]
   b:SetAttribute("pad-repeat-action",action)
   local name=spellInfo(s.id)
   if type(name)=="string"and name~=""then
    -- Resolve spell overrides by name and provide the selected unit explicitly.
    -- Empty fallback preserves native self casts and targeting cursors when
    -- there is no selected unit. Do not force @player or @cursor here.
    kind="macro";b:SetAttribute("macrotext","/cast [@target,exists][] "..name:gsub('[\r\n]',''))
   else b:SetAttribute("spell",s.id)end
  elseif kind=="item"then b:SetAttribute("item","item:"..s.id)
  elseif kind=="macro"then local id=macroIndex(s);b:SetAttribute("macro",id);if not id then kind=nil end
  elseif kind=="binding"then b:SetAttribute("pad-command",s.id)
  else kind=nil end
  b:SetAttribute("pad-base-macro",b:GetAttribute("macro"))
  b:SetAttribute("pad-base-macrotext",b:GetAttribute("macrotext"));b:SetAttribute("pad-base-spell",b:GetAttribute("spell"))
  local flightSpell=WoWUClient.isRetail and flightSpells[i]
  b:SetAttribute("pad-flight-spell",flightSpell or nil)
  local flightName=flightSpell and spellInfo(flightSpell)
  b:SetAttribute("pad-flight-macrotext",flightName and ("/cast "..flightName:gsub('[\r\n]',''))or nil)
  b:SetAttribute("pad-kind",kind);refreshIcon(b,s)
 end
 if P.active then
  UnregisterStateDriver(root,"context");RegisterStateDriver(root,"context",contextDriver())
  root:Execute("local newstate=self:GetAttribute('state-context') or '0'; "..contextSnippet)
 end
end
function P.SetHoldToCast(value)
 if combat()then return false,"Change Hold to Cast outside combat."end
 if holdingAction()then return false,"Release the held spell button before changing Hold to Cast."end
 if value and not P.SupportsHoldToCast()then return false,"This client does not support native hold-to-repeat casting."end
 WoWUDB.controller=WoWUDB.controller or {characters={}}
 local previous=P.HoldToCast();WoWUDB.controller.holdToCast=value==true
 if P.active then
  local ok,err=pcall(applyHoldPreference)
  if not ok then WoWUDB.controller.holdToCast=previous;return false,"Could not change Hold to Cast: "..tostring(err)end
  applyProfile()
 end
 return true,value and "Hold to Cast enabled. Assigned spells must also be on an existing action bar (hidden bars work). Macros/items remain single-press."or "Hold to Cast disabled."
end
function P.SetFishing(active)
 if not root or not P.active then return false,"Enable WoWU controller mode first."end
 if combat()then if not active then P.fishing=false end;return false,"Fishing controls wait until combat ends."end
 local context=root:GetAttribute("state-context")or "0"
 if active and tostring(context)~="0"then return false,"Leave vehicle, possession or shapeshift controls before fishing (context "..tostring(context)..")."end
 if active and WoWUPadNavigation then WoWUPadNavigation.Clear()end
 local castName=active and WoWUFishing and WoWUFishing.CastName()
 if active and not castName then return false,"The native Fishing spell name is unavailable."end
 root:SetAttribute("pad-fishing-spell",castName or nil)
 P.fishing=active and true or false
 root:SetAttribute("pad-fishing",P.fishing)
 if P.fishing and WoWUControllerShoulders then WoWUControllerShoulders.Reset()end
 root:Execute(root:GetAttribute("_refreshbindings"))
 for i=1,8 do if buttons[i]then refreshIcon(buttons[i],profile.slots[i]);buttons[i].cd:Show()end end
 return true
end
function P.RefreshFishingVisuals()
 if not P.fishing or IsShiftKeyDown()or IsControlKeyDown()or IsAltKeyDown()then return end
 for i=1,8 do
  local b=buttons[i]
  if b then
   local icon=i==8 and "Interface\\Icons\\Trade_Fishing"or i==5 and "Interface\\Icons\\INV_Fishingpole_02"or i==7 and "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
   b.icon:SetTexture(icon or b.emptyDirection or "Interface\\AddOns\\WoWU\\Media\\Controller\\empty-circle.tga")
   b.cd:Hide();if b.emptyLabel then b.emptyLabel:SetShown(not icon)end
  end
 end
end
function P.RestoreInspectDefault()
 if combat()then return false,"Restore the Y assignment outside combat."end
 local p=getProfile();p.slots[6]={kind="binding",id="WOWUPAD_INSPECT",name="Inspect"};p.inspectDefaultMigrated=true
 if root then applyProfile()end
 return true,"Unmodified Y now opens the target's Inspect/context menu."
end
function P.Start(isManual)
 if combat()then return false,"Enable controller controls outside combat."end
 if WoWUClient and WoWUClient.isForever then return false,"Forever already supplies its native controller controls."end
 if not C_GamePad or not SetOverrideBindingClick or getvar("GamePadEnable")==nil then return false,"This client does not expose native controller support."end
 local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
 if loaded and loaded("ConsolePort")then return false,"Disable ConsolePort before enabling WoWU controller controls."end
 if P.active then if isManual then manual=true end;return true,"Controller controls are active."end
 local restored,msg=P.RestoreSettings();if not restored then return false,msg end
 snapshotSettings()
 local ok,err=pcall(function()
  for n,v in pairs(cvars)do if getvar(n)~=nil then setvar(n,v)end end
  applyHoldPreference()
  build();WoWUControllerLayout.Apply();applyProfile();root:SetAttribute("pad-active",true);P.active=true
  applyProfile()
 end)
 if not ok then P.Stop();return false,"Could not enable controller controls: "..tostring(err)end
 manual=isManual==true;suppressed=false
 if WoWUControllerTargeting then WoWUControllerTargeting.LeaveCursor()end
 modeChanged()
 return true,"Controller controls enabled. Select a spell or item and press + Pad to assign it."
end
function P.Stop()
 if holdingAction()then pendingStop=true;return false,"Release the held spell button to finish restoring controller controls."end
 if WoWUFishing and WoWUFishing.active then WoWUFishing.Stop()end
 if WoWUPadNavigation then WoWUPadNavigation.Clear()end
 if combat()then pendingStop=true;return false,"Controller restoration is queued until combat ends."end
 if capture then capture:Hide()end
 if WoWUControllerLayout.editing then WoWUControllerLayout.FinishEditing()end
 if root then root:SetAttribute("pad-active",false);root:Execute("self:ClearBindings()");UnregisterStateDriver(root,"context");root:Hide()end
 P.active=false;manual=false;pendingStop=false
 if WoWUControllerTargeting then WoWUControllerTargeting.Reset()end
 if WoWUControllerShoulders then WoWUControllerShoulders.Reset()end
 modeChanged()
 return P.RestoreSettings()
end
function P.Disable()
 suppressed=true
 local ok,msg=P.Stop()
 return ok,msg or "Controller controls released; normal bindings and settings restored."
end
function P.CloseEditors()
 if capture then capture:Hide()end
 if editor then editor:Hide()end
end
function P.BeginAssignment(kind,id,name,icon,feedback)
 if not P.active then return false,"Enable the controller overlay first."end
 if combat()then return false,"Assign pad controls outside combat."end
 if kind~="spell"and kind~="item"then return false,"Choose an active spell or item."end
 if WoWUControllerLayout.editing then WoWUControllerLayout.FinishEditing()end
 if not capture then
  capture=CreateFrame("Frame","WoWUPadAssignment",UIParent,"BackdropTemplate")
  capture:SetSize(530,285);capture:SetFrameStrata("FULLSCREEN_DIALOG");capture:SetFrameLevel(500);capture:EnableMouse(true)
  capture:Hide();WoWU_Theme.Panel(capture)
  if not capture.EnableGamePadButton then return false,"Controller button capture is unavailable on this client."end
  capture:EnableKeyboard(true);capture:SetPropagateKeyboardInput(false);capture:EnableGamePadButton(true)
  local prompt=text(capture,"Press the button you would like to bind this to",18)
  prompt:SetPoint("TOP",0,-25);prompt:SetWidth(480);prompt:SetWordWrap(true)
  capture.icon=capture:CreateTexture(nil,"ARTWORK");capture.icon:SetSize(52,52);capture.icon:SetPoint("TOP",-145,-78)
  capture.name=text(capture,"",18);capture.name:SetPoint("LEFT",capture.icon,"RIGHT",15,0);capture.name:SetWidth(300);capture.name:SetJustifyH("LEFT")
  capture.layer=text(capture,"",14);capture.layer:SetPoint("TOP",0,-153)
  local help=text(capture,"Hold a trigger to choose a layer, then press a face button or D-pad direction.",13)
  help:SetWidth(475);help:SetWordWrap(true);help:SetPoint("TOP",0,-181)
  local close=CreateFrame("Button",nil,capture,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT")
  simple(capture,"Cancel",130,function()capture:Hide()end):SetPoint("BOTTOM",0,18)
  capture:SetScript("OnHide",function(self)
   self.assignment=nil;self.chosen=nil;self.feedback=nil
   if self.cursorWasEnabled~=nil and SetGamePadCursorControl then pcall(SetGamePadCursorControl,self.cursorWasEnabled)end
   self.cursorWasEnabled=nil;self.committing=false
   if root and not combat()then root:SetAttribute("pad-capturing",false);root:Execute(root:GetAttribute("_refreshbindings"))end
  end)
  local function layerText(self)
   -- Emulated triggers need not generate OnGamePadButtonDown. Read both
   -- modifier state and mapped physical buttons when the face key arrives.
   local left=IsShiftKeyDown()or self.left or self.keyboardShift
   local right=IsControlKeyDown()or self.right or self.keyboardCtrl
   local state=call(C_GamePad.GetDeviceMappedState,call(C_GamePad.GetActiveDeviceID))
   if state and state.buttons and C_GamePad.ButtonBindingToIndex then
    local function down(binding)
     local i=call(C_GamePad.ButtonBindingToIndex,binding);if i==nil then return end
     local index=state.buttons[0]~=nil and i or i+1
     return state.buttons[index]
    end
    local l,r=down("PADLTRIGGER"),down("PADRTRIGGER")
    if l~=nil then left=l or IsShiftKeyDown()or self.prefixShift end
    if r~=nil then right=r or IsControlKeyDown()or self.prefixCtrl end
   end
   local layer=(right and 2 or 0)+(left and 1 or 0)+1
   self.layer:SetText(layers[layer]);return layer
  end
  capture:SetScript("OnKeyDown",function(self,key)
   if key=="ESCAPE"then self:Hide()
   elseif key=="LSHIFT"or key=="RSHIFT"then self.keyboardShift=true;layerText(self)
   elseif key=="LCTRL"or key=="RCTRL"then self.keyboardCtrl=true;layerText(self)end
  end)
  capture:SetScript("OnKeyUp",function(self,key)
   if key=="LSHIFT"or key=="RSHIFT"then self.keyboardShift=false;layerText(self)
   elseif key=="LCTRL"or key=="RCTRL"then self.keyboardCtrl=false;layerText(self)end
  end)
  capture:SetScript("OnGamePadButtonDown",function(self,key)
   if combat()or not P.active then self:Hide();return end
   self.prefixShift=key:find("SHIFT-",1,true)~=nil
   self.prefixCtrl=key:find("CTRL-",1,true)~=nil
   key=key:match("(PAD[%w]+)$")or key
   if key=="PADLTRIGGER"then self.left=true;layerText(self);return
   elseif key=="PADRTRIGGER"then self.right=true;layerText(self);return end
   if self.chosen then return end
   local layer=layerText(self)
   if layer==1 and key=="PAD2"then self.layer:SetText("B is reserved for Back. Hold a trigger to assign B.");return end
   for k,binding in ipairs(keys)do if key==binding then
    self.chosen={key=key,index=(layer-1)*8+k,layer=layer,label=labels[k]}
    self.layer:SetText(layers[layer].." - "..labels[k]);return
   end end
   self.layer:SetText("Choose a face button or D-pad direction.")
  end)
  capture:SetScript("OnGamePadButtonUp",function(self,key)
   key=key:match("(PAD[%w]+)$")or key
   if key=="PADLTRIGGER"then self.left=false;layerText(self)
   elseif key=="PADRTRIGGER"then self.right=false;layerText(self)end
   local chosen=self.chosen
   if not chosen or key~=chosen.key or self.committing then return end
   if combat()or not P.active then self:Hide();return end
   local p,keyNow=getProfile()
   if keyNow~=self.profileKey then self:Hide();say("Character or specialization changed; select the ability again.");return end
   self.committing=true
   p.slots[chosen.index]=self.assignment
   applyProfile()
   local message="Assigned "..(self.assignment.name or "action").." to "..layers[chosen.layer].." - "..chosen.label.."."
   self.layer:SetText("Assigned!")
   if self.feedback then pcall(self.feedback,message,true)end
   -- Consume the button's release too, before restoring its new action.
   local generation=self.generation
   C_Timer.After(.15,function()if self.committing and self.generation==generation then self:Hide()end end)
  end)
 end
 if not capture.EnableGamePadButton then return false,"Controller button capture is unavailable on this client."end
 capture:Hide()
 capture.generation=(capture.generation or 0)+1
 local _,key=getProfile()
 capture.profileKey=key;capture.assignment={kind=kind,id=id,name=name};capture.feedback=feedback
 capture.prefixShift=false;capture.prefixCtrl=false
 capture.left=false;capture.right=false;capture.keyboardShift=IsShiftKeyDown();capture.keyboardCtrl=IsControlKeyDown();capture.committing=false;capture.chosen=nil
 capture.name:SetText(name or describe(capture.assignment));capture.icon:SetTexture(icon or select(2,describe(capture.assignment))or 134400)
 capture.layer:SetText(layers[(capture.right and 2 or 0)+(capture.left and 1 or 0)+1])
 if IsGamePadCursorControlEnabled and SetGamePadCursorControl then
  capture.cursorWasEnabled=IsGamePadCursorControlEnabled();SetGamePadCursorControl(false)
 end
 capture:ClearAllPoints();capture:SetPoint("CENTER",WoWU_MainFrame and WoWU_MainFrame:IsShown()and WoWU_MainFrame or UIParent,"CENTER")
 root:SetAttribute("pad-capturing",true);root:Execute(root:GetAttribute("_refreshbindings"))
 capture:Show();return true
end
local function actionCopy(slot)
 local kind,id=call(GetActionInfo,slot)
 if kind=="spell"or kind=="item"then return {kind=kind,id=id}
 elseif kind=="macro"then local n,_,body=GetMacroInfo(id);if n then return {kind="macro",name=n,body=body}end end
end
local function cursorAction()
 local kind,a,_,c=GetCursorInfo()
 if kind=="spell"then
  local id=c
  if not id and GetSpellBookItemInfo then local _,v=GetSpellBookItemInfo(a,"spell");id=v end
  if id then local n=spellInfo(id);return {kind="spell",id=id,name=n}end
 elseif kind=="item"then return {kind="item",id=a}
 elseif kind=="macro"then local n,_,body=GetMacroInfo(a);if n then return {kind="macro",name=n,body=body}end
 end
end
local function knownSpells()
 local list,seen={},{}
 local function add(id,passive)
  if not id or passive or seen[id]then return end
  local n,t=spellInfo(id);if not n then return end
  seen[id]=true;list[#list+1]={kind="spell",id=id,name=n,icon=t}
 end
 if WoWUSpellBook and WoWUSpellBook.GetNumSpellBookSkillLines then
  local bank=WoWUSpellBook.PlayerBank or (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)or 0
  for line=1,WoWUSpellBook.GetNumSpellBookSkillLines()do
   local info=WoWUSpellBook.GetSpellBookSkillLineInfo(line)
   if info then for slot=(info.itemIndexOffset or 0)+1,(info.itemIndexOffset or 0)+(info.numSpellBookItems or 0)do
    local s=WoWUSpellBook.GetSpellBookItemInfo(slot,bank);if s then add(s.spellID,s.isPassive)end
   end end
  end
 elseif GetNumSpellTabs then
  for tab=1,GetNumSpellTabs()do local _,_,offset,count=GetSpellTabInfo(tab)
   for slot=offset+1,offset+count do local _,id=GetSpellBookItemInfo(slot,"spell");add(id,call(IsPassiveSpell,id))end
  end
 end
 table.sort(list,function(a,b)return a.name<b.name end);return list
end
local selected=1
local function saveSlot(s)
 if selected==7 then editor.status:SetText("B is reserved for Back. Choose a trigger layer to assign B.");return end
 if combat()then editor.status:SetText("Assignments are locked during combat.");return end
 local p=getProfile();p.slots[selected]=s
 if root then applyProfile()end
 editor:Refresh();editor.status:SetText("Saved to WoWU only. Your hotbars are unchanged.")
end
function P.OpenSetup()
 if combat()then return false,"Open controller setup outside combat."end
 if WoWUControllerLayout.editing then WoWUControllerLayout.FinishEditing()end
 if not WoWUDB then return false,"Wait for WoWU to load."end
 if editor then editor:Show();editor:Refresh();return true end
 editor=CreateFrame("Frame","WoWUControllerSetup",UIParent,"BackdropTemplate")
 editor:SetSize(900,650);editor:SetFrameStrata("DIALOG");editor:SetClampedToScreen(true);editor:SetMovable(true);editor:EnableMouse(true)
 editor:SetPoint("CENTER",WoWU_MainFrame and WoWU_MainFrame:IsShown()and WoWU_MainFrame or UIParent,"CENTER")
 WoWU_Theme.Panel(editor)
 local drag=CreateFrame("Button",nil,editor);drag:SetPoint("TOPLEFT");drag:SetPoint("TOPRIGHT");drag:SetHeight(40);drag:RegisterForDrag("LeftButton")
 drag:SetScript("OnDragStart",function()editor:StartMoving()end);drag:SetScript("OnDragStop",function()editor:StopMovingOrSizing()end)
 text(drag,"WoWU Controller - independent assignments",20):SetPoint("CENTER")
 local close=CreateFrame("Button",nil,editor,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",1,1)
 local hint=text(editor,"Select a slot, then choose a spell or copy an existing hotbar action from the list.\nYou can also drop spells from the spellbook, items from bags, or macros. Shift-click clears a slot.",12)
 hint:SetPoint("TOPLEFT",20,-46);hint:SetWidth(860);hint:SetJustifyH("LEFT")
 editor.status=text(editor,"",12);editor.status:SetPoint("BOTTOMLEFT",20,14);editor.status:SetWidth(860);editor.status:SetJustifyH("LEFT")
 local slots={}
 local layer=1
 local function scroll(parent,x,width)
  local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate");s:SetPoint("TOPLEFT",x,-155);s:SetSize(width,426)
  local body=CreateFrame("Frame",nil,s);body:SetSize(width,1);s:SetScrollChild(body);return s,body
 end
 local _,slotBody=scroll(editor,20,380)
 local spellScroll,spellBody=scroll(editor,450,400)
 spellScroll:ClearAllPoints();spellScroll:SetPoint("TOPLEFT",450,-189);spellScroll:SetHeight(390)
 local search=CreateFrame("EditBox",nil,editor,"InputBoxTemplate");search:SetSize(390,28);search:SetPoint("TOPLEFT",456,-153);search:SetAutoFocus(false)
 local rows={}
 local source="Spells"
 local function fillSpells()
  for _,b in ipairs(rows)do b:Hide()end
  local filter=string.lower(search:GetText()or "");local list={}
  if source=="Spells"then list=knownSpells()
  elseif source=="Hotbars"then
   for slot=1,180 do local s=actionCopy(slot);if s then local n=describe(s);s.name=s.name or n;s.display="Slot "..slot..": "..n;list[#list+1]=s end end
  else
   for i=1,138 do local n,_,body=GetMacroInfo(i);if n then list[#list+1]={kind="macro",name=n,body=body}end end
  end
  local row=0
  for _,s in ipairs(list)do if filter==""or string.find(string.lower(s.name),filter,1,true)then
   row=row+1;local b=rows[row]
   if not b then b=simple(spellBody,"",390,function(self)saveSlot(self.assignment)end);rows[row]=b;b:SetHeight(34)end
   b.assignment=s;b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(row-1)*37);b:SetText(s.display or s.name);b:Show()
  end end
  spellBody:SetHeight(math.max(1,row*37));spellScroll:SetVerticalScroll(0)
 end
 for i,name in ipairs({"Spells","Hotbars","Macros"})do
  local b=simple(editor,name,128,function()source=name;fillSpells()end);b:SetPoint("TOPLEFT",450+(i-1)*134,-116)
 end
 for k=1,8 do
  local b=simple(slotBody,"",374,function()
   selected=(layer-1)*8+k
   if IsShiftKeyDown()then saveSlot(nil)elseif GetCursorInfo()then
    local s=cursorAction();if s then saveSlot(s);ClearCursor()else editor.status:SetText("Use a spell, item, or existing macro; this action type cannot be copied.")end
   else editor:Refresh()end
  end)
  b:SetHeight(46);b:SetPoint("TOPLEFT",0,-(k-1)*50)
  b:SetScript("OnReceiveDrag",function()
   selected=(layer-1)*8+k;local s=cursorAction()
   if combat()then editor.status:SetText("Assignments are locked during combat.")
   elseif s then saveSlot(s);ClearCursor()else editor.status:SetText("This action type cannot be copied.")end
  end)
  slots[k]=b
 end
 for i,name in ipairs(layers)do
  local b=simple(editor,name,200,function()layer=i;selected=(i-1)*8+1;editor:Refresh()end)
  b:SetPoint("TOPLEFT",20+(i-1)*216,-82)
 end
 local current=text(editor,"",14);current:SetPoint("TOPLEFT",20,-120)
 local clear=simple(editor,"Clear selected slot",180,function()saveSlot(nil)end);clear:SetPoint("BOTTOMLEFT",20,42)
 local jump=simple(editor,"Assign Jump",150,function()saveSlot({kind="binding",id="JUMP",name="Jump"})end);jump:SetPoint("LEFT",clear,"RIGHT",12,0)
 local interact=simple(editor,"Assign Interact",150,function()saveSlot({kind="binding",id="INTERACTTARGET",name="Interact"})end);interact:SetPoint("LEFT",jump,"RIGHT",12,0)
 local inspect=simple(editor,"Assign Inspect",150,function()saveSlot({kind="binding",id="WOWUPAD_INSPECT",name="Inspect"})end);inspect:SetPoint("LEFT",interact,"RIGHT",12,0)
 function editor:Refresh()
  local p=getProfile();current:SetText(layers[layer].." - choose a slot")
  for k,b in ipairs(slots)do local index=(layer-1)*8+k
   local n=describe(p.slots[index]);b:SetText((selected==index and "> "or "")..labels[k].."   "..n)
  end
 end
 search:SetScript("OnTextChanged",fillSpells)
 editor:SetScript("OnShow",function()editor:Refresh();fillSpells()end)
 editor:Refresh();fillSpells()
 return true
end
local highlightedLayer,highlightedEditing
local function updateLayerHighlight()
 if not P.active then highlightedLayer=nil;highlightedEditing=nil;return end
 local layer=(IsControlKeyDown()and 2 or 0)+(IsShiftKeyDown()and 1 or 0)+1
 if WoWUControllerLayout.IsCompact()then return end
 highlightedLayer=layer;highlightedEditing=WoWUControllerLayout.editing
 for i,g in ipairs(groups)do g:SetAlpha(WoWUControllerLayout.editing and 1 or layer==i and 1 or .5)end
end
local e=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_LOGOUT","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_SPECIALIZATION_CHANGED","ACTIVE_TALENT_GROUP_CHANGED","UPDATE_MACROS","SPELLS_CHANGED","DISPLAY_SIZE_CHANGED","MODIFIER_STATE_CHANGED","ACTIONBAR_SLOT_CHANGED"})do pcall(e.RegisterEvent,e,event)end
e:SetScript("OnEvent",function(_,event)
 if event=="ACTIONBAR_SLOT_CHANGED"then pendingProfile=true;return end
 if event=="MODIFIER_STATE_CHANGED"then updateLayerHighlight();return end
 if event=="PLAYER_LOGIN"then ready=true;local ok,msg=P.RestoreSettings();if not ok then say(msg)end;return end
 if event=="PLAYER_LOGOUT"then if not combat()then P.Stop()end;return end
 if event=="PLAYER_REGEN_DISABLED"then if editor then editor:Hide()end;if capture then capture:Hide()end;return end
 if event=="PLAYER_REGEN_ENABLED"and not P.active then local ok,msg=P.RestoreSettings();if not ok then say(msg)end end
 if not combat()and P.active then applyProfile();WoWUControllerLayout.Apply()end
end)
local elapsed=0
e:SetScript("OnUpdate",function(_,dt)
 -- Trigger feedback is immediate; spell/cooldown and lifecycle work stays throttled.
 updateLayerHighlight()
 if WoWUControllerShoulders then WoWUControllerShoulders.RefreshVisuals()end
 P.RefreshFishingVisuals()
 WoWUControllerEffects.Tick(dt,P.active,WoWUControllerLayout.editing)
 elapsed=elapsed+dt;if elapsed<.3 or not ready or not WoWUDB then return end;elapsed=0
 if not combat()then
  if pendingStop then local ok,msg=P.Stop();if not ok then say(msg)end end
  local auto=WoWUViewport and WoWUViewport.active and P.IsAutomatic()and not (WoWUClient and WoWUClient.isForever)
  if auto and not suppressed and not P.active then
   local ok,msg=P.Start(false);if not ok then suppressed=true;say(msg)end
  elseif P.active and not manual and not auto then local ok,msg=P.Stop();if not ok then say(msg)end
  end
  if not auto then suppressed=false end
  if P.active then local _,key=getProfile();if pendingProfile or profileKey~=key then applyProfile()end end
 end
 if not P.active then return end
 local page=tonumber(root:GetAttribute("pad-actionpage"))or 0
 for i,b in ipairs(buttons)do
  local flightSpell=root:GetAttribute("pad-flight")and b:GetAttribute("pad-flight-spell")
  local displayPage=flightSpell and -flightSpell or page
  if flightSpell then
   if b.emptyLabel then b.emptyLabel:Hide()end
   local _,icon=spellInfo(flightSpell);b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  elseif page>0 then
   if b.emptyLabel then b.emptyLabel:Hide()end
   b.icon:SetTexture(call(C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture,(page-1)*12+(i-1)%12+1))
  elseif b.iconPage~=0 then refreshIcon(b,profile.slots[i])
  elseif profile.slots[i]and profile.slots[i].kind=="spell"then
   local _,icon=spellInfo(profile.slots[i].id);b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  end
  local procSpell
  if flightSpell then procSpell=flightSpell
  elseif page>0 then
   local kind,id=call(GetActionInfo,(page-1)*12+(i-1)%12+1)
   if WoWUClient.Public(kind)and WoWUClient.Public(id)then
    if kind=="spell"then procSpell=id elseif kind=="macro"then procSpell=call(GetMacroSpell,id)end
   end
  else
   local assignment=profile.slots[i]
   if assignment and assignment.kind=="spell"then procSpell=assignment.id
   elseif assignment and assignment.kind=="macro"then local macro=macroIndex(assignment);if macro then procSpell=call(GetMacroSpell,macro)end end
  end
  if i<=8 and (P.fishing or WoWUControllerShoulders and WoWUControllerShoulders.VisualMode())then procSpell=nil end
  WoWUControllerEffects.SetSpell(b,procSpell)
  b.iconPage=displayPage
  -- Never branch on secret cooldowns. Restricted information is omitted.
  local s=flightSpell and {kind="spell",id=flightSpell}or profile.slots[i];local start,duration,enabled
  if page>0 then
   local slot=(page-1)*12+(i-1)%12+1
   if C_ActionBar and C_ActionBar.GetActionCooldown then
    local cd=call(C_ActionBar.GetActionCooldown,slot);if cd then start,duration=cd.startTime,cd.duration end
   else start,duration=call(GetActionCooldown,slot)end
  elseif s and s.kind=="spell"then
   local cd=call(C_Spell and C_Spell.GetSpellCooldown,s.id)
   if cd then start,duration,enabled=cd.startTime,cd.duration,cd.isEnabled else start,duration,enabled=call(GetSpellCooldown,s.id)end
  elseif s and s.kind=="item"then start,duration,enabled=call(C_Item and C_Item.GetItemCooldown or GetItemCooldown,s.id)end
  local durationObject
  if b.cd.SetCooldownFromDurationObject then
   if page>0 then durationObject=call(C_ActionBar and C_ActionBar.GetActionCooldownDuration,(page-1)*12+(i-1)%12+1)
   elseif s and s.kind=="spell"then durationObject=call(C_Spell and C_Spell.GetSpellCooldownDuration,s.id)end
  end
  if durationObject then b.cd:SetCooldownFromDurationObject(durationObject)
  elseif not (issecretvalue and issecretvalue(start))and not (issecretvalue and issecretvalue(duration))and type(start)=="number"and type(duration)=="number"then
   b.cd:SetCooldown(start,duration)
  else b.cd:Clear()end
 end
 if WoWUControllerShoulders then WoWUControllerShoulders.RefreshVisuals()end
 P.RefreshFishingVisuals()
end)
SLASH_WOWUPAD1="/wowupad"
SlashCmdList.WOWUPAD=function(input)
 local cmd=(input or ""):lower():match("^%s*(%S*)")
 local ok,msg
 if cmd=="on"then ok,msg=P.Start(true)
 elseif cmd=="off"then ok,msg=P.Disable()
 elseif cmd=="setup"or cmd==""then ok,msg=P.OpenSetup()
 elseif cmd=="edit"then ok,msg=WoWUControllerLayout.ToggleEdit()
 elseif cmd=="resetlayout"then ok,msg=WoWUControllerLayout.Reset()
 elseif cmd=="status"then msg=(P.active and "Active"or "Off")..". Independent per-character, per-specialization assignments; native hotbars and saved bindings untouched."
 else msg="/wowupad on, off, edit, resetlayout, setup, status"end
 if msg then say(msg)end
end
