-- Shared NPC service content takeover. No floating overlay; top navigation stays available.
WoWUInteractions={}
local I=WoWUInteractions
local function call(fn,...)
 if type(fn)~='function'then return end
 local function pack(...)return {n=select('#',...),...}end
 local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local registry={}
if hooksecurefunc and RegisterPlayerInteraction then hooksecurefunc('RegisterPlayerInteraction',function(kind,data)if data and data.frame then registry[kind]=data.frame end end)end
local known={TradePartner={'TradeFrame'},TaxiNode={'FlightMapFrame','TaxiFrame'},Trainer={'ClassTrainerFrame'},GuildBanker={'GuildBankFrame'},Registrar={'GuildRegistrarFrame'},PetitionVendor={'PetitionFrame'},GuildTabardVendor={'TabardFrame'},MailInfo={'MailFrame'},Auctioneer={'AuctionHouseFrame','AuctionFrame'},StableMaster={'StableFrame','PetStableFrame'},BattleMaster={'PVPFrame'},Transmogrifier={'TransmogFrame','WardrobeFrame'},BlackMarket={'BlackMarketFrame'},GarrArchitect={'GarrisonBuildingFrame'},GarrMission={'GarrisonMissionFrame'},ShipmentCrafter={'GarrisonCapacitiveDisplayFrame'},GarrRecruitment={'GarrisonRecruiterFrame'},GarrTalent={'GarrisonTalentFrame'},PlayerChoice={'PlayerChoiceFrame'},ArtifactForge={'ArtifactFrame'},ObliterumForge={'ObliterumForgeFrame'},ScrappingMachine={'ScrappingMachineFrame'},AzeriteRespec={'AzeriteRespecFrame'},ItemInteraction={'ItemInteractionFrame'},ChromieTime={'ChromieTimeFrame'},CovenantPreview={'CovenantPreviewFrame'},LegendaryCrafting={'RunecarvingFrame'},WeeklyRewards={'WeeklyRewardsFrame'},Soulbind={'SoulbindViewer'},CovenantSanctum={'CovenantSanctumFrame'},ItemUpgrade={'ItemUpgradeFrame'},Renown={'CovenantRenownFrame'},MajorFactionRenown={'MajorFactionRenownFrame'},ProfessionsCustomerOrder={'ProfessionsCustomerOrdersFrame'},ProfessionsCraftingOrder={'ProfessionsFrame'},Professions={'ProfessionsFrame'},TraitSystem={'GenericTraitFrame'},PerksProgramVendor={'PerksProgramFrame'}}
local current,root,slot,serviceTitle
if WoWUClient.isClassic then
 known.Banker={'BankFrame'};known.CharacterBanker={'BankFrame'}
 known.Transmogrifier={'TransmogrifyFrame','TransmogFrame','WardrobeFrame'}
end
local internal=false
local candidate,candidateAt
if hooksecurefunc and ShowUIPanel then hooksecurefunc('ShowUIPanel',function(f)if f and f.GetObjectType then candidate,candidateAt=f,GetTime()end end)end
local function restoreFrame(s)
 if not s or not s.frame then return end
 local f=s.frame
 if InCombatLockdown()and f:IsProtected()then return end
 for _,rec in ipairs(s.childScaling or {})do
  rec.frame:SetIgnoreParentScale(rec.ignoreParentScale);rec.frame:SetScale(rec.scale)
 end
 if s.parent then f:SetParent(s.parent)end
 if s.ignoreParentScale~=nil then f:SetIgnoreParentScale(s.ignoreParentScale)end
 if s.w then f:SetSize(s.w,s.h)end
 f:SetScale(s.scale);if s.strata then f:SetFrameStrata(s.strata);f:SetFrameLevel(s.level)end;f:ClearAllPoints();for _,p in ipairs(s.points)do f:SetPoint(unpack(p))end;f:SetClampedToScreen(s.clamped)
end
function I.Release()
 if current and current.native and InCombatLockdown()and current.native.frame:IsProtected()then I.pendingRelease=true;return end
 I.pendingRelease=nil
 local c=current;current=nil;if not c then return end
 if c.cleanup then c.cleanup()end
 restoreFrame(c.mailOpen)
 restoreFrame(c.native)
 if c.mail and c.bags and c.bags.WoWUSetMailLayout then c.bags.WoWUSetMailLayout(false)end
 if c.mail and WoWUQoL and WoWUQoL.SetMailHosted then WoWUQoL.SetMailHosted(false)end
 if root then root:Hide()end
 if c.page and c.restorePage and not c.page:IsShown()then c.page:Show()end
end
function I.OnNavigate()
 if internal or not current then return end
 local c=current
 if c.close then c.close()else I.Release();if c.kind and C_PlayerInteractionManager then call(C_PlayerInteractionManager.ClearInteraction,c.kind)end end
end
function I.Navigate(name)
 internal=true;WoWU_ShowPage(name);internal=false
end
function I.Possess(owner,kind,cleanup,close)
 if not root or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
 if current and current.owner==owner then current.kind=kind;return root,slot end
 I.Release()
 local page=WoWU_GetCurrentModuleFrame and WoWU_GetCurrentModuleFrame()
 current={owner=owner,kind=kind,page=page,restorePage=page and page:IsShown(),cleanup=cleanup,close=close}
 if page then page:Hide()end
 root:ClearAllPoints();root:SetPoint('TOPLEFT',WoWU_MainFrame,'TOPLEFT',40,-93);root:SetPoint('BOTTOMRIGHT',WoWU_MainFrame,'BOTTOMRIGHT',-40,40)
 slot:ClearAllPoints();slot:SetPoint('TOPLEFT',12,-48);slot:SetPoint('BOTTOMRIGHT',-12,12)
 serviceTitle:SetText('');root:Show();return root,slot
end
function I.SetTitle(value)if serviceTitle then serviceTitle:SetText(value or '')end end
function I.HasActive()return current~=nil end
function I.IsOwner(owner)return current and current.owner==owner end
local fitting=false
local function inheritServiceScale(state)
 if not state.uniformChildScale then return end
 state.childScaling=state.childScaling or {};state.scaledChildren=state.scaledChildren or {}
 local function visit(parent)
  for _,child in ipairs({parent:GetChildren()})do
   if not(child.IsForbidden and child:IsForbidden())then
    if child.IsIgnoringParentScale and child.SetIgnoreParentScale then
     local saved=state.scaledChildren[child]
     if not saved and child:IsIgnoringParentScale()then
      saved={frame=child,ignoreParentScale=true,scale=child:GetScale()}
      state.scaledChildren[child]=saved;state.childScaling[#state.childScaling+1]=saved
     end
     if saved then
      if child:IsIgnoringParentScale()then child:SetIgnoreParentScale(false)end
      if child:GetScale()~=1 then child:SetScale(1)end
     end
    end
    visit(child)
   end
  end
 end
 visit(state.frame)
end
local function fitNative()
 if fitting then return end
 local c=current;if not c or not c.native then return end
 local f=c.native.frame;if InCombatLockdown()and f:IsProtected()then return end
 if c.native.docked then
  fitting=true
  if f:GetParent()~=slot then f:SetParent(slot)end
  if f.SetIgnoreParentScale and f:IsIgnoringParentScale()then f:SetIgnoreParentScale(false)end
  if c.native.designWidth and (math.abs(f:GetWidth()-c.native.designWidth)>.1 or math.abs(f:GetHeight()-c.native.designHeight)>.1)then f:ClearAllPoints();f:SetSize(c.native.designWidth,c.native.designHeight)end
  inheritServiceScale(c.native)
 end
 local parentScale=f:GetParent()and f:GetParent():GetEffectiveScale()or 1
 local scale=math.min(slot:GetWidth()*slot:GetEffectiveScale()/(math.max(1,f:GetWidth())*parentScale),slot:GetHeight()*slot:GetEffectiveScale()/(math.max(1,f:GetHeight())*parentScale))
 scale=math.max(.1,math.min(4,scale))
 if c.native.docked and f:GetNumPoints()==1 then
  local point,relative,to,x,y=f:GetPoint(1)
  if point=='CENTER'and relative==slot and to=='CENTER'and x==0 and y==0
   and math.abs(f:GetScale()-scale)<.0001 and f:GetFrameStrata()==root:GetFrameStrata()
   and f:GetFrameLevel()==root:GetFrameLevel()+15 and not f:IsClampedToScreen()then fitting=false;return end
 end
 f:SetFrameStrata(root:GetFrameStrata());f:SetFrameLevel(root:GetFrameLevel()+15)
 f:SetClampedToScreen(false);f:SetScale(math.max(.1,math.min(4,scale)));f:ClearAllPoints();f:SetPoint('CENTER',slot,'CENTER',0,0)
 fitting=false
end
local function fit()
 if fitting or (current and current.native and current.native.fitFailed)then return end
 local ok,err=pcall(fitNative);fitting=false
 if not ok then
  if current and current.native then current.native.fitFailed=true end
  print('WoWU: NPC window docking stopped: '..tostring(err))
 end
end
local function showService(kind,frame)
 if not root or not frame or not frame:IsShown()or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
 local E=Enum and Enum.PlayerInteractionType or {}
 -- Native service windows can inherit protection from their action buttons.
 -- They may still be positioned outside combat, like other protected UI.
 if frame:IsProtected()and not WoWUClient.isClassic and kind~=E.Transmogrifier and kind~=E.PerksProgramVendor then return end
 if frame.IsForbidden and frame:IsForbidden()then return end
 I.Release()
 local mail=kind==E.MailInfo
 local classicBank=WoWUClient.isClassic and (kind==E.Banker or kind==E.CharacterBanker)
 if mail or classicBank then I.Navigate('Bags')end
 local _,area=I.Possess('service',kind)
 if not area then return end
 local points={};for n=1,frame:GetNumPoints()do points[n]={frame:GetPoint(n)}end
 current.native={frame=frame,scale=frame:GetScale(),clamped=frame:IsClampedToScreen(),points=points,strata=frame:GetFrameStrata(),level=frame:GetFrameLevel()}
 if kind==E.Transmogrifier or kind==E.PerksProgramVendor then
  current.native.docked=true;current.native.parent=frame:GetParent();current.native.w=frame:GetWidth();current.native.h=frame:GetHeight()
  if kind==E.PerksProgramVendor then
   current.native.designWidth=1920;current.native.designHeight=1080
   current.native.uniformChildScale=true
  end
  if frame.IsIgnoringParentScale and frame.SetIgnoreParentScale then
   current.native.ignoreParentScale=frame:IsIgnoringParentScale();frame:SetIgnoreParentScale(false)
  end
  current.close=function()
   if HideUIPanel then HideUIPanel(frame)else frame:Hide()end
   I.Release()
   if C_PlayerInteractionManager then call(C_PlayerInteractionManager.ClearInteraction,kind)end
  end
 end
 if mail or classicBank then
  local page=current.page;if page then page:Show()end;current.restorePage=false;current.mail=true
  current.bags=WoWU_BagsPanel
  if not current.bags or not current.bags.WoWUSetMailLayout then I.Release();return end
  current.bags.WoWUSetMailLayout(true,classicBank and 'bank'or nil)
  if mail and WoWUQoL and WoWUQoL.SetMailHosted then WoWUQoL.SetMailHosted(true)end
  root:ClearAllPoints();root:SetPoint('TOPLEFT',WoWU_BagsPanel,'TOP',12,0);root:SetPoint('BOTTOMRIGHT',WoWU_BagsPanel,'BOTTOMRIGHT',0,0)
  if mail and OpenMailFrame and not OpenMailFrame.WoWUMailContentHook then
   OpenMailFrame.WoWUMailContentHook=true
   OpenMailFrame:HookScript('OnShow',function(f)
    if not current or not current.mail then return end
    local points={};for i=1,f:GetNumPoints()do points[i]={f:GetPoint(i)}end
    current.mailOpen={frame=f,scale=f:GetScale(),clamped=f:IsClampedToScreen(),points=points,strata=f:GetFrameStrata(),level=f:GetFrameLevel()}
    f:SetClampedToScreen(false);f:SetFrameStrata(root:GetFrameStrata());f:SetFrameLevel(root:GetFrameLevel()+25)
    local parentScale=f:GetParent()and f:GetParent():GetEffectiveScale()or 1
    local scale=math.min(slot:GetWidth()*slot:GetEffectiveScale()/(math.max(1,f:GetWidth())*parentScale),slot:GetHeight()*slot:GetEffectiveScale()/(math.max(1,f:GetHeight())*parentScale))
    f:SetScale(math.max(.1,math.min(4,scale)));f:ClearAllPoints();f:SetPoint('CENTER',slot,'CENTER',0,0)
   end)
   OpenMailFrame:HookScript('OnHide',function()
    if current and current.mailOpen then local saved=current.mailOpen;current.mailOpen=nil;restoreFrame(saved)end
   end)
  end
 end
 serviceTitle:SetText(mail and 'Mail - Inbox and Send Mail'or classicBank and 'Bank - Inventory and Bank'or kind==E.Transmogrifier and 'Transmogrify'or kind==E.PerksProgramVendor and 'Trading Post'or(call(UnitName,'npc')or 'NPC Service'))
 fit()
 if CloseAllBags then CloseAllBags(frame)end
 if not frame.WoWUInteractionHideHook then
  frame.WoWUInteractionHideHook=true
  frame:HookScript('OnHide',function()if current and current.native and current.native.frame==frame then I.Release()end end)
 end
end
-- Retail's transmog UI is loaded on demand. Its interaction event may precede
-- the actual frame, so bind its OnShow as well as retrying the initial request.
local transmogGeneration=0
local legacyTransmogOpen=false
local function transmogKind()return Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Transmogrifier end
local function transmogIsOpen()
 if WoWUClient.isClassic and legacyTransmogOpen then return true end
 local kind=transmogKind()
 local interacting=kind and C_PlayerInteractionManager and call(C_PlayerInteractionManager.IsInteractingWithNpcOfType,kind)
 return interacting==true or (interacting==nil and legacyTransmogOpen)
end
local function dockTransmog()
 local kind=transmogKind()
 if not kind or not root or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
 for _,name in ipairs({'TransmogrifyFrame','TransmogFrame','WardrobeFrame'})do
  local f=_G[name]
  if f and f:IsShown()and (name=='TransmogFrame'or transmogIsOpen())then
   if current and current.owner=='service'and current.native and current.native.frame==f then fit()
   else showService(kind,f)end
   return
  end
 end
end
local tradingPanelState
local tradingPanelOptions={area='center',allowOtherPanels=1,neverAllowOtherPanels=0,centerFrameSkipAnchoring=true,checkFit=0}
local function setTradingPanelAttribute(f,key,value)
 if UIPanelWindows and UIPanelWindows.PerksProgramFrame then SetUIPanelAttribute(f,key,value)
 else f:SetAttributeNoHandler('UIPanelLayout-defined',true);f:SetAttributeNoHandler('UIPanelLayout-'..key,value)end
end
local function restoreTradingPanel()
 if not tradingPanelState or InCombatLockdown()then return end
 local s=tradingPanelState;tradingPanelState=nil
 for _,rec in ipairs(s.attributes)do
  if s.frame:GetAttribute('UIPanelLayout-'..rec.key)==tradingPanelOptions[rec.key]then setTradingPanelAttribute(s.frame,rec.key,rec.value)end
 end
 if not(UIPanelWindows and UIPanelWindows.PerksProgramFrame)then s.frame:SetAttributeNoHandler('UIPanelLayout-defined',s.defined)end
end
local function prepareTradingPanel()
 local f=_G.PerksProgramFrame
 -- IsShown describes the user's WoWU choice even if the fullscreen panel has
 -- already hidden UIParent. IsVisible would reject the exact case we repair.
 if not f or not root or not WoWU_MainFrame:IsShown()or InCombatLockdown()or not SetUIPanelAttribute then return end
 if not tradingPanelState then
  local definition=UIPanelWindows and UIPanelWindows.PerksProgramFrame or {}
  local attributes={}
  for key in pairs(tradingPanelOptions)do
   local value=f:GetAttribute('UIPanelLayout-'..key)
   if not f:GetAttribute('UIPanelLayout-defined')then value=definition[key]end
   attributes[#attributes+1]={key=key,value=value}
  end
  tradingPanelState={frame=f,attributes=attributes,defined=f:GetAttribute('UIPanelLayout-defined')}
 end
 for key,value in pairs(tradingPanelOptions)do
  if f:GetAttribute('UIPanelLayout-'..key)~=value then setTradingPanelAttribute(f,key,value)end
 end
 -- Recover without Hide/Show: hiding the native window ends the NPC service.
 if GetUIPanel and GetUIPanel('fullscreen')==f and RestoreUIPanelArea then
  RestoreUIPanelArea(f)
  if GetUIPanel('fullscreen')~=f and not UIParent:IsShown()then UIParent:Show()end
 end
end
local function dockTradingPost()
 prepareTradingPanel()
 local kind=Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.PerksProgramVendor
 local f=_G.PerksProgramFrame
 if not kind or not f or not f:IsShown()or not root or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
 if current and current.native and current.native.frame==f then fit()else showService(kind,f)end
end
local function hookTransmog()
 prepareTradingPanel()
 for _,name in ipairs({'TransmogrifyFrame','TransmogFrame','WardrobeFrame','PerksProgramFrame'})do
  local f=_G[name]
  if f and not f.WoWUTransmogDockHook then
   f.WoWUTransmogDockHook=true
   f:HookScript('OnShow',function()C_Timer.After(0,name=='PerksProgramFrame'and dockTradingPost or dockTransmog)end)
  end
 end
end
local function requestTransmog()
 transmogGeneration=transmogGeneration+1;local generation=transmogGeneration
 for _,delay in ipairs({0,.1,.3,.75,1.5})do
  C_Timer.After(delay,function()
   if generation~=transmogGeneration then return end
   hookTransmog();dockTransmog();dockTradingPost()
  end)
 end
end
function WoWU_BuildInteractions(main)
 root=CreateFrame('Frame',nil,main,'BackdropTemplate');WoWU_Theme.Panel(root);root:SetFrameLevel(main:GetFrameLevel()+40);root:Hide();root:EnableMouse(true)
 serviceTitle=root:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');serviceTitle:SetPoint('TOPLEFT',18,-15);WoWU_Theme.TextColor(serviceTitle,.95,.82,.56)
 slot=CreateFrame('Frame',nil,root)
 slot:HookScript('OnSizeChanged',fit)
 local close=CreateFrame('Button',nil,root,'UIPanelButtonTemplate');close:SetSize(90,30);close:SetPoint('TOPRIGHT',-12,-9);close:SetText('Close')
 close:SetScript('OnClick',function()I.OnNavigate()end)
 root:HookScript('OnSizeChanged',fit)
 if hooksecurefunc and UpdateUIPanelPositions then
  local queued=false
  hooksecurefunc('UpdateUIPanelPositions',function()if current and current.native and not queued then queued=true;C_Timer.After(0,function()queued=false;fit()end)end end)
 end
 main:HookScript('OnHide',function()
  I.Release()
  if not main:IsShown()then restoreTradingPanel()end
 end)
 main:HookScript('OnShow',prepareTradingPanel)
 local e=CreateFrame('Frame')
 for _,event in ipairs({'PLAYER_INTERACTION_MANAGER_FRAME_SHOW','PLAYER_INTERACTION_MANAGER_FRAME_HIDE','MAIL_SHOW','MAIL_CLOSED','TRAINER_SHOW','TRAINER_CLOSED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','ADDON_LOADED','TRANSMOGRIFY_OPEN','TRANSMOGRIFY_CLOSE'})do pcall(e.RegisterEvent,e,event)end
 hookTransmog()
 if WoWUClient.isClassic then pcall(e.RegisterEvent,e,'BANKFRAME_OPENED')end
 -- The service frame can appear after its interaction/addon events have run.
 -- This observer stays active while the takeover root itself is hidden.
 local discoveryElapsed=0
 e:SetScript('OnUpdate',function(_,dt)
  discoveryElapsed=discoveryElapsed+dt;if discoveryElapsed<.25 then return end;discoveryElapsed=0
  if not WoWU_MainFrame:IsShown()or InCombatLockdown()then return end
  prepareTradingPanel()
  if current and current.native then return end
  hookTransmog();dockTransmog();dockTradingPost()
 end)
 -- Fullscreen/native scaling code can reapply geometry after OnShow. Keep
 -- these two services fitted while WoWU owns them, including after UI resizes.
 local fitElapsed=0
 root:HookScript('OnUpdate',function(_,dt)
  fitElapsed=fitElapsed+dt;if fitElapsed<.2 then return end;fitElapsed=0
  if current and current.native and current.native.docked and not InCombatLockdown()then fit()end
 end)
 local names={};for name,value in pairs(Enum and Enum.PlayerInteractionType or {})do names[value]=name end
 local excluded={Gossip=true,QuestGiver=true,Merchant=true,Banker=true,CharacterBanker=true,AccountBanker=true,None=true,Item=true}
 if WoWUClient.isClassic then excluded.Banker=nil;excluded.CharacterBanker=nil;excluded.Professions=true;excluded.TradeSkill=true;excluded.Craft=true end
 if WoWUAuctionHouse and WoWUAuctionHouse.supported then excluded.Auctioneer=true end
 e:SetScript('OnEvent',function(_,event,kind)
  if event=='PLAYER_REGEN_ENABLED'then if I.pendingRelease then I.Release()end;if WoWU_MainFrame:IsShown()then prepareTradingPanel()else restoreTradingPanel()end;return end
  if event=='ADDON_LOADED'then hookTransmog();if transmogIsOpen()or (_G.PerksProgramFrame and PerksProgramFrame:IsShown())or (_G.TransmogFrame and TransmogFrame:IsShown())then requestTransmog()end;return end
  if event=='TRANSMOGRIFY_OPEN'then legacyTransmogOpen=true;requestTransmog();return end
  if event=='TRANSMOGRIFY_CLOSE'then
   legacyTransmogOpen=false;transmogGeneration=transmogGeneration+1
   if current and current.kind==transmogKind()then I.Release()end;return
  end
  if kind==transmogKind()and event=='PLAYER_INTERACTION_MANAGER_FRAME_SHOW'then requestTransmog();return end
  if Enum and Enum.PlayerInteractionType and kind==Enum.PlayerInteractionType.PerksProgramVendor and event=='PLAYER_INTERACTION_MANAGER_FRAME_SHOW'then requestTransmog();return end
  if kind==transmogKind()and event=='PLAYER_INTERACTION_MANAGER_FRAME_HIDE'then legacyTransmogOpen=false;transmogGeneration=transmogGeneration+1 end
  if event=='PLAYER_REGEN_DISABLED'then I.Release();return end
  if event=='BANKFRAME_OPENED'and WoWUClient.isClassic then kind=Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
  elseif event=='MAIL_SHOW'then kind=Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
  elseif event=='TRAINER_SHOW'then kind=Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Trainer
  elseif event=='MAIL_CLOSED'or event=='TRAINER_CLOSED'then
   local name=current and names[current.kind];if name==(event=='MAIL_CLOSED'and 'MailInfo'or 'Trainer')then I.Release()end;return
  end
  if event=='PLAYER_INTERACTION_MANAGER_FRAME_HIDE'then if current and current.kind==kind and current.owner=='service'then I.Release()end;return end
  if not kind or excluded[names[kind]]then return end
  local at=GetTime()
  C_Timer.After(0,function()
   if current and current.owner=='service'and current.kind==kind then fit();return end
   if C_PlayerInteractionManager and call(C_PlayerInteractionManager.IsInteractingWithNpcOfType,kind)==false then return end
   local f=registry[kind]and _G[registry[kind]]
   if not f then for _,name in ipairs(known[names[kind]]or {})do if _G[name]and _G[name]:IsShown()then f=_G[name];break end end end
   if not f and candidateAt and candidateAt>=at-.15 and candidate and candidate:IsShown()then f=candidate end
   if f then showService(kind,f)end
  end)
 end)
 if hooksecurefunc and StaticPopup_Show then hooksecurefunc('StaticPopup_Show',function(which)
  if not current then return end
  local relevant={GOSSIP_CONFIRM=true,GOSSIP_ENTER_CODE=true,CONFIRM_ACCEPT_PVP_QUEST=true,CONFIRM_COMPLETE_EXPENSIVE_QUEST=true,XP_LOSS=true,CONFIRM_BINDER=true,CONFIRM_TALENT_WIPE=true,CONFIRM_MAIL_ITEM_UNREFUNDABLE=true,COD_ALERT=true,COD_CONFIRMATION=true,DELETE_MAIL=true,DELETE_MONEY=true,CONFIRM_BUY_OUTFIT_SLOT=true,TRANSMOG_OUTFIT_INVALID_NAME=true,TRANSMOG_PENDING_CHANGES=true,CONFIRM_TRANSMOG_USABLE_DISCOUNT=true,CONFIRM_DELETE_TRANSMOG_CUSTOM_SET=true,TRANSMOG_CUSTOM_SET_NAME=true,TRANSMOG_CUSTOM_SET_CONFIRM_OVERWRITE=true}
  if relevant[which]then local f=call(StaticPopup_FindVisible,which);if f then f:ClearAllPoints();f:SetPoint('CENTER',root,'CENTER',0,0)end end
 end)end
end
