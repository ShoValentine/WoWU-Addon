-- WoWU Gilded Stone. Bundled Blizzard artwork from Gethe/wow-ui-textures.
-- This module only decorates explicitly supplied WoWU frames. No global hooks,
-- frame discovery, input handlers, reparenting, or protected action attributes.
WoWU_Theme = {}
local T = WoWU_Theme
local root = "Interface\\AddOns\\WoWU\\Textures\\Gilded\\"
T.assets = {
    stone=root.."Stone", marble=root.."Marble", gold=root.."GoldBorder",
    border=root.."InsetBorder", corner=root.."GoldCorner", divider=root.."Divider",
    amber=root.."Amber", highlight=root.."Highlight", slot=root.."EmptySlot",
    rim=root.."IconRim", pressed=root.."Pressed", statusbar=root.."StatusBar",
    thumb=root.."ScrollThumb", up=root.."ScrollUp", upDown=root.."ScrollUpDown",
    down=root.."ScrollDown", downDown=root.."ScrollDownDown",
}
local A=T.assets
function T.Initialize()
    local prefs=WoWUDB and WoWUDB.preferences or {}
    T.leather=prefs.surfaceTheme=="collections";T.light=prefs.surfaceTheme=="parchment";T.silver=prefs.frameTheme=="silver"
    local surfaces={stone=root.."Stone",parchment=root.."Parchment",marble=root.."Marble",dialog="Interface\\DialogFrame\\UI-DialogBox-Background",plain="Interface\\Buttons\\WHITE8X8"}
    A.stone=surfaces[prefs.surfaceTheme] or root.."Stone";A.marble=A.stone
    T.surface=prefs.surfaceTheme or "stone"
    if T.silver then
        for key,name in pairs({gold="GoldBorder",border="InsetBorder",corner="GoldCorner",divider="Divider",rim="IconRim",thumb="ScrollThumb",up="ScrollUp",upDown="ScrollUpDown",down="ScrollDown",downDown="ScrollDownDown"})do A[key]=root..name.."Silver"end
    end
    if prefs.frameTheme=="dialog" then
        A.gold="Interface\\DialogFrame\\UI-DialogBox-Border";A.border=A.gold
    elseif prefs.frameTheme=="tooltip" then
        A.gold="Interface\\Tooltips\\UI-Tooltip-Border";A.border=A.gold
    end
end
-- Native Collections artwork, applied only to WoWU-owned backgrounds.
function T.Surface(frame,pad)
    if not T.leather then return end
    if not C_Texture or not C_Texture.GetAtlasInfo or not C_Texture.GetAtlasInfo("collections-background-tile") then return end
    local t=frame.WoWUCollectionSurface
    if not t then t=frame:CreateTexture(nil,"BACKGROUND",nil,1);frame.WoWUCollectionSurface=t end
    t:ClearAllPoints();t:SetPoint("TOPLEFT",pad or 7,-(pad or 7));t:SetPoint("BOTTOMRIGHT",-(pad or 7),pad or 7)
    t:SetAtlas("collections-background-tile");t:Show()
end
function T.Fill(frame,r,g,b,a)
    if T.light and not (frame.IsObjectType and frame:IsObjectType("StatusBar")) then
        frame:SetBackdropColor(.98,.94,.85,a or 1)
    elseif T.surface=="marble" or T.surface=="dialog" then frame:SetBackdropColor(.8,.8,.8,a or 1)
    elseif T.surface=="plain" then frame:SetBackdropColor(.035,.04,.045,a or 1)
    else frame:SetBackdropColor(r,g,b,a or 1)end
end
function T.Border(frame,r,g,b,a)
    if T.silver then
        local brightness=math.max(r,g,b);frame:SetBackdropBorderColor(brightness,brightness,brightness,a or 1)
    else frame:SetBackdropBorderColor(r,g,b,a or 1)end
end
function T.TextColor(text,r,g,b,a)
    local parent=text:GetParent();local keep=false
    while parent do
        if parent.WoWUKeepLight or (parent.IsObjectType and parent:IsObjectType("StatusBar"))then keep=true;break end
        parent=parent.GetParent and parent:GetParent()
    end
    if T.light and not keep then
        if r>.7 and g<.45 then r,g,b=.65,.08,.04
        elseif g>.6 and r<.5 then r,g,b=.07,.36,.12
        elseif b>.6 and r<.5 then r,g,b=.08,.19,.5
        else r,g,b=.22,.14,.07 end
        text:SetShadowOffset(0,0)
    end
    text:SetTextColor(r,g,b,a or 1)
end

function T.Backdrop(frame, original)
    if not original then frame:SetBackdrop(nil);return end
    local info={}
    for k,v in pairs(original) do info[k]=v end
    if info.bgFile then info.bgFile=A.stone;info.tile=true;info.tileSize=256 end
    if info.edgeFile then info.edgeFile=A.border end
    frame:SetBackdrop(info)
    if info.bgFile then T.Surface(frame,7) end
    if frame.IsObjectType and frame:IsObjectType("Button") and not frame.WoWUSkinButton then
        frame.WoWUSkinButton=true;T.Button(frame)
    end
end

-- Existing selection/quality logic keeps its own colours. Compensate for the
-- stone texture's grey base, which is darker than the old white flat fill.
function T.Color(frame,r,g,b,a)
    T.Fill(frame,math.min(1,r*3.2),math.min(1,g*3.2),math.min(1,b*3.2),a or 1)
end

function T.Panel(frame, style, ornament)
    local main=style=="outer"
    local inset=style=="inset"
    local edge=main and 30 or inset and 16 or 22
    local pad=main and 10 or inset and 5 or 7
    frame:SetBackdrop({bgFile=A.stone,edgeFile=A.gold,tile=true,tileSize=256,
        edgeSize=edge,insets={left=pad,right=pad,top=pad,bottom=pad}})
    T.Fill(frame,main and .20 or .25,main and .30 or .38,main and .34 or .43,1)
    local brightness=inset and .55 or main and 1 or .87
    frame:SetBackdropBorderColor(brightness,brightness,brightness,1)
    T.Surface(frame,pad)
    if ornament then T.Corners(frame, main and 30 or 23) end
end

function T.Corners(frame,size)
    if frame.WoWUSkinCorners then return end
    frame.WoWUSkinCorners={}
    for i,point in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMRIGHT","BOTTOMLEFT"}) do
        local art=frame:CreateTexture(nil,"OVERLAY",nil,6)
        art:SetTexture(A.corner);art:SetSize(size,size)
        art:SetPoint(point,frame,point,(i==1 or i==4) and 3 or -3, i<=2 and -3 or 3)
        -- The original is a complete small gold ornament, kept unwarped.
        frame.WoWUSkinCorners[i]=art
    end
end

function T.Divider(frame,y)
    local art=frame:CreateTexture(nil,"ARTWORK")
    art:SetTexture(A.divider);art:SetTexCoord(0,193/256,0,.5);art:SetHeight(5)
    art:SetPoint("TOPLEFT",frame,"TOPLEFT",19,y)
    art:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-19,y)
    if T.silver then art:SetVertexColor(.85,.88,.94,.8)else art:SetVertexColor(.85,.67,.36,.8)end
    return art
end

function T.Button(frame)
    if frame.SetHighlightTexture then
        frame:SetHighlightTexture(A.highlight,"ADD")
        local highlight=frame.GetHighlightTexture and frame:GetHighlightTexture()
        if highlight then highlight:SetAlpha(.16) end
    end
    if frame.SetPushedTexture then
        frame:SetPushedTexture(A.pressed)
        local pressed=frame.GetPushedTexture and frame:GetPushedTexture()
        if pressed then pressed:SetAlpha(.38) end
    end
end

function T.Tab(frame,selected)
    frame:SetBackdrop({bgFile=T.light and A.stone or selected and A.amber or A.stone,edgeFile=A.gold,
        tile=true,tileSize=selected and 64 or 256,edgeSize=20,
        insets={left=7,right=7,top=7,bottom=7}})
    T.Surface(frame,7)
    if selected then
        if T.light then frame:SetBackdropColor(.76,.67,.49,1)else frame:SetBackdropColor(.95,.86,.68,1)end
        T.Border(frame,1,1,.9,1)
        if frame.label then T.TextColor(frame.label,1,.91,.67)end
    else
        T.Fill(frame,.28,.40,.44,1)
        frame:SetBackdropBorderColor(.65,.65,.65,1)
        if frame.label then T.TextColor(frame.label,.87,.80,.63)end
    end
end

function T.IconRim(parent,icon,size)
    local rim=parent:CreateTexture(nil,"OVERLAY",nil,2)
    rim:SetTexture(A.rim);rim:SetTexCoord(.15,.85,.15,.85)
    rim:SetPoint("CENTER",icon,"CENTER",0,0);rim:SetSize(size,size)
    if T.silver then rim:SetVertexColor(.90,.94,1,1)else rim:SetVertexColor(1,.86,.55,1)end
    return rim
end

function T.Scrollbar(scroll)
    local bar=scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName().."ScrollBar"])
    if not bar or bar.WoWUSkinApplied then return end
    bar.WoWUSkinApplied=true
    if bar.SetThumbTexture then
        bar:SetThumbTexture(A.thumb)
        local thumb=bar:GetThumbTexture()
        if thumb then if T.silver then thumb:SetVertexColor(.9,.94,1,1)else thumb:SetVertexColor(1,.78,.36,1)end end
    end
    for _,entry in ipairs({{bar.ScrollUpButton or bar.Back,A.up,A.upDown},{bar.ScrollDownButton or bar.Forward,A.down,A.downDown}}) do
        local button=entry[1]
        if button and button.SetNormalTexture then
            button:SetNormalTexture(entry[2]);button:SetPushedTexture(entry[3])
        end
    end
end

-- Shared touch-sized X for WoWU-owned windows; native game windows are untouched.
function T.CloseButton(button)
 if not button then return end
 button:SetSize(48,48);button:SetHitRectInsets(0,0,0,0)
 for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"})do
  local texture=button[method]and button[method](button)
  if texture then texture:ClearAllPoints();texture:SetAllPoints(button)end
 end
end
