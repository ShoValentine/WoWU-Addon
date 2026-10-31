local N=WoWUNavigation
local defaults={enabled=true,minimap=true,worldmap=true,backToMap=true,size=5,spacing=18,speed=32,opacity=.9}
function N.GetTrailSetting(key)
    local s=N.State();s.trails=s.trails or {}
    local value=s.trails[key];if value==nil then return defaults[key] end;return value
end
function N.SetTrailSetting(key,value)
    if defaults[key]==nil then return end
    local limits={size={2,12},spacing={10,40},speed={0,80},opacity={.2,1}}
    if limits[key] then
        value=tonumber(value);if not value or value~=value then return end
        value=math.max(limits[key][1],math.min(limits[key][2],value))
    else value=value==true end
    local s=N.State();s.trails=s.trails or {};s.trails[key]=value
end
local layers={}
local function layer(key,parent)
    local l=layers[key]
    if l and l.parent~=parent then l.frame:Hide();layers[key]=nil;l=nil end
    if not l then
        local f=CreateFrame("Frame",nil,parent);f.WoWUMapOverlay=true;f:SetAllPoints();f:EnableMouse(false)
        l={frame=f,parent=parent,dots={},shadows={}};layers[key]=l
    end
    local now=GetTime()
    if not l.raisedAt or now-l.raisedAt>.5 then
        local highest=parent:GetFrameLevel()
        local function scan(f,depth)
            if f==l.frame or f.WoWUMapOverlay or depth>5 then return end
            if f.GetFrameLevel then highest=math.max(highest,f:GetFrameLevel()) end
            if f.GetChildren then for _,child in ipairs({f:GetChildren()}) do scan(child,depth+1) end end
        end
        scan(parent,0)
        l.frame:SetFrameStrata(parent:GetFrameStrata())
        l.frame:SetFrameLevel(highest+10);l.raisedAt=now
    end
    l.frame:Show();return l
end
local function hide(key) if layers[key] then layers[key].frame:Hide() end end
local function draw(l,x1,y1,x2,y2,time,scale)
    scale=scale or 1
    local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
    local spacing=math.max(N.GetTrailSetting("spacing")/scale,length/159)
    local size=N.GetTrailSetting("size")/scale
    local offset=(time*N.GetTrailSetting("speed")/scale)%spacing
    local used=0
    if length>1 then
        for d=offset,length,spacing do
            used=used+1;if used>160 then used=160;break end
            local t=l.dots[used]
            if not t then
                t=l.frame:CreateTexture(nil,"OVERLAY",nil,1);t:SetTexture("Interface\\Buttons\\WHITE8X8");l.dots[used]=t
                local shadow=l.frame:CreateTexture(nil,"OVERLAY",nil,0)
                shadow:SetTexture("Interface\\Buttons\\WHITE8X8");l.shadows[used]=shadow
            end
            t:ClearAllPoints();t:SetPoint("TOPLEFT",l.frame,"TOPLEFT",x1+dx*d/length-size/2,-(y1+dy*d/length)+size/2)
            local shadow=l.shadows[used]
            shadow:ClearAllPoints();shadow:SetPoint("CENTER",t,"CENTER",1/scale,-1/scale)
            shadow:SetSize(size+2/scale,size+2/scale);shadow:SetVertexColor(0,0,0,.8*N.GetTrailSetting("opacity"));shadow:Show()
            t:SetSize(size,size);t:SetVertexColor(1,.8,.25,N.GetTrailSetting("opacity"));t:Show()
        end
    end
    for i=used+1,#l.dots do l.dots[i]:Hide();l.shadows[i]:Hide() end
end
-- Clip the geographic segment to the displayed map bounds before drawing.
local function clip(x1,y1,x2,y2)
    local dx,dy=x2-x1,y2-y1;local lo,hi=0,1
    for _,edge in ipairs({{-dx,x1},{dx,1-x1},{-dy,y1},{dy,1-y1}}) do
        local p,q=edge[1],edge[2]
        if p==0 then if q<0 then return end
        else
            local r=q/p
            if p<0 then lo=math.max(lo,r) else hi=math.min(hi,r) end
            if lo>hi then return end
        end
    end
    return x1+dx*lo,y1+dy*lo,x1+dx*hi,y1+dy*hi
end
local function update()
    local t=N.Destination()
    if not N.GetTrailSetting("enabled") or not t or not t.mapID or t.distance<5 then hide("mini");hide("world");return end
    local now=GetTime()
    if N.GetTrailSetting("minimap") and Minimap and Minimap:IsVisible() then
        local radius=N.MinimapRadius()
        if radius and radius>0 then
            local east,north=t.east,t.north
            if GetCVarBool and GetCVarBool("rotateMinimap") then
                local facing=N.Number(GetPlayerFacing())
                if not facing then hide("mini");hide("world");return end
                east,north=east*math.cos(facing)+north*math.sin(facing),north*math.cos(facing)-east*math.sin(facing)
            end
            local w,h=Minimap:GetWidth(),Minimap:GetHeight();local r=math.min(w,h)/2-9
            local factor=math.min(1,radius/t.distance)*r/radius
            draw(layer("mini",Minimap),w/2,h/2,w/2+east*factor,h/2-north*factor,now)
        else hide("mini") end
    else hide("mini") end
    local map=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame
    if N.GetTrailSetting("worldmap") and map and map.WoWUNavigationDocked and map:IsVisible() and map.GetMapID and map.GetCanvas then
        local canvas=map:GetCanvas();local w,h=canvas:GetWidth(),canvas:GetHeight()
        local scale=canvas:GetEffectiveScale()/map:GetEffectiveScale()
        local px,py,x,y=N.ProjectEndpoints(t,map:GetMapID())
        if px then px,py,x,y=clip(px,py,x,y) end
        if px then draw(layer("world",canvas),px*w,py*h,x*w,y*h,now,math.max(.01,scale))
        else hide("world") end
    else hide("world") end
end
local driver=CreateFrame("Frame");local elapsed=0
driver:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<.033 then return end;elapsed=0
    local ok=pcall(update);if not ok then hide("mini");hide("world") end
end)

function WoWU_BuildNavigationSettings(parent)
    local function text(p,caption,size,x,y,width)
        local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
        t:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(t,.94,.80,.50)
        t:SetPoint("TOPLEFT",x,y);t:SetJustifyH("LEFT");t:SetText(caption)
        if width then t:SetWidth(width);t:SetWordWrap(true) end
        return t
    end
    local function button(p,caption,x,y,w,fn)
        local b=CreateFrame("Button",nil,p,"BackdropTemplate");b:SetSize(w,38);b:SetPoint("TOPLEFT",x,y)
        WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13})
        WoWU_Theme.Color(b,.25,.19,.10,1);text(b,caption,15,12,-10)
        b:SetScript("OnClick",fn);return b
    end
    local panel=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    panel:SetAllPoints();panel:SetFrameLevel(parent:GetFrameLevel()+30);panel:EnableMouse(true)
    WoWU_Theme.Backdrop(panel,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=18})
    WoWU_Theme.Color(panel,.06,.08,.09,1)
    text(panel,"Navigation & Ant Trails",23,25,-22)
    button(panel,"Back to Settings",880,-18,190,function() panel:Hide() end)
    local checks={}
    for i,entry in ipairs({{"enabled","Enable ant trails"},{"minimap","Show on minimap"},{"worldmap","Show on world map"},{"backToMap","Show Back to Map shortcut"}}) do
        local key=entry[1];local b=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
        b:SetSize(38,38);b:SetPoint("TOPLEFT",25,-80-(i-1)*48)
        text(panel,entry[2],18,70,-89-(i-1)*48)
        b:SetScript("OnClick",function(self) N.SetTrailSetting(key,self:GetChecked()) end);checks[key]=b
    end
    text(panel,"Direct guidance only: dots do not follow roads or avoid obstacles.\n\nTap a logged quest marker to open its details, then tap Navigate. Trails disappear when accurate positions are unavailable. Minimap trails require the client's view-radius API.",16,460,-88,580)
    local sliders={}
    for i,entry in ipairs({{"size","Dot size",2,12,1},{"spacing","Dot spacing",10,40,1},{"speed","Animation speed",0,80,1},{"opacity","Opacity",.2,1,.05}}) do
        local key=entry[1];local x=35+((i-1)%2)*530;local y=-290-math.floor((i-1)/2)*100
        local caption=text(panel,entry[2],17,x,y)
        local s=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate")
        s:SetPoint("TOPLEFT",x,y-36);s:SetSize(420,22);s:SetMinMaxValues(entry[3],entry[4]);s:SetValueStep(entry[5])
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        s:SetScript("OnValueChanged",function(_,value)
            N.SetTrailSetting(key,value);caption:SetText(entry[2]..": "..string.format(key=="opacity" and "%.2f" or "%.0f",value))
        end);sliders[key]=s
    end
    local status=text(panel,"",16,35,-540,950)
    button(panel,"Stop navigation",35,-495,210,function() local _,msg=N.Stop();status:SetText(msg or "Navigation stopped. Choose a quest and tap Navigate to resume.") end)
    panel:HookScript("OnShow",function()
        for key,b in pairs(checks) do b:SetChecked(N.GetTrailSetting(key)) end
        for key,s in pairs(sliders) do s:SetValue(N.GetTrailSetting(key)) end
        status:SetText("Compass and trails share the active navigation destination.")
    end)
    parent:HookScript("OnHide",function() panel:Hide() end)
    panel:Hide()
    button(parent,"Navigation & Trails",615,-14,240,function() panel:Show() end)
end
