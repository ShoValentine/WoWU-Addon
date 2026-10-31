-- Shared pin/drop behaviour for the grid and independent one-button widgets.
WoWUQuickAccess={}
local Q=WoWUQuickAccess
local cells={};local drag;local dragErrorReported
local function combat()return InCombatLockdown()end
local function character()return UnitGUID('player')or((UnitName('player')or 'Player')..'-'..GetRealmName())end
local function copy(e)if not e then return end;local c={};for k,v in pairs(e)do c[k]=v end;return c end
local function call(fn,...)if type(fn)=='function'then local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end end end
function Q.MountID(e)
 if e and e.kind=='spell'and C_MountJournal then
  local id=e.mountID
  if not id and C_MountJournal.GetMountFromSpell then local ok,value=pcall(C_MountJournal.GetMountFromSpell,e.id);if ok then id=value end end
  if type(id)=='number'and id>0 then return id end
 end
end
-- Only call from the user's hardware click, never a refresh or timer.
function Q.ActivateMount(e)
 if combat()then return end
 local mountID=Q.MountID(e);if not mountID then return end
 local active=select(4,C_MountJournal.GetMountInfoByID(mountID))
 local ok,err
 if active then ok,err=pcall(C_MountJournal.Dismiss)
 else ok,err=pcall(C_MountJournal.SummonByID,mountID)end
 if not ok and UIErrorsFrame then UIErrorsFrame:AddMessage('WoWU: '..tostring(err),1,.2,.2)end
end
local function singleData()
 local p=WoWUDashboardLayout.Profile();p.singleShortcuts=p.singleShortcuts or {}
 local key=character();p.singleShortcuts[key]=p.singleShortcuts[key]or {};return p.singleShortcuts[key]
end
local function entryFromCursor()
 local kind,id,_,spell=GetCursorInfo()
 local e
 if kind=='item'then
  e={kind='item',id=id,name=call(C_Item and C_Item.GetItemNameByID,id)or call(GetItemInfo,id),icon=call(C_Item and C_Item.GetItemIconByID,id)or call(GetItemIcon,id)}
 elseif kind=='spell'then
  id=spell or id;local s=call(C_Spell and C_Spell.GetSpellInfo,id)
  e={kind='spell',id=id,name=s and s.name,icon=s and s.iconID}
 elseif kind=='mount'and C_MountJournal then
  local n,s,t=call(C_MountJournal.GetMountInfoByID,id);e={kind='spell',id=s,mountID=id,name=n,icon=t}
 end
 if e and e.id then e.mountID=Q.MountID(e);return e end
end
function Q.Refresh()
 for _,b in ipairs(cells)do
  local e=b.pin.get();b.pinEntry=e
  b.icon:SetTexture(e and e.icon or nil);b.emptyArtwork:SetShown(not e);b.emptyMark:SetShown(not e)
  b.text:SetText(e and(e.name or(e.kind..' '..e.id))or '')
  if b.count then
   local n=e and e.kind=='item'and C_Item and C_Item.GetItemCount and C_Item.GetItemCount(e.id)or 0
   b.count:SetText(n and n>1 and tostring(n)or '')
  end
  if not combat()then
   -- Journal mounts need a hardware-click summon, not a spellbook cast.
   local mountID=Q.MountID(e)
   b:SetAttribute('type',not mountID and e and e.kind or nil)
   b:SetAttribute('spell',not mountID and e and e.kind=='spell'and e.id or nil)
   b:SetAttribute('item',e and e.kind=='item'and('item:'..e.id)or nil)
  end
 end
end
local function changed()
 if WoWU_RefreshDashboard then WoWU_RefreshDashboard()end;Q.Refresh()
end
local function drop(target)
 if combat()then return end
 if drag then
  local source=drag.source
  if source~=target then
   local a,b=source.pin,target.pin
   if a.grid and b.grid then
    local list=WoWUDashboardLayout.Shortcuts(character());local e=table.remove(list,a.index)
    if e then table.insert(list,math.min(b.index,#list+1),e)end
   else local e=copy(a.get());local other=copy(b.get());a.set(other);b.set(e)end
  end
  changed();return true
 else
  local e=entryFromCursor();if not e then return end
  target.pin.set(e);target.ignoreClickUntil=GetTime()+.25;ClearCursor();changed();return true
 end
end
function Q.CancelDrag()
 if drag then drag.source.icon:SetAlpha(1)end
 if drag and drag.source.pin.scroll then drag.source.pin.scroll.WoWUSuspendTouch=combat()end
 drag=nil
end
function Q.Attach(b,pin)
 b.pin=pin;cells[#cells+1]=b;b:RegisterForDrag('LeftButton')
 b:SetScript('PreClick',function(self,_,down)
  if down or combat()then return end
  local scroll=pin.scroll
  if drag or GetCursorInfo()or IsShiftKeyDown()or(self.ignoreClickUntil or 0)>GetTime()or(scroll and WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll))then
   self.pinSuppressed=true;self:SetAttribute('type',nil)
  end
 end)
 b:SetScript('PostClick',function(self,button,down)
  if down or combat()then return end
  if not drag and GetCursorInfo()then drop(self)
  elseif IsShiftKeyDown()and(self.ignoreClickUntil or 0)<=GetTime()then pin.set(nil);changed()
  elseif not self.pinSuppressed and not drag and button=='LeftButton'and(self.ignoreClickUntil or 0)<=GetTime()then
   Q.ActivateMount(pin.get())
  end
  if self.pinSuppressed then self.pinSuppressed=nil;Q.Refresh()end
 end)
 b:SetScript('OnReceiveDrag',function(self)if not combat()then drop(self)end end)
 local function startDrag(self)
  if combat()or WoWUDashboardLayout.editing or not pin.get()then return end
  self.pinPress=nil
  drag={source=self};self.ignoreClickUntil=GetTime()+.3
  if pin.scroll then pin.scroll.WoWUSuspendTouch=true;if WoWU_StopTouchScroll then WoWU_StopTouchScroll(pin.scroll,true)end end
  -- Mark the source without a cursor-following frame that updates every tick.
  GameTooltip:Hide();self.icon:SetAlpha(.45)
 end
 local function finishDrag(self)
  self.pinPress=nil
  if drag and drag.source==self then
   for _,target in ipairs(cells)do if target:IsVisible()and target:IsMouseOver()then drop(target);target.ignoreClickUntil=GetTime()+.3;break end end
   self.ignoreClickUntil=GetTime()+.3
   Q.CancelDrag()
  end
 end
 b:HookScript('OnMouseDown',function(self,button)
  self.pinPress=nil
  if button~='LeftButton'or combat()or WoWUDashboardLayout.editing or not pin.get()or GetCursorInfo()or IsShiftKeyDown()then return end
  local x,y=GetCursorPosition()
  self.pinPress={time=GetTime(),x=x,y=y,entry=pin.get(),scroll=pin.scroll and pin.scroll:GetVerticalScroll()}
 end)
 local function holdUpdate(self)
  local press=self.pinPress;if not press then return end
  if combat()or WoWUDashboardLayout.editing or not IsMouseButtonDown('LeftButton')or not self:IsMouseOver()or pin.get()~=press.entry then self.pinPress=nil;return end
  local x,y=GetCursorPosition();local scale=self:GetEffectiveScale()
  -- Movement or scrolling before the hold completes belongs to the list.
  if (x-press.x)^2+(y-press.y)^2>(12*scale)^2 or (pin.scroll and math.abs(pin.scroll:GetVerticalScroll()-(press.scroll or 0))>2)then self.pinPress=nil;return end
  if GetTime()-press.time>=2 then startDrag(self)end
 end
 b:HookScript('OnUpdate',function(self)
  if not self.pinPress then return end
  local ok,err=pcall(holdUpdate,self)
  if not ok then
   self.pinPress=nil;Q.CancelDrag()
   if not dragErrorReported then dragErrorReported=true;print('WoWU: Quick Access drag stopped: '..tostring(err))end
  end
 end)
 -- Native drag-start fires on movement, which must remain a scroll gesture.
 b:SetScript('OnDragStart',function()end)
 b:SetScript('OnDragStop',finishDrag)
 b:HookScript('OnMouseUp',function(self,button)if button=='LeftButton'then finishDrag(self)end end)
 b:HookScript('OnHide',function()b.pinPress=nil;if drag and drag.source==b then Q.CancelDrag()end end)
 b:SetScript('OnEnter',function(self)
  local e=pin.get();GameTooltip:SetOwner(self,'ANCHOR_TOP')
  if e and e.kind=='spell'then GameTooltip:SetSpellByID(e.id)
  elseif e then GameTooltip:SetItemByID(e.id)else GameTooltip:SetText('Drop an item, spell or mount here')end
  GameTooltip:AddLine('Hold still for 2 seconds, then drag to move or reorder. Shift-click removes a pin.',.8,.8,.8,true);GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function()GameTooltip:Hide()end)
end
function Q.AttachGrid(b,index,scroll)
 Q.Attach(b,{grid=true,index=index,scroll=scroll,get=function()return WoWUDashboardLayout.Shortcuts(character())[index]end,
  set=function(e)local list=WoWUDashboardLayout.Shortcuts(character());if e then list[math.min(index,#list+1)]=e elseif list[index]then table.remove(list,index)end end})
end
local function single(parent,id)
 local b=CreateFrame('Button',nil,parent,'SecureActionButtonTemplate,BackdropTemplate');WoWU_Theme.Panel(b)
 b:RegisterForClicks('AnyDown','AnyUp');b:SetAttribute('useOnKeyDown',false)
 b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('CENTER',0,5)
 b.emptyArtwork=b:CreateTexture(nil,'BACKGROUND');b.emptyArtwork:SetTexture(WoWU_Theme.assets.slot);b.emptyArtwork:SetPoint('CENTER',b.icon,'CENTER');b.emptyArtwork:SetSize(48,48)
 b.emptyMark=b:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');b.emptyMark:SetPoint('CENTER',b.icon,'CENTER');b.emptyMark:SetText('+')
 b.text=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');b.text:SetPoint('BOTTOM',0,5);b.text:SetHeight(24);b.text:SetWordWrap(true)
 b.count=b:CreateFontString(nil,'OVERLAY','GameFontHighlight');b.count:SetPoint('BOTTOMRIGHT',b.icon,'BOTTOMRIGHT',0,0)
 Q.Attach(b,{get=function()return singleData()[id]end,set=function(e)singleData()[id]=e end})
 return b
end
function Q.AddDefinitions(defs)
 for i=1,20 do
  local id='quickSingle'..i
  defs[#defs+1]={id=id,name='Quick Access Button',repeatGroup='singleQuick',minW=2,minH=2,create=function(p)return single(p,id)end,
   resize=function(b,w,h)
    local labels=h>=90;b.text:SetShown(labels);b.text:SetWidth(math.max(20,w-10))
    local size=math.max(20,math.min(70,w-14,h-(labels and 36 or 14)))
    b.icon:SetSize(size,size);b.emptyArtwork:SetSize(size,size)
    b.icon:ClearAllPoints();b.icon:SetPoint('CENTER',b,'CENTER',0,labels and 15 or 0)
    b.text:ClearAllPoints();b.text:SetPoint('TOP',b.icon,'BOTTOM',0,-6)
    b.text:SetJustifyH('CENTER');b.text:SetJustifyV('MIDDLE')
   end}
 end
 return defs
end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_REGEN_DISABLED');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('BAG_UPDATE_DELAYED')
events:SetScript('OnEvent',function(_,e)if e=='PLAYER_REGEN_DISABLED'then Q.CancelDrag()else Q.Refresh()end end)
