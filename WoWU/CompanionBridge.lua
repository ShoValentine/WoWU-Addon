WoWUCompanionBridge={}
local B=WoWUCompanionBridge
local waiting,endsAt,lastAttempt
local lastArmedSignal,waitReason,waitNoticeAt
local function reloadUI()
 if C_UI and C_UI.Reload then return C_UI.Reload() end
 return ReloadUI()
end
function B.GetStatus() return waitReason or (WoWUViewport.active and "Companion viewport active." or "Waiting for a Gamepad Mode request.") end
local function config()
 local c=WoWUCompanionConfig
 if not c or c.schema~=1 or not c.expires or GetServerTime()>c.expires then return nil end
 return c
end
local function getCVar(name)
 local get=C_CVar and C_CVar.GetCVar or GetCVar
 return get and get(name)
end
local function setCVar(name,value)
 if value==nil then return end
 local set=C_CVar and C_CVar.SetCVar or SetCVar
 if not set then error("The game does not expose display settings.") end
 set(name,value)
end
local function enterWindowed()
 if not UpdateWindow then error("The game cannot apply display-mode changes automatically.") end
 if not WoWUDB.companionWindowMode then
  local w,h=GetPhysicalScreenSize();local c=config()
  WoWUDB.companionWindowMode={maximize=getCVar("gxMaximize"),window=getCVar("gxWindow"),spanWidth=c and c.width or w,spanHeight=(c and c.height or h)+800}
 end
 setCVar("gxWindow",getCVar("gxWindow") and "1" or nil)
 setCVar("gxMaximize","0")
 UpdateWindow()
 if getCVar("gxMaximize")~="0" then error("The game did not accept Windowed mode.") end
end
local modeRestoreAt,modeNoticeAt
local function restoreWindowedMode()
 local saved=WoWUDB and WoWUDB.companionWindowMode
 if not saved or WoWUViewport.active or WoWUDB.companionBridgeTransition or InCombatLockdown() then return end
 local w,h=GetPhysicalScreenSize()
 -- Let the Assistant restore its window geometry before restoring fullscreen.
 if saved.spanWidth and math.abs(w-saved.spanWidth)<=2 and math.abs(h-saved.spanHeight)<=2 then
  modeRestoreAt=nil;return
 end
 modeRestoreAt=modeRestoreAt or GetTime()+1
 if GetTime()<modeRestoreAt then return end
 local ok,err=pcall(function()
  setCVar("gxWindow",saved.window)
  setCVar("gxMaximize",saved.maximize)
  if not UpdateWindow then error("Use Graphics settings to restore your display mode.") end
  UpdateWindow()
  if saved.maximize and getCVar("gxMaximize")~=saved.maximize then error("The game did not accept the previous display mode.") end
 end)
 if ok then WoWUDB.companionWindowMode=nil;modeRestoreAt=nil
 else
  modeRestoreAt=GetTime()+2
  if not modeNoticeAt or GetTime()>modeNoticeAt then
   modeNoticeAt=GetTime()+15;print("WoWU: Display-mode restoration: "..tostring(err))
  end
 end
end
local function send(phase,id)
 local c
 if phase=="off"then c=(WoWUDB and WoWUDB.companionSession)or WoWUCompanionConfig else c=config()end
 if not c or type(c.token)~="string"or not c.token:match("^[a-f0-9]+$")or #c.token~=32 then return false,"Keep the WoWU Gamepad Assistant running so it can connect automatically, then try Gamepad Mode again." end
 WoWUBridgeSignal=string.format("%s|%d|%s|%d",c.token,id,phase,GetServerTime())
 return true
end
function B.Disable()
 if InCombatLockdown() then return false,"Disable companion mode outside combat." end
 local id=WoWUDB.companionRequestId or 1
 send("off",id)
 waiting=nil
 WoWUDB.companionSession=nil
 WoWUDB.companionResumeSuppressed=true
 WoWUDB.companionBridgeTransition=nil
 WoWUDB.companionReloadStage=nil
 local ok,msg=WoWUViewport.Restore()
 if not ok then return false,msg end
 if WoWU_MainFrame then WoWU_MainFrame:Hide() end
 reloadUI();return true
end
function B.Enable()
 if InCombatLockdown() then return false,"Enable companion mode outside combat." end
 if WoWUViewport.active then return false,"Companion mode is already active." end
 WoWUDB.companionResumeSuppressed=nil
 local ok,err=pcall(WoWUCompanionLayouts.Capture)
 if not ok then return false,tostring(err) end
 WoWUDB.companionBridgeTransition=true
 WoWUDB.companionReloadStage="single"
 local modeOK,modeError=pcall(enterWindowed)
 if not modeOK then
  WoWUDB.companionBridgeTransition=nil;WoWUDB.companionReloadStage=nil
  restoreWindowedMode()
  return false,"Could not switch to Windowed mode: "..tostring(modeError)
 end
 WoWUDB.companionRequestId=(WoWUDB.companionRequestId or 0)+1
 -- The single reload loads the prepared config and flushes the activation
 -- request. The Assistant resizes the window; this session then applies the viewport.
 WoWUBridgeSignal=string.format("%s|%d|activate|%d",string.rep("0",32),WoWUDB.companionRequestId,GetServerTime())
 reloadUI();return true
end
StaticPopupDialogs.WOWU_GAMEPAD_ENABLE={
 text="Would you like to enable WoWU Gamepad Mode?",
 button1="Yes",button2="No",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
 OnAccept=function()local ok,msg=B.Enable();if not ok then print("WoWU: "..tostring(msg)) end end,
}
StaticPopupDialogs.WOWU_GAMEPAD_DISABLE={
 text="Would you like to disable WoWU Gamepad Mode?",
 button1="Yes",button2="No",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
 OnAccept=function()local ok,msg=B.Disable();if not ok then print("WoWU: "..tostring(msg)) end end,
}
function B.PromptEnable()
 if WoWUViewport.active then return false,"Gamepad Mode is already active." end
 if InCombatLockdown() then return false,"Enable Gamepad Mode outside combat." end
 StaticPopup_Show("WOWU_GAMEPAD_ENABLE");return true
end
function B.PromptDisable()
 if InCombatLockdown() then return false,"Disable Gamepad Mode outside combat." end
 StaticPopup_Show("WOWU_GAMEPAD_DISABLE");return true
end
local toggle=CreateFrame("Button","WoWUGamepadToggle",UIParent,"UIPanelButtonTemplate")
toggle:SetSize(150,32);toggle:SetFrameStrata("HIGH")
local dragging,suppressClick=false,false
toggle:SetMovable(true);toggle:SetClampedToScreen(true);toggle:RegisterForDrag("LeftButton")
toggle:SetScript("OnDragStart",function()dragging=true;suppressClick=true;toggle:StartMoving()end)
toggle:SetScript("OnDragStop",function()
 toggle:StopMovingOrSizing();dragging=false
 local r=WoWUViewport.GetGameplayRect() or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
 local x,y=toggle:GetCenter()
 if WoWUDB and x and y then WoWUDB.gamepadButtonPosition={x=(x-r.left)/(r.right-r.left),y=(y-r.bottom)/(r.top-r.bottom)} end
 B.RefreshButton()
 C_Timer.After(.1,function()suppressClick=false end)
end)
toggle:SetScript("OnClick",function()
 if dragging or suppressClick then return end
 local ok,msg
 if WoWUViewport.active then ok,msg=B.PromptDisable() else ok,msg=B.PromptEnable() end
 if not ok then print("WoWU: "..tostring(msg)) end
end)
function B.RefreshButton()
 if dragging then return end
 toggle:SetShown(not (WoWUDB and WoWUDB.hideGamepadToggle))
 toggle:SetText(WoWUViewport.active and "Gamepad Mode: On" or "Gamepad Mode")
 local r=WoWUViewport.GetGameplayRect()
 toggle:ClearAllPoints()
 local pos=WoWUDB and WoWUDB.gamepadButtonPosition
 if pos then
  r=r or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
  local x=math.max(r.left+75,math.min(r.right-75,r.left+pos.x*(r.right-r.left)))
  local y=math.max(r.bottom+16,math.min(r.top-16,r.bottom+pos.y*(r.top-r.bottom)))
  toggle:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
 elseif r then toggle:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",r.right-24,r.top-140)
 else toggle:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-24,-140) end
end
local elapsed=0
toggle:SetScript("OnUpdate",function(_,dt)
 elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0;B.RefreshButton()
end)
B.RefreshButton()
local e=CreateFrame("Frame")
local inWorld,loading=false,false
local stageAtEntry,activationStableAt,lastRenderWidth,lastRenderHeight
local resumeAttempted,reapplyAt,resumeGeometry
local reloadEntry=false
local function sameGeometry(a,b)
 return a and b and a.width==b.width and a.height==b.height and a.left==b.left
end
local function validSession(s)
 if type(s)~="table"then return false end
 for _,key in ipairs({"width","height","left"})do
  local v=s[key];if type(v)~="number"or v~=v or v%1~=0 then return false end
 end
 return s.width>=1280 and s.width<=16384 and s.height>=600 and s.height<=8192 and s.left>=0 and s.left+1280<=s.width
end
local function armViewport()
 if WoWUViewport.active or waiting or not WoWUDB then return end
 local c=config()
 -- Upgrade an already connected installation without requiring another
 -- enable/reload cycle. Require its saved window-mode recovery and exact span.
 if not WoWUDB.companionSession and not WoWUDB.companionResumeSuppressed and not WoWUDB.companionBridgeTransition and WoWUDB.companionWindowMode and c and not (type(WoWUBridgeSignal)=="string"and WoWUBridgeSignal:find("|off|",1,true))then
  local w,h=GetPhysicalScreenSize()
  if math.abs(w-c.width)<=2 and math.abs(h-c.height-800)<=2 then
   WoWUDB.companionSession={width=c.width,height=c.height,left=c.left,token=c.token}
  end
 end
 local session=WoWUDB.companionSession
 if session and not resumeAttempted then
  resumeAttempted=true
  -- The handoff authorizes a NEW Assistant request, not our own local UI layout.
  -- Addon updates can replace its file with the shipped nil stub, and the
  -- handoff expires after two hours. Neither ends an already active viewport.
  -- Reload-only recovery retains the saved span; it never starts streaming,
  -- moves Windows displays or emits a new request to the Assistant.
  local raw=WoWUCompanionConfig
  local savedWindow=WoWUDB.companionWindowMode
  local explicitOff=type(WoWUBridgeSignal)=="string"and WoWUBridgeSignal:find("|off|",1,true)
  local localResume=reloadEntry and not WoWUDB.companionResumeSuppressed and not explicitOff and validSession(session)
   and savedWindow and savedWindow.spanWidth==session.width and savedWindow.spanHeight==session.height+800
   and (not raw or raw.schema~=1 or sameGeometry(raw,session))
  local handoffResume=c and validSession(session)and c.token==session.token and sameGeometry(c,session)
  if not localResume and not handoffResume then
   WoWUDB.companionSession=nil;WoWUDB.companionBridgeTransition=nil;WoWUDB.companionResumeSuppressed=true
   waitReason="The previous companion connection is no longer valid. Keep the Assistant running, then enable Gamepad Mode again."
   print("WoWU: "..waitReason)
   if not InCombatLockdown()then pcall(WoWUCompanionLayouts.Restore)end
   return
  end
  resumeGeometry={width=session.width,height=session.height,left=session.left,token=session.token}
  WoWUDB.companionBridgeTransition=true
  waiting="resume";endsAt=GetTime()+60;lastAttempt=0;waitNoticeAt=GetTime()+5;activationStableAt=nil
  waitReason=localResume and "Restoring the saved companion viewport after /reload."or "Restoring the connected companion viewport after loading."
  return
 end
 if stageAtEntry~="single" and stageAtEntry~="second" then return end
 if waiting or not WoWUDB or not WoWUDB.companionBridgeTransition or type(WoWUBridgeSignal)~="string" or lastArmedSignal==WoWUBridgeSignal then return end
 local token,id,phase,stamp=WoWUBridgeSignal:match("^([^|]+)|(%d+)|([^|]+)|(%d+)$")
 if (phase~="activate" and phase~="confirmed") or not stamp or math.abs(GetServerTime()-tonumber(stamp))>90 then return end
 lastArmedSignal=WoWUBridgeSignal
 local c=config()
 if not c then
  waitReason="The Assistant connection is not ready. Keep the Assistant running, then try Gamepad Mode again."
  print("WoWU: "..waitReason);return
 end
 if token~=c.token and token~=string.rep("0",32) then
  waitReason="The Assistant connection changed during reload. Try Gamepad Mode again."
  print("WoWU: "..waitReason);return
 end
 waiting="confirmed";endsAt=GetTime()+60;lastAttempt=0;waitNoticeAt=GetTime()+5
 waitReason="Waiting for the game window to finish resizing."
end
for _,event in ipairs({"PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED"}) do pcall(e.RegisterEvent,e,event) end
e:SetScript("OnEvent",function(_,event,isInitialLogin,isReloadingUi)
 if event=="LOADING_SCREEN_ENABLED" then loading=true;activationStableAt=nil;return end
 if event=="PLAYER_ENTERING_WORLD" then
  if not inWorld then reloadEntry=isReloadingUi==true end
  inWorld=true
  reapplyAt=GetTime()+1
  if stageAtEntry==nil then stageAtEntry=WoWUDB and WoWUDB.companionReloadStage end
 end
 if event=="LOADING_SCREEN_DISABLED" then loading=false;reapplyAt=GetTime()+1 end
 if inWorld and not loading then B.RefreshButton();armViewport() end
end)
e:SetScript("OnUpdate",function()
 if not inWorld or loading or not UIParent:IsShown() or not WorldFrame:IsShown() then return end
 restoreWindowedMode()
 armViewport()
 if WoWUViewport.active then
  resumeAttempted=false
  if not InCombatLockdown()and ((reapplyAt and GetTime()>=reapplyAt)or WoWUViewport.reapplyPending)then
   local w,h=GetPhysicalScreenSize()
   local ux,uy=UIParent:GetWidth()/w,UIParent:GetHeight()/h
   if ux>0 and uy>0 and math.abs(ux/uy-1)<=.02 and math.abs(w-WoWUViewport.width)<=2 and math.abs(h-WoWUViewport.height-800)<=2 then
    local ok=pcall(WoWUViewport.ApplyUIScale)
    if ok then reapplyAt=nil;WoWUViewport.reapplyPending=nil end
   end
  end
 end
 if not waiting then return end
 if GetTime()>endsAt then
  if waiting=="resume"then WoWUDB.companionSession=nil;WoWUDB.companionBridgeTransition=nil;WoWUDB.companionResumeSuppressed=true;if not InCombatLockdown()then pcall(WoWUCompanionLayouts.Restore)end end
  waiting=nil
  local w,h=GetPhysicalScreenSize()
  print(string.format("WoWU: Connection timed out; game render area is %.0f x %.0f. %s Check the Assistant status before trying again.",w,h,waitReason or "Viewport was not ready."));return
 end
 if GetTime()-lastAttempt<.5 then return end
 if InCombatLockdown() then waitReason="Waiting for combat to end before applying the viewport.";return end
 lastAttempt=GetTime()
 local c=waiting=="resume"and resumeGeometry or config();if not c then
  if waiting=="resume"then
   WoWUDB.companionSession=nil;WoWUDB.companionBridgeTransition=nil;WoWUDB.companionResumeSuppressed=true
   pcall(WoWUCompanionLayouts.Restore)
  end
  waiting=nil;waitReason="Assistant configuration expired during activation. Try Gamepad Mode again.";print("WoWU: "..waitReason);return
 end
 local w,h=GetPhysicalScreenSize()
 if math.abs(w-c.width)>2 or math.abs(h-c.height-800)>2 then
  activationStableAt=nil
  waitReason=string.format("Waiting for render area %d x %d; currently %.0f x %.0f.",c.width,c.height+800,w,h)
  if GetTime()>=waitNoticeAt then print("WoWU: "..waitReason);waitNoticeAt=GetTime()+15 end
  return
 end
 -- Wait for the scaled UI canvas to settle after the window resize.
 local ux,uy=UIParent:GetWidth()/w,UIParent:GetHeight()/h
 if ux<=0 or uy<=0 or math.abs(ux/uy-1)>.02 then
  activationStableAt=nil
  waitReason="Waiting for the UI canvas to match the resized game window."
  if GetTime()>=waitNoticeAt then print("WoWU: "..waitReason);waitNoticeAt=GetTime()+15 end
  return
 end
 if not WoWU_MainFrame then waitReason="Waiting for WoWU to finish loading.";return end
 if lastRenderWidth~=w or lastRenderHeight~=h then activationStableAt=nil end
 lastRenderWidth,lastRenderHeight=w,h
 activationStableAt=activationStableAt or GetTime()
 if GetTime()-activationStableAt<1 then waitReason="Waiting for the resized game window to settle.";return end
 local called,ok,msg=pcall(WoWUViewport.Start,c.width,c.height,c.left)
 if not called then msg=ok;ok=false end
 if not ok then
  waitReason="Viewport activation: "..tostring(msg)
  if GetTime()>=waitNoticeAt then print("WoWU: "..waitReason);waitNoticeAt=GetTime()+15 end
  return
 end
 waiting=nil;waitReason="Companion viewport active."
 WoWUDB.companionBridgeTransition=nil
 WoWUDB.companionReloadStage=nil
 WoWUDB.companionSession={width=c.width,height=c.height,left=c.left,token=c.token}
 WoWUDB.companionResumeSuppressed=nil
 WoWUViewport.Keep()
 print("WoWU: Companion mode connected. Use Settings > Companion Display to disable.")
end)
