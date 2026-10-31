dofile('tests/fake_frames.lua')
dofile('WoWU/Settings.lua')
WoWUViewport={active=false}
WoWUDashboardLayout={IsEnabled=function()return true end}
MinimapCluster=CreateFrame('Frame','MinimapCluster',UIParent)
MinimapBackdrop=CreateFrame('Frame','MinimapBackdrop',MinimapCluster)
Minimap=CreateFrame('Frame','Minimap',MinimapCluster)
Minimap:SetSize(140,141);Minimap:SetScale(.83);Minimap:SetAlpha(.72);Minimap:SetFrameStrata('LOW');Minimap:SetFrameLevel(7);Minimap:SetMaskTexture('original-custom-mask')
Minimap:SetPoint('TOPRIGHT',MinimapCluster,'TOPRIGHT',-11,-22)
local names={'MinimapBorder','MinimapBorderTop','MinimapNorthTag','MinimapZoneTextButton','MinimapZoneText','MinimapZoomIn','MinimapZoomOut','MiniMapWorldMapButton','MinimapToggleButton','TimeManagerClockButton','MiniMapTracking','GameTimeFrame','MiniMapMailFrame','AddonCompartmentFrame'}
for i,name in ipairs(names)do local f=CreateFrame('Button',name,MinimapCluster);f:SetSize(30,31);f:SetScale(.8);f:SetFrameStrata('LOW');f:SetFrameLevel(4);f:SetPoint('CENTER',MinimapCluster,'CENTER',i,-i)end
MinimapNorthTag:Hide();MiniMapMailFrame:Hide()
local function snap(f)return {parent=f:GetParent(),w=f:GetWidth(),h=f:GetHeight(),scale=f:GetScale(),alpha=f:GetAlpha(),strata=f:GetFrameStrata(),level=f:GetFrameLevel(),shown=f:IsShown(),point={f:GetPoint()},mask=f:GetMaskTexture()}end
local originals={};originals[Minimap]=snap(Minimap)
for _,name in ipairs(names)do originals[_G[name]]=snap(_G[name])end
local function same(f,o)
 for key,value in pairs(snap(f))do
  if key=='point'then for i=1,5 do assert(value[i]==o.point[i],f:GetName()..' point '..i)end
  else assert(value==o[key],f:GetName()..' '..key)end
 end
end
local holder=CreateFrame('Frame',nil,UIParent);holder:SetSize(400,400)
local panel=CreateFrame('Frame',nil,UIParent);panel:Hide()
local clock=CreateFrame('Frame',nil,holder);clock:SetSize(100,40)
local tracking=CreateFrame('Frame',nil,holder);tracking:SetSize(40,40)
local calendar=CreateFrame('Frame',nil,holder);calendar:SetSize(40,40)
dofile('WoWU/MinimapControls.lua');dofile('WoWU/Dashboard.lua')
-- Supply only the dashboard-created host frames; exercise real ownership code.
local function upvalue(fn,name,value)
 for i=1,100 do local n=debug.getupvalue(fn,i);if not n then break end;if n==name then debug.setupvalue(fn,i,value);return end end
 error('Missing host upvalue '..name)
end
upvalue(WoWU_DashboardEnter,'panel',panel);upvalue(WoWU_DashboardEnter,'holder',holder);upvalue(WoWU_DashboardEnter,'calendarHost',calendar)
local function nested(fn,name)for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end;error(name)end
upvalue(nested(WoWU_DashboardEnter,'dockClock'),'clockHost',clock)
upvalue(nested(WoWU_DashboardEnter,'dockTracking'),'trackingHost',tracking)
WoWU_DashboardEnter();for f,o in pairs(originals)do same(f,o)end
print('PASS startup/hidden dashboard never acquires the native map')
panel:Show();WoWU_DashboardEnter();assert(Minimap:GetParent()==MinimapCluster)
print('PASS manually showing WoWU with mode off leaves native map untouched')
for cycle=1,3 do
 WoWUViewport.active=true;WoWU_DashboardEnter()
 assert(Minimap:GetParent()==holder and Minimap:GetMaskTexture():find('SquareMask'))
 assert(TimeManagerClockButton:GetParent()==clock and MiniMapTracking:GetParent()==tracking and GameTimeFrame:GetParent()==calendar)
 panel:Hide();WoWU_DashboardExit();assert(Minimap:GetParent()==holder)
 WoWUViewport.active=false
 if cycle==2 then combat=true;assert(WoWU_RestoreNativeMinimap()==false);assert(Minimap:GetParent()==holder);combat=false end
 assert(WoWU_RestoreNativeMinimap())
 for f,o in pairs(originals)do same(f,o)end
 WoWU_RestoreNativeMinimap();for f,o in pairs(originals)do same(f,o)end
 panel:Show()
end
print('PASS three activation/deactivation cycles restore native geometry, mask, decoration visibility and controls')
print('PASS page changes retain companion ownership; combat delays restoration; repeated restores are harmless')
-- Addon buttons must restore once and capture user changes between sessions.
dofile('WoWU/AddonMenu.lua')
local addon=CreateFrame('Button','LibDBIcon10_Test',Minimap);addon:SetSize(32,32);addon:SetPoint('LEFT',Minimap,'LEFT',-10,0)
local click=function()end;local drag=function()end
addon:SetScript('OnClick',click);addon:SetScript('OnDragStart',drag);addon:SetHitRectInsets(1,2,3,4)
LibStub=function()return {objects={Test=addon}}end
local before=snap(addon)
WoWU_BuildAddonMenu(panel,holder,holder);WoWU_RefreshAddonMenu();same(addon,before)
WoWUViewport.active=true;WoWU_RefreshAddonMenu();assert(addon:GetParent()~=Minimap)
panel:Hide();WoWU_RefreshAddonMenu();assert(addon:GetParent()~=Minimap)
WoWUViewport.active=false;WoWU_RestoreAddonMenu();same(addon,before)
assert(addon:GetScript('OnClick')==click and addon:GetScript('OnDragStart')==drag)
addon:ClearAllPoints();addon:SetPoint('RIGHT',Minimap,'RIGHT',19,0);local moved=snap(addon)
WoWU_RefreshAddonMenu();same(addon,moved)
WoWUViewport.active=true;WoWU_RefreshAddonMenu();WoWUViewport.active=false;WoWU_RestoreAddonMenu();same(addon,moved)
print('PASS addon buttons stay docked across pages, restore handlers once and respect user repositioning on the next session')
-- Location changes restore every native component and stop background collection.
WoWUViewport.active=true;panel:Show();WoWU_DashboardEnter();WoWU_RefreshAddonMenu()
assert(Minimap:GetParent()==holder and addon:GetParent()~=Minimap)
assert(WoWU_SetMinimapLocation('main'))
for f,o in pairs(originals)do same(f,o)end
same(addon,moved)
for i=1,3 do WoWU_DashboardEnter();WoWU_RefreshAddonMenu()end
for f,o in pairs(originals)do same(f,o)end
same(addon,moved)
print('PASS Main screen restores native minimap, decorations, clock, tracking, calendar and addon icons without redocking')
assert(WoWU_SetMinimapLocation('wowu'));assert(Minimap:GetParent()==holder)
combat=true;assert(not WoWU_SetMinimapLocation('main'));assert(WoWU_GetMinimapLocation()=='wowu');combat=false
assert(not WoWU_SetMinimapLocation('invalid'));assert(WoWU_GetMinimapLocation()=='wowu')
print('PASS WoWU location reacquires the map; combat and invalid selections leave saved preference unchanged')
WoWUViewport.active=false;WoWU_RestoreNativeMinimap()
for f,o in pairs(originals)do same(f,o)end
assert(WoWU_GetMinimapLocation()=='wowu')
WoWU_SetMinimapLocation('main');WoWU_DashboardEnter()
for f,o in pairs(originals)do same(f,o)end
print('PASS mode off always keeps the native minimap restored for both location preferences')
return 12
