-- User-driven navigation for WoWU conversations and the target action menu.
WoWUPadNavigation={}
local N=WoWUPadNavigation
local host,owner,rows,close,index,menu
local function combat()return InCombatLockdown()end
local function selectRow(n)
 if not rows or #rows==0 then return end
 if rows[index or 0]then rows[index]:UnlockHighlight()end
 index=(n-1)%#rows+1;local b=rows[index];b:LockHighlight()
 if b.WoWUReveal then b:WoWUReveal()end
end
function N.Clear(who)
 if who and owner~=who then return end
 if rows and rows[index or 0]then rows[index]:UnlockHighlight()end
 rows=nil;owner=nil;close=nil;index=nil
 if host and not combat()then host:Execute('self:ClearBindings()')end
end
function N.Set(who,list,onClose)
 if combat()or not WoWUController or not WoWUController.active then return end
 local previous=owner==who and rows and rows[index or 1]
 N.Clear();owner=who;rows=list;close=onClose
 if not host then
  host=CreateFrame('Frame',nil,UIParent,'SecureHandlerStateTemplate')
  host:SetAttribute('_onstate-combat',[[if newstate=='combat' then self:ClearBindings()end]])
  RegisterStateDriver(host,'combat','[combat] combat; peace')
  for _,d in ipairs({{'Prev',-1},{'Next',1},{'Accept',0},{'Back',2}})do
   local b=CreateFrame('Button','WoWUNav'..d[1],host);b:RegisterForClicks('AnyUp');local action=d[2]
   b:SetScript('OnClick',function()
    if combat()or not rows then return end
    if action==2 then N.Back()
    elseif action==0 then
     if WoWUCompanionPrompts and WoWUCompanionPrompts.HasModal()then return end
     local target=rows[index or 1];if target and target:IsVisible()and target:IsEnabled()then target:Click()end
    else selectRow((index or 1)+action)end
   end)
  end
 end
 for key,name in pairs({PADDUP='Prev',PADDLEFT='Prev',PADDDOWN='Next',PADDRIGHT='Next',PAD1='Accept',PAD2='Back'})do
  host:Execute(string.format('self:SetBindingClick(true,%q,%q,"LeftButton")',key,'WoWUNav'..name))
 end
 local selected=1;for i,b in ipairs(list)do if b==previous then selected=i;break end end
 selectRow(selected)
end
function N.Back()
 if combat()then return false end
 if WoWUControllerTargeting then WoWUControllerTargeting.LeaveCursor()end
 if WoWUKeyboard and WoWUKeyboard.CloseVisible()then return true end
 if WoWUAuctionHouse and WoWUAuctionHouse.Back and WoWUAuctionHouse.Back()then return true end
 if WoWUCompanionPrompts and WoWUCompanionPrompts.Back()then return true end
 if close then local fn=close;N.Clear();fn();return true end
 if WoWUInteractions and WoWUInteractions.HasActive and WoWUInteractions.HasActive()then WoWUInteractions.OnNavigate();return true end
 if menu and menu:IsShown()then menu:Hide();return true end
 if MerchantFrame and MerchantFrame:IsShown()and CloseMerchant then CloseMerchant();return true end
 if BankFrame and BankFrame:IsShown()and CloseBankFrame then CloseBankFrame();return true end
 if GameMenuFrame and GameMenuFrame:IsShown()then HideUIPanel(GameMenuFrame);return true end
 -- Use the same native window-closing path as Start, without opening the game menu.
 if CloseAllWindows and CloseAllWindows()then return true end
 return false
end
function N.TargetMenu()
 if combat()or not UnitExists('target')then return end
 if not menu then
  menu=CreateFrame('Frame',nil,WoWU_MainFrame or UIParent,'BackdropTemplate');menu:SetSize(480,440);menu:SetPoint('CENTER');menu:SetFrameStrata('DIALOG');WoWU_Theme.Panel(menu)
  local title=menu:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOP',0,-18);menu.title=title
  menu.buttons={}
  local actions={
   {'Interact',function()
    if C_PlayerInteractionManager and C_PlayerInteractionManager.InteractUnit then C_PlayerInteractionManager.InteractUnit('target')elseif InteractUnit then InteractUnit('target')end
   end},
   {'Inspect',function()if InspectUnit then InspectUnit('target')end end},
   {'Whisper',function()local n,r=UnitName('target');if n then ChatFrame_SendTell(r and r~=''and(n..'-'..r)or n)end end},
   {'Invite',function()local n,r=UnitName('target');if n then local fn=C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit;fn(r and r~=''and(n..'-'..r)or n)end end},
   {'Follow',function()FollowUnit('target')end},
   {'Trade',function()InitiateTrade('target')end},
   {'Back',function()end},
  }
  for i,d in ipairs(actions)do
   local b=CreateFrame('Button',nil,menu,'UIPanelButtonTemplate');b:SetSize(410,44);b:SetPoint('TOP',0,-60-(i-1)*50);b:SetNormalFontObject('GameFontNormalLarge');b:SetText(d[1]);menu.buttons[i]=b;local fn=d[2]
   b:SetScript('OnClick',function()
    if combat()then return end
    if UnitGUID('target')~=menu.targetGUID then menu:Hide();print('WoWU: Target changed. Open the target menu again.');return end
    menu:Hide();fn()
   end)
  end
  menu:HookScript('OnHide',function()N.Clear('target')end)
 end
 menu.targetGUID=UnitGUID('target');menu.title:SetText(UnitName('target')or 'Target');menu:Show();N.Set('target',menu.buttons,function()menu:Hide()end)
end
local e=CreateFrame('Frame');e:RegisterEvent('PLAYER_REGEN_DISABLED');e:RegisterEvent('PLAYER_REGEN_ENABLED')
e:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_REGEN_DISABLED'then rows=nil;close=nil;owner=nil;if menu then menu:Hide()end
 elseif host then host:Execute('self:ClearBindings()')end
end)
