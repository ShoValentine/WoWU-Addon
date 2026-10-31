-- Explicit HUD positioning sandbox. Never enumerates arbitrary child frames.
WoWUHUDDebug={}
local D=WoWUHUDDebug
local entries={}
local function combat() return InCombatLockdown and InCombatLockdown() end
local function say(s) print("WoWU HUD: "..s) end
local function rect()
 local r=WoWUViewport and WoWUViewport.GetGameplayRect()
 return r or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
end
local function place(f,x,y)
 local ratio=UIParent:GetEffectiveScale()/f:GetEffectiveScale()
 f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x*ratio,y*ratio)
end
local function center(f)
 local x,y=f:GetCenter();local ratio=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
 if x and y then return x*ratio,y*ratio end
end
local function hideHandles()
 for _,e in ipairs(entries) do if e.handle then e.handle:SetScript("OnUpdate",nil);e.handle:Hide() end end
end
function D.Restore()
 if combat() then return false end
 hideHandles()
 local remaining={}
 for _,e in ipairs(entries) do
  local ok=pcall(function()
   e.frame:ClearAllPoints()
   for _,p in ipairs(e.points) do e.frame:SetPoint(unpack(p)) end
  end)
  if not ok then remaining[#remaining+1]=e end
 end
 entries=remaining
 return #entries==0
end
local function candidates()
 local names={"PlayerFrame","TargetFrame","FocusFrame","PetFrame","TargetFrameToT","FocusFrameToT",
 "MainMenuBar","MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarLeft","MultiBarRight",
 "MultiBar5","MultiBar6","MultiBar7","StanceBar","StanceBarFrame","PetActionBar","PetActionBarFrame",
 "PossessBarFrame","OverrideActionBar","MainMenuBarVehicleLeaveButton","BuffFrame","DebuffFrame",
 "CastingBarFrame","PlayerCastingBarFrame","TargetFrameSpellBar","FocusFrameSpellBar",
 "MirrorTimer1","MirrorTimer2","MirrorTimer3","UIErrorsFrame","RaidWarningFrame","RaidBossEmoteFrame",
 "ObjectiveTrackerFrame","QuestWatchFrame","WatchFrame","CompactRaidFrameContainer","CompactPartyFrame",
 "PartyFrame","PartyMemberFrame1","PartyMemberFrame2","PartyMemberFrame3","PartyMemberFrame4",
 "DurabilityFrame","ZoneTextFrame","SubZoneTextFrame","ExtraActionBarFrame","ZoneAbilityFrame",
 "StatusTrackingBarManager","MainMenuExpBar","ReputationWatchBar","MicroMenuContainer","MicroButtonAndBagsBar","BagsBar"}
 for i=1,10 do names[#names+1]="ChatFrame"..i end
 local list,seen={},{}
 local function add(f)
  if f and not seen[f] and f.GetName and f:GetName() and f.GetNumPoints and f:GetNumPoints()>0 then
   seen[f]=true;list[#list+1]=f
  end
 end
 for _,n in ipairs(names) do add(_G[n]) end
 if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
  for _,f in pairs(EditModeManagerFrame.registeredSystemFrames) do
   -- WoWU owns the docked minimap; it must remain in the companion panel.
   local n=f.GetName and f:GetName() or ""
   if not n:lower():find("minimap") then add(f) end
  end
 end
 local out={}
 for _,f in ipairs(list) do
  local parent=f:GetParent();local nested=false
  while parent and parent~=UIParent do
   if seen[parent] then nested=true;break end
   parent=parent:GetParent()
  end
  if not nested then out[#out+1]=f end
 end
 return out
end
local function handle(e,index)
 local h=CreateFrame("Button",nil,UIParent,"BackdropTemplate");e.handle=h
 h:SetSize(190,24);h:SetFrameStrata("DIALOG");h:EnableMouse(true)
 h:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
 h:SetBackdropColor(.08,.08,.08,.95);h:SetBackdropBorderColor(1,.8,.2,1)
 local t=h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");t:SetAllPoints();t:SetText(e.frame:GetName())
 local function follow()h:ClearAllPoints();h:SetPoint("CENTER",e.frame,"CENTER")end
 follow();h:RegisterForDrag("LeftButton")
 h:SetScript("OnDragStart",function()
  if combat() then return end
  local cx,cy=GetCursorPosition();local fx,fy=center(e.frame)
  if not fx then return end
  local scale=UIParent:GetEffectiveScale();local dx,dy=fx-cx/scale,fy-cy/scale
  h:SetScript("OnUpdate",function()
   if combat() then hideHandles();return end
   local x,y=GetCursorPosition();local r=rect()
   x=math.max(r.left,math.min(r.right,x/UIParent:GetEffectiveScale()+dx))
   y=math.max(r.bottom,math.min(r.top,y/UIParent:GetEffectiveScale()+dy))
   local ok=pcall(place,e.frame,x,y)
   if not ok then h:SetScript("OnUpdate",nil);say("Cannot move "..e.frame:GetName());return end
   follow()
  end)
 end)
 h:SetScript("OnDragStop",function()h:SetScript("OnUpdate",nil)end)
end
local function begin(load)
 if combat() then say("Use this outside combat.");return end
 local layout=WoWUDB and WoWUDB.hudDebugLayout
 if load and not layout then say("No saved layout yet.");return end
 if not D.Restore() then say("Some frames could not be restored; reload before trying again.");return end
 local r=rect();local count,failed=0,0
 for _,f in ipairs(candidates()) do
  local n=f:GetName();local pos=load and layout[n]
  if (load and pos) or (not load and f:IsShown()) then
   local e={frame=f,points={}}
   for i=1,f:GetNumPoints() do e.points[i]={f:GetPoint(i)} end
   entries[#entries+1]=e
   local x,y
   if pos then x=r.left+pos.x*(r.right-r.left);y=r.bottom+pos.y*(r.top-r.bottom)
   else
    -- Stagger near the centre so each drag handle remains reachable.
    x=(r.left+r.right)/2+((count%3)-1)*205
    y=(r.bottom+r.top)/2+(math.floor(count/3)-4)*30
   end
   local ok=pcall(place,f,x,y)
   if ok then count=count+1;handle(e,count) else failed=failed+1 end
  end
 end
 say(count.." HUD elements positioned. Drag their named handles; /wowuhud save or /wowuhud restore. Skipped failures: "..failed)
end
SLASH_WOWUHUD1="/wowuhud"
SlashCmdList.WOWUHUD=function(input)
 local cmd=(input or ""):lower():match("^%s*(%S+)")
 if cmd=="center" then begin(false)
 elseif cmd=="load" then begin(true)
 elseif cmd=="restore" then say(D.Restore() and "Original positions restored. Saved layout retained." or "Restore outside combat; reload if restoration fails.")
 elseif cmd=="save" then
  if combat() then say("Save outside combat.");return end
  if #entries==0 then say("Use /wowuhud center or load first.");return end
  local r=rect();local layout={}
  for _,e in ipairs(entries) do
   local x,y=center(e.frame)
   if x and y then layout[e.frame:GetName()]={x=(x-r.left)/(r.right-r.left),y=(y-r.bottom)/(r.top-r.bottom)} end
  end
  WoWUDB.hudDebugLayout=layout;hideHandles();say("Layout saved for this character. /wowuhud load reapplies it and shows drag handles.")
 else say("/wowuhud center, save, load, restore. Visible HUD elements only; hidden elements stay hidden. Native layout managers may reposition some frames.") end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_LOGOUT","DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
 if event=="PLAYER_REGEN_DISABLED" then hideHandles() else D.Restore() end
end)
