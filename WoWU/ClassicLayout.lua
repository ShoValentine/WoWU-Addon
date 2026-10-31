-- Native preset switching only; no automatic per-frame Classic positioning.
if not(WoWUClient and WoWUClient.isClassic)then return end
WoWUClassicLayout={}
local L=WoWUClassicLayout
local function key()return UnitGUID('player')or UnitName('player')or 'Player'end
local function recovery()
 WoWUDB.classicUtilityRecovery=WoWUDB.classicUtilityRecovery or {}
 return WoWUDB.classicUtilityRecovery
end


function L.PrepareUtilities()
 if InCombatLockdown()or not(WoWUViewport and WoWUViewport.active)then return end
 local f=MainMenuBarVehicleLeaveButton;if not f then return end
 local all,id=recovery(),key()
 if not all[id]then
  local parent=f:GetParent();all[id]={parent=parent and parent:GetName()or 'MainActionBar'}
 end
 -- Visibility-only exception: preserve native click behavior and all user anchors.
 if f:GetParent()~=UIParent then f:SetParent(UIParent)end
end
local function restoreUtility()
 if InCombatLockdown()then error('Restore Classic controls outside combat.')end
 local all,id=recovery(),key();local record=all[id]
 if record and MainMenuBarVehicleLeaveButton and _G[record.parent]then
  MainMenuBarVehicleLeaveButton:SetParent(_G[record.parent]);all[id]=nil
 end
 -- Old classicLayouts snapshots remain untouched for recovery. Do not apply
 -- them: that would overwrite the layout the user has just arranged and saved.
end

local usesPreset=WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5
local pending,expires,restorePending=false,0,false
function L.GetStatus()
 if not usesPreset then return 'Classic frame repositioning is disabled.'end
 if pending then return 'Waiting to activate Classic WoWU Layout.'end
 if L.lastError then return 'Classic layout: '..L.lastError end
 return 'Classic: native WoWU Layout switching; automatic frame repositioning disabled.'
end
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function state()
 WoWUDB.classicCompanionLayouts=WoWUDB.classicCompanionLayouts or WoWUDB.classicEraLayouts or {}
 local all=WoWUDB.classicCompanionLayouts;local id=key();all[id]=all[id]or {};return all[id]
end
local function manager()
 local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
 if load then pcall(load,'Blizzard_EditMode')end
 local m=EditModeManagerFrame
 if not(C_EditMode and C_EditMode.GetLayouts and C_EditMode.SetActiveLayout and m and m.layoutInfo and m.layoutInfo.layouts)then error('Classic Edit Mode layouts are not ready yet.')end
 if m:IsShown()or m.HasActiveChanges and m:HasActiveChanges()then error('Save and close Edit Mode before switching Gamepad Mode.')end
 return m
end
local function identity(layout,index)return {name=layout.layoutName,kind=layout.layoutType,index=index,preset=layout.layoutIndex}end
local function find(m,id)
 if not id then return end
 for i,layout in ipairs(m.layoutInfo.layouts)do
  if layout.layoutName==id.name and layout.layoutType==id.kind then return i end
 end
end
local function target(m)
 local name=WoWUClassicPreset.name
 local active=m.layoutInfo.activeLayout
 if m.layoutInfo.layouts[active]and m.layoutInfo.layouts[active].layoutName==name then return active end
 for i,layout in ipairs(m.layoutInfo.layouts)do if layout.layoutName==name then return i end end
end
local function ensureTarget(m)
 local index=target(m);if index then return index end
 local preset=WoWUClassicPreset
 if not(C_EditMode.ConvertStringToLayoutInfo and C_EditMode.SaveLayouts)then error('The Classic client cannot import the bundled WoWU Layout.')end
 local layout=C_EditMode.ConvertStringToLayoutInfo(preset.export)
 if not(layout and layout.systems and #layout.systems==preset.systemCount)then error('The Classic client did not accept the bundled WoWU Layout. Import your saved WoWU Layout in Edit Mode, then retry.')end
 if WoWUClient.classicMajor==5 then
  -- Start with this client's complete system list. Bring over the author's
  -- anchors and matching settings, retaining Mists-only systems/settings.
  local base=copy(m.layoutInfo.layouts[m.layoutInfo.activeLayout])
  if not(base and base.systems)then error('The current Mists layout is not ready to adapt.')end
  local mapped={}
  for _,system in ipairs(layout.systems)do mapped[tostring(system.system)..':'..tostring(system.systemIndex or -1)]=system end
  local applied=0
  for _,system in ipairs(base.systems)do
   local authored=mapped[tostring(system.system)..':'..tostring(system.systemIndex or -1)]
   if authored then
    system.anchorInfo=copy(authored.anchorInfo);system.anchorInfo2=copy(authored.anchorInfo2)
    system.isInDefaultPosition=authored.isInDefaultPosition
    local settings={};for _,setting in ipairs(authored.settings or {})do settings[setting.setting]=setting.value end
    for _,setting in ipairs(system.settings or {})do if settings[setting.setting]~=nil then setting.value=settings[setting.setting]end end
    applied=applied+1
   end
  end
  if applied==0 then error('No matching Mists UI systems were found in WoWU Layout.')end
  layout=base
 end
 local kind=Enum.EditModeLayoutType.Character
 local count=0;for _,item in ipairs(m.layoutInfo.layouts)do if item.layoutType==kind then count=count+1 end end
 local limit=Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
 if limit and count>=limit then error('No free character Edit Mode layout slot for WoWU Layout.')end
 -- Save an inactive new layout without replacing or renaming any existing one.
 local all=copy(m.layoutInfo);index=#all.layouts+1
 layout.layoutName=preset.name;layout.layoutType=kind;all.layouts[index]=layout
 C_EditMode.SaveLayouts(all)
 if C_EditMode.OnLayoutAdded then C_EditMode.OnLayoutAdded(index,false,true)end
 m:UpdateLayoutInfo(copy(C_EditMode.GetLayouts()))
 index=target(m);if not index then error('The imported WoWU Layout is not available yet.')end
 return index
end
function L.Capture()
 if not usesPreset then return end
 if InCombatLockdown()then error('Switch Classic layouts outside combat.')end
 local m=manager();local s=state();if s.previous then return end
 local index=m.layoutInfo.activeLayout;local layout=m.layoutInfo.layouts[index]
 if not layout then error('The active Classic layout is unavailable.')end
 if layout.layoutName==WoWUClassicPreset.name then
  -- The author may have left the companion preset selected after saving it.
  index=find(m,s.lastNormal)
  if not index then
   for i,item in ipairs(m.layoutInfo.layouts)do
    if item.layoutType==Enum.EditModeLayoutType.Preset then
     index=index or i
     if item.layoutIndex==Enum.EditModePresetLayouts.Classic then index=i;break end
    end
   end
  end
  layout=index and m.layoutInfo.layouts[index]
 end
 if not layout then error('Select a normal gameplay layout once before enabling Gamepad Mode.')end
 s.previous=identity(layout,index)
end
function L.Apply()
 if not usesPreset then return end
 if InCombatLockdown()then error('Classic layout activation is waiting for combat to end.')end
 local m=manager();local s=state()
 if not s.previous then L.Capture()end
 local index=ensureTarget(m)
 if m.layoutInfo.activeLayout~=index then C_EditMode.SetActiveLayout(index)end
 local updated=manager();local selected=target(updated)
 if not selected or updated.layoutInfo.activeLayout~=selected then error('Waiting for Classic to activate WoWU Layout.')end
 s.target=identity(updated.layoutInfo.layouts[selected],selected)
 pending=false
 -- Native layout switching may show ordinary bars; visibility is separate.
 if WoWU_ApplyBlizzardVisibility then WoWU_ApplyBlizzardVisibility()end
end
function L.Begin()
 if not usesPreset then return end
 pending=true;expires=GetTime()+30
 local ok,err=pcall(L.Apply)
 if not ok then L.lastError=tostring(err)else L.lastError=nil end
end
function L.Restore()
 pending=false;restoreUtility()
 if not usesPreset then return end
 local s=state();if not s.previous then restorePending=false;return end
 restorePending=true
 if InCombatLockdown()then error('Classic layout restoration is waiting for combat to end.')end
 local m=manager();local index=find(m,s.previous)
 if not index then error('The previous Classic layout was renamed or deleted. Restore it in Edit Mode; the recovery record has been retained.')end
 if m.layoutInfo.activeLayout~=index then C_EditMode.SetActiveLayout(index)end
 if manager().layoutInfo.activeLayout~=index then error('Waiting for Classic to restore the previous layout.')end
 s.lastNormal=s.previous;s.previous=nil;s.target=nil;restorePending=false
end
local events=CreateFrame('Frame');local elapsed=0
for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','EDIT_MODE_LAYOUTS_UPDATED'})do pcall(events.RegisterEvent,events,event)end
local function connected()
 return WoWUViewport and WoWUViewport.active or WoWUDB and(WoWUDB.companionSession or WoWUDB.companionBridgeTransition)
end
events:SetScript('OnEvent',function()
 if not usesPreset or not WoWUDB then return end
 if not connected()and state().previous then restorePending=true end
 -- Never re-select a layout in response to ordinary native layout edits.
end)
events:SetScript('OnUpdate',function(_,dt)
 if not usesPreset or not WoWUDB then return end
 elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0
 if pending and WoWUViewport and WoWUViewport.active then
  if GetTime()>expires then pending=false;print('WoWU layout: '..(L.lastError or 'Classic layout activation timed out.'));return end
  if not InCombatLockdown()then local ok,err=pcall(L.Apply);L.lastError=not ok and tostring(err)or nil end
 elseif restorePending and not connected()and not InCombatLockdown()then
  local ok,err=pcall(L.Restore)
  if not ok then restorePending=false;print('WoWU layout recovery: '..tostring(err))end
 end
end)
