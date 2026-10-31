-- Dashboard widget implementations. Layout and edit controls live in DashboardLayout.lua.
local function font(p,size,color)
 local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
 WoWU_Theme.TextColor(t,unpack(color or {.93,.80,.55}))
 t:SetJustifyH("LEFT")
 return t
end
local function frame(p)
 local f=CreateFrame("Frame",nil,p,"BackdropTemplate")
 WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=18,insets={left=4,right=4,top=4,bottom=4}})
 WoWU_Theme.Color(f,.11,.15,.18,.97);WoWU_Theme.Panel(f)
 return f
end
local function button(p,text,w,h,fn)
 local b=CreateFrame("Button",nil,p,"BackdropTemplate")
 b:SetSize(w,h);WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13,insets={left=3,right=3,top=3,bottom=3}})
 WoWU_Theme.Color(b,.27,.23,.17,1);WoWU_Theme.Border(b,.62,.48,.29,1)
 local t=font(b,14);t:SetPoint("CENTER");t:SetText(text)
 b:SetScript("OnClick",fn);return b
end
local function characterKey() return (UnitGUID and UnitGUID("player")) or ((UnitName("player") or "player").."-"..(GetRealmName and GetRealmName() or "realm")) end
function WoWU_AddShortcut(kind,id,name,icon,options)
 if not WoWUDB then return false end
 local key=characterKey()
 local list=WoWUDashboardLayout.Shortcuts(key)
 if kind~="item" and kind~="spell" then return false end
 if not id then return false end
 for _,e in ipairs(list) do if e.kind==kind and e.id==id then
  if options and options.mountID then e.mountID=options.mountID end
  if WoWU_RefreshDashboard then WoWU_RefreshDashboard()end;return true
 end end
 if #list>=WoWUDashboardLayout.QuickLimit() then return false end
 list[#list+1]={kind=kind,id=id,name=name,icon=icon,mountID=options and options.mountID}
 if WoWU_RefreshDashboard then WoWU_RefreshDashboard() end
 return true
end
local panel, holder, mini, previous, active = nil,nil,nil,nil,false
local trackingHost,trackingFrame,trackingPrevious,calendarHost
local clockHost,clockFrame,clockPrevious
local nativeRestorePending=false
local function locked() return InCombatLockdown and InCombatLockdown() end
-- Dedicated opaque square mask: do not rely on the default circular alpha mask.
local SQUARE_MASK = "Interface\\AddOns\\WoWU\\Textures\\SquareMask"
local DEFAULT_MASK = "Textures\\MinimapMask"
local hiddenDecorations = {}
local function hideDecoration(obj)
 if not obj then return end
 if not hiddenDecorations[obj] then hiddenDecorations[obj]={shown=obj:IsShown(),alpha=obj:GetAlpha()}end
 obj:SetAlpha(0)
 obj:Hide()
end
local function hideMinimapShell()
 -- The map and native controls are reparented before hiding the old shell.
 hideDecoration(MinimapBackdrop)
 if MinimapCluster and MinimapCluster.GetRegions then
  for _,region in ipairs({MinimapCluster:GetRegions()})do hideDecoration(region)end
 end
 for _,owner in pairs({MinimapCluster})do
  for _,key in ipairs({"Background","BorderTop","Backdrop","ZoneTextButton"})do hideDecoration(owner[key])end
 end
end
local function hideNativeZoom()
 if locked() or not Minimap then return end
 local controls={Minimap.ZoomIn or MinimapZoomIn,Minimap.ZoomOut or MinimapZoomOut}
 for _,control in pairs(controls) do
  if control and not (control.IsProtected and control:IsProtected()) then
   hideDecoration(control);control:Hide()
  end
 end
end
local function WoWU_StyleMinimap(mini)
 if not mini then return end
 hideNativeZoom();hideMinimapShell()
 -- A square mask is the essential part. The supplied Leatrix effects module
 -- provides perimeter effects, but does not itself configure the map mask.
 if mini.SetMaskTexture then mini:SetMaskTexture(SQUARE_MASK) end
 local names={
  "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapCompassTextureUnderlay",
  "MinimapNorthTag"
 }
 for _,name in ipairs(names) do hideDecoration(_G[name]) end
 hideDecoration(MinimapZoneTextButton)
 hideDecoration(MinimapZoneText)
 hideDecoration(MinimapCluster and MinimapCluster.ZoneTextButton)
 for _,control in pairs({MiniMapWorldMapButton,MinimapToggleButton,Minimap.CloseButton,Minimap.WorldMapButton})do hideDecoration(control)end
end
local function WoWU_RestoreMinimapStyle(mini)
 if previous and mini and mini.SetMaskTexture then mini:SetMaskTexture(previous.mask or DEFAULT_MASK) end
 for obj,state in pairs(hiddenDecorations) do
  obj:SetAlpha(state.alpha)
  if state.shown then obj:Show() else obj:Hide() end
  hiddenDecorations[obj]=nil
 end
end
local function snapshot(f)
 local s={parent=f:GetParent(),w=f:GetWidth(),h=f:GetHeight(),scale=f:GetScale(),alpha=f:GetAlpha(),strata=f:GetFrameStrata(),level=f:GetFrameLevel(),shown=f:IsShown(),points={}}
 for i=1,f:GetNumPoints()do s.points[i]={f:GetPoint(i)}end
 return s
end
local function restore(f,s)
 if not f or not s then return end
 f:SetParent(s.parent);f:SetScale(s.scale);f:SetSize(s.w,s.h);f:ClearAllPoints()
 for _,point in ipairs(s.points)do f:SetPoint(unpack(point))end
 f:SetAlpha(s.alpha);f:SetFrameStrata(s.strata);f:SetFrameLevel(s.level)
 f:SetShown(s.shown)
end
-- Switching pages hides the Dashboard's frame tree. Keep the map and its
-- satellites there so neither the map nor its restored decorations leak onto
-- the gameplay display. Only ending companion mode restores native placement.
function WoWU_DashboardExit()
 if not (WoWUViewport and WoWUViewport.active)or(WoWU_GetMinimapLocation and WoWU_GetMinimapLocation()=="main")then WoWU_RestoreNativeMinimap()end
end
function WoWU_RestoreNativeMinimap()
 if locked()then nativeRestorePending=true;return false end
 nativeRestorePending=false
 if WoWU_RestoreAddonMenu then WoWU_RestoreAddonMenu()end
 if WoWUMinimapControls then WoWUMinimapControls.Restore()end
 if trackingFrame and trackingPrevious then restore(trackingFrame,trackingPrevious)end
 trackingFrame,trackingPrevious=nil,nil
 -- Also unwind partial acquisitions; decorations can be hidden before docking
 -- has finished. Restore the original mask rather than imposing a client default.
 WoWU_RestoreMinimapStyle(mini)
 if mini and previous then
  restore(mini,previous)
  if previous.mask and mini.SetMaskTexture then mini:SetMaskTexture(previous.mask)end
 end
 if clockFrame and clockPrevious then restore(clockFrame,clockPrevious)end
 clockFrame,clockPrevious=nil,nil
 active=false;previous=nil
 if WoWU_RefreshAddonMenu then WoWU_RefreshAddonMenu()end
 return true
end
local function dockClock()
 local f=TimeManagerClockButton or (MinimapCluster and MinimapCluster.Clock)
 if locked()or not clockHost or not f or (f.IsProtected and f:IsProtected())then return end
 if not clockPrevious then clockFrame=f;clockPrevious=snapshot(f)end
 local scale=math.min(math.max(16,clockHost:GetWidth()-4)/math.max(1,f:GetWidth()),math.max(16,clockHost:GetHeight()-4)/math.max(1,f:GetHeight()))
 local _,relative=f:GetPoint(1)
 if f:GetParent()~=clockHost or relative~=clockHost or f:GetScale()~=scale then
  f:SetParent(clockHost);f:SetScale(scale);f:ClearAllPoints();f:SetPoint("CENTER",clockHost,"CENTER",0,0)
 end
 f:Show()
end
local function dockTracking()
 if locked() or not trackingHost then return end
 local f=MiniMapTracking or (MinimapCluster and MinimapCluster.Tracking) or MiniMapTrackingButton
 if not f or (f.IsProtected and f:IsProtected())then return end
 local _,relative=f:GetPoint(1)
 local scale=math.min(1,trackingHost:GetWidth()/math.max(1,f:GetWidth(),f:GetHeight()))
 if f==trackingFrame and f:GetParent()==trackingHost and relative==trackingHost and f:GetScale()==scale then return end
 if not trackingPrevious then trackingPrevious=snapshot(f);trackingFrame=f end
 f:SetParent(trackingHost);f:ClearAllPoints();f:SetPoint("CENTER")
 f:SetScale(scale);f:Show()
end
function WoWU_DashboardEnter()
 local companion=WoWUViewport and WoWUViewport.active
 if WoWU_GetMinimapLocation and WoWU_GetMinimapLocation()=="main"then
  WoWU_RestoreNativeMinimap();return
 end
 -- IsShown can be true while the dashboard's parent is hidden, especially at
 -- construction. Only the active viewport may own Blizzard's minimap.
 if not companion then
  if active or previous or next(hiddenDecorations)then WoWU_RestoreNativeMinimap()end
  return
 end
 if not panel or not holder or not Minimap then return end
 if locked() then return end
 nativeRestorePending=false
 if active and mini==Minimap then
  mini:SetSize(math.max(40,holder:GetWidth()-20),math.max(40,holder:GetHeight()-20))
  if holder.WoWUZoneOverlay then holder.WoWUZoneOverlay:SetFrameStrata(mini:GetFrameStrata());holder.WoWUZoneOverlay:SetFrameLevel(mini:GetFrameLevel()+60)end
  dockClock();dockTracking();WoWUMinimapControls.Dock(holder,calendarHost);return
 end
 mini=Minimap
 if mini.IsProtected and mini:IsProtected() then
  -- A protected Blizzard frame should not be force-reparented.
  return
 end
 previous=snapshot(mini)
 previous.mask=mini.GetMaskTexture and mini:GetMaskTexture()
 dockClock()
 local ok=pcall(function()
  mini:SetParent(holder)
  mini:ClearAllPoints();mini:SetPoint("CENTER",holder,"CENTER",0,0)
  mini:SetScale(1);mini:SetSize(math.max(40,holder:GetWidth()-20),math.max(40,holder:GetHeight()-20));WoWU_StyleMinimap(mini);mini:Show()
  if holder.WoWUZoneOverlay then holder.WoWUZoneOverlay:SetFrameStrata(mini:GetFrameStrata());holder.WoWUZoneOverlay:SetFrameLevel(mini:GetFrameLevel()+60)end
 end)
 if ok then active=true;dockClock();dockTracking();WoWUMinimapControls.Dock(holder,calendarHost)
  if WoWU_RefreshAddonMenu then WoWU_RefreshAddonMenu()end
 else
  if previous then pcall(restore,mini,previous) end
  WoWU_RestoreMinimapStyle(mini)
  if previous and previous.mask and mini.SetMaskTexture then mini:SetMaskTexture(previous.mask)end
  if clockFrame and clockPrevious then restore(clockFrame,clockPrevious)end
  clockFrame,clockPrevious=nil,nil
  previous=nil
 end
end
local function buildTrackingMenu(parent,host)
 local popup=frame(parent);popup:SetFrameStrata("FULLSCREEN_DIALOG");popup:SetFrameLevel(parent:GetFrameLevel()+350);popup:EnableMouse(true);popup:Hide()
 local heading=font(popup,22);heading:SetPoint("TOPLEFT",20,-20);heading:SetText("Minimap Tracking")
 local close=CreateFrame("Button",nil,popup,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",function()popup:Hide()end)
 local scroll=CreateFrame("ScrollFrame",nil,popup,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",16,-65);scroll:SetPoint("BOTTOMRIGHT",-32,18)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(360,1);scroll:SetScrollChild(body);WoWU_EnableTouchScroll(scroll)
 local empty=font(body,17);empty:SetPoint("TOPLEFT",8,-8);empty:SetWidth(330)
 local rows={};local render
 local function read(index)
  local fn=C_Minimap and C_Minimap.GetTrackingInfo or GetTrackingInfo
  if type(fn)~="function"then return end
  local ok,name,texture,active=pcall(fn,index);if not ok then return end
  if type(name)=="table"then return name end
  if name then return {name=name,texture=texture,active=active==true or active==1}end
 end
 render=function()
  if not popup:IsShown()then return end
  local get=C_Minimap and C_Minimap.GetNumTrackingTypes or GetNumTrackingTypes
  local ok,count=false,0;if type(get)=="function"then ok,count=pcall(get)end
  count=ok and tonumber(count)or 0;local n=0;local width=math.max(100,scroll:GetWidth())
  body:SetWidth(width)
  for index=1,count or 0 do
   local entry=read(index)
   if entry and entry.name then
    n=n+1;local row=rows[n]
    if not row then
     row=CreateFrame("Button",nil,body,"BackdropTemplate");rows[n]=row;WoWU_Theme.Panel(row);WoWU_Theme.Button(row)
     row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.check:SetSize(30,30);row.check:SetPoint("LEFT",4,0);row.check:EnableMouse(false)
     row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(30,30);row.icon:SetPoint("LEFT",38,0)
     row.label=font(row,17);row.label:SetPoint("LEFT",77,0);row.label:SetPoint("RIGHT",-8,0);row.label:SetWordWrap(true)
     row:SetScript("OnClick",function(self)
      if locked()or not WoWU_TouchTapAllowed(scroll)then return end
      local current=read(self.index);local set=C_Minimap and C_Minimap.SetTracking or SetTracking
      if current and type(set)=="function"then
       local on=current.active==true or current.active==1
       local success=pcall(set,self.index,not on)
       if success then render()end
      end
     end)
    end
    row.index=index;row:SetSize(width,52);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(n-1)*57)
    row.icon:SetTexture(entry.texture);row.label:SetText(entry.name);row.check:SetChecked(entry.active==true or entry.active==1);row:SetEnabled(not locked());row:Show()
   end
  end
  for i=n+1,#rows do rows[i]:Hide()end
  empty:SetText(n==0 and "No tracking options are available."or "");empty:SetShown(n==0)
  body:SetHeight(math.max(60,n*57))
 end
 local toggle=CreateFrame("Button",nil,host);toggle:SetAllPoints();toggle:SetFrameLevel(host:GetFrameLevel()+100);toggle:RegisterForClicks("AnyUp")
 toggle:SetScript("OnClick",function()
  if popup:IsShown()then popup:Hide();return end
  if locked()then return end
  if CloseDropDownMenus then CloseDropDownMenus()end
  popup:SetSize(math.min(440,parent:GetWidth()-40),math.min(520,parent:GetHeight()-90))
  popup:ClearAllPoints();popup:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-20,-55);popup:Show();scroll:SetVerticalScroll(0);render()
 end)
 parent:HookScript("OnHide",function()popup:Hide()end);host:HookScript("OnHide",function()popup:Hide()end)
 scroll:HookScript("OnSizeChanged",function()if popup:IsShown()then render()end end)
 local events=CreateFrame("Frame",nil,popup)
 for _,event in ipairs({"MINIMAP_UPDATE_TRACKING","SPELLS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"})do pcall(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function()if popup:IsShown()then render()end end)
end
function WoWU_BuildDashboard(parent)
 local keyboardButton,keyboard=WoWU_BuildDashboardKeyboard(parent)
 panel=parent
 local quests=frame(parent);quests:SetPoint("TOPLEFT",12,-12);quests:SetSize(297,529)
 local middle=CreateFrame("Frame",nil,parent);middle:SetPoint("TOPLEFT",quests,"TOPRIGHT",8,0);middle:SetSize(550,505)
 local quick=frame(parent);quick:SetPoint("TOPLEFT",middle,"TOPRIGHT",8,0);quick:SetSize(304,529)
 local qtitle=font(quests,20);qtitle:SetPoint("TOP",quests,"TOP",0,-15);qtitle:SetText("Tracked Quests");qtitle:SetDrawLayer("OVERLAY",7)
 local trackerHost=CreateFrame("Frame",nil,quests)
 trackerHost:SetPoint("TOPLEFT",quests,"TOPLEFT",13,-1)
 trackerHost:SetPoint("BOTTOMRIGHT",quests,"BOTTOMRIGHT",-13,13)
 trackerHost:SetFrameLevel(quests:GetFrameLevel())
 local trackerDocked=false
 local nativeTracker
 local function dockTracker()
  if not nativeTracker then nativeTracker=WoWU_BuildQuestTracker(trackerHost) end
  trackerDocked=true
  nativeTracker.Refresh()
 end
 holder=frame(middle);holder:SetSize(414,414);holder:SetPoint("CENTER",middle,"CENTER",0,12)
 local zoneOverlay=CreateFrame('Frame',nil,holder);holder.WoWUZoneOverlay=zoneOverlay
 zoneOverlay:SetPoint('TOPLEFT',10,-10);zoneOverlay:SetPoint('TOPRIGHT',-10,-10);zoneOverlay:SetHeight(30);zoneOverlay:EnableMouse(false)
 local zoneShade=zoneOverlay:CreateTexture(nil,'BACKGROUND');zoneShade:SetAllPoints();zoneShade:SetColorTexture(0,0,0,.38)
 local location=font(zoneOverlay,19);location:SetPoint('TOPLEFT',6,-4);location:SetPoint('BOTTOMRIGHT',-6,4);location:SetJustifyH('CENTER');location:SetJustifyV('MIDDLE');location:SetWordWrap(false);location:SetText('Azeroth')
 location:SetShadowColor(0,0,0,1);location:SetShadowOffset(1,-1)
 trackingHost=CreateFrame("Frame",nil,middle);trackingHost:SetSize(44,44);trackingHost:SetPoint("LEFT",holder,"RIGHT",8,75)
 calendarHost=CreateFrame("Frame",nil,middle);calendarHost:SetSize(44,44);calendarHost:SetPoint("BOTTOM",trackingHost,"TOP",0,6)
 buildTrackingMenu(parent,trackingHost)
 local controlsWidget=frame(parent)
 clockHost=CreateFrame("Frame",nil,controlsWidget);clockHost:SetSize(44,44)
 local zoomButtons={}
 local function refreshZoom()
  local available=WoWUViewport and WoWUViewport.active and active and Minimap and Minimap:GetParent()==holder and Minimap.GetZoom and Minimap.GetZoomLevels and Minimap.SetZoom
  if available then hideNativeZoom() end
  if available and not locked() then
   hideMinimapShell();dockClock();dockTracking()
   WoWUMinimapControls.Dock(holder,calendarHost)
   for _,control in pairs({MiniMapWorldMapButton,MinimapToggleButton,Minimap.CloseButton,Minimap.WorldMapButton})do hideDecoration(control)end
   hideDecoration(MinimapZoneTextButton);hideDecoration(MinimapZoneText)
   hideDecoration(MinimapCluster and MinimapCluster.ZoneTextButton)
   if Minimap.GetMaskTexture and Minimap:GetMaskTexture()~=SQUARE_MASK then WoWU_StyleMinimap(Minimap)end
  end
  local zoom=available and Minimap:GetZoom() or 0
  local maximum=available and math.max(0,Minimap:GetZoomLevels()-1) or 0
  for _,b in ipairs(zoomButtons) do
   local canZoom=available and (b.delta>0 and zoom<maximum or b.delta<0 and zoom>0)
   b:SetEnabled(canZoom and true or false);b:SetAlpha(canZoom and 1 or .4)
  end
 end
 for i,entry in ipairs({{1,"+","Zoom in"},{-1,"-","Zoom out"}}) do
  local delta=entry[1]
  local b=CreateFrame("Button",nil,middle,"BackdropTemplate")
  b:SetSize(44,44);b:SetPoint("LEFT",holder,"RIGHT",8,i==1 and 25 or -25)
  b.delta=delta;b.label=font(b,25);b.label:SetPoint("CENTER",0,1);b.label:SetText(entry[2])
  WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)
  b:SetScript("OnClick",function()
   if not active or not Minimap or Minimap:GetParent()~=holder then return end
   if not Minimap.GetZoom or not Minimap.GetZoomLevels or not Minimap.SetZoom then return end
   local maximum=math.max(0,Minimap:GetZoomLevels()-1)
   Minimap:SetZoom(math.max(0,math.min(maximum,Minimap:GetZoom()+delta)))
   refreshZoom()
  end)
  local caption=entry[3]
  b:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(caption);GameTooltip:Show() end end)
  b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  zoomButtons[#zoomButtons+1]=b
 end
 local zoomElapsed=0
 controlsWidget:HookScript("OnUpdate",function(_,dt) zoomElapsed=zoomElapsed+dt;if zoomElapsed>=.25 then zoomElapsed=0;refreshZoom() end end)
 refreshZoom()
 local addonToggle
 if WoWU_BuildAddonMenu then addonToggle=WoWU_BuildAddonMenu(parent,middle,holder) end
 for _,control in ipairs({calendarHost,trackingHost,zoomButtons[1],zoomButtons[2],clockHost,addonToggle})do control:SetParent(controlsWidget)end
 local fallback=font(holder,16,{.8,.72,.58});fallback:SetPoint("CENTER");fallback:SetText("Native minimap unavailable\nor protected by the client")
 fallback:SetJustifyH("CENTER")
 local notification,adventureView=WoWU_BuildAdventure(parent,middle,holder)
 -- Inventory counts are read from bags, not character storage or bank.
 local function itemCount(id)
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return nil end
  local total=0
  for bag=0,WoWUClient.LastBag() do
   local slots=C_Container.GetContainerNumSlots(bag) or 0
   for slot=1,slots do
    local info=C_Container.GetContainerItemInfo(bag,slot)
    if info and info.itemID==id then total=total+(info.stackCount or 1) end
   end
  end
  return total
 end
 local function spellKnown(id)
  if IsSpellKnown then
   local ok,known=pcall(IsSpellKnown,id)
   if ok then return known end
  end
  if IsPlayerSpell then
   local ok,known=pcall(IsPlayerSpell,id)
   if ok then return known end
  end
  return nil -- Missing API: preserve shortcut instead of guessing.
 end
 local quickScroll=CreateFrame("ScrollFrame",nil,quick,"UIPanelScrollFrameTemplate")
 quickScroll:SetPoint("TOPLEFT",14,-14);quickScroll:SetPoint("BOTTOMRIGHT",-32,12)
 local quickBody=CreateFrame("Frame",nil,quickScroll);quickBody:SetSize(240,1);quickScroll:SetScrollChild(quickBody)
 WoWU_EnableTouchScroll(quickScroll)
 quickScroll:SetScript("OnMouseWheel",function(self,delta)
  if locked()then return end
  self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScroll()-delta*55,math.max(0,quickBody:GetHeight()-self:GetHeight()))))
 end)
 local cells={}
 for i=1,20 do
  local ix=i
  local b=CreateFrame("Button",nil,quickBody,"SecureActionButtonTemplate,BackdropTemplate")
  b:SetSize(110,98);b:SetPoint("TOPLEFT",quick,"TOPLEFT",34+((i-1)%2)*126,-103-math.floor((i-1)/2)*105)
  WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13,insets={left=3,right=3,top=3,bottom=3}})
  WoWU_Theme.Color(b,.20,.24,.25,1);WoWU_Theme.Border(b,.56,.44,.28,1)
  b:RegisterForClicks("AnyDown","AnyUp")
  b:SetAttribute("useOnKeyDown",false)
  local texture=b:CreateTexture(nil,"ARTWORK",nil,2);texture:SetSize(44,44);texture:SetPoint("TOP",0,-8)
  local empty=b:CreateTexture(nil,"ARTWORK",nil,1);empty:SetTexture(WoWU_Theme.assets.slot);empty:SetTexCoord(0,41/64,0,41/64);empty:SetSize(44,44);empty:SetPoint("CENTER",texture,"CENTER")
  b.rim=WoWU_Theme.IconRim(b,texture,56)
  local emptyMark=font(b,24,{.9,.75,.43});emptyMark:SetPoint("CENTER",texture,"CENTER");emptyMark:SetText("+")
  b.emptyArtwork=empty;b.emptyMark=emptyMark
  local label=font(b,12,{.94,.88,.72});label:SetPoint("BOTTOM",0,6);label:SetWidth(100);label:SetHeight(28);label:SetWordWrap(true);label:SetJustifyH("CENTER")
  local count=font(b,15,{1,1,1})
  count:SetPoint("BOTTOMRIGHT",texture,"BOTTOMRIGHT",1,-1)
  count:SetJustifyH("RIGHT")
  count:SetShadowColor(0,0,0,1);count:SetShadowOffset(1,-1)
  b.icon=texture;b.text=label;b.count=count
  -- Removing a shortcut is a deliberate Shift-click outside combat.
  b:SetScript("PreClick",function(self,_,down)
   if not down and not locked() and not WoWU_TouchTapAllowed(quickScroll)then
    self.suppressedType=self:GetAttribute("type");self:SetAttribute("type",nil)
   end
  end)
  b:SetScript("PostClick",function(self,_,down)
   if self.suppressedType and not locked()then
    self:SetAttribute("type",self.suppressedType);self.suppressedType=nil
   end
   if down or not WoWU_TouchTapAllowed(quickScroll)then return end
   if not IsShiftKeyDown() or locked() then return end
   local list=WoWUDashboardLayout.Shortcuts(characterKey())
   if list and list[ix] then table.remove(list,ix);if WoWU_RefreshDashboard then WoWU_RefreshDashboard() end end
  end)
  WoWUQuickAccess.AttachGrid(b,i,quickScroll)
  cells[i]=b
 end
 local foot=frame(parent);foot:SetPoint("TOPLEFT",quests,"BOTTOMLEFT",0,-10);foot:SetPoint("TOPRIGHT",quick,"BOTTOMRIGHT",0,-10);foot:SetHeight(60)
 local xpBarBack=CreateFrame("Frame",nil,foot,"BackdropTemplate")
 xpBarBack:SetPoint("TOPLEFT",foot,"TOPLEFT",15,-17);xpBarBack:SetPoint("TOPRIGHT",foot,"TOPRIGHT",-15,-17);xpBarBack:SetHeight(24)
 WoWU_Theme.Backdrop(xpBarBack,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
 WoWU_Theme.Color(xpBarBack,.09,.08,.16,.95);WoWU_Theme.Border(xpBarBack,.83,.68,.40,1)
 local xpBar=CreateFrame("StatusBar",nil,foot);xpBar:SetPoint("TOPLEFT",xpBarBack,"TOPLEFT",4,-4);xpBar:SetPoint("BOTTOMRIGHT",xpBarBack,"BOTTOMRIGHT",-4,4);xpBar:SetStatusBarTexture(WoWU_Theme.assets.statusbar);xpBar:SetStatusBarColor(.56,.30,.88)
 local xpGlow=xpBar:CreateTexture(nil,"OVERLAY");xpGlow:SetColorTexture(1,1,1,.08);xpGlow:SetPoint("TOPLEFT",xpBar,"TOPLEFT",0,0);xpGlow:SetPoint("TOPRIGHT",xpBar,"TOPRIGHT",0,0);xpGlow:SetHeight(7)
 local xpTextLayer=CreateFrame("Frame",nil,foot)
 xpTextLayer:SetAllPoints(xpBarBack)
 xpTextLayer:SetFrameLevel(xpBar:GetFrameLevel()+5)
 local xpVal=font(xpTextLayer,16,{1,1,1})
 xpVal:SetPoint("CENTER",xpTextLayer,"CENTER")
 xpVal:SetDrawLayer("OVERLAY",7)
 xpVal:SetShadowColor(0,0,0,1)
 xpVal:SetShadowOffset(2,-2)
 local summary=CreateFrame("Frame",nil,parent)
 local extra=font(summary,14);extra:SetPoint("LEFT",6,0);extra:SetPoint("RIGHT",-6,0);extra:SetJustifyH("LEFT");extra:SetWordWrap(true)
 local hs=CreateFrame("Button",nil,parent,"SecureActionButtonTemplate,BackdropTemplate")
 hs:SetSize(40,40);hs:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-14,12)
 WoWU_Theme.Backdrop(hs,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13,insets={left=3,right=3,top=3,bottom=3}})
 WoWU_Theme.Color(hs,.18,.22,.26,1);WoWU_Theme.Border(hs,.63,.49,.29,1)
 hs:RegisterForClicks("AnyDown","AnyUp")
 hs:SetAttribute("type","item");hs:SetAttribute("item","item:6948")
 local hsIcon=hs:CreateTexture(nil,"ARTWORK");hsIcon:SetPoint("TOPLEFT",5,-5);hsIcon:SetPoint("BOTTOMRIGHT",-5,5);hsIcon:SetTexCoord(.08,.92,.08,.92);hsIcon:SetTexture(134414)
 hs:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_TOPLEFT"); GameTooltip:SetHyperlink("item:6948") end end)
 hs:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
 local function moneyString(copper)
  copper=tonumber(copper) or 0
  local g=math.floor(copper/10000)
  local s=math.floor((copper%10000)/100)
  local c=copper%100
  local parts={}
  if g>0 then parts[#parts+1]=g.."|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t" end
  if s>0 or g>0 then parts[#parts+1]=s.."|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:0:0|t" end
  parts[#parts+1]=c.."|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:0:0|t"
  return table.concat(parts, " ")
 end
 local function refresh()
  if not panel:IsShown() then return end
  location:SetText(GetRealZoneText and GetRealZoneText() or "Current location")
  if not trackerDocked then dockTracker() end
  local level=UnitLevel("player") or 0
  local xp=UnitXP and UnitXP("player") or 0;local max=UnitXPMax and UnitXPMax("player") or 0
  xpBar:SetMinMaxValues(0,math.max(1,max));xpBar:SetValue(xp)
  xpVal:SetText(max>0 and ("Lvl "..level.." - "..math.floor(xp/math.max(max,1)*100).."% ("..xp.." / "..max..")") or ("Lvl "..level.." - Maximum"))
  local total,free=0,0
  for bag=0,WoWUClient.LastBag() do
   if C_Container and C_Container.GetContainerNumSlots then
    local slots=C_Container.GetContainerNumSlots(bag) or 0;total=total+slots
    if C_Container.GetContainerNumFreeSlots then local count=C_Container.GetContainerNumFreeSlots(bag);free=free+(count or 0) end
   end
  end
  local durability={}
  for slot=1,19 do
   if GetInventoryItemDurability then
    local cur,mx=GetInventoryItemDurability(slot)
    if cur and mx and mx>0 then durability[#durability+1]=cur/mx end
   end
  end
  local repair="N/A"
  if #durability>0 then local sum=0;for _,v in ipairs(durability) do sum=sum+v end;repair=math.floor(sum/#durability*100).."%" end
  local money=moneyString(GetMoney and GetMoney() or 0)
  local parts={}
  if WoWU_GetPreference("dashboardMoney")then parts[#parts+1]=money end
  if WoWU_GetPreference("dashboardBags")then parts[#parts+1]="Bags: "..free.." / "..total.." free"end
  if WoWU_GetPreference("dashboardDurability")then parts[#parts+1]="Durability: "..repair end
  extra:SetText(table.concat(parts,"    |    "))
  foot:SetShown(WoWU_GetPreference("dashboardXP"));xpVal:SetShown(WoWU_GetPreference("dashboardXPText"))
  zoneOverlay:SetShown(WoWU_GetPreference("dashboardZone"))
  local list=WoWUDashboardLayout.Shortcuts(characterKey())
  -- Secure action attributes must only be changed outside combat.
  if not locked() then
   for i=#list,1,-1 do
    local entry=list[i]
    local remove=false
    if entry.kind=="item" then
     local n=itemCount(entry.id)
     remove=n~=nil and n==0
    elseif entry.kind=="spell" then
     remove=not WoWUQuickAccess.MountID(entry)and spellKnown(entry.id)==false
    else
     remove=true
    end
    if remove then table.remove(list,i) end
   end
  end
  for i,b in ipairs(cells) do
   local entry=i<=WoWUDashboardLayout.QuickLimit()and list[i]or nil
   if entry then
    b.emptyArtwork:Hide();b.emptyMark:Hide()
    b.icon:SetTexture(entry.icon or 134400);b.text:SetText(entry.name or entry.kind)
    if entry.kind=="item" then
     local n=itemCount(entry.id)
     b.count:SetText(n and n>1 and tostring(n) or "")
    else
     b.count:SetText("")
    end
   else
    b.emptyArtwork:Show();b.emptyMark:Show()
    b.icon:SetTexture(nil);b.text:SetText("");b.count:SetText("")
   end
  end
  WoWUQuickAccess.Refresh()
  fallback:SetShown(not active)
 end
 WoWU_RefreshDashboard=refresh
 local events=CreateFrame("Frame",nil,parent)
 for _,event in ipairs({"PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","BAG_UPDATE_DELAYED","SPELLS_CHANGED","UPDATE_INVENTORY_DURABILITY","QUEST_LOG_UPDATE","ZONE_CHANGED_NEW_AREA","PLAYER_REGEN_ENABLED","ADDON_LOADED"}) do pcall(events.RegisterEvent,events,event) end
 events:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_REGEN_ENABLED"then
   if WoWUViewport and WoWUViewport.active then WoWU_DashboardEnter()
   elseif nativeRestorePending or active then WoWU_RestoreNativeMinimap()end
  end
  if event=="PLAYER_REGEN_ENABLED" and panel:IsShown() then dockTracker() end
  if panel:IsShown() then refresh() end
 end)
 local scrollCombat=CreateFrame("Frame",nil,quick)
 scrollCombat:RegisterEvent("PLAYER_REGEN_DISABLED");scrollCombat:RegisterEvent("PLAYER_REGEN_ENABLED")
 scrollCombat:SetScript("OnEvent",function()
  -- Secure item/spell buttons remain usable; layout and swipe updates wait for peace.
  quickScroll.WoWUSuspendTouch=locked()
 end)
 quickScroll.WoWUSuspendTouch=locked()
 panel:HookScript("OnShow",function() WoWU_DashboardEnter();dockTracker();refresh() end)
 panel:HookScript("OnHide",WoWU_DashboardExit)
 local function quickResize(_,w,h)
  local limit=WoWUDashboardLayout.QuickLimit()
  local gap=8;local height=math.max(24,h-26)
  local compact=height<82
  local width=math.max(24,w-28)
  local function columnCount(available)
   return math.max(1,math.min(limit,math.floor((available+gap)/((compact and 48 or 100)+gap))))
  end
  local columns=columnCount(width)
  local cellH=compact and math.min(64,height)or 88
  local rows=math.ceil(limit/columns)
  local scrolling=rows*(cellH+gap)-gap>height
  if scrolling then width=math.max(24,w-46);columns=columnCount(width);rows=math.ceil(limit/columns)end
  local cellW=(width-gap*(columns-1))/columns
  local labels=not compact and cellW>=76
  quickScroll:SetPoint("BOTTOMRIGHT",scrolling and -32 or -14,12)
  quickBody:SetWidth(width)
  for i,b in ipairs(cells)do
   b:SetShown(i<=limit)
   b:ClearAllPoints();b:SetPoint("TOPLEFT",quickBody,"TOPLEFT",((i-1)%columns)*(cellW+gap),-math.floor((i-1)/columns)*(cellH+gap))
   b:SetSize(cellW,cellH);b.text:SetWidth(math.max(12,cellW-8));b.text:SetShown(labels)
   local size=math.max(12,math.min(44,cellW-16,cellH-(labels and 40 or 16)))
   b.icon:ClearAllPoints();b.icon:SetPoint("CENTER",b,"CENTER",0,labels and 14 or 0)
   b.icon:SetSize(size,size);b.emptyArtwork:SetSize(size,size)
   b.rim:SetSize(size+12,size+12)
  end
  quickBody:SetHeight(math.max(1,rows*(cellH+gap)-gap))
  if quickScroll.ScrollBar then quickScroll.ScrollBar:SetShown(scrolling)end
  quickScroll:SetVerticalScroll(math.min(quickScroll:GetVerticalScroll(),math.max(0,quickBody:GetHeight()-quickScroll:GetHeight())))
 end
 local function centerButton(f,w,h)
  f:ClearAllPoints();f:SetPoint("CENTER",f:GetParent(),"CENTER");f:SetSize(52,math.min(44,h))
 end
 local function dismissOverlays()
  keyboard:Hide();adventureView:Hide()
  if nativeTracker and nativeTracker.Close then nativeTracker.Close()end
  if WoWU_CloseAddonMenu then WoWU_CloseAddonMenu()end
 end
 WoWUDashboardLayout.Build(parent,WoWUQuickAccess.AddDefinitions({
  {id="dungeon",name="Dungeon Hub",create=WoWUDungeonHub.BuildSafely,minW=24,minH=20,resize=function(f,w,h)if WoWUDungeonHub.Resize then WoWUDungeonHub.Resize(f,w,h)end end},
  {id="quests",name="Quest Tracker",frame=quests,minW=5,minH=6},
  {id="companionmap",name="Mini World Map",create=WoWU_BuildCompanionMap,minW=5,minH=5,defaultW=8,defaultH=10},
  {id="minimap",name="Minimap",frame=middle,minW=7,minH=7,
   available=function()return WoWU_GetMinimapLocation()~="main"end,
   resize=function(_,w,h)
    local size=math.max(100,math.min(w-16,h-16))
    holder:ClearAllPoints();holder:SetPoint("TOPLEFT",8,-8);holder:SetSize(size,size)
    if active and not locked()then mini:SetSize(size-20,size-20)end
   end,
   visibility=function(shown)if shown then WoWU_DashboardEnter()else WoWU_DashboardExit()end end},
  {id="mapcontrols",name="Minimap Controls",frame=controlsWidget,minW=1,minH=1,
   available=function()return WoWU_GetMinimapLocation()~="main"end,
   defaultW=2,defaultH=8,
   validRect=function(r)return r.w>=5 or r.h>=7 end,
   resize=function(_,w,h)
    local horizontal=w>h;local span=horizontal and w or h;local cross=horizontal and h or w
    local controls={clockHost,calendarHost,trackingHost,zoomButtons[1],zoomButtons[2]}
    if addonToggle then controls[#controls+1]=addonToggle end
    local n=#controls;local available=math.max(1,span-16)
    local side=math.max(12,math.min(44,cross-12,(available-(n-1)*6)/(n+(horizontal and .7 or 0))))
    local clockWidth=horizontal and side*1.7 or math.max(16,w-16)
    local length=horizontal and (clockWidth+(n-1)*side)or n*side
    local gap=n>1 and math.max(0,math.min(14,(available-length)/(n-1)))or 0
    local cursor=-(length+gap*(n-1))/2
    for i,control in ipairs(controls)do
     local cw=control==clockHost and clockWidth or side
     local extent=horizontal and cw or side
     control:ClearAllPoints();control:SetSize(cw,side)
     if horizontal then control:SetPoint("CENTER",controlsWidget,"CENTER",cursor+extent/2,0)
     else control:SetPoint("CENTER",controlsWidget,"CENTER",0,-cursor-extent/2)end
     cursor=cursor+extent+gap
    end
    if active and not locked()then dockClock()end
   end},
  {id="damage",name="Damage Meter",create=WoWU_BuildDamageMeter,minW=6,minH=7},
  {id="quick",name="Quick Access",frame=quick,minW=2,minH=2,resize=quickResize,beforeEdit=dismissOverlays},
  {id="notifications",name="Notifications",frame=notification,minW=6,minH=2,
   resize=function(_,w,h)notification.label:SetWidth(w-28);notification.label:SetHeight(h-14)end},
  {id="xp",name="Experience",frame=foot,minW=6,minH=2},
  {id="summary",name="Gold / Bags / Durability",frame=summary,minW=8,minH=2},
  {id="keyboard",name="Keyboard",frame=keyboardButton,minW=2,minH=2,resize=centerButton},
  {id="hearth",name="Hearthstone",frame=hs,minW=2,minH=2,resize=centerButton},
  {id="emotes",name="Emotes",create=WoWUDashboardLayout.CreateEmotes,minW=6,minH=8,
   resize=function(f)f:Resize()end},
 }))
 WoWUDungeonHub.Initialize(parent)
end
