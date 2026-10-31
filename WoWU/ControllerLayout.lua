-- Presentation and edit handles for the independent secure controller buttons.
WoWUControllerLayout={editing=false,groups={},clusters={},handles={}}
local L=WoWUControllerLayout
local root,toolbar,selection,selectedName
local centers={{0,100},{-210,-20},{210,-20},{0,-145}}
local layerNames={"Base","LT","RT","LT + RT"}
local media="Interface\\AddOns\\WoWU\\Media\\Controller\\"
local function combat()return InCombatLockdown and InCombatLockdown()end
local function db()
 WoWUDB.controller=WoWUDB.controller or {characters={}}
 local c=WoWUDB.controller;c.layout=c.layout or {groups={},clusters={}}
 c.layout.groups=c.layout.groups or {};c.layout.clusters=c.layout.clusters or {}
 return c.layout
end
local function config(kind,index)
 local d=db();d[kind][index]=d[kind][index]or {};return d[kind][index]
end
local function defaultScale()return WoWUClient and WoWUClient.isClassic and .7 or 1 end
function L.GetScale()return db().scale or defaultScale()end
function L.IsCompact()return db().compact==true end
function L.SetCompact(value)
 if combat()then return false,"Change Compact Layout outside combat."end
 db().compact=value==true
 L.SetMovePairs(L.MovePairs());return true,"Controller layout saved."
end
function L.MovePairs()return db().movePairs~=false end
local function label(parent,value,size)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"");t:SetText(value);return t
end
local function rect()
 return WoWUViewport and WoWUViewport.GetGameplayRect()or {left=0,bottom=0,right=UIParent:GetWidth(),top=UIParent:GetHeight()}
end
local function anchor(f,parent,x,y)
 local ratio=parent:GetEffectiveScale()/f:GetEffectiveScale()
 f:ClearAllPoints();f:SetPoint("CENTER",parent,"CENTER",x*ratio,y*ratio)
end
local function offset(f,parent)
 local x,y=f:GetCenter();local px,py=parent:GetCenter()
 local scale=f:GetEffectiveScale()/parent:GetEffectiveScale()
 return x*scale-px,y*scale-py
end
local function clamp(f,parent)
 local x,y=f:GetCenter();if not x then return end
 local ratio=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
 x,y=x*ratio,y*ratio
 local r=rect();local hw,hh=f:GetWidth()*ratio/2,f:GetHeight()*ratio/2
 local cx=math.max(r.left+hw,math.min(r.right-hw,x))
 local cy=math.max(r.bottom+hh+(f.bottomInset or 0)*ratio,math.min(r.top-hh-(f.topInset or 0)*ratio,y))
 if cx~=x or cy~=y then
  local px,py=parent:GetCenter();local ps=parent:GetEffectiveScale()/UIParent:GetEffectiveScale()
  anchor(f,parent,(cx-px*ps)/ps,(cy-py*ps)/ps)
 end
end
local function setSelection(kind,index,name)
 selection=kind and {kind=kind,index=index}or nil;selectedName=name
 if toolbar then toolbar.selection:SetText(selection and (name.."  |  "..math.floor((config(kind,index).scale or 1)*100+.5).."%")or "Select a highlighted cluster to move or scale it.")end
 for _,h in ipairs(L.handles)do
  h:SetBackdropBorderColor(1,.72,.2,h.kind==kind and h.index==index and 1 or .45)
 end
end
function L.Apply()
 if not root or combat()then return end
 local d=db();root:SetScale(L.GetScale())
 if WoWUController and WoWUController.PositionHUD then WoWUController.PositionHUD()end
 for i,g in ipairs(L.groups)do
  local source=L.IsCompact()and 1 or i
  g.topInset=source==1 and 55 or 0;g.bottomInset=source>1 and 30 or 0
  local c=config("groups",source);g:SetScale(c.scale or 1)
  anchor(g,root,c.x or centers[source][1],c.y or centers[source][2]);clamp(g,root)
  if g.badge then g.badge:SetShown(not L.IsCompact()and L.MovePairs())end
 end
 for i,c in ipairs(L.clusters)do
  c.topInset=(L.IsCompact()or i<=2)and 55 or 0;c.bottomInset=(not L.IsCompact()and i>2)and 30 or 0
  local p=config("clusters",L.IsCompact()and ((i-1)%2+1)or i);c:SetScale(p.scale or 1)
  anchor(c,c:GetParent(),p.x or (i%2==1 and -58 or 58),p.y or 0);clamp(c,c:GetParent())
  if c.badge then c.badge:SetShown(not L.IsCompact()and not L.MovePairs())end
 end
 for i=1,2 do
  local c=L.clusters[i];local hint=c and c.shoulderHint
  if hint then
   hint:SetParent(L.IsCompact()and root or c)
   hint:SetScale(L.IsCompact()and c:GetEffectiveScale()/root:GetEffectiveScale()or 1)
   hint:ClearAllPoints();hint:SetPoint("BOTTOM",c,"TOP",i==1 and -58 or 58,13)
  end
 end
 root:SetAttribute("pad-compact",L.IsCompact());root:Execute(root:GetAttribute("_refreshlayout"))
 for _,h in ipairs(L.handles)do if not h.dragging then h:ClearAllPoints();h:SetAllPoints(h.target)end end
end
function L.SetScale(value)
 if combat()then return false,"Scale the controller HUD outside combat."end
 db().scale=math.max(.5,math.min(1.5,value));L.Apply();return true,"Controller HUD scale saved."
end
function L.SetMovePairs(value)
 if combat()then return false,"Change edit grouping outside combat."end
 db().movePairs=value;setSelection(nil)
 L.Apply()
 for _,h in ipairs(L.handles)do h:SetShown(L.editing and (h.kind=="groups")==value and (not L.IsCompact()or h.index<=(h.kind=="groups"and 1 or 2)))end
 return true,value and "Edit eight-button pairs."or "Edit individual four-button clusters."
end
function L.SelectedScale()
 return L.editing and selection and (config(selection.kind,selection.index).scale or 1)or nil
end
function L.SetSelectedScale(value)
 if combat()or not L.editing or not selection then return false,"Select a cluster in controller edit mode first."end
 config(selection.kind,selection.index).scale=math.max(.5,math.min(1.8,value))
 L.Apply();setSelection(selection.kind,selection.index,selectedName);return true,"Element scale saved."
end
function L.Reset()
 if combat()then return false,"Reset the controller layout outside combat."end
 local d=db();d.groups={};d.clusters={};d.scale=nil
 WoWUDB.controller.position=nil
 L.Apply();setSelection(nil);return true,"Controller positions and scales reset; action assignments are unchanged."
end
local function addHandle(target,kind,index,name)
 -- Drag an unprotected proxy. Secure action frames are only repositioned
 -- outside combat, and are never left in native StartMoving state.
 local h=CreateFrame("Button",nil,UIParent,"BackdropTemplate");h:SetAllPoints(target);h:SetMovable(true);h:SetFrameStrata("DIALOG");h:SetFrameLevel(target:GetFrameLevel()+30)
 h.kind=kind;h.index=index;h.target=target;h:Hide()
 h:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14})
 h:SetBackdropColor(.08,.06,.015,.24);h:SetBackdropBorderColor(1,.72,.2,.55)
 label(h,name,11):SetPoint("TOP",0,15)
 h:RegisterForDrag("LeftButton");h:EnableMouseWheel(true)
 h:SetScript("OnClick",function()setSelection(kind,index,name)end)
 h:SetScript("OnDragStart",function()
  if combat()or not L.editing then return end
  setSelection(kind,index,name);h:StartMoving();h.dragging=true
 end)
 h:SetScript("OnDragStop",function()
  if not h.dragging then return end
  h.dragging=nil;h:StopMovingOrSizing()
  if combat()then return end
  local parent=target:GetParent()
  local c=config(kind,index);c.x,c.y=offset(h,parent)
  L.Apply()
 end)
 h:SetScript("OnUpdate",function()
  if h.dragging and not combat()then
   local c=config(kind,index);c.x,c.y=offset(h,target:GetParent());L.Apply()
  end
 end)
 h:SetScript("OnMouseWheel",function(_,delta)
  setSelection(kind,index,name);L.SetSelectedScale((L.SelectedScale()or 1)+delta*.05)
 end)
 L.handles[#L.handles+1]=h
end
function L.Attach(f)
 root=f
end
function L.CreateGroup(layer)
 local g=CreateFrame("Frame",nil,root);g:SetSize(232,114);g.topInset=layer==1 and 55 or 0;g.bottomInset=layer>1 and 30 or 0;L.groups[layer]=g
 -- Trigger badges sit beside the pair, as on the native controller bars.
 if layer>1 then
  local badge=CreateFrame("Frame",nil,g);badge:SetSize(layer==4 and 70 or 34,29);badge:SetPoint("BOTTOM",0,-30)
  local bg=badge:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetTexture(media.."trigger.tga")
  label(badge,layerNames[layer],12):SetPoint("CENTER")
  g.badge=badge
 end
 addHandle(g,"groups",layer,layerNames[layer].." pair")
 for half=1,2 do
  local index=(layer-1)*2+half
  local c=CreateFrame("Frame",nil,g);c:SetSize(108,108);c.topInset=layer==1 and 55 or 0;c.bottomInset=layer>1 and 30 or 0;L.clusters[index]=c
  if layer==1 then
   local hint=CreateFrame("Frame",nil,c);hint:SetSize(29,29);hint:SetPoint("BOTTOM",c,"TOP",half==1 and -58 or 58,13);c.shoulderHint=hint
   WoWUControllerEffects.Attach(hint,false,half==1 and "PADLSHOULDER"or "PADRSHOULDER")
   local bg=hint:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetTexture(media.."square.tga")
   local reticle=hint:CreateTexture(nil,"ARTWORK");reticle:SetAllPoints();reticle:SetTexture(media.."target.tga")
   reticle:SetVertexColor(half==1 and .45 or 1,half==1 and .85 or .15,.12)
   label(hint,half==1 and "LB"or "RB",9):SetPoint("BOTTOM",0,-10)
  elseif layer>1 then
   local badge=CreateFrame("Frame",nil,c);badge:SetSize(layer==4 and 62 or 32,25);badge:SetPoint("TOP",c,"BOTTOM",0,-5)
   local bg=badge:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetTexture(media.."trigger.tga")
   label(badge,layerNames[layer],11):SetPoint("CENTER");c.badge=badge
  end
  addHandle(c,"clusters",index,layerNames[layer]..(half==1 and " D-pad"or " face buttons"))
 end
 return g
end
function L.PlaceButton(button,layer,k)
 local cluster=L.clusters[(layer-1)*2+(k<=4 and 1 or 2)]
 button:SetParent(cluster);button:SetSize(40,40)
 local offsets={{-35,0},{0,35},{35,0},{0,-35}}
 local p=offsets[(k-1)%4+1];button:SetPoint("CENTER",cluster,"CENTER",p[1],p[2])
end
local function atlas(name)return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)end
function L.StyleButton(b,k)
 local round=k>4;local shape=round and "circle"or "square"
 local normal="gamepad-actionbar-"..(round and "circleslot"or "squareslot").."-border-normal"
 local pressed="gamepad-actionbar-"..(round and "circleslot"or "squareslot").."-border-pressed"
 b:SetNormalTexture(media..shape..".tga");b:SetPushedTexture(media..shape.."-pressed.tga")
 if atlas(normal)and b.SetNormalAtlas then b:SetNormalAtlas(normal)end
 if atlas(pressed)and b.SetPushedAtlas then b:SetPushedAtlas(pressed)end
 b:GetNormalTexture():SetVertexColor(1,.92,.75)
 b:GetNormalTexture():SetDrawLayer("OVERLAY",2);b:GetNormalTexture():SetAllPoints()
 local pushed=b:GetPushedTexture();pushed:SetDrawLayer("OVERLAY",3);pushed:SetAllPoints()
 b:SetHighlightTexture(media..shape.."-highlight.tga","ADD")
 b.icon:ClearAllPoints();b.icon:SetPoint("TOPLEFT",4,-4);b.icon:SetPoint("BOTTOMRIGHT",-4,4)
 if round then
  local mask=b:CreateMaskTexture(nil,"ARTWORK");mask:SetAllPoints(b.icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
  b.icon:AddMaskTexture(mask);b.roundMask=mask
  if b.cd.SetSwipeTexture then b.cd:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")end
  local badge=b:CreateTexture(nil,"OVERLAY",nil,4);badge:SetSize(17,17);badge:SetPoint("TOPRIGHT",5,5);badge:SetTexture(media.."badge.tga")
  b.key:ClearAllPoints();b.key:SetPoint("CENTER",badge,"CENTER",0,0);b.key:SetFont("Fonts\\FRIZQT__.TTF",10,"")
  b.key:SetDrawLayer("OVERLAY",7)
  b.emptyLabel=label(b,({"X","Y","B","A"})[k-4],21);b.emptyLabel:SetPoint("CENTER");b.emptyLabel:SetTextColor(.55,.55,.48);b.emptyLabel:SetDrawLayer("OVERLAY",6)
 else
  b.key:Hide()
  b.emptyDirection=media..({"left","up","right","down"})[k]..".tga"
 end
end
local function finishEditing()
 L.editing=false;setSelection(nil)
 for _,h in ipairs(L.handles)do
  if h.dragging then h:StopMovingOrSizing();h.dragging=nil end
  h:Hide()
 end
 if toolbar then toolbar:Hide()end
 if WoWUController then WoWUController.editing=false end
 if root and not combat()then root:SetAttribute("pad-editing",false);root:Execute(root:GetAttribute("_refreshbindings"))end
end
L.FinishEditing=finishEditing
function L.ToggleEdit()
 if combat()then return false,"Edit the controller layout outside combat."end
 if L.editing then finishEditing();return true,"Controller layout saved."end
 if not root or not WoWUController or not WoWUController.active then return false,"Enable the controller overlay before editing its layout."end
 if WoWUController.CloseEditors then WoWUController.CloseEditors()end
 L.editing=true;WoWUController.editing=true
 root:SetAttribute("pad-editing",true);root:Execute(root:GetAttribute("_refreshbindings"))
 if not toolbar then
  toolbar=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");toolbar:SetSize(650,94);toolbar:SetFrameStrata("FULLSCREEN_DIALOG");WoWU_Theme.Panel(toolbar)
  label(toolbar,"Controller edit mode - drag a highlighted group; scroll to scale",14):SetPoint("TOP",0,-12)
  toolbar.selection=label(toolbar,"",12);toolbar.selection:SetPoint("TOP",0,-34)
  local function button(caption,x,w,fn)
   local b=CreateFrame("Button",nil,toolbar,"UIPanelButtonTemplate");b:SetSize(w,26);b:SetPoint("BOTTOMLEFT",x,9);b:SetText(caption);b:SetScript("OnClick",fn)
  end
  button("4 / 8 buttons",12,135,function()L.SetMovePairs(not L.MovePairs())end)
  button("-",160,45,function()L.SetSelectedScale((L.SelectedScale()or 1)-.05)end)
  button("+",213,45,function()L.SetSelectedScale((L.SelectedScale()or 1)+.05)end)
  button("Reset layout",275,135,L.Reset)
  button("Done",493,145,finishEditing)
 end
 local r=rect();toolbar:ClearAllPoints();toolbar:SetPoint("TOP",UIParent,"BOTTOMLEFT",(r.left+r.right)/2,r.top-28);toolbar:Show()
 L.SetMovePairs(L.MovePairs());setSelection(nil)
 return true,"Drag clusters to move them; mouse wheel or + / - scales the selected element."
end
local events=CreateFrame("Frame");events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent",function()if L.editing then finishEditing()end end)
