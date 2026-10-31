-- Touch keyboard: real edit boxes and click-triggered chat, no simulated OS input.
WoWUKeyboard={}
local K=WoWUKeyboard
local keyboards={}
function K.CloseVisible()
 for i=#keyboards,1,-1 do local f=keyboards[i];if f:IsVisible()then f:Hide();return true end end
 return false
end
local function label(p,value,size)
 local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal");t:SetFont("Fonts\\FRIZQT__.TTF",size or 18,"");WoWU_Theme.TextColor(t,1,.86,.59);t:SetText(value);return t
end
local function key(p,value,fn)
 local b=CreateFrame("Button",nil,p,"BackdropTemplate");b.label=label(b,value);b.label:SetPoint("CENTER");WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",fn);return b
end
function K.Create(parent,options)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");f:Hide();f:SetFrameLevel(parent:GetFrameLevel()+300);f:EnableMouse(true);f:SetClampedToScreen(true);f:SetMovable(options.draggable==true)
 keyboards[#keyboards+1]=f
 WoWU_Theme.Panel(f,"outer",false)
 local title=label(f,options.draggable and "Keyboard - drag this bar to move" or "Keyboard",16);title:SetPoint("TOPLEFT",18,-13)
 local drag=CreateFrame("Frame",nil,f);drag:SetPoint("TOPLEFT",4,-3);drag:SetPoint("TOPRIGHT",-60,-3);drag:SetHeight(37);drag:EnableMouse(true)
 drag:RegisterForDrag("LeftButton");drag:SetScript("OnDragStart",function()if options.draggable and (not WoWU_GetPreference or WoWU_GetPreference("keyboardDrag"))then f:StartMoving()end end);drag:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",1,1);close:SetScript("OnClick",function()f:Hide()end)
 local input=CreateFrame("EditBox",nil,f,"InputBoxTemplate");input:SetAutoFocus(false);input:SetFontObject("ChatFontNormal");input:SetHeight(34);input:SetPoint("TOPLEFT",22,-48);input:SetPoint("TOPRIGHT",-22,-48);input:SetMaxBytes(255)
 f.input=input;local syncing=false;local shifted=false;local caps=false;local symbols=false
 local feedback=label(f,"",12);feedback:SetPoint("BOTTOMLEFT",18,7)
 local function syncTarget()
  if not syncing and f.target and f.target~=input then f.target:SetText(input:GetText()) end
 end
 input:SetScript("OnTextChanged",syncTarget)
 function f:SetTarget(target,send,caption)
  self.target=target;self.send=send;self.caption=caption or "Send";if self.sendButton then self.sendButton.label:SetText(self.caption)end
  syncing=true;input:SetText(target and target:GetText() or self.dashboardDraft or "");syncing=false
  input:SetCursorPosition(#input:GetText());feedback:SetText("")
 end
 local function enter()
  syncTarget()
  if f.send then f.send();if f.target then syncing=true;input:SetText(f.target:GetText());syncing=false end
  elseif options.dashboard then
   local channel=f.channel or "SAY";local destination=f.recipient:GetText()
   if channel=="WHISPER"and not destination:find("%S")then feedback:SetText("Enter a character name for your whisper.");return end
   if not input:GetText():find("%S")then return end
   local fn=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
   local ok,result=false,nil;if type(fn)=="function"then ok,result=pcall(fn,input:GetText(),channel,nil,channel=="WHISPER"and destination or nil)end
   if ok and result~=false then input:SetText("");feedback:SetText("Message submitted; check game chat for delivery feedback.")else feedback:SetText("The game could not send this message.")end
  else f:Hide()end
 end
 input:SetScript("OnEnterPressed",enter);input:SetScript("OnEscapePressed",function()f:Hide()end)
 local top=92
 if options.dashboard then
  top=134;local channels={"SAY","PARTY","RAID","INSTANCE_CHAT","GUILD","OFFICER","WHISPER"};local idx=1
  local channel=key(f,"Say",function(self)idx=idx%#channels+1;f.channel=channels[idx];self.label:SetText(f.channel);f.recipient:SetShown(f.channel=="WHISPER")end)
  channel:SetSize(160,30);channel:SetPoint("TOPLEFT",18,-90);channel.label:SetFont("Fonts\\FRIZQT__.TTF",13,"")
  local recipient=CreateFrame("EditBox",nil,f,"InputBoxTemplate");recipient:SetSize(260,30);recipient:SetPoint("LEFT",channel,"RIGHT",18,0);recipient:SetAutoFocus(false);recipient:SetFontObject("ChatFontNormal");recipient:SetMaxBytes(100);recipient:Hide();f.recipient=recipient
  recipient:HookScript("OnEditFocusGained",function()f.editingRecipient=true;feedback:SetText("Typing whisper recipient. Tap the message box to return.")end)
  input:HookScript("OnEditFocusGained",function()f.editingRecipient=false;feedback:SetText("")end)
 end
 -- Each printable symbol appears once; unused key slots are hidden.
 local rows={};local letters={"1234567890","qwertyuiop","asdfghjkl","zxcvbnm"}
 local punctuation={"!@#$%^&*()","[]{}<>/\\|=",";:'\"`~","_+-,.?"}
 local function target()return f.editingRecipient and f.recipient or input end
 local function insert(value)
  local edit=target();edit:Insert(value);edit:SetFocus()
  if shifted then shifted=false end
 end
 local function backspace()
  local edit=target()
  -- Insert replaces a selection. A highlighted previous UTF-8 character makes
  -- backspace work without sending a keyboard event to the game or OS.
  local value=edit:GetText();local cursor=edit:GetCursorPosition()
  if edit.GetTextHighlight then
   local a,b=edit:GetTextHighlight();if a and b and a~=b then edit:Insert("");return end
  end
  if cursor>0 then
   local first=cursor
   while first>1 and value:byte(first)>=128 and value:byte(first)<192 do first=first-1 end
   edit:HighlightText(first-1,cursor);edit:Insert("");edit:SetCursorPosition(first-1)
  end
  edit:SetFocus()
 end
 local updateKeys
 for r,chars in ipairs(letters)do
  rows[r]={}
  for i=1,#chars do
   local b=key(f,"",function(self)insert(self.value);updateKeys()end);rows[r][i]=b
  end
 end
 local back=key(f,"Backspace",backspace)
 local shift=key(f,"Shift",function()shifted=not shifted;updateKeys()end)
 local capsButton=key(f,"Caps",function()caps=not caps;updateKeys()end)
 local symbol=key(f,"123 / #+=",function()symbols=not symbols;updateKeys()end)
 local space=key(f,"Space",function()insert(" ");updateKeys()end)
 local extras={}
 for _,value in ipairs({"!","?",",",".","/"})do
  local char=value;extras[char]=key(f,char,function()insert(char);updateKeys()end)
 end
 local send=key(f,"Send",enter);f.sendButton=send
 local arrowLeft=key(f,"Left",function()local e=target();local pos=e:GetCursorPosition();local v=e:GetText();pos=math.max(0,pos-1);while pos>0 and v:byte(pos+1)>=128 and v:byte(pos+1)<192 do pos=pos-1 end;e:SetCursorPosition(pos)end)
 local arrowRight=key(f,"Right",function()local e=target();local pos=e:GetCursorPosition();local v=e:GetText();pos=math.min(#v,pos+1);while pos<#v and v:byte(pos+1)>=128 and v:byte(pos+1)<192 do pos=pos+1 end;e:SetCursorPosition(pos)end)
 updateKeys=function()
  for r,row in ipairs(rows)do for i,b in ipairs(row)do
   local chars=symbols and punctuation[r]or letters[r];local value=chars:sub(i,i)
   if value~=""then
    if not symbols and (shifted~=caps)then value=value:upper()end
    b.value=value;b.label:SetText(value=="|"and "||"or value);b:Show()
   else b.value=nil;b:Hide()end
  end end
  for _,b in pairs(extras)do b:SetShown(not symbols)end
  shift:SetEnabled(not symbols);capsButton:SetEnabled(not symbols)
  WoWU_Theme.Tab(shift,shifted);WoWU_Theme.Tab(capsButton,caps);WoWU_Theme.Tab(symbol,symbols)
  symbol.label:SetText(symbols and "ABC"or "123 / #+=");send.label:SetText(f.caption or "Send")
 end
 function f:Layout()
  local w=math.min(1200,math.max(300,parent:GetWidth()-28))*(WoWU_GetPreference("keyboardWidth")or 1);local h=math.max(240,parent:GetHeight()*(WoWU_GetPreference("keyboardHeight")or 2/3))
  self:SetSize(w,h);self:ClearAllPoints();self:SetPoint("BOTTOM",parent,"BOTTOM",0,62)
  local gap=7;local unit=(w-36-10*gap)/11;local kh=(h-top-38-4*gap)/5
  local function place(b,x,row,width)b:ClearAllPoints();b:SetPoint("TOPLEFT",18+x*(unit+gap),-top-row*(kh+gap));b:SetSize(width or unit,kh)end
  -- Main rows: numbers, QWERTY, indented home row, Caps + bottom letters.
  for r,row in ipairs(rows)do local offset=r==3 and .45 or r==4 and 1 or 0;for i,b in ipairs(row)do place(b,i-1+offset,r-1)end end
  place(back,10,0);back.label:SetFont("Fonts\\FRIZQT__.TTF",12,"")
  place(extras["!"],10,1);place(extras["?"],10,2)
  place(capsButton,0,3);place(extras[","],8,3);place(extras["."],9,3);place(extras["/"],10,3)
  local function span(cells)return cells*(unit+gap)-gap end
  -- Bottom controls: symbols, Shift, Space, cursor left/right, Send/Done.
  place(symbol,0,4,span(1.6));place(shift,1.75,4,span(1.8))
  place(space,3.7,4,span(3.8));place(arrowLeft,7.7,4,span(.95));place(arrowRight,8.8,4,span(.95));place(send,9.9,4,span(1.1))
  for _,row in ipairs(rows)do for _,b in ipairs(row)do b.label:SetFont("Fonts\\FRIZQT__.TTF",18*(WoWU_GetPreference("keyboardLetters")or 1),"")end end
  for _,b in pairs(extras)do b.label:SetFont("Fonts\\FRIZQT__.TTF",18*(WoWU_GetPreference("keyboardLetters")or 1),"")end
  updateKeys()
 end
 function f:Open(targetEdit,sendAction,caption)
  self.editingRecipient=false;self:SetTarget(targetEdit,sendAction,caption);self:Layout();self:Show();input:SetFocus();if options.changed then options.changed(true)end
 end
 f:SetScript("OnHide",function()f:StopMovingOrSizing();f.dashboardDraft=input:GetText();input:ClearFocus();if f.recipient then f.recipient:ClearFocus()end;if options.changed then options.changed(false)end end)
 parent:HookScript("OnHide",function()f:Hide()end)
 parent:HookScript("OnSizeChanged",function()if f:IsShown()then f:Layout();if options.changed then options.changed(true)end end end)
 return f
end
function K.ToggleButton(parent,fn)
 local b=key(parent,"Keyboard",fn);b:SetSize(52,40);b.label:Hide();b:SetPoint("BOTTOM",parent,"BOTTOM",0,12);b.label:SetFont("Fonts\\FRIZQT__.TTF",14,"")
 -- Crisp drawn keyboard icon; no font glyph or atlas dependency.
 local function rect(x,y,w,h)local t=b:CreateTexture(nil,"ARTWORK");if WoWU_Theme.light then t:SetColorTexture(.24,.18,.1,1)elseif WoWU_Theme.silver then t:SetColorTexture(.9,.94,1,1)else t:SetColorTexture(.95,.80,.49,1)end;t:SetPoint("TOPLEFT",x,y);t:SetSize(w,h)end
 rect(9,-10,34,2);rect(9,-28,34,2);rect(9,-10,2,20);rect(41,-10,2,20)
 for row=0,1 do for col=0,5 do rect(14+col*4.5,-15-row*4,3,2)end end
 rect(19,-24,16,2)
 b:HookScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Toggle keyboard");GameTooltip:Show()end)
 b:HookScript("OnLeave",function()GameTooltip:Hide()end)
 return b
end
function WoWU_BuildDashboardKeyboard(parent)
 local keyboard=K.Create(parent,{dashboard=true,draggable=true})
 local toggle=K.ToggleButton(parent,function()if keyboard:IsShown()then keyboard:Hide()else keyboard:Open()end end)
 return toggle,keyboard
end
