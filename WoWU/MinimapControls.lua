-- Native minimap satellites keep their real handlers. The time display has its own Dashboard control slot.
local M={records={},known={},order={}};WoWUMinimapControls=M
local function combat()return InCombatLockdown and InCombatLockdown()end
local function usable(f)
 return f and f.GetParent and not (f.IsForbidden and f:IsForbidden())
  and not (f.IsProtected and f:IsProtected())
end
local function descendant(f,parent)
 if not parent then return false end
 while f do
  if f==parent then return true end
  if f.IsForbidden and f:IsForbidden()then return false end
  f=f.GetParent and f:GetParent()
 end
 return false
end
local function excluded(f)
 if not usable(f)then return true end
 local name=f.GetName and f:GetName()or ""
 if name:find("^WoWU")or name:find("^LibDBIcon")then return true end
 for _,root in pairs({AddonCompartmentFrame,TimeManagerClockButton,MinimapCluster and MinimapCluster.Clock,MiniMapWorldMapButton,MinimapToggleButton,Minimap and Minimap.CloseButton,Minimap and Minimap.WorldMapButton,
  MiniMapTracking,MiniMapTrackingButton,MinimapCluster and MinimapCluster.Tracking,
  MinimapZoneTextButton,MinimapCluster and MinimapCluster.ZoneTextButton})do
  if descendant(f,root)then return true end
 end
 return false
end
function M.IsDocked(f)
 for control in pairs(M.known)do if descendant(f,control)then return true end end
 return false
end
function M.Dock(holder,calendarHost)
 if combat()then return end
 if usable(AddonCompartmentFrame)then
  if not M.compartment then M.compartment={frame=AddonCompartmentFrame,shown=AddonCompartmentFrame:IsShown()}end
  AddonCompartmentFrame:Hide()
 end
 if not M.host then
  M.host=CreateFrame("Frame",nil,holder)
  M.host:SetAllPoints(holder);M.host:SetFrameLevel(holder:GetFrameLevel()+30)
 end
 M.host:Show()
 local candidates,seen={},{}
 local function add(f)
  if excluded(f)or seen[f]then return end
  for _,parent in ipairs(candidates)do if descendant(f,parent)then return end end
  seen[f]=true;candidates[#candidates+1]=f
 end
 local calendar=GameTimeFrame or CalendarButton or MinimapCalendarButton or (MinimapCluster and MinimapCluster.Calendar)
 add(calendar)
 add(MinimapCluster and MinimapCluster.IndicatorFrame)
 for _,name in ipairs({"CalendarButton","MinimapCalendarButton","MiniMapInstanceDifficulty",
  "MiniMapChallengeMode","MiniMapMailFrame","MiniMapBattlefieldFrame","QueueStatusMinimapButton",
  "QueueStatusButton","ExpansionLandingPageMinimapButton"})do add(_G[name])end
 for _,owner in pairs({MinimapCluster,MinimapBackdrop})do
  for _,key in ipairs({"Calendar","InstanceDifficulty","DifficultyIndicator","MailFrame","ExternalEventURLButton"})do
   add(owner[key])
  end
 end
 -- Forever can add its own small satellite buttons. Include minimap-cluster
 -- buttons and UIParent buttons anchored to that cluster, without touching the clock.
 local function smallButton(f)
  return usable(f)and f.IsObjectType and f:IsObjectType("Button")
   and f:GetWidth()>=16 and f:GetWidth()<=90 and f:GetHeight()>=16 and f:GetHeight()<=90
 end
 local function walk(parent,depth)
  if not parent or not parent.GetChildren or (parent.IsForbidden and parent:IsForbidden())or depth>2 then return end
  for _,f in ipairs({parent:GetChildren()})do
   if not excluded(f)then
    if smallButton(f)then add(f)
    elseif f~=Minimap and f~=MinimapBackdrop and f.GetChildren then walk(f,depth+1)end
   end
  end
 end
 walk(MinimapCluster,0)
 for _,f in ipairs({UIParent:GetChildren()})do
  if smallButton(f)and not excluded(f)then
   for i=1,f:GetNumPoints()do
    local _,relative=f:GetPoint(i)
    if descendant(relative,MinimapCluster)then add(f);break end
   end
  end
 end
 -- Include already docked controls after they have left the native hierarchy.
 for _,f in ipairs(M.order)do add(f)end
 local columns=math.max(1,math.floor((holder:GetWidth()-16)/44))
 local slot=0
 for _,f in ipairs(candidates)do
  local record=M.records[f]
  if not record then
   record={parent=f:GetParent(),scale=f:GetScale(),strata=f:GetFrameStrata(),level=f:GetFrameLevel(),points={}}
   for i=1,f:GetNumPoints()do record.points[i]={f:GetPoint(i)}end
   M.records[f]=record
   if not M.known[f]then M.known[f]=true;M.order[#M.order+1]=f end
  end
  -- Keep native visibility, including mail/queue indicators appearing later.
  local isCalendar=f==calendar and calendarHost
  local target=isCalendar and calendarHost or M.host
  local scale=math.min(1,(isCalendar and calendarHost:GetWidth() or 40)/math.max(1,f:GetWidth(),f:GetHeight()))
  local column,row=slot%columns,math.floor(slot/columns)
  local _,relative,_,x,y=f:GetPoint(1)
  local px,py=28+column*44,28+row*44
  if isCalendar then px,py=0,0 end
  if f:GetParent()~=target or relative~=target or x~=px/scale or y~=py/scale or f:GetScale()~=scale then
   f:SetParent(target);f:SetScale(scale);f:ClearAllPoints()
   f:SetPoint("CENTER",target,isCalendar and "CENTER" or "BOTTOMLEFT",px/scale,py/scale)
   f:SetFrameStrata(holder:GetFrameStrata());f:SetFrameLevel(target:GetFrameLevel()+2)
  end
  if f:IsShown()and not isCalendar then slot=slot+1 end
 end
end
function M.Restore()
 if combat()then return end
 if M.compartment then
  if usable(M.compartment.frame)then M.compartment.frame:SetShown(M.compartment.shown)end
  M.compartment=nil
 end
 for f,record in pairs(M.records)do
  if usable(f)then
   f:SetParent(record.parent);f:SetScale(record.scale);f:ClearAllPoints()
   for _,point in ipairs(record.points)do f:SetPoint(unpack(point))end
   f:SetFrameStrata(record.strata);f:SetFrameLevel(record.level)
  end
  M.records[f]=nil
 end
 if M.host then M.host:Hide()end
end
