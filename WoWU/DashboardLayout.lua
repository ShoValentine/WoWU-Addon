-- Dashboard layout data and grid editor. Secure widgets are only moved out of combat.
local L={};WoWUDashboardLayout=L
local COLS,ROWS,GAP=24,20,8
local function combat()return InCombatLockdown and InCombatLockdown()end
local function copy(value)
 if type(value)~="table"then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function rect(x,y,w,h)return {x=x,y=y,w=w,h=h}end
local function defaultProfile(index)
 return {name="Layout "..index,widgets={
  quests=rect(0,0,6,16),minimap=rect(6,0,8,14),mapcontrols=rect(14,0,2,14),quick=rect(18,0,6,16),
  notifications=rect(6,14,12,2),xp=rect(0,16,24,2),
  summary=rect(0,18,10,2),keyboard=rect(11,18,2,2),hearth=rect(22,18,2,2)},
  emotes={"WAVE","DANCE","CHEER","LAUGH","BOW","SIT"},shortcuts={}}
end
local function state()
 WoWUDB.dashboardLayouts=WoWUDB.dashboardLayouts or {active=1,profiles={}}
 local s=WoWUDB.dashboardLayouts
 s.profiles=s.profiles or {}
 for i=1,3 do if type(s.profiles[i])~="table"then s.profiles[i]=defaultProfile(i)end end
 for _,profile in ipairs(s.profiles)do
  if not profile.mapControlsMigrated then
   local m=profile.widgets and profile.widgets.minimap
   if m and m.w>=9 and m.h>=8 and not profile.widgets.mapcontrols then
    -- Carve the new widget out of the old minimap footprint; other widgets do not move.
    profile.widgets.mapcontrols=rect(m.x+m.w-2,m.y,2,m.h);m.w=m.w-2
   end
   profile.mapControlsMigrated=true
  end
 end
 if type(s.active)~="number"or s.active<1 or s.active>3 then s.active=1 end
 return s
end
function L.Profile()local s=state();return s.profiles[s.active]end
function L.QuickLimit()
 return math.max(1,math.min(20,math.floor(tonumber(L.Profile().quickLimit)or 8)))
end
function L.SetQuickLimit(value)
 value=tonumber(value)
 if not value or value~=value then return false,"Enter a number from 1 to 20."end
 if combat()then return false,"Change Quick Access capacity after combat."end
 L.Profile().quickLimit=math.max(1,math.min(20,math.floor(value)))
 if L.Apply then L.Apply()end
 return true,"Saved for this layout. Pins beyond the limit are kept for later."
end
function L.Shortcuts(key)
 local profile=L.Profile();profile.shortcuts=profile.shortcuts or {}
 if not profile.shortcuts[key]then
  profile.shortcuts[key]=copy(WoWUDB.shortcuts and WoWUDB.shortcuts[key]or {})
 end
 return profile.shortcuts[key]
end
local function text(parent,value,size)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size or 14,"");WoWU_Theme.TextColor(t,1,.84,.52);t:SetText(value)
 return t
end
local function button(parent,caption,width,fn)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(width,34)
 b.label=text(b,caption,13);b.label:SetPoint("CENTER")
 WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",fn);return b
end
local emoteChoices={"WAVE","DANCE","CHEER","LAUGH","BOW","SIT","HELLO","THANK","NOD","NO","POINT","SALUTE","CLAP","SHRUG","SLEEP","BYE"}
function L.CreateEmotes(parent)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");WoWU_Theme.Panel(f)
 local title=text(f,"Emotes",20);title:SetPoint("TOP",0,-14)
 local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",14,-48);scroll:SetPoint("BOTTOMRIGHT",-32,14)
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(200,1);scroll:SetScrollChild(body)
 WoWU_EnableTouchScroll(scroll)
 local buttons={}
 function f:Resize()
  local profile=L.editing and L.draft or L.Profile()
  local favorites=profile.emotes or emoteChoices
  local columns=self:GetWidth()>430 and 3 or 2
  local count=math.max(1,#favorites);local rows=math.ceil(count/columns)
  local width=math.max(100,self:GetWidth()-46)
  body:SetWidth(width)
  local w=(width-(columns-1)*8)/columns
  local h=48
  for i,token in ipairs(favorites)do
   local b=buttons[i]
   if not b then
    b=button(body,"",100,function()end);buttons[i]=b
    b:SetScript("OnClick",function(self)
     if not L.editing and WoWU_TouchTapAllowed(scroll) and DoEmote then DoEmote(self.token)end
    end)
   end
   b.token=token;b.label:SetText(_G["EMOTE_"..token]or token:sub(1,1)..token:sub(2):lower())
   b:SetSize(w,math.max(28,h));b:ClearAllPoints()
   b:SetPoint("TOPLEFT",((i-1)%columns)*(w+8),-math.floor((i-1)/columns)*(h+8));b:Show()
  end
  for i=#favorites+1,#buttons do buttons[i]:Hide()end
  body:SetHeight(math.max(1,rows*(h+8)-8))
  scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
 end
 return f
end

function L.Build(parent,definitions)
 L.widgets={};L.order={}
 local canvas=CreateFrame("Frame",nil,parent)
 canvas:SetPoint("TOPLEFT",10,-54);canvas:SetPoint("BOTTOMRIGHT",-10,10)
 local toolbar=CreateFrame("Frame",nil,parent);toolbar:SetPoint("TOPLEFT",12,-9);toolbar:SetPoint("TOPRIGHT",-12,-9);toolbar:SetHeight(36)
 local profiles={}
 local function current()return L.override or (L.editing and L.draft or L.Profile())end
 local function metrics()return canvas:GetWidth()/COLS,canvas:GetHeight()/ROWS end
 local function position(frame,r)
  local cw,ch=metrics()
  frame:ClearAllPoints();frame:SetPoint("TOPLEFT",canvas,"TOPLEFT",r.x*cw,-r.y*ch)
  frame:SetSize(r.w*cw-GAP,r.h*ch-GAP)
 end
 local function valid(key,r,layout)
  local def=L.widgets[key]
  if not def or not L.WidgetAvailable(key)or r.x<0 or r.y<0 or r.w<def.minW or r.h<def.minH or r.x+r.w>COLS or r.y+r.h>ROWS then return false end
  if def.validRect and not def.validRect(r)then return false end
  for id,other in pairs(layout.widgets)do
   if id~=key and L.WidgetAvailable(id)and r.x<other.x+other.w and r.x+r.w>other.x and r.y<other.y+other.h and r.y+r.h>other.y then return false end
  end
  return true
 end
 local editor=CreateFrame("Frame",nil,parent)
 editor:SetAllPoints(parent);editor:SetFrameStrata("DIALOG");editor:SetFrameLevel(parent:GetFrameLevel()+500)
 editor:EnableMouse(true);editor:Hide()
 local grid=CreateFrame("Frame",nil,editor);grid:SetAllPoints(canvas)
 for x=0,COLS do
  local line=grid:CreateTexture(nil,"BACKGROUND");line:SetColorTexture(.9,.7,.2,.14);line:SetWidth(1)
  line:SetPoint("TOPLEFT",grid,"TOPLEFT",0,0);line:SetPoint("BOTTOMLEFT",grid,"BOTTOMLEFT",0,0)
  line.fraction=x/COLS
  grid.lines=grid.lines or {};grid.lines[#grid.lines+1]=line
 end
 for y=0,ROWS do
  local line=grid:CreateTexture(nil,"BACKGROUND");line:SetColorTexture(.9,.7,.2,.14);line:SetHeight(1)
  line.row=y/ROWS;grid.lines[#grid.lines+1]=line
 end
 local status=text(editor,"Drag a widget to move it. Drag its lower-right handle to resize.",12)
 status:SetPoint("BOTTOM",parent,"BOTTOM",0,0)
 local name=CreateFrame("EditBox",nil,editor,"InputBoxTemplate")
 name:SetSize(175,32);name:SetPoint("TOPLEFT",parent,"TOPLEFT",20,-10);name:SetAutoFocus(false);name:SetMaxLetters(24)
 name:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
 name:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
 local menu=CreateFrame("Frame",nil,editor,"BackdropTemplate");menu:SetSize(320,480);menu:SetPoint("TOPRIGHT",-12,-49)
 menu:SetFrameLevel(editor:GetFrameLevel()+30);WoWU_Theme.Panel(menu);menu:EnableMouse(true);menu:Hide()
 local menuTitle=text(menu,"Add a widget",18);menuTitle:SetPoint("TOPLEFT",16,-14)
 local menuButtons={}
 local ghost=CreateFrame("Frame",nil,editor,"BackdropTemplate")
 WoWU_Theme.Backdrop(ghost,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
 ghost:SetFrameLevel(editor:GetFrameLevel()+15);ghost:EnableMouse(false);ghost:Hide()
 local drag
 local function clearGesture()drag=nil;ghost:Hide()end
 local function pointer()
  local x,y=GetCursorPosition();local scale=canvas:GetEffectiveScale()
  return x/scale,y/scale
 end
 local function start(key,resize)
  if combat()then return end
  menu:Hide();name:ClearFocus()
  local x,y=pointer()
  drag={key=key,resize=resize,x=x,y=y,original=copy(L.draft.widgets[key])}
  ghost:Show()
 end
 local function updateGesture(release)
  if not drag then return end
  if combat()then clearGesture();return end
  local x,y=pointer();local cw,ch=metrics()
  local dx=math.floor((x-drag.x)/cw+.5);local dy=math.floor((drag.y-y)/ch+.5)
  local r=copy(drag.original)
  if drag.resize then r.w=r.w+dx;r.h=r.h+dy else r.x=r.x+dx;r.y=r.y+dy end
  local okay=valid(drag.key,r,L.draft)
  if r.w>0 and r.h>0 then position(ghost,r)end
  ghost:SetBackdropColor(okay and .2 or .7,okay and .6 or .1,.08,.35)
  ghost:SetBackdropBorderColor(okay and .6 or 1,okay and 1 or .2,.2,1)
  if release then
   if okay then L.draft.widgets[drag.key]=r;status:SetText("Position updated. Save when ready.")
   else status:SetText("That space is occupied or too small. Widget returned to its previous position.")end
   clearGesture();L.Apply()
  end
 end
 for _,def in ipairs(definitions)do
  L.widgets[def.id]=def;L.order[#L.order+1]=def.id
  local host=CreateFrame("Frame",nil,canvas);def.host=host
  if def.create then def.frame=def.create(host)end
  def.frame:SetParent(host);def.frame:ClearAllPoints();def.frame:SetAllPoints(host)
  local cover=CreateFrame("Frame",nil,editor,"BackdropTemplate");def.cover=cover;cover:EnableMouse(true)
  cover:SetFrameLevel(editor:GetFrameLevel()+2)
  WoWU_Theme.Backdrop(cover,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
  cover:SetBackdropColor(.12,.08,.015,.7);cover:SetBackdropBorderColor(.95,.73,.24,1)
  cover.label=text(cover,def.name,17);cover.label:SetPoint("CENTER");cover.label:SetWidth(200);cover.label:SetWordWrap(true)
  cover:SetScript("OnMouseDown",function(_,b)if b=="LeftButton"then start(def.id,false)end end)
  cover:SetScript("OnMouseUp",function()updateGesture(true)end)
  local resize=button(cover,"Size",48,function()end);resize:SetPoint("BOTTOMRIGHT",-3,3)
  resize:SetScript("OnMouseDown",function(_,b)if b=="LeftButton"then start(def.id,true)end end)
  resize:SetScript("OnMouseUp",function()updateGesture(true)end)
  local remove=button(cover,"X",34,function()
   if combat()then return end
   clearGesture();L.draft.widgets[def.id]=nil;L.Apply();status:SetText(def.name.." removed. Use Add Widget to restore it.")
  end);remove:SetSize(44,44);remove:SetPoint("TOPLEFT",3,-3)
  cover:SetScript("OnEnter",function(self)
   GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText(def.name)
   GameTooltip:AddLine("Drag to move. Size resizes. X removes.",1,.8,.4);GameTooltip:Show()
  end)
  cover:SetScript("OnLeave",function()GameTooltip:Hide()end)
 end
 function L.WidgetAvailable(id)
  local def=L.widgets[id];return def~=nil and(not def.available or def.available())
 end
 function L.IsEnabled(id)return L.WidgetAvailable(id)and current().widgets[id]~=nil end
 local function restoreMinimapWidgets(layout)
  -- Hidden rectangles are only saved preferences, not occupied grid cells.
  -- On returning to WoWU, keep visible widgets fixed and find room for the
  -- minimap/controls. A full dashboard parks them until space is freed.
  local saved={};local moved,waiting=0,0
  layout.parkedWidgets=layout.parkedWidgets or {}
  for _,id in ipairs({"minimap","mapcontrols"})do
   if L.WidgetAvailable(id)then
    saved[id]=layout.widgets[id]or layout.parkedWidgets[id]
    layout.widgets[id]=nil
   end
  end
  for _,id in ipairs({"minimap","mapcontrols"})do
   local wanted=saved[id]
   if wanted then
    local chosen
    if valid(id,wanted,layout)then chosen=wanted
    else
     for y=0,ROWS-wanted.h do
      for x=0,COLS-wanted.w do
       local candidate=rect(x,y,wanted.w,wanted.h)
       if valid(id,candidate,layout)then chosen=candidate;break end
      end
      if chosen then break end
     end
    end
    if chosen then
     layout.widgets[id]=chosen;layout.parkedWidgets[id]=nil
     if chosen~=wanted then moved=moved+1 end
    else
     layout.parkedWidgets[id]=copy(wanted);waiting=waiting+1
    end
   end
  end
  if waiting>0 then return "Dashboard full: make room in Edit Dashboard to restore the minimap widgets. Their saved sizes and positions are kept."end
  if moved>0 then return "Minimap widgets moved to free dashboard space; your other widgets stayed in place."end
 end
 function L.Apply()
  if combat()then L.pending=true;return end
  if canvas.dungeon~=(L.override~=nil)then
   canvas.dungeon=L.override~=nil
   canvas:ClearAllPoints();canvas:SetPoint("TOPLEFT",10,L.override and -10 or -54);canvas:SetPoint("BOTTOMRIGHT",-10,10)
  end
  toolbar:SetShown(not L.override and not L.editing)
  if canvas:GetWidth()<100 then L.pending=true;return end
  L.pending=false
  local layout=current()
  if not L.editing and not L.override and not layout.minimapTrimmed then
   local m=layout.widgets.minimap
   if m then
    local cw,ch=metrics();local width=math.max(7,math.ceil((m.h*ch-32)/cw))
    if m.w>width then
     local controls=layout.widgets.mapcontrols
     if controls and controls.x==m.x+m.w then controls.x=m.x+width end
     m.w=width
    end
   end
   layout.minimapTrimmed=true
  end
  if not L.editing and not L.override and not layout.minimapTitleInset then
   local m=layout.widgets.minimap
   if m then
    local _,ch=metrics();local def=L.widgets.minimap
    -- Reclaim only the old 32px external title gutter, rounded to the grid.
    -- Keep the user's position/width and all neighbouring widgets unchanged.
    if ch>0 then m.h=math.max(def and def.minH or 7,m.h-math.max(1,math.floor(32/ch+.5)));layout.minimapTitleInset=true end
   else
    layout.minimapTitleInset=true
   end
  end
  if not L.override and not L.editing then L.minimapPlacementNotice=restoreMinimapWidgets(layout)end
  for _,id in ipairs(L.order)do
   local def=L.widgets[id];local r=layout.widgets[id]
   local visible=r~=nil and L.WidgetAvailable(id)
   def.host:SetShown(visible)
   def.cover:SetShown(L.editing and visible)
   if visible then
    position(def.host,r);position(def.cover,r)
    def.cover.label:SetShown(def.host:GetWidth()>180 and def.host:GetHeight()>85)
    if def.resize then def.resize(def.frame,def.host:GetWidth(),def.host:GetHeight(),layout)end
   end
   if def.visibility then def.visibility(visible and parent:IsVisible())end
  end
  for i,b in ipairs(profiles)do
   b.label:SetText(state().profiles[i].name);WoWU_Theme.Tab(b,i==state().active)
  end
  for _,line in ipairs(grid.lines)do
   line:ClearAllPoints()
   if line.fraction then
    line:SetPoint("TOPLEFT",grid,"TOPLEFT",grid:GetWidth()*line.fraction,0)
    line:SetPoint("BOTTOMLEFT",grid,"BOTTOMLEFT",grid:GetWidth()*line.fraction,0)
   else
    line:SetPoint("TOPLEFT",grid,"TOPLEFT",0,-grid:GetHeight()*line.row)
    line:SetPoint("TOPRIGHT",grid,"TOPRIGHT",0,-grid:GetHeight()*line.row)
   end
  end
  if WoWU_RefreshDashboard then WoWU_RefreshDashboard()end
 end
 local function finish(save)
  if combat()then status:SetText("Editing is paused during combat. Save or cancel afterwards.");return end
  clearGesture()
  if save then
   local value=name:GetText():match("^%s*(.-)%s*$")
   L.draft.name=value~=""and value or "Layout "..state().active
   state().profiles[state().active]=copy(L.draft)
  end
  L.editing=false;L.draft=nil;name:ClearFocus();editor:Hide();menu:Hide();toolbar:Show()
  L.Apply()
 end
 function L.Edit()
  if combat()then print("WoWU: edit the Dashboard after combat.");return end
  if L.override then print("WoWU: return to the normal Dashboard before editing a layout.");return end
  if L.editing then return end
  L.draft=copy(L.Profile());L.editing=true
  for _,def in pairs(L.widgets)do if def.beforeEdit then def.beforeEdit()end end
  name:SetText(L.draft.name);toolbar:Hide();editor:Show();L.Apply()
  status:SetText("Drag to move. Use Size to resize. X removes a widget. Gold grid spaces are available.")
 end
 local function populateMenu(emotes)
  for _,b in ipairs(menuButtons)do b:Hide()end
  menuTitle:SetText(emotes and "Favourite emotes"or "Add a widget")
  local list={}
  if emotes then list=emoteChoices else
   local repeats={}
   for _,id in ipairs(L.order)do
    local def=L.widgets[id]
    if id~="dungeon"and L.WidgetAvailable(id)and(not def.repeatGroup or(not repeats[def.repeatGroup]and not L.draft.widgets[id]))then
     list[#list+1]=id;if def.repeatGroup then repeats[def.repeatGroup]=true end
    end
   end
  end
  menu:SetSize(emotes and 420 or 320,emotes and 400 or 48+#list*38)
  for i,id in ipairs(list)do
   local b=menuButtons[i]
   if not b then b=button(menu,"",285,function()end);menuButtons[i]=b end
   b:ClearAllPoints()
   if emotes then b:SetSize(187,34);b:SetPoint("TOPLEFT",14+((i-1)%2)*201,-44-math.floor((i-1)/2)*40)
   else b:SetSize(290,34);b:SetPoint("TOPLEFT",15,-44-(i-1)*38)end
   local selected=false
   if emotes then for _,token in ipairs(L.draft.emotes or {})do if token==id then selected=true end end
   else selected=L.draft.widgets[id]~=nil end
   b.label:SetText((selected and "[x] "or "")..(emotes and id:sub(1,1)..id:sub(2):lower()or L.widgets[id].name))
   b:SetScript("OnClick",function()
    if combat()then return end
    if emotes then
     local favorites=L.draft.emotes or {};L.draft.emotes=favorites
     local found
     for j,token in ipairs(favorites)do if token==id then found=j;break end end
     if found then table.remove(favorites,found)
     else favorites[#favorites+1]=id end
     L.Apply();populateMenu(true);return
    end
    if L.draft.widgets[id]then status:SetText("That widget is already on this layout.");return end
    local def=L.widgets[id]
    local addW,addH=def.defaultW or def.minW,def.defaultH or def.minH
    for y=0,ROWS-addH do
     for x=0,COLS-addW do
      local r=rect(x,y,addW,addH)
      if valid(id,r,L.draft)then
       L.draft.widgets[id]=r;menu:Hide();L.Apply();status:SetText("Added "..def.name..". Drag its Size handle to expand it.");return
      end
     end
    end
    status:SetText("No free space for "..def.name..". Remove or resize another widget first.")
   end);b:Show()
  end
  menu:Show()
 end
 local save=button(editor,"Save",90,function()finish(true)end);save:SetPoint("TOPRIGHT",-12,-9)
 local cancel=button(editor,"Cancel",90,function()finish(false)end);cancel:SetPoint("RIGHT",save,"LEFT",-7,0)
 local reset=button(editor,"Reset Layout",120,function()
  if combat()then return end
  local old=L.draft
  L.draft=defaultProfile(state().active);L.draft.name=old.name;L.draft.shortcuts=old.shortcuts;L.draft.quickLimit=old.quickLimit;L.draft.singleShortcuts=old.singleShortcuts
  clearGesture();menu:Hide();L.Apply();status:SetText("Default layout restored in preview. Save to keep it, or Cancel.")
 end);reset:SetPoint("RIGHT",cancel,"LEFT",-7,0)
 local favorites=button(editor,"Emotes",95,function()if not combat()then populateMenu(true)end end);favorites:SetPoint("RIGHT",reset,"LEFT",-7,0)
 local add=button(editor,"Add Widget",120,function()
  if combat()then return end
  if menu:IsShown()then menu:Hide()else populateMenu(false)end
 end);add:SetPoint("RIGHT",favorites,"LEFT",-7,0)
 for i=1,3 do
  local index=i
  profiles[i]=button(toolbar,"Layout "..i,160,function()
   if combat()then print("WoWU: switch layouts after combat.");return end
   for _,def in pairs(L.widgets)do if def.beforeEdit then def.beforeEdit()end end
   state().active=index;L.Apply()
  end);profiles[i]:SetPoint("LEFT",(i-1)*168,0)
  profiles[i].label:SetWidth(144);profiles[i].label:SetHeight(24);profiles[i].label:SetWordWrap(false)
 end
 local edit=button(toolbar,"Edit Dashboard",165,L.Edit);edit:SetPoint("RIGHT")
 editor:SetScript("OnUpdate",function()
  if drag then updateGesture(not IsMouseButtonDown("LeftButton"))end
 end)
 parent:HookScript("OnHide",function()if L.editing and not combat()then finish(false)end end)
 parent:HookScript("OnShow",function()L.Apply()end)
 canvas:SetScript("OnSizeChanged",function()L.Apply()end)
 local events=CreateFrame("Frame",nil,parent)
 events:RegisterEvent("PLAYER_REGEN_ENABLED");events:RegisterEvent("PLAYER_REGEN_DISABLED")
 events:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_REGEN_DISABLED"and L.editing then clearGesture();status:SetText("Editing paused during combat. Continue when combat ends.")
  elseif event=="PLAYER_REGEN_ENABLED"then
   if L.editing and not parent:IsVisible()then finish(false)else L.Apply()end
  end
 end)
 function L.SetOverride(layout)
  if combat()then return false end
  if L.editing then finish(false)end
  for _,def in pairs(L.widgets)do if def.beforeEdit then def.beforeEdit()end end
  L.override=layout;L.Apply();return true
 end
 L.Apply()
end
