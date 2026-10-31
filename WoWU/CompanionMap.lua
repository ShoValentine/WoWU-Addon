-- Independent zone-art map. Never acquires or changes Blizzard's Minimap/WorldMapFrame.
local N=WoWUNavigation
local function call(fn,...)return N.Call(fn,...)end
local function number(v)return N.Number(v)end
function WoWU_BuildCompanionMap(parent)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
 WoWU_Theme.Panel(f)
 local view=CreateFrame("Frame",nil,f)
 view:SetPoint("TOPLEFT",8,-8);view:SetPoint("BOTTOMRIGHT",-8,8)
 view:SetClipsChildren(true);view:EnableMouseWheel(true)
 local bg=view:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.035,.045,.05,1)
 local canvas=CreateFrame("Frame",nil,view)
 local overlay=CreateFrame("Frame",nil,view);overlay:SetAllPoints()
 overlay:SetFrameLevel(canvas:GetFrameLevel()+5)
 local pins=CreateFrame("Frame",nil,overlay);pins:SetAllPoints()
 local arrow=CreateFrame("Frame",nil,overlay);arrow:SetAllPoints();arrow:SetFrameLevel(pins:GetFrameLevel()+1)
 local player=arrow:CreateTexture(nil,"OVERLAY",nil,3)
 player:SetTexture("Interface\\Minimap\\MinimapArrow");player:SetSize(24,24);player:SetPoint("CENTER")
 local title=overlay:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
 title:SetPoint("TOPLEFT",8,-6);title:SetPoint("TOPRIGHT",-8,-6)
 title:SetFont("Fonts\\FRIZQT__.TTF",18,"OUTLINE");title:SetTextColor(1,.84,.52)
 local status=overlay:CreateFontString(nil,"OVERLAY","GameFontNormal")
 status:SetPoint("CENTER");status:SetWidth(220);status:SetText("Waiting for your location...")
 local controls=CreateFrame("Frame",nil,overlay);controls:SetPoint("BOTTOMRIGHT",-6,6);controls:SetSize(94,42)
 controls:SetFrameLevel(pins:GetFrameLevel()+5)
 local tiles,explored,markers,dots={},{},{},{}
 local mapID,layer,files,regions,points
 local zoom,elapsed,slow=1,0,0
 local dirty=true
 local aw,ah,px,py
 local function hidePool(pool)for _,t in ipairs(pool)do t:Hide()end end
 local function unavailable(message)
  canvas:Hide();player:Hide();pins:Hide();status:SetText(message)
 end
 local function loadMap(id)
  mapID=id;layer=nil;files=nil;regions=nil;points=nil
  hidePool(tiles);hidePool(explored);hidePool(markers);hidePool(dots)
  local info=call(C_Map and C_Map.GetMapInfo,id)
  title:SetText(info and info.name or "Mini World Map")
  local layers=call(C_Map and C_Map.GetMapArtLayers,id)
  local l=type(layers)=="table"and layers[1]
  if l and number(l.layerWidth)and number(l.layerHeight)and number(l.tileWidth)and number(l.tileHeight)
   and l.layerWidth>0 and l.layerHeight>0 and l.tileWidth>0 and l.tileHeight>0 then
   local textures=call(C_Map.GetMapArtLayerTextures,id,1)
   if type(textures)=="table"and #textures>0 then layer=l;files=textures end
  end
  regions=call(C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures,id)
  dirty=true
 end
 local function texture(pool,index,drawLayer,sublevel)
  local t=pool[index]
  if not t then t=canvas:CreateTexture(nil,drawLayer,nil,sublevel);pool[index]=t end
  t:ClearAllPoints();return t
 end
 local function drawArt()
  if not layer then return end
  local w,h=view:GetWidth(),view:GetHeight()
  if w<10 or h<10 then return end
  -- Keep the geographic viewing distance stable as the widget is resized.
  local mw,mh=N.MapWorldSize(mapID)
  local scale
  if mw and mh then scale=math.max(w*mw/layer.layerWidth,h*mh/layer.layerHeight)/600*zoom
  else scale=math.max(w/layer.layerWidth,h/layer.layerHeight)*3*zoom end
  aw,ah=layer.layerWidth*scale,layer.layerHeight*scale
  canvas:SetSize(aw,ah)
  hidePool(tiles);hidePool(explored)
  local cols=math.ceil(layer.layerWidth/layer.tileWidth)
  local rows=math.ceil(layer.layerHeight/layer.tileHeight)
  for i=1,math.min(#files,cols*rows)do
   local col,row=(i-1)%cols,math.floor((i-1)/cols)
   local pw,ph=math.min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth),math.min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
   local t=texture(tiles,i,"ARTWORK",0)
   t:SetPoint("TOPLEFT",canvas,"TOPLEFT",col*layer.tileWidth*scale,-row*layer.tileHeight*scale)
   t:SetSize(pw*scale,ph*scale);t:SetTexture(files[i]);t:SetTexCoord(0,pw/layer.tileWidth,0,ph/layer.tileHeight);t:Show()
  end
  local used=0
  local function edge(n)local v=16;while v<n do v=v*2 end;return v end
  for _,r in ipairs(type(regions)=="table"and regions or {})do
   local rw,rh=number(r.textureWidth),number(r.textureHeight)
   if rw and rh and rw>0 and rh>0 and type(r.fileDataIDs)=="table"and not r.isShownByMouseOver then
    local columns,rows=math.ceil(rw/layer.tileWidth),math.ceil(rh/layer.tileHeight)
    for i,file in ipairs(r.fileDataIDs)do
     if i>columns*rows then break end
     local col,row=(i-1)%columns,math.floor((i-1)/columns)
     local pw,ph=math.min(layer.tileWidth,rw-col*layer.tileWidth),math.min(layer.tileHeight,rh-row*layer.tileHeight)
     used=used+1;local t=texture(explored,used,"ARTWORK",r.isDrawOnTopLayer and 2 or 1)
     t:SetPoint("TOPLEFT",canvas,"TOPLEFT",((number(r.offsetX)or 0)+col*layer.tileWidth)*scale,-((number(r.offsetY)or 0)+row*layer.tileHeight)*scale)
     t:SetSize(pw*scale,ph*scale);t:SetTexture(file)
     t:SetTexCoord(0,pw/(col==columns-1 and edge(pw)or layer.tileWidth),0,ph/(row==rows-1 and edge(ph)or layer.tileHeight));t:Show()
    end
   end
  end
  dirty=false
 end
 local function screen(x,y)
  x,y=N.Coordinates(x,y);if not x then return end
  return view:GetWidth()/2+(x-px)*aw,view:GetHeight()/2+(y-py)*ah
 end
 local function drawMarkers()
  hidePool(markers);hidePool(dots)
  local used=0
  for _,p in ipairs(points or {})do
   local x,y=N.Project(p.mapID,p.x,p.y,mapID)
   if x then x,y=screen(x,y)end
   if x and x>=10 and y>=10 and x<=view:GetWidth()-10 and y<=view:GetHeight()-10 and used<120 then
    used=used+1;local t=markers[used]
    if not t then t=pins:CreateTexture(nil,"ARTWORK");markers[used]=t end
    t:ClearAllPoints();t:SetSize(20,20);t:SetTexture(p.icon or(WoWUExplorer and WoWUExplorer.icons and WoWUExplorer.icons.pois)or 134400)
    t:SetPoint("CENTER",pins,"TOPLEFT",x,-y);t:Show()
   end
  end
  if not(N.GetTrailSetting and N.GetTrailSetting("enabled")and N.GetTrailSetting("minimap"))then return end
  local target=call(N.Destination)
  if not target or not number(target.distance)or target.distance<5 then return end
  local _,_,tx,ty=N.ProjectEndpoints(target,mapID)
  if not tx then return end
  local x,y=screen(tx,ty);if not x then return end
  local cx,cy=view:GetWidth()/2,view:GetHeight()/2
  local dx,dy=x-cx,y-cy
  -- End at the viewport edge, even when the destination is outside this map crop.
  local factor=math.min(1,(cx-8)/math.max(math.abs(dx),.001),(cy-8)/math.max(math.abs(dy),.001))
  dx,dy=dx*factor,dy*factor
  local length=math.sqrt(dx*dx+dy*dy)
  local spacing=math.max(10,N.GetTrailSetting("spacing"),length/100)
  local offset=((GetTime and GetTime()or 0)*N.GetTrailSetting("speed"))%spacing
  local count=0
  for d=offset,length,spacing do
   if length<1 then break end
   count=count+1;local t=dots[count]
   if not t then t=pins:CreateTexture(nil,"OVERLAY");t:SetColorTexture(1,.8,.25,N.GetTrailSetting("opacity"));dots[count]=t end
   t:ClearAllPoints();t:SetColorTexture(1,.8,.25,N.GetTrailSetting("opacity"));t:SetSize(N.GetTrailSetting("size"),N.GetTrailSetting("size"))
   t:SetPoint("CENTER",pins,"TOPLEFT",cx+dx*d/length,-cy-dy*d/length);t:Show()
  end
 end
 local function update(refresh)
  local id=number(call(C_Map and C_Map.GetBestMapForUnit,"player"))
  if not id then unavailable("Your position is unavailable here.");return end
  if id~=mapID or(refresh and not layer)then loadMap(id)end
  if not layer then unavailable("No map artwork available here.");return end
  local pos=call(C_Map and C_Map.GetPlayerMapPosition,mapID,"player")
  px,py=N.Vector(pos)
  if not px then unavailable("Your position is unavailable here.");return end
  if dirty then drawArt()end
  if not aw then return end
  canvas:Show();pins:Show();player:Show();status:SetText("")
  canvas:ClearAllPoints();canvas:SetPoint("TOPLEFT",view,"TOPLEFT",view:GetWidth()/2-px*aw,-view:GetHeight()/2+py*ah)
  local facing=number(call(GetPlayerFacing));player:SetRotation(facing or 0)
  if refresh or not points then
   points=call(WoWUExplorer and WoWUExplorer.Markers,mapID)or {}
  end
  drawMarkers()
 end
 local function changeZoom(delta)
  zoom=math.max(.25,math.min(8,zoom*(delta>0 and 1.25 or .8)));dirty=true;update(false)
 end
 for i,caption in ipairs({"-","+"})do
  local b=CreateFrame("Button",nil,controls,"UIPanelButtonTemplate")
  b:SetSize(44,42);b:SetPoint("LEFT",(i-1)*48,0);b:SetText(caption)
  b:SetScript("OnClick",function()changeZoom(i==1 and -1 or 1)end)
 end
 view:SetScript("OnMouseWheel",function(_,delta)changeZoom(delta)end)
 view:SetScript("OnSizeChanged",function()dirty=true end)
 f:SetScript("OnShow",function()dirty=true;update(true)end)
 f:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;slow=slow+dt
  if elapsed<.1 then return end
  elapsed=0;local refresh=slow>=1;if refresh then slow=0 end
  update(refresh)
 end)
 for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED_INDOORS","MAP_EXPLORATION_UPDATED"})do pcall(f.RegisterEvent,f,event)end
 f:SetScript("OnEvent",function()
  -- Hidden widgets only invalidate their data; they do no map work in the background.
  mapID=nil;dirty=true
  if f:IsVisible()then update(true)end
 end)
 return f
end
