-- Copy native layout data, including hidden systems, using the active canvas.
local function copy(t)
 if type(t)~="table" then return t end
 local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function say(s) print("WoWU layout: "..s) end
-- Native layout switching shares the viewport lifecycle, including rollback.
WoWUCompanionLayouts={}
local L=WoWUCompanionLayouts
local pendingConversion,conversionEnds,nextConversion,layoutStatus
function L.GetStatus()
 if WoWUClassicLayout and WoWUClassicLayout.GetStatus then return WoWUClassicLayout.GetStatus()end
 return layoutStatus or "Layout conversion has not started."
end
local function managerReady()
 if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_EditMode") end
 local m=EditModeManagerFrame
 if not m or not m.layoutInfo or not C_EditMode or not C_EditMode.SetActiveLayout then
  error("Edit Mode layouts are not ready. Open and close Edit Mode, then retry.")
 end
 return m
end
local function identity(layout,index)
 return {name=layout.layoutName,kind=layout.layoutType,index=index}
end
local function find(m,id)
 for index,layout in pairs(m.layoutInfo.layouts or {}) do
  if layout.layoutName==id.name and layout.layoutType==id.kind then return index end
 end
end
function L.Restore()
 pendingConversion=nil
 if WoWUClassicLayout then return WoWUClassicLayout.Restore()end
 local prior=WoWUDB and WoWUDB.companionPreviousLayout
 if not prior then return end
 if InCombatLockdown() then error("Layout restoration is waiting for combat to end.") end
 local m=managerReady()
 if m:IsShown() then error("Close Edit Mode to restore the previous layout.") end
 local index=find(m,prior)
 if not index then error("The previous layout was renamed or deleted; restore your layout in Edit Mode, then use /wowulayout forget.") end
 C_EditMode.SetActiveLayout(index)
 -- Keep recovery through reload until the native API reports the restored layout.
 C_Timer.After(.25,function()
  if WoWUViewport.active or WoWUDB.companionBridgeTransition or WoWUDB.companionSession then return end
  local ok,info=pcall(C_EditMode.GetLayouts)
  if ok and info.activeLayout==index and WoWUDB.companionPreviousLayout==prior then
   WoWUDB.companionPreviousLayout=nil
   WoWUDB.companionSourceLayout=nil
  end
 end)
end
local function playerKey()
 return UnitGUID("player") or ((UnitName("player") or "Player").."-"..(GetRealmName() or "Realm"))
end
local function resolveDefaults(m,layout)
 for _,system in ipairs(layout.systems or {}) do
  if system.isInDefaultPosition and m.GetRegisteredSystemFrame and m.GetDefaultAnchor then
   local frame=m:GetRegisteredSystemFrame(system.system,system.systemIndex)
   if frame then
    local ok,anchor=pcall(m.GetDefaultAnchor,m,frame)
    if ok and type(anchor)=="table" then system.anchorInfo=copy(anchor) end
   end
  end
 end
 return layout
end
function L.Capture()
 if WoWUClient and WoWUClient.isClassic then
  if WoWUClassicLayout then WoWUClassicLayout.Capture()end
  layoutStatus='Classic normal layout captured; frame repositioning remains disabled.';return
 end
 local m=managerReady()
 if m:IsShown() then error("Save and close Edit Mode before enabling Gamepad Mode.") end
 if m.HasActiveChanges and m:HasActiveChanges() then error("Save your Edit Mode changes before enabling Gamepad Mode.") end
 local info=C_EditMode.GetLayouts()
 local prior=WoWUDB.companionPreviousLayout
 local index=prior and find(m,prior) or info.activeLayout
 local current=index and m.layoutInfo.layouts[index]
 if not current then error("Could not identify the original Edit Mode layout.") end
 if not prior then WoWUDB.companionPreviousLayout=identity(current,index) end
 if not WoWUDB.companionSourceLayout then
  local v=WoWUViewport
  local r=v.active and v.GetGameplayRect() or nil
  WoWUDB.companionSourceLayout={
   layout=resolveDefaults(m,copy(current)),
   width=r and r.right-r.left or UIParent:GetWidth(),
   height=r and r.top-r.bottom or UIParent:GetHeight(),
  }
 end
end
local function anchorFraction(point,horizontal)
 if type(point)~="string" then error("Unrecognised Edit Mode anchor; the original layout has been retained.") end
 if horizontal then
  if point:find("LEFT") then return 0 elseif point:find("RIGHT") then return 1 end
 else
  if point:find("BOTTOM") then return 0 elseif point:find("TOP") then return 1 end
 end
 if point=="CENTER" or point=="TOP" or point=="BOTTOM" or point=="LEFT" or point=="RIGHT" then return .5 end
 error("Unsupported Edit Mode anchor: "..point)
end
local function convert(source,r)
 local target=copy(source.layout)
 local sx=(r.right-r.left)/source.width
 local sy=(r.top-r.bottom)/source.height
 local count=0
 for _,system in ipairs(target.systems or {}) do
  local moved=false
  for _,field in ipairs({"anchorInfo","anchorInfo2"}) do
   local a=system[field]
   if a and a.relativeTo=="UIParent" then
    local fx=anchorFraction(a.relativePoint,true)
    local fy=anchorFraction(a.relativePoint,false)
    a.offsetX=(a.offsetX or 0)*sx+r.left+fx*(r.right-r.left)-fx*UIParent:GetWidth()
    a.offsetY=(a.offsetY or 0)*sy+r.bottom+fy*(r.top-r.bottom)-fy*UIParent:GetHeight()
    moved=true;count=count+1
   end
  end
  -- Links to other native frames follow the converted owner automatically.
  if moved then system.isInDefaultPosition=false end
 end
 if count==0 then error("This layout has no supported screen anchors to convert.") end
 return target,count
end
local function freeName(m)
 local used={};for _,layout in pairs(m.layoutInfo.layouts or {}) do used[layout.layoutName]=true end
 for n=1,99 do
  local name=n==1 and "WoWU Spanned" or "WoWU Spanned "..n
  if not used[name] and (not C_EditMode.IsValidLayoutName or C_EditMode.IsValidLayoutName(name)) then return name end
 end
 error("No free name is available for the WoWU layout copy.")
end
function L.ConvertCurrent(force)
 if WoWUClassicLayout then
  if not WoWUViewport.active then error('Enable Gamepad Mode before applying the Classic HUD layout.')end
  WoWUClassicLayout.Apply();layoutStatus='Classic WoWU Layout selected; frame repositioning remains disabled.';return
 end
 if InCombatLockdown() then error("Convert outside combat.") end
 local v=WoWUViewport
 if not v or not v.active then error("Enable the companion viewport first.") end
 local m=managerReady()
 if m:IsShown() then error("Save and close Edit Mode before converting.") end
 if not WoWUDB.companionPreviousLayout or not WoWUDB.companionSourceLayout then L.Capture() end
 local source=WoWUDB.companionSourceLayout
 local target,count=convert(source,v.GetGameplayRect())
 local types=Enum and Enum.EditModeLayoutType
 if not types or not types.Character then error("This client does not expose character Edit Mode layouts.") end
 WoWUDB.companionManagedLayouts=WoWUDB.companionManagedLayouts or {}
 local key=playerKey()
 local managed=WoWUDB.companionManagedLayouts[key]
 local index=managed and find(m,managed)
 if index and WoWUDB.companionPreviousLayout and index==find(m,WoWUDB.companionPreviousLayout) then error("Select your normal gameplay layout before enabling Gamepad Mode.") end
 local fingerprint
 if C_EditMode.ConvertLayoutInfoToString then
  local ok,value=pcall(C_EditMode.ConvertLayoutInfoToString,source.layout)
  if ok then fingerprint=value end
 end
 local geometry=string.format("%.3f:%.3f:%.3f:%.3f:%.3f:%.3f",source.width,source.height,v.GetGameplayRect().bottom,v.GetGameplayRect().top,UIParent:GetWidth(),UIParent:GetHeight())
 if index and not force and fingerprint and managed.source==fingerprint and managed.geometry==geometry then
  C_EditMode.SetActiveLayout(index);return
 end
 if index then
  -- Refresh only the copy recorded as ours. Never overwrite the source layout.
  local all=copy(m.layoutInfo)
  target.layoutName=all.layouts[index].layoutName
  target.layoutType=all.layouts[index].layoutType
  all.layouts[index]=target
  C_EditMode.SaveLayouts(all)
  if m.UpdateLayoutInfo then m:UpdateLayoutInfo(C_EditMode.GetLayouts()) end
 else
  if not C_EditMode.SaveLayouts then error("This client cannot save an Edit Mode layout.") end
  local countForType=0
  for _,layout in pairs(m.layoutInfo.layouts or {}) do if layout.layoutType==types.Character then countForType=countForType+1 end end
  local limit=Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
  if limit and countForType>=limit then error("Edit Mode has no free character layout slot. Remove an unused layout, then retry.") end
  local name=freeName(m)
  -- Record the reserved free name first so asynchronous native imports
  -- cannot produce another copy on the next deferred attempt.
  WoWUDB.companionManagedLayouts[key]={name=name,kind=types.Character}
  -- Use native layout data directly. ImportLayout depends on private
  -- dropdown bookkeeping that Retail initializes only when Edit Mode opens.
  local all=copy(m.layoutInfo)
  index=1
  for existing in pairs(all.layouts or {}) do
   if type(existing)=="number" and existing>=index then index=existing+1 end
  end
  target.layoutName=name;target.layoutType=types.Character
  all.layouts[index]=target
  C_EditMode.SaveLayouts(all)
  if C_EditMode.OnLayoutAdded then C_EditMode.OnLayoutAdded(index,true,true) end
  if m.UpdateLayoutInfo then m:UpdateLayoutInfo(C_EditMode.GetLayouts()) end
  index=find(m,{name=name,kind=types.Character})
  if not index then error("The converted layout is not ready yet. Use /wowulayout convert to retry.") end
 end
 local result=m.layoutInfo.layouts[index]
 WoWUDB.companionManagedLayouts[key]={name=result.layoutName,kind=result.layoutType,index=index,source=fingerprint,geometry=geometry}
 C_EditMode.SetActiveLayout(index)
 say("Converted "..source.layout.layoutName.." into "..result.layoutName.." ("..count.." screen anchors).")
end
function L.Start()
 if WoWUClient and WoWUClient.isClassic then
  pendingConversion=nil;if WoWUClassicLayout and WoWUClassicLayout.Begin then WoWUClassicLayout.Begin()end
  layoutStatus='Classic uses the saved WoWU Layout; frame repositioning remains disabled.';return
 end
 pendingConversion=true;conversionEnds=GetTime()+30;nextConversion=GetTime()+1
 layoutStatus="Viewport active; waiting for Edit Mode layout conversion."
end
local conversion=CreateFrame("Frame")
conversion:SetScript("OnUpdate",function()
 if not pendingConversion then return end
 if not WoWUViewport.active then pendingConversion=nil;return end
 if GetTime()<nextConversion then return end
 nextConversion=GetTime()+1
 if InCombatLockdown() then
  layoutStatus="Viewport active; layout conversion is waiting for combat to end."
  conversionEnds=GetTime()+30;return
 end
 local ok,err=pcall(L.ConvertCurrent,false)
 if ok then
  pendingConversion=nil;layoutStatus="Spanned layout applied."
 elseif GetTime()>=conversionEnds then
  pendingConversion=nil;layoutStatus="Viewport active; layout conversion failed: "..tostring(err)
  say(layoutStatus.." Use /wowulayout convert to retry.")
 else layoutStatus="Viewport active; layout conversion waiting: "..tostring(err) end
end)
SLASH_WOWULAYOUT1="/wowulayout"
SlashCmdList.WOWULAYOUT=function(input)
 local command=(input or ""):lower()
 if command=="forget" then
  if WoWUViewport.active then say("End companion mode before clearing layout recovery.");return end
  WoWUDB.companionPreviousLayout=nil;WoWUDB.companionSourceLayout=nil
  say("Layout recovery cleared; current layout retained.")
 elseif command=="convert" then
  local ok,err=pcall(L.ConvertCurrent,true);if not ok then layoutStatus="Layout conversion failed: "..tostring(err);say(layoutStatus) else pendingConversion=nil;layoutStatus="Spanned layout applied." end
 else say("/wowulayout convert - refresh the spanned copy from your normal layout. Conversion also happens automatically in Gamepad Mode.") end
end
local recovery=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED"}) do recovery:RegisterEvent(event) end
local recovering=false
recovery:SetScript("OnEvent",function()
 if recovering or not WoWUDB or not WoWUDB.companionPreviousLayout or WoWUDB.companionBridgeTransition or WoWUDB.companionSession or WoWUViewport.active or InCombatLockdown() then return end
 -- Defer until native layout initialization has completed.
 C_Timer.After(0,function()
  if recovering or WoWUViewport.active or WoWUDB.companionBridgeTransition or WoWUDB.companionSession or InCombatLockdown() or not WoWUDB.companionPreviousLayout then return end
  recovering=true
  local ok,err=pcall(L.Restore)
  recovering=false
  if not ok then say("Layout recovery pending: "..tostring(err)) end
 end)
end)
