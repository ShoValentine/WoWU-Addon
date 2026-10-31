-- WoWU Map v0.12.9: experimental native WorldMapFrame docking with WoWU skin, external touch controls, and custom renderer fallback.
local function txt(parent, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    WoWU_Theme.TextColor(t,unpack(color or {0.94,0.79,0.51}))
    return t
end
local function button(parent, label, w, h, click)
    local b=CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w,h)
    WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(b,.18,.22,.24,1)
    WoWU_Theme.Border(b,.65,.49,.29,1)
    local l=txt(b,15)
    l:SetPoint("CENTER")
    l:SetText(label)
    b:SetScript("OnClick",click)
    b.label=l
    return b
end

local function WoWU_ApplyWorldMapSkin(map, host)
    if not map then return nil end
    local state = { hidden = {}, seen = {} }

    local function hideObj(obj)
        if not obj then return end
        if not state.seen[obj]then
            local rec = { obj = obj }
            if obj.GetParent then rec.parent = obj:GetParent() end
            if obj.GetAlpha then rec.alpha = obj:GetAlpha() end
            if obj.IsShown then rec.shown = obj:IsShown() end
            state.hidden[#state.hidden+1] = rec;state.seen[obj]=true
        end
        if obj.Hide then pcall(obj.Hide, obj) end
        if obj.SetAlpha then pcall(obj.SetAlpha, obj, 0) end
    end

    local function showObj(obj)
        if not obj then return end
        if obj.SetAlpha then pcall(obj.SetAlpha, obj, 1) end
        if obj.Show then pcall(obj.Show, obj) end
    end

    -- Best-effort hide of Blizzard chrome while preserving map content and quest log.
    local candidates = {
        map.BorderFrame,
        map.InsetFrame,
        map.Bg,
        map.BlackoutFrame,
        map.NineSlice,
        map.Border,
        map.Header,
        map.MiniBorderFrame,
        map.MaximizeMinimizeFrame,
        _G.WorldMapFrameBg,
        _G.WorldMapFrameBorderFrame,
        _G.WorldMapFrameInsetFrame,
        _G.WorldMapFrameNavBarBackground,
    }
    -- Optional members leave holes in this table on Classic. ipairs stops at
    -- the first missing Retail member, leaving later Classic chrome visible.
    for _, obj in pairs(candidates) do hideObj(obj) end
    if WoWUClient and WoWUClient.isClassic then hideObj(_G.WorldMapTitleButton)end
    if WoWUClient and WoWUClient.isRetail then
        state.HideRetailChrome=function()
            for _,obj in pairs({map.NavBar,map.navBar,map.MapDropdown,map.FloorDropdown,map.WorldMapTrackingOptionsButton,map.WorldMapTrackingPinButton,_G.WorldMapFrameNavBar,_G.WorldMapFrameNavBarBackground})do hideObj(obj)end
            local canvas=map.GetCanvasContainer and map:GetCanvasContainer()or map.ScrollContainer
            for _,obj in ipairs(map.overlayFrames or {})do
                -- Retail creates its floor dropdown anonymously on the canvas.
                if obj.SetupMenu and obj.GetPoint then
                    local point,relative=obj:GetPoint(1)
                    if point=="TOPLEFT"and relative==canvas then hideObj(obj)end
                end
            end
        end
        state.HideRetailChrome()
    end

    -- Hide title text and close/maximize buttons if present.
    if map.BorderFrame then
        hideObj(map.BorderFrame.TitleText)
        hideObj(map.BorderFrame.CloseButton)
        hideObj(map.BorderFrame.MaximizeMinimizeFrame)
        hideObj(map.BorderFrame.Tutorial)
    end
    hideObj(_G.WorldMapFrameCloseButton)

    -- Give WoWU-style frame around the whole map and soft dark backing.
    local skin = CreateFrame("Frame", nil, host, "BackdropTemplate")
    skin:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    skin:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    skin:SetFrameLevel((map.GetFrameLevel and map:GetFrameLevel()) and (map:GetFrameLevel()-1) or host:GetFrameLevel())
    WoWU_Theme.Backdrop(skin,{
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    WoWU_Theme.Color(skin,0.07, 0.10, 0.12, 0.96)
    WoWU_Theme.Border(skin,0.62, 0.47, 0.28, 1)

    local topBand = skin:CreateTexture(nil, "BORDER")
    topBand:SetColorTexture(0.11, 0.14, 0.17, 0.95)
    topBand:SetPoint("TOPLEFT", skin, "TOPLEFT", 3, -3)
    topBand:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -3, -3)
    topBand:SetHeight(42)

    local title = txt(skin, 18)
    title:SetPoint("TOP", skin, "TOP", 0, -14)
    title:SetText("Map")
    if WoWUClient and WoWUClient.isRetail then topBand:Hide();title:Hide()end

    state.skin = skin
    state.title = title

    -- Try to tuck the map neatly into the skinned host.
    pcall(function()
        map:ClearAllPoints()
        map:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -6)
        map:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -6, 6)
    end)

    return state
end

local function WoWU_RestoreWorldMapSkin(map, state)
    if not state then return end
    if state.skin then pcall(state.skin.Hide, state.skin) end
    if state.hidden then
        for _, rec in ipairs(state.hidden) do
            if rec.obj then
                if rec.alpha and rec.obj.SetAlpha then pcall(rec.obj.SetAlpha, rec.obj, rec.alpha) end
                if rec.shown and rec.obj.Show then pcall(rec.obj.Show, rec.obj) end
            end
        end
    end
end

function WoWU_BuildMap(panel)
    local host=CreateFrame("Frame",nil,panel)
    host:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
    host:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-312,0)
    if WoWU_BuildExplorer then WoWU_BuildExplorer(panel) end
    local fallback=CreateFrame("Frame",nil,host)
    fallback:SetAllPoints(host)
    -- Original map renderer stays intact, but is hidden while native docking works.
    panel=fallback
    local mapID,zoom,tiles,selectedParent= nil,1,{},nil
    local panX,panY=0,0
    local exploredTiles,exploredHover={},{}
    local artWidth,artHeight
    local header=CreateFrame("Frame",nil,panel)
    header:SetPoint("TOPLEFT",14,-12)
    header:SetPoint("TOPRIGHT",-14,-12)
    header:SetHeight(42)
    local zone=txt(header,18)
    zone:SetPoint("LEFT",header,"LEFT",5,0)
    zone:SetWidth(430)
    zone:SetJustifyH("LEFT")
    local viewport=CreateFrame("Frame",nil,panel)
    viewport:SetPoint("TOPLEFT",14,-65)
    viewport:SetPoint("BOTTOMRIGHT",-14,14)
    viewport:SetClipsChildren(true)
    viewport:EnableMouse(true)
    local backdrop=viewport:CreateTexture(nil,"BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(.08,.11,.13,1)
    local canvas=CreateFrame("Frame",nil,viewport)
    canvas:SetPoint("CENTER")
    local status=txt(viewport,17,{.9,.8,.65})
    status:SetPoint("CENTER")
    status:SetText("Map loading...")
    local pin=CreateFrame("Frame",nil,canvas)
    pin:SetSize(22,22)
    local pt=pin:CreateTexture(nil,"OVERLAY")
    pt:SetAllPoints()
    pt:SetTexture("Interface\\Minimap\\MinimapArrow")
    pin:Hide()
    local function updatePlayer()
        pin:Hide()
        if not mapID or not C_Map or not C_Map.GetPlayerMapPosition then return end
        local pos=C_Map.GetPlayerMapPosition(mapID,"player")
        if pos and pos.GetXY then
            local x,y=pos:GetXY()
            if type(x)=="number"and type(y)=="number"and x>=0 and x<=1 and y>=0 and y<=1 then
                pin:ClearAllPoints();pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight())
                local facing=GetPlayerFacing and GetPlayerFacing();if facing then pt:SetRotation(facing)end
                pin:Show()
            end
        end
    end
    local function clearTiles()
        for _,tile in ipairs(tiles) do tile:Hide();tile:ClearAllPoints() end
        for _,tile in ipairs(exploredTiles)do tile:Hide();tile:ClearAllPoints()end
        exploredHover={}
    end
    local function explored(layer,scale)
        local api=C_MapExplorationInfo
        if not(api and api.GetExploredMapTextures)then return end
        local ok,regions=pcall(api.GetExploredMapTextures,mapID)
        if not ok or type(regions)~="table"then return end
        local used=0
        local function edgeSize(n)local value=16;while value<n do value=value*2 end;return value end
        for _,region in ipairs(regions)do
            local w,h=region.textureWidth,region.textureHeight
            if type(w)=="number"and type(h)=="number"and w>0 and h>0 and type(region.fileDataIDs)=="table"then
                local columns,rows=math.ceil(w/layer.tileWidth),math.ceil(h/layer.tileHeight)
                local hover=region.isShownByMouseOver and {rect=region.hitRect,tiles={}}or nil
                for i,file in ipairs(region.fileDataIDs)do
                    if i>columns*rows then break end
                    local col,row=(i-1)%columns,math.floor((i-1)/columns)
                    local pw,ph=math.min(layer.tileWidth,w-col*layer.tileWidth),math.min(layer.tileHeight,h-row*layer.tileHeight)
                    local fw=col==columns-1 and edgeSize(pw)or layer.tileWidth
                    local fh=row==rows-1 and edgeSize(ph)or layer.tileHeight
                    used=used+1;local t=exploredTiles[used]
                    if not t then t=canvas:CreateTexture(nil,"ARTWORK",nil,1);exploredTiles[used]=t end
                    t:SetDrawLayer("ARTWORK",region.isDrawOnTopLayer and 2 or 1)
                    t:SetPoint("TOPLEFT",canvas,"TOPLEFT",((region.offsetX or 0)+col*layer.tileWidth)*scale,-((region.offsetY or 0)+row*layer.tileHeight)*scale)
                    t:SetSize(pw*scale,ph*scale);t:SetTexture(file)
                    t:SetTexCoord(0,pw/fw,0,ph/fh)
                    t:SetShown(not hover)
                    if hover then hover.tiles[#hover.tiles+1]=t end
                end
                if hover then exploredHover[#exploredHover+1]=hover end
            end
        end
    end
    local function draw()
        if not mapID or not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then
            status:SetText("Map art API unavailable on this build.");return
        end
        local ok,layers=pcall(C_Map.GetMapArtLayers,mapID)
        local layer=ok and layers and layers[1]
        if not layer or not layer.tileWidth or not layer.tileHeight or not layer.layerWidth or not layer.layerHeight then
            status:SetText("No map artwork available for this region.");clearTiles();return
        end
        local good,files=pcall(C_Map.GetMapArtLayerTextures,mapID,1)
        if not good or type(files)~="table" or #files==0 then
            status:SetText("Map tiles unavailable.");clearTiles();return
        end
        clearTiles()
        local vw,vh=viewport:GetWidth(),viewport:GetHeight()
        if vw<10 or vh<10 then return end
        local scale=math.min(vw/layer.layerWidth,vh/layer.layerHeight)*zoom
        local aw,ah=layer.layerWidth*scale,layer.layerHeight*scale
        artWidth,artHeight=layer.layerWidth,layer.layerHeight
        canvas:SetSize(aw,ah)
        panX=math.max(-math.max(0,(aw-vw)/2),math.min(math.max(0,(aw-vw)/2),panX))
        panY=math.max(-math.max(0,(ah-vh)/2),math.min(math.max(0,(ah-vh)/2),panY))
        canvas:ClearAllPoints();canvas:SetPoint("CENTER",viewport,"CENTER",panX,panY)
        local cols=math.ceil(layer.layerWidth/layer.tileWidth)
        local rows=math.ceil(layer.layerHeight/layer.tileHeight)
        -- Blizzard provides artwork in row-major tile order.
        for i=1,math.min(#files,cols*rows) do
            local col=(i-1)%cols
            local row=math.floor((i-1)/cols)
            local pixelW=math.min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth)
            local pixelH=math.min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
            local t=tiles[i]
            if not t then t=canvas:CreateTexture(nil,"ARTWORK");tiles[i]=t end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT",canvas,"TOPLEFT",col*layer.tileWidth*scale,-row*layer.tileHeight*scale)
            t:SetSize(pixelW*scale,pixelH*scale)
            t:SetTexture(files[i])
            t:SetTexCoord(0,pixelW/layer.tileWidth,0,pixelH/layer.tileHeight)
            t:Show()
        end
        explored(layer,scale)
        status:SetText("")
        updatePlayer()
    end
    local function changeMap(id)
        if not id or not C_Map or not C_Map.GetMapInfo then return end
        local ok,info=pcall(C_Map.GetMapInfo,id)
        if not ok or not info then return end
        mapID=id;zoom=1;panX,panY=0,0
        zone:SetText(info.name or ("Map "..id))
        selectedParent=info.parentMapID
        if WoWUDB then WoWUDB.mapID=id end
        draw()
    end
    local back=button(header,"Parent",105,32,function()
        if selectedParent and selectedParent>0 then changeMap(selectedParent) end
    end)
    back:SetPoint("RIGHT",header,"RIGHT",-319,0)
    local here=button(header,"My Zone",105,32,function()
        if C_Map and C_Map.GetBestMapForUnit then changeMap(C_Map.GetBestMapForUnit("player")) end
    end)
    here:SetPoint("LEFT",back,"RIGHT",6,0)
    local minus=button(header,"-",45,32,function() zoom=math.max(1,zoom/1.25);draw() end)
    minus:SetPoint("LEFT",here,"RIGHT",6,0)
    local plus=button(header,"+",45,32,function() zoom=math.min(3,zoom*1.25);draw() end)
    plus:SetPoint("LEFT",minus,"RIGHT",6,0)
    local list=button(header,"Zones",100,32,function() end)
    list:SetPoint("LEFT",plus,"RIGHT",6,0)
    local menu=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    menu:SetSize(250,350)
    menu:SetPoint("TOPRIGHT",list,"BOTTOMRIGHT",0,-3)
    menu:SetFrameLevel(panel:GetFrameLevel()+15)
    WoWU_Theme.Backdrop(menu,{bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=15,insets={left=4,right=4,top=4,bottom=4}})
    menu:Hide()
    local menuScroll=CreateFrame("ScrollFrame",nil,menu,"UIPanelScrollFrameTemplate")
    menuScroll:SetPoint("TOPLEFT",8,-8);menuScroll:SetPoint("BOTTOMRIGHT",-28,8)
    local menuBody=CreateFrame("Frame",nil,menuScroll);menuBody:SetSize(212,1);menuScroll:SetScrollChild(menuBody)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(menuScroll)end
    list:SetScript("OnClick",function()
        if menu:IsShown() then menu:Hide();return end
        local choices={}
        if C_Map and C_Map.GetMapChildrenInfo and mapID then
            local ok,children=pcall(C_Map.GetMapChildrenInfo,mapID)
            if ok and type(children)=="table" then
                for _,entry in ipairs(children) do choices[#choices+1]=entry end
            end
        end
        table.sort(choices,function(a,b)return(a.name or '')<(b.name or '')end)
        for i=1,math.max(#choices,menu.itemCount or 0)do
            local b=menu["item"..i]
            if not b then
                b=button(menuBody,"",212,29,function(self)if not WoWU_TouchTapAllowed or WoWU_TouchTapAllowed(menuScroll)then changeMap(self.mapID);menu:Hide()end end)
                b:SetPoint("TOPLEFT",0,-(i-1)*31)
                menu["item"..i]=b
            end
            local item=choices[i]
            if item then b.mapID=item.mapID;b.label:SetText(item.name or tostring(item.mapID));b:Show() else b:Hide() end
        end
        menu.itemCount=#choices;menuBody:SetHeight(math.max(1,#choices*31));menuScroll:SetVerticalScroll(0)
        if #choices==0 then zone:SetText("No subzones found");return end
        menu:Show()
    end)
    viewport:EnableMouseWheel(true)
    local function wheel(_,delta)
        zoom=math.max(1,math.min(3,zoom*(delta>0 and 1.25 or .8)))
        draw()
    end
    viewport:SetScript("OnMouseWheel",wheel);viewport.OnMouseWheel=wheel
    local drag
    viewport.WoWUStopPan=function()drag=nil end
    local function mouseDown(_,mouse)
        if mouse=="LeftButton"then local x,y=GetCursorPosition();drag={x=x,y=y,px=panX,py=panY,moved=false}end
    end
    viewport:SetScript("OnMouseDown",mouseDown);viewport.OnMouseDown=mouseDown
    local function normalized()
        local x,y=GetCursorPosition();local scale=canvas:GetEffectiveScale()
        local l,t=canvas:GetLeft(),canvas:GetTop();if not l or not t then return end
        return(x/scale-l)/canvas:GetWidth(),(t-y/scale)/canvas:GetHeight()
    end
    viewport:SetScript("OnMouseUp",function(_,mouse)
        local previous=drag;drag=nil
        if mouse=="RightButton"then if selectedParent and selectedParent>0 then changeMap(selectedParent)end;return end
        if previous and previous.moved then return end
        if mouse~="LeftButton" or not mapID or not C_Map or not C_Map.GetMapInfoAtPosition then return end
        local rx,ry=normalized();if not rx then return end
        if rx<0 or rx>1 or ry<0 or ry>1 then return end
        local ok,info=pcall(C_Map.GetMapInfoAtPosition,mapID,rx,ry)
        if ok and info and info.mapID and info.mapID~=mapID then changeMap(info.mapID) end
    end)
    local playerElapsed=0
    viewport:HookScript("OnUpdate",function(_,dt)
        if drag then
            if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton")then drag=nil
            else
                local x,y=GetCursorPosition();local scale=viewport:GetEffectiveScale()
                local dx,dy=(x-drag.x)/scale,(y-drag.y)/scale
                if dx*dx+dy*dy>100 then drag.moved=true end
                if drag.moved then
                    panX=drag.px+dx;panY=drag.py+dy
                    local maxX,maxY=math.max(0,(canvas:GetWidth()-viewport:GetWidth())/2),math.max(0,(canvas:GetHeight()-viewport:GetHeight())/2)
                    panX=math.max(-maxX,math.min(maxX,panX));panY=math.max(-maxY,math.min(maxY,panY))
                    canvas:ClearAllPoints();canvas:SetPoint("CENTER",viewport,"CENTER",panX,panY)
                end
            end
        end
        playerElapsed=playerElapsed+dt;if playerElapsed>=.1 then
            playerElapsed=0;updatePlayer()
            local x,y=normalized()
            local over=viewport:IsMouseOver()and x and y and artWidth and artHeight
            for _,region in ipairs(exploredHover)do
                local r=region.rect
                local show=over and r and x*artWidth>=r.left and x*artWidth<=r.right and y*artHeight>=r.top and y*artHeight<=r.bottom
                for _,t in ipairs(region.tiles)do t:SetShown(not not show)end
            end
        end
    end)
    viewport:HookScript("OnHide",function()drag=nil end)
    viewport:SetScript("OnSizeChanged",function() if mapID then draw() end end)
    local events=CreateFrame("Frame",nil,panel)
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(events.RegisterEvent,events,"MAP_EXPLORATION_UPDATED")
    events:SetScript("OnEvent",function() if panel:IsShown() then draw() end end)
    panel:HookScript("OnShow",function()
        if not mapID then
            local chosen=WoWUDB and WoWUDB.mapID
            if not chosen and C_Map and C_Map.GetBestMapForUnit then chosen=C_Map.GetBestMapForUnit("player") end
            if not chosen and C_Map and C_Map.GetFallbackWorldMapID then chosen=C_Map.GetFallbackWorldMapID() end
            changeMap(chosen)
        else draw() end
    end)
    if WoWUClient and WoWUClient.isClassic then
        -- Classic's native minimized/maximized WorldMap layout keeps resizing
        -- its root/canvas. Use the owned tile canvas; never dock that frame.
        fallback.ScrollContainer=viewport;fallback.WoWUNavigationDocked=true
        fallback.GetMapID=function()return mapID end
        fallback.SetMapID=function(_,id)changeMap(id)end
        fallback.GetCanvas=function()return canvas end
        fallback.GetNormalizedCursorPosition=normalized
        if WoWUMistsQuests then WoWUMistsQuests.Attach(fallback)end
        function WoWU_GetActiveMap()return fallback end
        function WoWU_ResetMapPosition()
            panX,panY=0,0;zoom=1;draw();return true,"Classic map position reset."
        end
        header:HookScript("OnSizeChanged",function()zone:SetWidth(math.max(100,header:GetWidth()-440))end)
        zone:SetWidth(math.max(100,header:GetWidth()-440))
        return
    end

    -- Experimental Blizzard world map embedding. Do not force protected frames.
    local docked, original, skinState = false, nil, nil
    local dockScale, pendingLayout, layoutElapsed = nil, false, 0
    local dockWidth,dockHeight
    local notice=txt(host,15,{.92,.78,.51})
    notice:SetPoint("TOP",host,"TOP",0,-18)
    notice:SetText("")
    local nativeHost=CreateFrame("Frame",nil,host)
    nativeHost:SetPoint("TOPLEFT",host,"TOPLEFT",9,-9)
    nativeHost:SetPoint("BOTTOMRIGHT",host,"BOTTOMRIGHT",-65,9)
    local nativeBackdrop=CreateFrame("Frame",nil,nativeHost,"BackdropTemplate")
    nativeBackdrop:SetAllPoints(nativeHost)
    WoWU_Theme.Backdrop(nativeBackdrop,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Color(nativeBackdrop,.07,.10,.12,.96)
    WoWU_Theme.Border(nativeBackdrop,.62,.47,.28,1)
    nativeBackdrop:Hide()

    -- Touch-sized controls outside the live native map. Only shown after docking.
    local touchControls=CreateFrame("Frame",nil,host,"BackdropTemplate")
    touchControls:SetSize(48,166)
    touchControls:SetPoint("CENTER",nativeHost,"RIGHT",33,0)
    WoWU_Theme.Backdrop(touchControls,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(touchControls,.10,.14,.17,.97)
    WoWU_Theme.Border(touchControls,.64,.48,.27,1)
    touchControls:Hide()

    local function nativeZoom(delta)
        local map=_G.WorldMapFrame
        local scroll=map and map.ScrollContainer
        if not scroll then return end
        -- Same input path as mouse-wheel zoom, keeping Blizzard's map logic.
        if scroll.OnMouseWheel then
            pcall(scroll.OnMouseWheel,scroll,delta)
        else
            local wheel=scroll:GetScript("OnMouseWheel")
            if wheel then pcall(wheel,scroll,delta) end
        end
    end
    local function nativeParent()
        local map=_G.WorldMapFrame
        if not map or not C_Map or not C_Map.GetMapInfo then return end
        local mapID=(map.GetMapID and map:GetMapID()) or (map.ScrollContainer and map.ScrollContainer.GetMapID and map.ScrollContainer:GetMapID())
        if not mapID then return end
        local info=C_Map.GetMapInfo(mapID)
        if info and info.parentMapID and info.parentMapID>0 and map.SetMapID then
            pcall(map.SetMapID,map,info.parentMapID)
        end
    end
    local function touchButton(index,label,up,down,fn)
        local b=CreateFrame("Button",nil,touchControls,"BackdropTemplate")
        b:SetSize(38,44)
        b:SetPoint("TOP",touchControls,"TOP",0,-8-(index-1)*50)
        WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
        WoWU_Theme.Color(b,.16,.21,.24,1)
        WoWU_Theme.Border(b,.68,.52,.32,1)
        -- These are Blizzard's built-in button textures, not custom image assets.
        local image=b:CreateTexture(nil,"ARTWORK")
        image:SetSize(28,28);image:SetPoint("CENTER")
        image:SetTexture(up)
        local pressed=b:CreateTexture(nil,"ARTWORK")
        pressed:SetSize(28,28);pressed:SetPoint("CENTER")
        pressed:SetTexture(down)
        pressed:Hide()
        b:SetScript("OnMouseDown",function() image:Hide();pressed:Show() end)
        b:SetScript("OnMouseUp",function() pressed:Hide();image:Show() end)
        b:SetScript("OnClick",fn)
        b:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(label);GameTooltip:Show() end
        end)
        b:SetScript("OnLeave",function() pressed:Hide();image:Show();if GameTooltip then GameTooltip:Hide() end end)
        return b
    end

    touchButton(1,"Parent map","Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up","Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down",nativeParent)
    touchButton(2,"Zoom in","Interface\\Buttons\\UI-PlusButton-Up","Interface\\Buttons\\UI-PlusButton-Down",function() nativeZoom(1) end)
    touchButton(3,"Zoom out","Interface\\Buttons\\UI-MinusButton-Up","Interface\\Buttons\\UI-MinusButton-Down",function() nativeZoom(-1) end)

    local function restoreGeometry(map,state)
        map:ClearAllPoints()
        map:SetParent(state.parent or UIParent)
        if state.ignoreParentScale~=nil then map:SetIgnoreParentScale(state.ignoreParentScale) end
        if state.clampedToScreen~=nil then map:SetClampedToScreen(state.clampedToScreen) end
        map:SetSize(state.w,state.h)
        map:SetScale(state.scale)
        for _,a in ipairs(state.points or {}) do map:SetPoint(unpack(a)) end
        if state.canvas then
            local s=state.canvas;local f=map.ScrollContainer
            f:ClearAllPoints();f:SetSize(s.w,s.h)
            for _,a in ipairs(s.points)do f:SetPoint(unpack(a))end
            if map.OnFrameSizeChanged then map:OnFrameSizeChanged()end
        end
    end

    local function restoreNative()
        if not docked then return end
        local map=original and original.frame
        if map and not (InCombatLockdown and InCombatLockdown()) then
            local ok=pcall(function()
                if WoWU_EndMapNavigation then WoWU_EndMapNavigation(map) end
                WoWU_RestoreWorldMapSkin(map, skinState)
                skinState=nil
                nativeBackdrop:Hide()
                touchControls:Hide()
                map:Hide()
                restoreGeometry(map,original)
                -- Do not reopen Blizzard's map after leaving WoWU.
            end)
            if not ok then return end
        else
            return
        end
        docked=false
        original=nil
        dockScale=nil;pendingLayout=false
        dockWidth=nil;dockHeight=nil
        fallback:Show()
    end

    local function positionNative(map)
        -- Stop a frame drag before replacing its anchors. Map-canvas panning
        -- belongs to ScrollContainer and is deliberately left alone.
        if map.StopMovingOrSizing then map:StopMovingOrSizing() end
        if map:GetParent()~=nativeHost then map:SetParent(nativeHost) end
        -- Dock and map must use the same coordinate space at every UI scale.
        -- Snapshot/restore these flags so the standalone native map is unchanged.
        if map.SetIgnoreParentScale and map.IsIgnoringParentScale then map:SetIgnoreParentScale(false) end
        if map.SetClampedToScreen and map.IsClampedToScreen then map:SetClampedToScreen(false) end
        map:ClearAllPoints()
        map:SetScale(1)
        map:SetSize(math.max(1,nativeHost:GetWidth()-12),math.max(1,nativeHost:GetHeight()-12))
        map:SetPoint("TOPLEFT",nativeHost,"TOPLEFT",6,-6)
        map:SetPoint("BOTTOMRIGHT",nativeHost,"BOTTOMRIGHT",-6,6)
        if WoWUClient and (WoWUClient.isClassic or WoWUClient.isRetail) and map.ScrollContainer then
            -- Era's minimized-map canvas/chrome keeps fixed native offsets.
            -- Fit the live canvas separately; its pins retain their own zoom.
            local f=map.ScrollContainer
            local left,top,right,bottom=WoWU_GetMapCanvasInsets()
            f:ClearAllPoints();f:SetPoint("TOPLEFT",map,"TOPLEFT",left,-top)
            f:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",-right,bottom)
            if map.MiniBorderFrame then map.MiniBorderFrame:Hide()end
            if map.MaximizeMinimizeFrame then map.MaximizeMinimizeFrame:Hide()end
            if WorldMapTitleButton then WorldMapTitleButton:Hide()end
        end
    end

    local function tryNative(force)
        if InCombatLockdown and InCombatLockdown() then
            return false,"Map position cannot be reset during combat. Try again after combat."
        end
        if docked and force~=true then return true end
        local map=_G.WorldMapFrame
        if not map then
            notice:SetText("Blizzard map is not loaded; using WoWU map.")
            fallback:Show();return false,"Blizzard's map is not loaded. Try opening the map first."
        end
        if map.IsProtected and map:IsProtected() then
            notice:SetText("Native map is protected; using WoWU map.")
            fallback:Show();return false,"The client is protecting the map frame. Try /reload."
        end
        -- A forced reset must retain the original undocked position, not save
        -- the escaped/docked position as the new restore target.
        local state=original
        if not state then
            state={frame=map,parent=map:GetParent(),w=map:GetWidth(),h=map:GetHeight(),scale=map:GetScale(),points={}}
            if map.IsIgnoringParentScale and map.SetIgnoreParentScale then state.ignoreParentScale=map:IsIgnoringParentScale() end
            if map.IsClampedToScreen and map.SetClampedToScreen then state.clampedToScreen=map:IsClampedToScreen() end
            for i=1,map:GetNumPoints() do state.points[i]={map:GetPoint(i)} end
            if WoWUClient and (WoWUClient.isClassic or WoWUClient.isRetail) and map.ScrollContainer then
                local f=map.ScrollContainer;state.canvas={w=f:GetWidth(),h=f:GetHeight(),points={}}
                for i=1,f:GetNumPoints()do state.canvas.points[i]={f:GetPoint(i)}end
            end
        end
        -- Frame artwork, pins, map controls and zoom stay Blizzard-owned.
        local ok=pcall(function()
            positionNative(map)
            nativeBackdrop:Show()
            if not skinState then
                skinState=WoWU_ApplyWorldMapSkin(map, nativeHost)
            else
                -- Reuse the skin and its original chrome snapshot on repeated resets.
                if skinState.skin then skinState.skin:Show() end
                for _,rec in ipairs(skinState.hidden or {}) do
                    if rec.obj.Hide then rec.obj:Hide() end
                    if rec.obj.SetAlpha then rec.obj:SetAlpha(0) end
                end
            end
            map:Show()
            -- Blizzard/addon OnShow handlers can move the window; anchor last.
            positionNative(map)
            if map.OnFrameSizeChanged then map:OnFrameSizeChanged() end
        end)
        if not ok then
            pcall(function()
                if WoWU_EndMapNavigation then WoWU_EndMapNavigation(map) end
                WoWU_RestoreWorldMapSkin(map, skinState)
                skinState=nil
                nativeBackdrop:Hide()
                touchControls:Hide()
                map:Hide();restoreGeometry(map,state)
            end)
            docked=false;original=nil
            notice:SetText("Native map docking was rejected; using WoWU map.")
            fallback:Show();return false,"Map docking was rejected by the client. Try /reload."
        end
        docked=true;original=state
        if WoWU_BeginMapNavigation then WoWU_BeginMapNavigation(map) end
        dockScale=nativeHost:GetEffectiveScale()
        dockWidth,dockHeight=nativeHost:GetWidth(),nativeHost:GetHeight()
        pendingLayout=true
        if WoWU_BindMapQuestTouch then
            WoWU_BindMapQuestTouch(map,nativeHost,function() return docked end)
        end
        touchControls:Show()
        notice:SetText("")
        fallback:Hide()
        return true,"Map position reset."
    end
    function WoWU_ResetMapPosition()
        -- Check before changing tabs so a failed request stays beside its feedback.
        if InCombatLockdown and InCombatLockdown() then
            return false,"Map position cannot be reset during combat. Try again after combat."
        end
        local map=_G.WorldMapFrame
        if not map then return false,"Blizzard's map is not loaded. Try opening the map first." end
        if map.IsProtected and map:IsProtected() then
            return false,"The client is protecting the map frame. Try /reload."
        end
        if WoWU_ShowPage then WoWU_ShowPage("Map") end
        return tryNative(true)
    end
    local function closeEnough(a,b) return a and b and math.abs(a-b)<0.5 end
    local function matchesDock(map)
        if WoWUClient and (WoWUClient.isClassic or WoWUClient.isRetail) and map.ScrollContainer then
            local f=map.ScrollContainer
            local left,top,right,bottom=WoWU_GetMapCanvasInsets()
            if not closeEnough(f:GetWidth(),map:GetWidth()-left-right)or not closeEnough(f:GetHeight(),map:GetHeight()-top-bottom)then return false end
            if f:GetNumPoints()~=2 then return false end
            local corners={}
            for i=1,2 do
                local p,relative,to,x,y=f:GetPoint(i)
                if relative~=map or p~=to then return false end
                if p=="TOPLEFT"and closeEnough(x,left)and closeEnough(y,-top)then corners.top=true
                elseif p=="BOTTOMRIGHT"and closeEnough(x,-right)and closeEnough(y,bottom)then corners.bottom=true end
            end
            if not(corners.top and corners.bottom)then return false end
            if map.MiniBorderFrame and map.MiniBorderFrame:IsShown()then return false end
        end
        if map:GetParent()~=nativeHost or math.abs(map:GetScale()-1)>0.0001 then return false end
        if map.IsIgnoringParentScale and map:IsIgnoringParentScale() then return false end
        if map.IsClampedToScreen and map:IsClampedToScreen() then return false end
        if not closeEnough(map:GetWidth(),nativeHost:GetWidth()-12) or
            not closeEnough(map:GetHeight(),nativeHost:GetHeight()-12) then return false end
        if map:GetNumPoints()~=2 then return false end
        local corners={}
        for i=1,2 do
            local point,relative,relativePoint,x,y=map:GetPoint(i)
            if relative~=nativeHost or relativePoint~=point then return false end
            if point=="TOPLEFT" and closeEnough(x,6) and closeEnough(y,-6) then corners.TOPLEFT=true
            elseif point=="BOTTOMRIGHT" and closeEnough(x,-6) and closeEnough(y,6) then corners.BOTTOMRIGHT=true
            else return false end
        end
        return corners.TOPLEFT and corners.BOTTOMRIGHT
    end
    local function reconcileNative()
        if not docked or not original or not host:IsVisible() then return end
        if InCombatLockdown and InCombatLockdown() then return end
        local map=original.frame
        if skinState and skinState.HideRetailChrome then skinState.HideRetailChrome()end
        if WoWUClient and WoWUClient.isClassic and skinState and skinState.title and C_Map then
            local info=C_Map.GetMapInfo(map:GetMapID())
            skinState.title:SetText(info and info.name or "Map")
        end
        if (map.IsForbidden and map:IsForbidden()) or (map.IsProtected and map:IsProtected()) then return end
        if nativeHost:GetWidth()<=12 or nativeHost:GetHeight()<=12 then return end
        local scale=nativeHost:GetEffectiveScale()
        local moved=not matchesDock(map)
        local rescaled=not dockScale or math.abs(scale-dockScale)>0.0001
        -- Two-corner anchors can resize the frame without changing its points.
        -- The canvas still needs its native size-change callback in that case.
        local resized=not closeEnough(dockWidth,nativeHost:GetWidth()) or
            not closeEnough(dockHeight,nativeHost:GetHeight())
        if not moved and not rescaled and not resized then pendingLayout=false;return end
        local ok=pcall(function()
            if moved then positionNative(map) end
            -- Refresh native layout after a scale/size change without reopening
            -- the map (OnShow changes the selected map and resets canvas zoom).
            if map.OnFrameSizeChanged then map:OnFrameSizeChanged() end
        end)
        if ok then
            dockScale=scale
            dockWidth,dockHeight=nativeHost:GetWidth(),nativeHost:GetHeight()
            notice:SetText("")
        else
            notice:SetText("Map alignment could not be updated. Use Settings > Reset Map Position.")
        end
        pendingLayout=false
    end
    local function requestLayout() pendingLayout=true end
    host:HookScript("OnShow",function() tryNative();requestLayout() end)
    host:HookScript("OnHide",restoreNative)
    nativeHost:HookScript("OnSizeChanged",requestLayout)
    local gate=CreateFrame("Frame",nil,host)
    gate:RegisterEvent("PLAYER_REGEN_ENABLED")
    gate:RegisterEvent("UI_SCALE_CHANGED")
    gate:RegisterEvent("DISPLAY_SIZE_CHANGED")
    gate:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_ENABLED" then
            if not host:IsVisible() then restoreNative();return end
            if not docked then tryNative()
            elseif WoWU_BindMapQuestTouch then
                WoWU_BindMapQuestTouch(_G.WorldMapFrame,nativeHost,function() return docked end)
            end
        end
        -- Run after Blizzard's handlers, regardless of event delivery order.
        requestLayout()
    end)
    gate:SetScript("OnUpdate",function(_,elapsed)
        if not docked or not host:IsVisible() or (InCombatLockdown and InCombatLockdown()) then return end
        layoutElapsed=layoutElapsed+elapsed
        if not pendingLayout and layoutElapsed<0.2 then return end
        layoutElapsed=0
        -- Also catches /wowu scale and delayed native/addon anchor rewrites.
        -- Stable frames are only inspected; their anchors are not rewritten.
        reconcileNative()
    end)
end
