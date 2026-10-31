-- NPC conversation and quest pages take over the current module through the shared content host.
local function truth(v)return v==true or v==1 end
local function call(fn,...)
 if type(fn)~='function'then return end
 local function pack(...)return {n=select('#',...),...}end
 local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local function ink(p,size,heading)
 local t=p:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetFont(heading and 'Fonts\\MORPHEUS.TTF'or 'Fonts\\FRIZQT__.TTF',size,'');t:SetTextColor(.18,.105,.045);t:SetShadowOffset(0,0);t:SetJustifyH('LEFT');t:SetJustifyV('TOP');t:SetWordWrap(true);return t
end
local function paper(p)
 local f=CreateFrame('Frame',nil,p,'BackdropTemplate');WoWU_Theme.Panel(f)
 local t=f:CreateTexture(nil,'BACKGROUND',nil,2);t:SetPoint('TOPLEFT',7,-7);t:SetPoint('BOTTOMRIGHT',-7,7)
 if call(C_Texture and C_Texture.GetAtlasInfo,'QuestDetailsBackgrounds')then t:SetAtlas('QuestDetailsBackgrounds')else t:SetTexture('Interface\\AddOns\\WoWU\\Textures\\Gilded\\Parchment')end
 return f
end
function WoWU_BuildNPCDialogs()
 local I=WoWUInteractions;if not I then return end
 local stage,questID,choice,revision=nil,nil,0,0
 local choiceStamp
 local native={};local area,left,right,body,story,title,optionBody,optionScroll,storyScroll,primary,note,portrait
 local rows={};local lastAction=0
 local render
 local function restore()
  if WoWUPadNavigation then WoWUPadNavigation.Clear("dialog")end
  for f,s in pairs(native)do f:SetScale(s.scale);f:ClearAllPoints();for _,p in ipairs(s.points)do f:SetPoint(unpack(p))end;f:SetClampedToScreen(s.clamped)end
  wipe(native);if area then area:Hide()end;stage=nil;revision=revision+1
 end
 local function park(f)
  if not f or not f:IsShown()then return end
  if not native[f]then local s={points={},clamped=f:IsClampedToScreen(),scale=f:GetScale()};for n=1,f:GetNumPoints()do s.points[n]={f:GetPoint(n)}end;native[f]=s end
  f:SetClampedToScreen(false);f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-3000)
 end
 local function close()
  local current=stage;I.Release()
  if current=='Gossip'then call(C_GossipInfo and C_GossipInfo.CloseGossip or CloseGossip)
  elseif current then call(CloseQuest);if QuestFrame and QuestFrame:IsShown()then call(HideUIPanel,QuestFrame)end end
 end
 local function valid()
  return stage and I.IsOwner('dialog')and not InCombatLockdown()and GetTime()-lastAction>.35 and(stage=='Gossip'or stage=='Greeting'or call(GetQuestID)==questID)
 end
 local function action(fn,...)
  if not valid()or type(fn)~='function'then return end
  lastAction=GetTime();local ok,message=pcall(fn,...)
  if not ok then note:SetText('The game could not complete this action: '..tostring(message))end
 end
 local function rewardStamp(index)
  local n,t,c=call(GetQuestItemInfo,'choice',index)
  return tostring(n)..':'..tostring(t)..':'..tostring(c)..':'..tostring(call(GetQuestItemLink,'choice',index))
 end
 local function build(parent)
  area=CreateFrame('Frame',nil,parent);area:SetAllPoints()
  left,right=paper(area),paper(area)
  left:SetPoint('TOPLEFT');left:SetPoint('BOTTOMRIGHT',area,'BOTTOM',95,58)
  right:SetPoint('TOPLEFT',left,'TOPRIGHT',8,0);right:SetPoint('BOTTOMRIGHT',0,58)
  portrait=left:CreateTexture(nil,'ARTWORK');portrait:SetSize(52,52);portrait:SetPoint('TOPLEFT',18,-17)
  title=ink(left,24,true);title:SetPoint('TOPLEFT',83,-18);title:SetPoint('TOPRIGHT',-20,-18);title:SetHeight(57)
  storyScroll=CreateFrame('ScrollFrame',nil,left,'UIPanelScrollFrameTemplate');storyScroll:SetPoint('TOPLEFT',21,-87);storyScroll:SetPoint('BOTTOMRIGHT',-33,20);if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(storyScroll)end
  body=CreateFrame('Frame',nil,storyScroll);body:SetSize(550,1);storyScroll:SetScrollChild(body)
  story=ink(body,17);story:SetPoint('TOPLEFT');story:SetWidth(530)
  local optionsTitle=ink(right,22,true);optionsTitle:SetPoint('TOPLEFT',18,-17);optionsTitle:SetText('Choices and quests')
  optionScroll=CreateFrame('ScrollFrame',nil,right,'UIPanelScrollFrameTemplate');optionScroll:SetPoint('TOPLEFT',12,-54);optionScroll:SetPoint('BOTTOMRIGHT',-32,14);if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(optionScroll)end
  optionBody=CreateFrame('Frame',nil,optionScroll);optionBody:SetSize(350,1);optionScroll:SetScrollChild(optionBody)
  primary=CreateFrame('Button',nil,area,'UIPanelButtonTemplate');primary:SetSize(220,36);primary:SetPoint('BOTTOMRIGHT',-10,8)
  note=area:CreateFontString(nil,'OVERLAY','GameFontNormal');WoWU_Theme.TextColor(note,.95,.82,.56);note:SetPoint('BOTTOMLEFT',12,9);note:SetPoint('RIGHT',primary,'LEFT',-16,0);note:SetHeight(37);note:SetJustifyH('LEFT');note:SetWordWrap(true)
  primary:SetScript('OnClick',function()
   if not valid()then return end
   if stage=='Detail'then
    if QuestDetailAcceptButton_OnClick then action(QuestDetailAcceptButton_OnClick)
    elseif not call(QuestFlagsPVP)then action(AcceptQuest)end
   elseif stage=='Progress'then if call(IsQuestCompletable)then action(QuestProgressCompleteButton_OnClick or CompleteQuest)end
   elseif stage=='Complete'then
    local num=call(GetNumQuestChoices)or 0
    if num>0 and choice==0 then note:SetText('Choose a reward before completing this quest.');return end
    if choice>0 and(choice>num or choiceStamp~=rewardStamp(choice))then choice=0;choiceStamp=nil;note:SetText('Reward information changed. Select your reward again.');render(false);return end
    if QuestInfoFrame then QuestInfoFrame.itemChoice=choice end
    if QuestFrameRewardPanel then QuestFrameRewardPanel.itemChoice=choice end
    if QuestRewardCompleteButton_OnClick then action(QuestRewardCompleteButton_OnClick)
    elseif (call(GetQuestMoneyToGet)or 0)<=0 then action(GetQuestReward,choice)end
   end
  end)
 end
 local function row(index,data)
  local b=rows[index]
  if not b then
   b=CreateFrame('Button',nil,optionBody,'BackdropTemplate')
   b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square','ADD')
   b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
   b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('LEFT',9,0);b.icon:SetSize(30,30)
   b.text=ink(b,15);b.text:SetPoint('TOPLEFT',48,-12);b.text:SetPoint('TOPRIGHT',-9,-12)
   b:SetScript('OnClick',function(self)
    if not valid()or(WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(optionScroll))then return end
    local d=self.data
    if d.choose then choice=d.index;choiceStamp=rewardStamp(choice);note:SetText('Reward selected. Complete Quest will claim it.');render(false)
    elseif d.fn then action(d.fn,d.id)end
   end)
   b:SetScript('OnEnter',function(self)
    local d=self.data;if not d.rewardKind or not GameTooltip then return end
    GameTooltip:SetOwner(self,'ANCHOR_LEFT');local link=call(GetQuestItemLink,d.rewardKind,d.index)
    if link then call(GameTooltip.SetHyperlink,GameTooltip,link)else GameTooltip:SetText(d.text)end;GameTooltip:Show()
   end)
   b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);WoWUDetails.BindHover(b,false)
   rows[index]=b
  end
  b.data=data;b:SetWidth(math.max(1,optionScroll:GetWidth()));b.text:SetText(data.text or 'Continue')
  b:SetHeight(math.max(56,b.text:GetStringHeight()+25));b.icon:SetTexture(data.icon or 'Interface\\GossipFrame\\GossipGossipIcon')
  local selected=data.choose and choice==data.index
  b:SetBackdropColor(.45,.26,.08,selected and .32 or .065);b:SetBackdropBorderColor(.43,.27,.09,selected and 1 or .25)
  b:SetEnabled(data.enabled~=false and(data.fn~=nil or data.choose==true));b:SetAlpha(data.enabled==false and .5 or 1);b:Show();return b
 end
 local function rewardRows(list,kind,num,selectable)
  for i=1,num do
   local n,t,count=call(GetQuestItemInfo,kind,i)
   if type(n)~='string'or n==''then n=nil end
   list[#list+1]={text=(n or 'Reward data loading...')..((count or 0)>1 and ' x'..count or '')..(selectable and '\nChoose one reward'or kind=='required'and '\nRequired for completion'or '\nYou will receive'),icon=t,index=i,rewardKind=kind,choose=selectable,enabled=n~=nil}
  end
 end
 render=function(reset)
  if not stage or not I.IsOwner('dialog')then return end
  park(GossipFrame);park(QuestFrame)
  local unit=call(UnitExists,'questnpc')and 'questnpc'or 'npc'
  if SetPortraitTexture and call(UnitExists,unit)then SetPortraitTexture(portrait,unit)else portrait:SetTexture('Interface\\QuestFrame\\UI-QuestLog-BookIcon')end
  local list,content={},''
  if stage=='Gossip'then
   title:SetText(call(UnitName,unit)or 'Conversation');content=call(C_GossipInfo and C_GossipInfo.GetText or GetGossipText)or ''
   for _,q in ipairs(call(C_GossipInfo and C_GossipInfo.GetAvailableQuests)or {})do list[#list+1]={text=q.title,icon='Interface\\GossipFrame\\AvailableQuestIcon',fn=C_GossipInfo.SelectAvailableQuest,id=q.questID}end
   for _,q in ipairs(call(C_GossipInfo and C_GossipInfo.GetActiveQuests)or {})do list[#list+1]={text=q.title..(q.isComplete and '\nReady to turn in'or '\nIn progress'),icon='Interface\\GossipFrame\\ActiveQuestIcon',fn=C_GossipInfo.SelectActiveQuest,id=q.questID}end
   local options=call(C_GossipInfo and C_GossipInfo.GetOptions)or {}
   table.sort(options,function(a,b)return(a.orderIndex or 0)<(b.orderIndex or 0)end)
   for i,d in ipairs(options)do
    local available=not d.status or not Enum or not Enum.GossipOptionStatus or(d.status~=Enum.GossipOptionStatus.Unavailable and d.status~=Enum.GossipOptionStatus.Locked)
    list[#list+1]={text=d.name..(d.failureDescription and '\n'..d.failureDescription or ''),icon=d.overrideIconID or d.icon,fn=d.gossipOptionID and C_GossipInfo.SelectOption or C_GossipInfo.SelectOptionByIndex,id=d.gossipOptionID or d.orderIndex or i,enabled=available}
   end
  elseif stage=='Greeting'then
   title:SetText(call(UnitName,unit)or 'Quests');content=call(GetGreetingText)or ''
   for i=1,call(GetNumAvailableQuests)or 0 do list[#list+1]={text=call(GetAvailableTitle,i),icon='Interface\\GossipFrame\\AvailableQuestIcon',fn=SelectAvailableQuest,id=i}end
   for i=1,call(GetNumActiveQuests)or 0 do local n,complete=call(GetActiveTitle,i);list[#list+1]={text=(n or 'Quest')..(complete and '\nReady to turn in'or '\nIn progress'),icon='Interface\\GossipFrame\\ActiveQuestIcon',fn=SelectActiveQuest,id=i}end
  else
   title:SetText(call(GetTitleText)or 'Quest')
   if stage=='Detail'then content=(call(GetObjectiveText)or '')..'\n\nDescription\n\n'..(call(GetQuestText)or '')
   elseif stage=='Progress'then content=call(GetProgressText)or ''
   else content=call(GetRewardText)or ''end
   if stage=='Progress'then
    if not call(C_QuestOffer and C_QuestOffer.GetHideRequiredItems)then rewardRows(list,'required',call(GetNumQuestItems)or 0,false)end
    for i=1,call(GetNumQuestCurrencies)or 0 do local d=call(C_QuestOffer and C_QuestOffer.GetQuestRequiredCurrencyInfo,i);if d then list[#list+1]={text=(d.name or 'Required currency')..' x'..(d.requiredAmount or 0),icon=d.texture}end end
    local required=call(GetQuestMoneyToGet)or 0;if required>0 then content=content..'\n\nRequired money: '..(GetMoneyString and GetMoneyString(required)or required)end
   else
    local xp=call(GetRewardXP)or 0;local amount=call(GetRewardMoney)or 0
    if xp>0 then list[#list+1]={text=xp..' experience',icon='Interface\\Icons\\XP_Icon'}end
    if amount>0 then list[#list+1]={text=GetMoneyString and GetMoneyString(amount)or tostring(amount),icon='Interface\\Icons\\INV_Misc_Coin_01'}end
    rewardRows(list,'reward',call(GetNumQuestRewards)or 0,false);rewardRows(list,'choice',call(GetNumQuestChoices)or 0,stage=='Complete')
    for _,d in ipairs(call(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies,questID)or {})do
     local n,t,count=d.name,d.texture,d.totalRewardAmount
     if CurrencyContainerUtil then local nn,tt,cc=call(CurrencyContainerUtil.GetCurrencyContainerInfo,d.currencyID,count,n,t,d.quality);n,t,count=nn or n,tt or t,cc or count end
     list[#list+1]={text=(n or 'Currency')..' x'..(count or 0),icon=t}
    end
    for _,id in ipairs(call(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells,questID)or {})do
     local spell=call(C_Spell and C_Spell.GetSpellInfo,id)
     if spell then list[#list+1]={text=spell.name or 'Spell reward',icon=spell.iconID}end
    end
    local honor=call(GetRewardHonor)or 0;if honor>0 then list[#list+1]={text=honor..' honor',icon='Interface\\Icons\\PVPCurrency-Honor-Horde'}end
    local skill,skillIcon,points=call(GetRewardSkillPoints);if skill and (points or 0)>0 then list[#list+1]={text=skill..' +'..points,icon=skillIcon}end
   end
  end
  story:SetWidth(math.max(1,storyScroll:GetWidth()-3));body:SetWidth(math.max(1,storyScroll:GetWidth()));story:SetText(content);body:SetHeight(story:GetStringHeight()+20)
  local y=0;for i,data in ipairs(list)do local b=row(i,data);b:ClearAllPoints();b:SetPoint('TOPLEFT',0,-y);y=y+b:GetHeight()+6 end
  for i=#list+1,#rows do rows[i]:Hide()end
  optionBody:SetWidth(math.max(1,optionScroll:GetWidth()));optionBody:SetHeight(math.max(1,y))
  primary:SetShown(stage=='Detail'or stage=='Progress'or stage=='Complete')
  primary:SetText(stage=='Detail'and(call(QuestGetAutoAccept)and 'Continue'or 'Accept Quest')or stage=='Progress'and 'Continue'or 'Complete Quest')
  primary:SetEnabled(not InCombatLockdown()and(stage~='Progress'or truth(call(IsQuestCompletable)))and(stage~='Complete'or(call(GetNumQuestChoices)or 0)==0 or choice>0))
  if WoWUPadNavigation then
   local nav={}
   for i=1,#list do local b=rows[i];if b:IsEnabled()then
    b.WoWUReveal=function(self)
     local _,_,_,_,y=self:GetPoint(1)
     optionScroll:SetVerticalScroll(math.min(math.max(0,-y),math.max(0,optionBody:GetHeight()-optionScroll:GetHeight())))
    end
    nav[#nav+1]=b
   end end
   if primary:IsShown()and primary:IsEnabled()then nav[#nav+1]=primary end
   WoWUPadNavigation.Set('dialog',nav,close)
  end
  if reset then storyScroll:SetVerticalScroll(0);optionScroll:SetVerticalScroll(0);note:SetText(stage=='Complete'and 'Choose your reward, then complete the quest.'or 'Tap an option to continue.')end
 end
 local function open(newStage)
  if not WoWU_MainFrame or not WoWU_MainFrame:IsVisible()or InCombatLockdown()then return end
  local f=newStage=='Gossip'and GossipFrame or QuestFrame
  if not f or not f:IsShown()then return end
  local newQuest=call(GetQuestID)
  if stage~=newStage or questID~=newQuest then choice=0;choiceStamp=nil end
  local E=Enum and Enum.PlayerInteractionType or {}
  local _,slot=I.Possess('dialog',newStage=='Gossip'and E.Gossip or E.QuestGiver,restore,close)
  if not slot then return end
  stage=newStage;questID=newQuest
  if not area then build(slot)end
  area:Show();if I.SetTitle then I.SetTitle(call(UnitName,newStage=='Gossip'and 'npc'or 'questnpc')or 'Conversation')end
  render(true)
 end
 local e=CreateFrame('Frame')
 local types={GOSSIP_SHOW='Gossip',QUEST_GREETING='Greeting',QUEST_DETAIL='Detail',QUEST_PROGRESS='Progress',QUEST_COMPLETE='Complete'}
 for _,event in ipairs({'GOSSIP_SHOW','GOSSIP_OPTIONS_REFRESHED','GOSSIP_UPDATE','GOSSIP_CLOSED','QUEST_GREETING','QUEST_DETAIL','QUEST_PROGRESS','QUEST_COMPLETE','QUEST_FINISHED','QUEST_ITEM_UPDATE','QUEST_LOG_UPDATE','MERCHANT_SHOW','BANKFRAME_OPENED'})do pcall(e.RegisterEvent,e,event)end
 e:SetScript('OnEvent',function(_,event,continuing)
  if types[event]then
   revision=revision+1;local token=revision;C_Timer.After(0,function()if token==revision then open(types[event])end end)
  elseif event=='GOSSIP_CLOSED'or event=='QUEST_FINISHED'then
   local closing=event=='GOSSIP_CLOSED'and stage=='Gossip'or event=='QUEST_FINISHED'and stage and stage~='Gossip'
   if closing then local token=revision;C_Timer.After(event=='GOSSIP_CLOSED'and continuing and .2 or 0,function()if token==revision and I.IsOwner('dialog')then I.Release()end end)end
  elseif event=='MERCHANT_SHOW'or event=='BANKFRAME_OPENED'then if I.IsOwner('dialog')then I.Release()end
  elseif stage and I.IsOwner('dialog')then render(false)end
 end)
 if hooksecurefunc and ShowUIPanel then hooksecurefunc('ShowUIPanel',function(f)if(f==GossipFrame or f==QuestFrame)and I.IsOwner('dialog')then C_Timer.After(0,function()if I.IsOwner('dialog')then render(false)end end)end end)end
end
