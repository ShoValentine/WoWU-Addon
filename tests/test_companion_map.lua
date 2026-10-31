local fixture=dofile('tests/fake_frames.lua')
local F=fixture.F
function F:SetClipsChildren(v)self.clips=v end
function F:SetRotation(v)self.rotation=v end
function F:SetTexture(v)self.texture=v end
function F:SetTextColor(...)end
function F:SetTexCoord(...)self.texCoords={...}end
local checks=0
local function test(ok,message)assert(ok,message);checks=checks+1;print('PASS '..message)end
local id,x,y=1,.25,.75
local art,position=true,true
local markerCalls=0
WoWUNavigation={
 Call=function(fn,...)if type(fn)=='function'then local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end end end,
 Number=function(v)if type(v)=='number'and v==v and v~=math.huge then return v end end,
 Coordinates=function(a,b)if type(a)=='number'and type(b)=='number'and a>=0 and a<=1 and b>=0 and b<=1 then return a,b end end,
 Vector=function(v)if v then return v:GetXY()end end,
 MapWorldSize=function()return 2000,1000 end,
 Project=function(source,a,b,view)if source==view then return a,b end end,
 ProjectEndpoints=function(t,view)return x,y,.8,.75 end,
 Destination=function()return {distance=300}end,
 GetTrailSetting=function(k)return ({enabled=true,minimap=true,spacing=18,size=5,speed=32,opacity=.9})[k]end,
}
local calls=0
C_Map={
 GetBestMapForUnit=function()calls=calls+1;return id end,
 GetPlayerMapPosition=function()if position then return {GetXY=function()return x,y end}end end,
 GetMapInfo=function()return {name='Test Zone'}end,
 GetMapArtLayers=function()if art then return {{layerWidth=1000,layerHeight=500,tileWidth=256,tileHeight=256}}end end,
 GetMapArtLayerTextures=function()return {101,102,103,104,105,106,107,108}end,
}
C_MapExplorationInfo={GetExploredMapTextures=function()return {{textureWidth=300,textureHeight=100,offsetX=20,offsetY=30,fileDataIDs={201,202}}}end}
GetPlayerFacing=function()return .6 end
WoWUExplorer={Markers=function(map)markerCalls=markerCalls+1;return {{mapID=map,x=x+.01,y=y,icon=301},{mapID=map,x=1,y=1,icon=302}}end}
local forbidden=setmetatable({},{__index=function()error('Native minimap or helper touched')end})
Minimap=forbidden;MinimapCluster=forbidden;WorldMapFrame=forbidden;C_AddOns=forbidden
WoWUDB.mapID=777
dofile('WoWU/CompanionMap.lua')
local f=WoWU_BuildCompanionMap(UIParent)
local function child(p)for _,v in ipairs(fixture.frames)do if v.parent==p and v.kind=='Frame'then return v end end end
local function tex(id)for _,v in ipairs(fixture.frames)do if v.texture==id then return v end end end
local view=child(f);view:SetSize(400,300);local canvas=child(view)
f:Fire('OnShow')
test(canvas:IsShown()and canvas:GetWidth()>400,'Mini World Map renders its own zone art')
test(view.clips,'map content stays clipped to widget')
local function centred(cx,cy)local p=canvas.points[1];return math.abs(p[4]+x*canvas:GetWidth()-cx)<.001 and math.abs(p[5]-y*canvas:GetHeight()+cy)<.001 end
test(centred(200,150),'player is centred in the map crop')
test(tex(101):IsShown()and tex(108):IsShown(),'base art tiles are populated')
test(tex(202).texCoords[2]==44/64,'exploration overlay respects padded edge textures')
test(tex(301):IsShown()and not tex(302),'nearby marker is drawn and distant marker culled')
test(tex('Interface\\Minimap\\MinimapArrow').rotation==.6,'player facing updates')
local old=canvas:GetWidth();view:Fire('OnMouseWheel',1)
test(canvas:GetWidth()>old,'zoom changes the custom map')
x=.3;f:Fire('OnUpdate',.11);test(centred(200,150),'movement keeps following the player')
local count=markerCalls;f:Fire('OnUpdate',.11);test(markerCalls==count,'location data is cached between refreshes')
f:Fire('OnUpdate',1.1);test(markerCalls>count,'location markers refresh periodically')
id=2;f:Fire('OnUpdate',.11);test(canvas:IsShown(),'map follows zone transitions')
position=false;f:Fire('OnUpdate',.11);test(not canvas:IsShown(),'unavailable coordinates hide stale artwork')
position=true;f:Fire('OnUpdate',.11);test(canvas:IsShown(),'position recovery restores the map')
art=false;id=3;f:Fire('OnUpdate',.11);test(not canvas:IsShown(),'unavailable art shows a safe empty state')
art=true;f:Fire('OnUpdate',1.1);test(canvas:IsShown(),'delayed art recovers automatically')
view:SetSize(600,200);view:Fire('OnSizeChanged');f:Fire('OnUpdate',.11);test(centred(300,100),'resizing preserves player centring')
f:Hide();count=calls;f:Fire('OnEvent','PLAYER_ENTERING_WORLD');test(calls==count,'hidden widgets defer map work')
f:Show();f:Fire('OnShow');test(canvas:IsShown(),'showing refreshes the custom map')
C_Map.GetMapArtLayers=nil;id=4;f:Fire('OnUpdate',.11);test(not canvas:IsShown(),'missing map API does not raise an error')
test(WoWUDB.mapID==777,'native maps, helper addon and world-map settings remain untouched')
return checks
