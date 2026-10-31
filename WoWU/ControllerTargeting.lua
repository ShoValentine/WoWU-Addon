-- Native mouse emulation is temporary and belongs only to the targeting ring.
-- Cursor positioning is requested from the spell's hardware PostClick, never a timer.
WoWUControllerTargeting={}
local T=WoWUControllerTargeting
local aiming,positioned,manualCursor,previousCursor=false,false,false,false
local warning
local function cursor(enabled)if SetGamePadCursorControl then pcall(SetGamePadCursorControl,enabled)end end
local function cvar(name,value)
 local get=C_CVar and C_CVar.GetCVar or GetCVar;local set=C_CVar and C_CVar.SetCVar or SetCVar
 if get and set and get(name)~=nil and get(name)~=value then pcall(set,name,value)end
end
local function ground()
 return WoWUController.active and SpellIsTargeting and SpellIsTargeting()
  and not((SpellCanTargetItem and SpellCanTargetItem())or(SpellCanTargetItemID and SpellCanTargetItemID()))
end
local function faceHeld()
 if not C_GamePad or not C_GamePad.GetDeviceMappedState or not C_GamePad.ButtonBindingToIndex or not C_GamePad.GetActiveDeviceID then return false end
 local ok,state=pcall(C_GamePad.GetDeviceMappedState,C_GamePad.GetActiveDeviceID())
 if not ok or not state or not state.buttons then return false end
 for _,key in ipairs({'PAD1','PAD2'})do
  local i=C_GamePad.ButtonBindingToIndex(key)
  if i and state.buttons[state.buttons[0]~=nil and i or i+1]then return true end
 end
 return false
end
local function restore()
 aiming=false;positioned=false;warning=nil;manualCursor=previousCursor
 cvar('GamePadCursorLeftClick',manualCursor and 'PAD1'or 'none')
 cvar('GamePadCursorRightClick',manualCursor and 'PAD3'or 'none')
 cursor(manualCursor)
end
function T.Sync(hardware)
 if WoWUFishing and WoWUFishing.active then return end
 local active=ground()
 if active and not aiming then
  aiming=true;positioned=false;warning=nil;previousCursor=manualCursor
  cvar('GamePadCursorLeftClick','PAD1');cvar('GamePadCursorRightClick','PAD2')
  cvar('GamePadCursorCentering','0');cursor(true)
 elseif not active and aiming and not faceHeld()then restore()end
 if active then
  if IsGamePadCursorControlEnabled and not IsGamePadCursorControlEnabled()then cursor(true)end
  if hardware and not positioned and SetCursorPosition then
   local r=WoWUViewport and WoWUViewport.GetGameplayRect()
   r=r or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
   local ok,err=pcall(SetCursorPosition,(r.left+r.right)/2,(r.bottom+r.top)/2)
   if ok then positioned=true else T.lastError=tostring(err);warning='Aim with the right stick; automatic centering was unavailable.'end
  end
 end
end
function T.ToggleCursor()
 if WoWUFishing and WoWUFishing.active then return end
 if aiming then return end
 manualCursor=not(IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled())
 cvar('GamePadCursorLeftClick',manualCursor and 'PAD1'or 'none')
 cvar('GamePadCursorRightClick',manualCursor and 'PAD3'or 'none');cursor(manualCursor)
end
function T.LeaveCursor()
 if WoWUFishing and WoWUFishing.active then return end
 if aiming then return end
 manualCursor=false;cursor(false);cvar('GamePadCursorLeftClick','none');cvar('GamePadCursorRightClick','none')
end
function T.Status()
 if not ground()then return end
 return warning or 'Ground targeting: right stick aims  |  A left-clicks  |  B right-clicks / cancels'
end
function T.Reset()
 aiming=false;positioned=false;manualCursor=false;previousCursor=false;warning=nil;cursor(false)
end
function T.Initialize()end -- Kept for the controller's initialization contract.
local watcher=CreateFrame('Frame');local elapsed=0
watcher:RegisterEvent('CURSOR_CHANGED');watcher:SetScript('OnEvent',function()T.Sync(false)end)
watcher:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed<.02 then return end;elapsed=0;T.Sync(false)end)
