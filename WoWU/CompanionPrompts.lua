-- Keep native prompt handlers/timers, but place their windows on the companion display.
WoWUCompanionPrompts={}
local P=WoWUCompanionPrompts
local saved,watched={},{}
local main,mailKey,mailKeyboard,lastEdit
local names={'LFGDungeonReadyPopup','LFGDungeonReadyDialog','LFGRoleCheckPopup','LFDRoleCheckPopup','LFGReadyCheckPopup','ReadyCheckFrame','InspectFrame','CalendarFrame','CalendarViewEventFrame','CalendarCreateEventFrame','CalendarViewHolidayFrame','CalendarViewRaidFrame'}
local alertNames={LFGDungeonReadyPopup='Your dungeon queue is ready',LFGDungeonReadyDialog='Your dungeon queue is ready',LFGRoleCheckPopup='Choose your group role',LFDRoleCheckPopup='Choose your group role',LFGReadyCheckPopup='Your group is checking readiness',ReadyCheckFrame='Ready check'}
local alertKinds={PARTY_INVITE='Party invitation',PARTY_INVITE_XREALM='Party invitation',GROUP_INVITE_CONFIRMATION='Group invitation',CONFIRM_SUMMON='Summon request',CONFIRM_SUMMON_SCENARIO='Summon request',CONFIRM_SUMMON_STARTING_AREA='Summon request',RESURRECT='Resurrection request',RESURRECT_NO_SICKNESS='Resurrection request',RESURRECT_NO_TIMER='Resurrection request',DEATH='Release spirit',RECOVER_CORPSE='Recover your corpse',RECOVER_CORPSE_INSTANCE='Recover your corpse',XP_LOSS='Spirit healer resurrection',XP_LOSS_NO_SICKNESS_NO_DURABILITY='Spirit healer resurrection',CONFIRM_BATTLEFIELD_ENTRY='Your battleground queue is ready'}
local alertSerial=0
local alertSession=tostring(time())..':'..tostring(GetTime())
local function promptToken(f)
 local which=f.which or f:GetName()
 if f.WoWUAlertWhich~=which or not f.WoWUAlertToken then alertSerial=alertSerial+1;f.WoWUAlertWhich=which;f.WoWUAlertToken=alertSerial end
 return f.WoWUAlertToken
end
local kinds={PARTY_INVITE=true,PARTY_INVITE_XREALM=true,GROUP_INVITE_CONFIRMATION=true,CONFIRM_SUMMON=true,CONFIRM_SUMMON_SCENARIO=true,CONFIRM_SUMMON_STARTING_AREA=true,RESURRECT=true,RESURRECT_NO_SICKNESS=true,RESURRECT_NO_TIMER=true,DEATH=true,RECOVER_CORPSE=true,RECOVER_CORPSE_INSTANCE=true,XP_LOSS=true,XP_LOSS_NO_SICKNESS_NO_DURABILITY=true,CONFIRM_BATTLEFIELD_ENTRY=true}
for _,kind in ipairs({'CONFIRM_BUY_BANK_SLOT','CONFIRM_BUY_GUILDBANK_TAB','CONFIRM_TALENT_WIPE','CONFIRM_LEARN_DUAL_SPEC','AUCTION_HOUSE_POST_ERROR','WOWU_ABANDON_QUEST'})do kinds[kind]=true end
local function movable(f)return not InCombatLockdown()or not f:IsProtected()end
local function restore(f)
 local s=saved[f];if not s or not movable(f)then return end
 saved[f]=nil;f:SetScale(s.scale);f:SetClampedToScreen(s.clamped);f:SetFrameStrata(s.strata);f:SetFrameLevel(s.level);f:ClearAllPoints()
 for _,point in ipairs(s.points)do f:SetPoint(unpack(point))end
end
local function place(f)
 if not main or not main:IsVisible()or not f:IsShown()or not movable(f)then return end
 if not saved[f]then
  local s={scale=f:GetScale(),clamped=f:IsClampedToScreen(),strata=f:GetFrameStrata(),level=f:GetFrameLevel(),points={}}
  for i=1,f:GetNumPoints()do s.points[i]={f:GetPoint(i)}end;saved[f]=s
 end
 local parentScale=f:GetParent()and f:GetParent():GetEffectiveScale()or 1
 local availableScale=main:GetEffectiveScale()/parentScale
 local scale=math.min(f==InspectFrame and availableScale*1.2 or availableScale,(main:GetWidth()-48)*availableScale/math.max(1,f:GetWidth()),(main:GetHeight()-100)*availableScale/math.max(1,f:GetHeight()))
 f:SetClampedToScreen(false);f:SetScale(math.max(.1,scale));f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(main:GetFrameLevel()+150)
 f:ClearAllPoints();f:SetPoint('CENTER',main,'CENTER',0,0)
end
local function watch(f)
 if not f or watched[f]then return end;watched[f]=true
 f:HookScript('OnShow',function(self)C_Timer.After(0,function()place(self)end)end)
 f:HookScript('OnHide',function(self)self.WoWUAlertToken=nil;restore(self)end)
 if f:IsShown()then place(f)end
end
local function activePrompt(f)
 if not f or not f:IsVisible()then return false end
 -- The dialog child can remain locally shown under a hidden pooled popup.
 -- A real proposal must also still exist and await the player's response.
 if (f==LFGDungeonReadyPopup or f==LFGDungeonReadyDialog)and type(GetLFGProposal)=='function'then
  local exists,_,_,_,_,_,_,responded=WoWUClient.Call(GetLFGProposal)
  if not exists or responded then return false end
 end
 return true
end
function P.Notifications()
 local result={};local seen={}
 local function add(f,title)
  if not activePrompt(f)or not title or seen[title]then return end;seen[title]=true
  local token=promptToken(f)
  result[#result+1]={key='request:'..alertSession..':'..token..':'..title,title=title,detail='Choose Respond to use the game\'s buttons on WoWU. This request ends when its native timer expires or you respond.',kind='requests',prompt=f,promptToken=token,actionText='Respond',popup=title,priority=200,requiresAction=true,icon=132053}
 end
 for name,title in pairs(alertNames)do add(_G[name],title)end
 for i=1,STATICPOPUP_NUMDIALOGS or 4 do local f=_G['StaticPopup'..i];if f then add(f,alertKinds[f.which])end end
 return result
end
function P.Focus(f,token)
 if not activePrompt(f)or promptToken(f)~=token then return false,'This request has ended.'end
 place(f);return true
end
local function scan()
 for f in pairs(saved)do if not main:IsVisible()or not f:IsShown()then restore(f)end end
 for _,name in ipairs(names)do watch(_G[name])end
 for i=1,STATICPOPUP_NUMDIALOGS or 4 do
  local f=_G['StaticPopup'..i]
  if f and kinds[f.which]then watch(f);place(f)end
 end
end
function P.HasModal()
 if WoWUDetails and WoWUDetails.IsShown()then return true end
 for f in pairs(saved)do if f:IsVisible()then return true end end
 return false
end
function P.Back()
 if WoWUDetails and WoWUDetails.IsShown()then WoWUDetails.Close();return true end
 -- B is an explicit user cancellation, never automatic acceptance.
 if InCombatLockdown()then return false end
 for i=STATICPOPUP_NUMDIALOGS or 4,1,-1 do
  local f=_G['StaticPopup'..i]
  if f and saved[f]and f:IsShown()then
   local b=f.GetButton2 and f:GetButton2()or f.button2
   if b and b:IsShown()and b:IsEnabled()then b:Click();return true end
  end
 end
 if ReadyCheckFrame and saved[ReadyCheckFrame]and ReadyCheckFrame:IsShown()and ReadyCheckFrameNoButton then ReadyCheckFrameNoButton:Click();return true end
 if LFGDungeonReadyDialog and saved[LFGDungeonReadyDialog]and LFGDungeonReadyDialog:IsVisible()then
  local b=LFGDungeonReadyDialog.leaveButton;if b and b:IsEnabled()then b:Click();return true end
 end
 for _,name in ipairs({'CalendarCreateEventFrame','CalendarViewEventFrame','CalendarViewHolidayFrame','CalendarViewRaidFrame','CalendarFrame','InspectFrame'})do
  local f=_G[name];if saved[f]and f:IsShown()and movable(f)then if f==InspectFrame and HideUIPanel then HideUIPanel(f)else f:Hide()end;return true end
 end
 return false
end
function WoWU_BuildCompanionPrompts(parent)
 main=parent
 mailKeyboard=WoWUKeyboard.Create(main,{draggable=true})
 mailKey=WoWUKeyboard.ToggleButton(main,function()
  if mailKeyboard:IsShown()then mailKeyboard:Hide();return end
  local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  local target=focus and focus.WoWUMailKeyboardHook and focus or lastEdit
  if not target or not target:IsVisible()then target=SendMailNameEditBox end
  if target and target:IsVisible()then mailKeyboard:Open(target,nil,'Done')end
 end)
 mailKey:ClearAllPoints();mailKey:SetPoint('BOTTOM',main,'BOTTOM',0,4);mailKey:SetFrameStrata('DIALOG');mailKey:Hide()
 local function mailFocus()
  for _,name in ipairs({'SendMailNameEditBox','SendMailSubjectEditBox','SendMailBodyEditBox','SendMailMoneyGold','SendMailMoneySilver','SendMailMoneyCopper'})do
   local edit=_G[name]
   if edit and not edit.WoWUMailKeyboardHook then edit.WoWUMailKeyboardHook=true;edit:HookScript('OnEditFocusGained',function(self)lastEdit=self end)end
  end
 end
 local e=CreateFrame('Frame')
 for _,event in ipairs({'ADDON_LOADED','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','MAIL_SHOW','MAIL_CLOSED','LFG_PROPOSAL_SHOW','LFG_ROLE_CHECK_SHOW','READY_CHECK','PARTY_INVITE_REQUEST','CONFIRM_SUMMON','RESURRECT_REQUEST','PLAYER_DEAD'})do pcall(e.RegisterEvent,e,event)end
 e:SetScript('OnEvent',function(_,event)
  if event=='MAIL_SHOW'then lastEdit=nil;mailFocus();if main:IsVisible()then mailKey:Show()end
  elseif event=='MAIL_CLOSED'then mailKey:Hide();mailKeyboard:Hide();lastEdit=nil end
  C_Timer.After(0,scan)
 end)
 if StaticPopup_Show then hooksecurefunc('StaticPopup_Show',function(which)
  if kinds[which]then local f=StaticPopup_FindVisible(which);if f then watch(f);place(f)end end
 end)end
 -- Static popups are pooled; never relocate an unrelated confirmation which reuses one.
 for i=1,STATICPOPUP_NUMDIALOGS or 4 do
  local f=_G['StaticPopup'..i]
  if f then watched[f]=true;f:HookScript('OnShow',function(self)if kinds[self.which]then C_Timer.After(0,function()if kinds[self.which]then place(self)end end)end end);f:HookScript('OnHide',function(self)self.WoWUAlertToken=nil;restore(self)end)end
 end
 main:HookScript('OnHide',function()mailKey:Hide();mailKeyboard:Hide();for f in pairs(saved)do restore(f)end end)
 main:HookScript('OnShow',function()scan();if MailFrame and MailFrame:IsShown()then mailKey:Show()end end)
 scan()
end
