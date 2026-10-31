local fixture=dofile('tests/fake_frames.lua')
local F=fixture.F
local checks=0
local function test(ok,message)assert(ok,message);checks=checks+1;print('PASS '..message)end
function F:SetFont(path,size)self.fontSize=size end
function F:GetStringHeight()
 local lines=0;for line in tostring(self.text or ''):gmatch('[^\n]+')do lines=lines+math.max(1,math.ceil(#line*7/math.max(1,self:GetWidth())))end
 return math.max(1,lines)*(self.fontSize or 14)*1.2
end
function F:GetText()return self.text or ''end
function F:SetEnabled(v)self.enabled=v end
function F:Enable()self.enabled=true end
function F:Disable()self.enabled=false end
function F:SetValue(v)self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v)end end
function F:GetValue()return self.value or 0 end
function F:GetVerticalScroll()return self.scroll or 0 end
function F:SetThumbTexture()self.thumb=CreateFrame('Texture',nil,self)end
function F:GetThumbTexture()return self.thumb end
function F:HasFocus()return false end
function F:SetTextColor()end
for _,k in ipairs({'SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetAutoFocus','SetMaxLetters','ClearFocus'})do F[k]=function()end end
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)local f=create(kind,name,parent);f.template=template;return f end
WoWU_Theme.assets={thumb='thumb'}
local function noop()return true,'Saved.'end
local function object(values)return setmetatable(values or {},{__index=function()return noop end})end
WoWUClient={isRetail=true,isForever=false,name='Test',version='1',interface=120105,FilterModules=function(v)return v end}
WoWUCompanionBridge=object()
WoWUViewport=object({GetUIScale=function()return 1 end})
WoWUController=object()
WoWUControllerLayout=object({GetScale=function()return 1 end,SelectedScale=function()return 1 end})
WoWUDashboardLayout=object({QuickLimit=function()return 8 end,Profile=function()return {name='Layout 2'}end})
WoWUAdventure=object()
WoWUNavigation=object({GetTrailSetting=function(key)return ({enabled=true,worldmap=true,minimap=true,backToMap=false,size=5,opacity=.9,speed=32,spacing=18})[key]end})
WoWUExplorer=object()
WoWUCompassAPI=object({Get=function(key)return ({scale=1,opacity=1,iconSize=24,width=680,poiRange=1500})[key]or true end})
WoWUQoL=object({Get=function(key)return ({cameraFactor=1,lootDuration=3,lootScale=1,lootX=0,lootY=0})[key]or false end})
WoWUDungeonHub=object({Get=function(key)return ({activation='auto',role='AUTO',spells=''})[key]end})
WoWU_IsLocked=function()return true end
WoWU_SetLocked=noop;WoWU_SetScale=noop
WoWU_RefreshTopTabs=function()WoWUDB.topTabs=WoWUDB.topTabs or {'Bags','Character','Quests','Map','Spells'}end
WoWU_IsBlizzardUIShown=function()return false end
WoWU_EnableTouchScroll=noop
WoWU_TouchTapAllowed=function()return true end
IsMouseButtonDown=function()return false end
WoWU_ShowPage=noop
WoWU_DashboardEnter=noop
ReloadUI=noop
WoWU_ResetMapPosition=noop
WoWU_SetBlizzardUIShown=noop
dofile('WoWU/Settings.lua')
local detail=CreateFrame('Frame',nil,UIParent);detail:SetSize(1240,670)
local roots={};WoWU_BuildExtraSettings(detail,roots)
local root=roots[1];test(root~=nil,'revised settings builds with every settings category')
root:Show();root:Fire('OnShow')
local nav={}
for _,f in ipairs(fixture.frames)do if f.kind=='Button'and f.label and f.template=='BackdropTemplate'then nav[f.label:GetText()]=f end end
local n=0
for name,b in pairs(nav)do n=n+1;b:Fire('OnClick');test(b:GetHeight()>=52,'large navigation category: '..name)end
test(n==19,'all settings pages remain reachable, including split controller help and compass markers')
nav.Minimap:Fire('OnClick')
local main,wowu
for _,f in ipairs(fixture.frames)do
 if f.kind=='Button'and f.label and f.label:GetText():find('^Main screen')then main=f end
 if f.kind=='Button'and f.label and f.label:GetText():find('^WoWU %(')then wowu=f end
end
test(main and wowu and main:GetHeight()==60,'minimap location has two large, explicit choices')
main:Fire('OnClick');test(WoWU_GetMinimapLocation()=='main'and main.label:GetText():find('selected'),'Main screen saves and highlights the selected choice')
wowu:Fire('OnClick');test(WoWU_GetMinimapLocation()=='wowu','WoWU choice restores the saved preference')
local small=0;local red=0
for _,f in ipairs(fixture.frames)do
 if f.kind=='CheckButton'then if f:GetWidth()<48 or f:GetHeight()<48 then small=small+1 end end
 if f.kind=='Button'and f.template=='UIPanelButtonTemplate,BackdropTemplate'then red=red+1;if f:GetHeight()<48 then small=small+1 end end
end
test(small==0 and red>20,'checkboxes and red action buttons have touch-sized targets')
-- Exercise the real dashboard availability rules without moving saved rectangles.
WoWUDB.dashboardLayouts={active=1,profiles={{name='One',widgets={minimap={x=0,y=0,w=7,h=7},mapcontrols={x=7,y=0,w=2,h=8},companionmap={x=10,y=0,w=8,h=10}},minimapTrimmed=true,minimapTitleInset=true,mapControlsMigrated=true}}}
WoWU_RefreshDashboard=noop
dofile('WoWU/DashboardLayout.lua')
local L=WoWUDashboardLayout
local defs={}
for _,id in ipairs({'minimap','mapcontrols','companionmap','extra'})do
 local key=id
 defs[#defs+1]={id=id,name=id,frame=CreateFrame('Frame',nil,detail),minW=2,minH=2,available=function()return(key~='minimap'and key~='mapcontrols')or WoWU_GetMinimapLocation()~='main'end}
end
L.Build(detail,defs)
local canvas=L.widgets.minimap.host:GetParent();canvas:SetSize(1200,600);L.Apply()
test(L.IsEnabled('minimap')and L.widgets.minimap.host:IsShown(),'native minimap widget is available in WoWU mode')
local rect=L.Profile().widgets.minimap
WoWU_SetMinimapLocation('main')
test(not L.WidgetAvailable('minimap')and not L.WidgetAvailable('mapcontrols')and not L.IsEnabled('minimap'),'main-screen location removes native widgets from availability')
test(not L.widgets.minimap.host:IsShown()and L.widgets.companionmap.host:IsShown(),'main-screen location hides native widget but keeps Mini World Map')
test(L.Profile().widgets.minimap==rect and rect.x==0 and rect.w==7,'hidden native widget retains its saved rectangle')
L.Edit()
local add
for _,v in ipairs(fixture.frames)do if v.label and v.label:GetText()=='Add Widget'then add=v end end
add:Fire('OnClick')
local visibleNames={}
for _,v in ipairs(fixture.frames)do if v.label and v:IsVisible()then visibleNames[v.label:GetText()]=true end end
test(not visibleNames['[x] minimap']and not visibleNames['[x] mapcontrols']and visibleNames['[x] companionmap'],'widget picker omits unavailable minimap widgets')
-- Place and resize a real widget through the editor in the hidden minimap cells.
local chooseExtra,save
for _,v in ipairs(fixture.frames)do
 if v.label and v.label:GetText()=='extra'and v:IsVisible()then chooseExtra=v end
 if v.label and v.label:GetText()=='Save'then save=v end
end
chooseExtra:Fire('OnClick')
test(L.draft.widgets.extra.x==0 and L.draft.widgets.extra.y==0,'Add Widget can occupy the hidden minimap footprint')
local fingerX,fingerY=100,100
GetCursorPosition=function()return fingerX,fingerY end
local resize
for _,v in ipairs(fixture.frames)do if v.parent==L.widgets.extra.cover and v.label and v.label:GetText()=='Size'then resize=v end end
resize:Fire('OnMouseDown','LeftButton');fingerX=350;fingerY=-50;resize:Fire('OnMouseUp','LeftButton')
test(L.draft.widgets.extra.w==7 and L.draft.widgets.extra.h==7,'resizing can use the entire former minimap footprint')
save:Fire('OnClick')
local extra=L.Profile().widgets.extra
local other=L.Profile().widgets.companionmap
WoWU_SetMinimapLocation('wowu')
local mini=L.Profile().widgets.minimap
local function overlap(a,b)return a and b and a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y end
test(mini and not overlap(mini,extra)and not overlap(mini,other),'returning minimap relocates to available space without overlap')
test(L.Profile().widgets.extra==extra and extra.x==0 and extra.y==0 and extra.w==7,'returning minimap does not move or resize replacement widget')
test(L.Profile().widgets.companionmap==other and other.x==10 and other.y==0,'other existing widgets stay in place')
local minimapX,minimapY=mini.x,mini.y
L.Profile().widgets.extra={x=0,y=0,w=24,h=20};L.Profile().widgets.companionmap=nil
L.Apply()
test(not L.Profile().widgets.minimap and L.Profile().parkedWidgets.minimap and not L.widgets.minimap.host:IsShown(),'full dashboard parks returning minimap rather than overlapping visible widgets')
test(L.minimapPlacementNotice and L.minimapPlacementNotice:find('Dashboard full'),'full dashboard explains how to make room')
local parked=L.Profile().parkedWidgets.minimap
L.Profile().widgets.extra=nil;L.Apply()
test(L.Profile().widgets.minimap and not L.Profile().parkedWidgets.minimap and L.Profile().widgets.minimap.x==minimapX and L.Profile().widgets.minimap.y==minimapY,'freeing space restores parked minimap at its saved location')
local restored=L.Profile().widgets.minimap
L.Apply();test(L.Profile().widgets.minimap==restored,'repeated layout refreshes preserve stable placement')
return checks
