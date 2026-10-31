if WoWUClient.classicMajor~=5 then return end
local U=WoWUMistsUI
local C_LFGList=C_LFGList or {}
local C_LFGInfo=C_LFGInfo or {}
local function levelStyle(rec,low,high,scaling)
 local target=tonumber(rec)
 if not target or target<=0 then target=tonumber(low)end
 local c=scaling and QuestDifficultyColors and QuestDifficultyColors.difficult or (target and U.Call(GetQuestDifficultyColor,target))or {r=1,g=.82,b=.4}
 local color=string.format("|cff%02x%02x%02x",math.floor((c.r or 1)*255+.5),math.floor((c.g or .82)*255+.5),math.floor((c.b or .4)*255+.5))
 local lo,hi=tonumber(low),tonumber(high)
 local range=lo and lo>0 and (hi and hi>lo and (lo.." - "..hi)or tostring(lo))or "--"
 return color,range,target
end
local function editable()return not InCombatLockdown()and not UnitIsDeadOrGhost("player")end
local function empowered()return not IsInGroup(LE_PARTY_CATEGORY_HOME)or UnitIsGroupLeader("player",LE_PARTY_CATEGORY_HOME)or UnitIsGroupAssistant("player",LE_PARTY_CATEGORY_HOME)end
local function safeText(value,fallback)
 if (issecretvalue and issecretvalue(value))or value==nil then return fallback or ""end
 return tostring(value)
end
function WoWU_CreateMistsDungeonFinder(parent,goHome)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();root:Hide()
 local view="Dungeon Finder";local category,activity,selected,queueID
 local crossFaction=false
 local refresh,detailRefresh,dirty,notice,searching,searchAt,searchCategory
 local pvp
 local queueRef=false
 local roles={false,false,true};local available={false,false,true};local selectedData
 local title=U.Text(root,24);title:SetPoint("TOPLEFT",18,-14);title:SetText("Dungeon Finder")
 local back=U.Button(root,110,"Back",goHome);back:SetPoint("TOPRIGHT",-18,-12)
 local message=U.Message(root)
 local tabs={}
 for i,label in ipairs({"Dungeon Finder","Raid Finder","Scenarios","Premade Groups","Applications","My Group","PvP"})do
  local mode=label;local b=U.Button(root,150,label,function()view=mode;selected=nil;selectedData=nil;queueID=nil;refresh()end)
  b:SetPoint("TOPLEFT",18+(i-1)*158,-57);tabs[label]=b
 end
 local roleButtons={}
 for i,label in ipairs({"Tank","Healer","Damage"})do
  local role=i;local b=U.Button(root,130,label,function()roles[role]=not roles[role];dirty=true end);b:SetPoint("TOPLEFT",18+(i-1)*198,-102);b:SetSize(184,70)
  local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(42,42);icon:SetPoint("LEFT",12,0);icon:SetTexture(({132110,135953,132355})[i]);b.label:SetPoint("CENTER",23,0);b.label:SetFont("Fonts\\FRIZQT__.TTF",19,"");roleButtons[i]=b
 end
 local categoryMenu=U.Menu(root,285,"Category");categoryMenu:SetPoint("TOPLEFT",18,-190)
 local activityMenu=U.Menu(root,420,"Any activity");activityMenu:SetPoint("LEFT",categoryMenu,"RIGHT",10,0)
 local filter
 local keyboard=WoWUKeyboard and WoWUKeyboard.Create(root,{})
 if keyboard then
  local toggle=WoWUKeyboard.ToggleButton(root,function()if keyboard:IsShown()then keyboard:Hide()else keyboard:Open(filter)end end)
  toggle:ClearAllPoints();toggle:SetPoint("TOPRIGHT",-300,-98)
 end
 local searchButton=U.Button(root,140,"Search");searchButton:SetPoint("LEFT",activityMenu,"RIGHT",10,0)
 local cross=U.Button(root,180,"Cross-faction: off",function()crossFaction=not crossFaction;dirty=true end);cross:SetPoint("TOPLEFT",620,-112)
 filter=CreateFrame("EditBox",nil,root,"InputBoxTemplate");filter:SetAutoFocus(false);filter:SetSize(260,28);filter:SetPoint("TOPRIGHT",-20,-107);filter:SetMaxLetters(80)
 filter:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);filter:SetScript("OnEnterPressed",function(self)self:ClearFocus();dirty=true end)
 local filterLabel=U.Text(root,11);filterLabel:SetPoint("BOTTOMLEFT",filter,"TOPLEFT",0,2);filterLabel:SetText("Filter shown activities / groups")
 filter:SetScript("OnTextChanged",function()dirty=true end)
 local listPanel=U.Panel(root);listPanel:SetPoint("TOPLEFT",14,-195);listPanel:SetPoint("BOTTOMLEFT",14,43);listPanel:SetWidth(570)
 local list=U.List(listPanel);list:SetPoint("TOPLEFT",7,-7);list:SetPoint("BOTTOMRIGHT",-28,7)
 local right=U.Panel(root);right:SetPoint("TOPLEFT",listPanel,"TOPRIGHT",12,0);right:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",-14,43)
 local ambience=right:CreateTexture(nil,"BACKGROUND",nil,1);ambience:SetPoint("TOPLEFT",6,-6);ambience:SetPoint("BOTTOMRIGHT",-6,6);ambience:SetAlpha(.12)
 local banner=right:CreateTexture(nil,"BACKGROUND",nil,2);banner:SetPoint("TOPLEFT",8,-8);banner:SetPoint("TOPRIGHT",-8,-8);banner:SetHeight(116)
 local art=banner;art:SetTexCoord(0,1,.12,.72);art:SetAlpha(.7)
 local shade=right:CreateTexture(nil,"BACKGROUND",nil,3);shade:SetAllPoints(banner);shade:SetColorTexture(0,0,0,.48)
 local heading=U.Text(right,25);heading:SetPoint("TOPLEFT",23,-24);heading:SetPoint("TOPRIGHT",-23,-24);heading:SetHeight(52)
 local recommendation=U.Text(right,16);recommendation:SetPoint("TOPLEFT",23,-86);recommendation:SetPoint("TOPRIGHT",-23,-86)
 local infoScroll,infoBody=U.Scroll(right);infoScroll:SetPoint("TOPLEFT",15,-139);infoScroll:SetPoint("BOTTOMRIGHT",-31,150)
 local info=U.Text(infoBody,14);info:SetPoint("TOPLEFT");info:SetPoint("TOPRIGHT",infoBody,"TOPRIGHT",-8,0);info:SetWordWrap(true);info:SetJustifyV("TOP")
 local function actionButton(caption,bottom,height)
  local b=CreateFrame("Button",nil,right,"UIPanelButtonTemplate");b:SetHeight(height or 54)
  b:SetPoint("BOTTOMLEFT",22,bottom);b:SetPoint("BOTTOMRIGHT",-22,bottom);b:SetText(caption)
  b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",18,"")
  return b
 end
 local primary=actionButton("Select an activity",82)
 local secondary=actionButton("Cancel application",18)
 local native=actionButton("Advanced listing editor",146,48)
 local rewardCards={}
 local rewardTitle=U.Text(infoBody,23);rewardTitle:SetPoint("TOPLEFT",0,0);rewardTitle:SetText("Rewards");rewardTitle:Hide()
 local rewardSummary=U.Text(infoBody,17);rewardSummary:SetPoint("TOPLEFT",0,-33);rewardSummary:SetPoint("TOPRIGHT",-8,-33);rewardSummary:SetJustifyV("TOP");rewardSummary:Hide()
 native:SetScript("OnClick",function()
  if not editable()then return end
  local ok=U.Load("Blizzard_GroupFinder")
  if not ok or not PVEFrame then notice="The native listing editor is unavailable.";dirty=true;return end
  if PVEFrame_ShowFrame then U.Call(PVEFrame_ShowFrame,"GroupFinderFrame","LFGListPVEStub")
  else U.Call(ShowUIPanel,PVEFrame)end
  if LFGListFrame and LFGListFrame.EntryCreation then
   U.Call(LFGListEntryCreation_SetEditMode,LFGListFrame.EntryCreation,U.Call(C_LFGList.HasActiveEntryInfo)==true)
   if activity and not U.Call(C_LFGList.HasActiveEntryInfo)then U.Call(LFGListEntryCreation_Select,LFGListFrame.EntryCreation,0,category,nil,activity)end
   U.Call(LFGListFrame_SetActivePanel,LFGListFrame,LFGListFrame.EntryCreation)
  end
 end)
 local function hasRoles()return (roles[1]and available[1])or (roles[2]and available[2])or (roles[3]and available[3])end
 local function updateRoles()
  local t,h,d
  if C_LFGList.GetAvailableRoles then t,h,d=U.Call(C_LFGList.GetAvailableRoles)else t,h,d=U.Call(UnitGetAvailableRoles,"player")end;available={t==true,h==true,d==true}
  if not ((roles[1]and available[1])or(roles[2]and available[2])or(roles[3]and available[3]))then roles[available[3]and 3 or available[1]and 1 or 2]=true end
  for i,b in ipairs(roleButtons)do
   if not available[i]then roles[i]=false end
   b.label:SetText(({"Tank","Healer","Damage"})[i]);b:SetEnabled(available[i]and editable());WoWU_Theme.Tab(b,roles[i]==true)
  end
 end
 local function queueCategory()return view=="Scenarios"and (LE_LFG_CATEGORY_SCENARIO or 4)or view=="Raid Finder"and (LE_LFG_CATEGORY_RF or 3)or (LE_LFG_CATEGORY_LFD or 1)end
 local function groupInfo(id)return U.Call(C_LFGList.GetSearchResultInfo,id)end
 local function application(id)local _,state,pending=U.Call(C_LFGList.GetApplicationInfo,id);return pending or state end
 local function writeInfo(value)
  for _,card in ipairs(rewardCards)do card:Hide()end
  rewardTitle:Hide();rewardSummary:Hide();info:ClearAllPoints();info:SetPoint("TOPLEFT");info:SetPoint("TOPRIGHT",infoBody,"TOPRIGHT",-8,0)
  info:SetFont("Fonts\\FRIZQT__.TTF",16,"")
  info:SetText(value or "");infoBody:SetHeight(math.max(1,info:GetStringHeight()+12));infoScroll:SetVerticalScroll(0)
 end
 local function populateActivities()
  if not category then return end
  local options={{id=0,name="Any activity"}}
  for _,id in ipairs(U.Call(C_LFGList.GetAvailableActivities,category,0,0)or {})do
   local a=U.Call(C_LFGList.GetActivityInfoTable,id)
   if a then options[#options+1]={id=id,name=a.fullName or a.shortName or ("Activity "..id)}end
  end
  table.sort(options,function(a,b)if a.id==b.id then return false elseif a.id==0 then return true elseif b.id==0 then return false end;return a.name<b.name end)
  activityMenu:SetOptions(options,activity or 0)
 end
 categoryMenu.OnSelect=function(value)category=value;activity=nil;selected=nil;selectedData=nil;searchCategory=nil;populateActivities();dirty=true end
 activityMenu.OnSelect=function(value)activity=value~=0 and value or nil;selected=nil;selectedData=nil;dirty=true end
 searchButton:SetScript("OnClick",function()
  if not editable()or not category or searching then return end
  -- Server search text is a protected native field. Use the supported activity
  -- filter; WoWU's own text box filters the returned results locally.
  U.Call(C_LFGList.ClearSearchTextFields)
  local ok,err=pcall(C_LFGList.Search,category,0,0,U.Call(C_LFGList.GetLanguageSearchFilter))
  if not ok then notice="Search could not start: "..safeText(err);dirty=true;return end
  searching=true;searchAt=GetTime();searchCategory=category;notice="Searching for groups...";dirty=true
 end)
 local function clickRow(d)if InCombatLockdown()then return end;selected=d.id;selectedData=d;queueID=d.queue and d.id or nil;detailRefresh()end
 local function queueRows()
  local data,seen={},{}
  local function add(id,random)
   if not id or id<=0 or seen[id]or U.Call(LFGIsIDHeader,id)then return end
   seen[id]=true
   local name,_,_,minLevel,maxLevel,recLevel,minRecLevel,maxRecLevel,_,_,texture,difficulty,maxPlayers,description,_,_,_,_,_,_,scaling=U.Call(GetLFGDungeonInfo,id)
   if not name then return end
   local all,player,hide=U.Call(IsLFGDungeonJoinable,id)
   if player==false and hide then return end
   local diffName=U.Call(GetDifficultyInfo,difficulty)or ""
   local low=(minRecLevel and minRecLevel>0)and minRecLevel or minLevel
   local high=(maxRecLevel and maxRecLevel>0)and maxRecLevel or maxLevel
   local color,range,target=levelStyle(recLevel,low,high,scaling)
   local artwork=texture or "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL"
   data[#data+1]={id=id,name=name,queue=true,description=description,difficulty=diffName,
    titleColor=color,levelText=color..range.."|r",artwork=artwork,recommendation=range,recommended=target,
    joinable=all~=false and player~=false,sub=(random and "Random / "or "")..diffName..(player==false and " / Locked"or ""),
    level=minLevel,maxLevel=maxLevel,maxPlayers=maxPlayers}
  end
  if view=="Raid Finder"then
   for i=1,(U.Call(GetNumRFDungeons)or 0)do local id=U.Call(GetRFDungeonInfo,i);add(id)end
  elseif view=="Scenarios"then
   for i=1,(U.Call(GetNumRandomScenarios)or 0)do local id=U.Call(GetRandomScenarioInfo,i);add(id,true)end
   for _,id in ipairs(U.Call(GetScenariosChoiceOrder)or {})do add(id)end
  else
   for i=1,(U.Call(GetNumRandomDungeons)or 0)do local id=U.Call(GetLFGRandomDungeonInfo,i);add(id,true)end
   for _,id in ipairs(U.Call(GetLFDChoiceOrder)or {})do add(id)end
  end
  return data
 end
 local function resultRow(id)
  local g=groupInfo(id);if not g then return end
  local activityID=g.activityIDs and g.activityIDs[1]or g.activityID
  local a=activityID and U.Call(C_LFGList.GetActivityInfoTable,activityID)or {}
  if view=="Premade Groups"and ((a.categoryID and a.categoryID~=category)or (activity and activityID~=activity))then return end
  local state=application(id)
  return {id=id,name=safeText(g.name,"Group"),sub=safeText(a.fullName or a.shortName).."  /  "..safeText(g.numMembers).." members"..(state and state~="none"and "  /  "..state or ""),result=g,app=state}
 end
 detailRefresh=function()
  primary:Disable();secondary:Hide();primary:Show();native:SetShown(view=="My Group");native:SetEnabled(editable())
  local d=selectedData
  local isQueue=view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios"
  banner:SetShown(isQueue);shade:SetShown(isQueue);ambience:SetShown(isQueue);recommendation:SetShown(isQueue)
  heading:ClearAllPoints();heading:SetPoint("TOPLEFT",isQueue and 23 or 15,isQueue and -24 or -15);heading:SetPoint("TOPRIGHT",isQueue and -23 or -15,isQueue and -24 or -15)
  infoScroll:ClearAllPoints();infoScroll:SetPoint("TOPLEFT",15,isQueue and -139 or -90);infoScroll:SetPoint("BOTTOMRIGHT",-31,view=="My Group"and 210 or 146)
  if isQueue then
   local texture=d and d.artwork or "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL"
   if not art:SetTexture(texture)then art:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL")end
   ambience:SetTexture(texture)
   recommendation:SetText(d and (d.titleColor.."Recommended level: "..d.recommendation.."|r  /  "..d.difficulty)or "Choose your next adventure")
  end
  if (view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios")then
   heading:SetText(d and ((d.titleColor or "")..d.name.."|r")or "Choose a queue")
   if d then
    local details=(d.description and d.description~=""and (d.description.."\n\n")or "").."|cffffd36aDungeon details|r\nMinimum entry level: "..(d.level or "?").."   /   Group size: "..(d.maxPlayers or "?")
    if not d.joinable then details=details.."\n\n|cffff7777Your character or party does not meet this queue's requirements.|r"end
    writeInfo(details)
    local done,money,_,xp,_,count=U.Call(GetLFGDungeonRewards,d.id)
    local summary={}
    if money and money>0 then summary[#summary+1]=(U.Call(GetCoinTextureString,money)or tostring(money)).." reward"end
    if xp and xp>0 then summary[#summary+1]=xp.." experience"end
    rewardTitle:Show();rewardSummary:SetText(#summary>0 and table.concat(summary,"   /   ")or "No currency or experience reward listed.");rewardSummary:Show()
    local y=40+math.max(24,rewardSummary:GetStringHeight())
    for i=1,math.min(count or 0,12)do
     local name,texture,quantity=U.Call(GetLFGDungeonRewardInfo,d.id,i)
     if name then
      local card=rewardCards[i]
      if not card then
       card=U.Panel(infoBody);rewardCards[i]=card
       card.icon=card:CreateTexture(nil,"ARTWORK");card.icon:SetSize(68,68);card.icon:SetPoint("LEFT",10,0)
       card.name=U.Text(card,20);card.name:SetPoint("TOPLEFT",92,-14);card.name:SetPoint("TOPRIGHT",-12,-14);card.name:SetWordWrap(true)
       card.quantity=U.Text(card,16);card.quantity:SetPoint("BOTTOMLEFT",92,12)
      end
      card:ClearAllPoints();card:SetPoint("TOPLEFT",0,-y);card:SetPoint("TOPRIGHT",infoBody,"TOPRIGHT",-8,-y);card:SetHeight(94)
      card.icon:SetTexture(texture or 134400);card.name:SetText(name);card.quantity:SetText("Quantity: "..(quantity or 1));card:Show();y=y+104
     end
    end
    info:ClearAllPoints();info:SetPoint("TOPLEFT",0,-y-14);info:SetPoint("TOPRIGHT",infoBody,"TOPRIGHT",-8,-y-14)
    infoBody:SetHeight(y+info:GetStringHeight()+32)
   else writeInfo("Select a dungeon or raid wing on the left. Only the game's own queue catalogue is used. Level, item-level, party and account requirements still apply.")end
   local canUse,reason=U.Call(view=="Raid Finder"and C_LFGInfo.CanPlayerUseLFR or C_LFGInfo.CanPlayerUseLFD)
   if canUse==false then writeInfo((d and d.description or "").."\n\n"..safeText(reason,"This queue is not available for your character."))end
   primary.label:SetText("Join queue");primary:SetEnabled(editable()and empowered()and hasRoles()and d~=nil and d.joinable==true and canUse~=false)
   secondary:Show();secondary.label:SetText("Leave this queue")
   local mode=U.Call(GetLFGMode,queueCategory());secondary:SetEnabled(editable()and mode~=nil and mode~="none")
  elseif view=="My Group"then
   local entry=U.Call(C_LFGList.GetActiveEntryInfo)
   if entry then
    heading:SetText(safeText(entry.name,"Your group"))
    local detail={safeText(entry.comment),"Select an applicant to inspect and invite or decline.","Listing remains active when you close WoWU."}
    if d and d.applicant then
     local applicant=U.Call(C_LFGList.GetApplicantInfo,d.id)
     if applicant then
      detail={"Application: "..safeText(applicant.applicationStatus),safeText(applicant.comment)}
      for i=1,(applicant.numMembers or 0)do
       local name,_,class,level,itemLevel,_,tank,healer,damage,role=U.Call(C_LFGList.GetApplicantMemberInfo,d.id,i)
       detail[#detail+1]=safeText(name).."  /  "..safeText(class).."  /  "..safeText(role).."\nLevel "..safeText(level).."  /  Item level "..safeText(itemLevel)
      end
      primary.label:SetText("Invite applicant");primary:SetEnabled(editable()and empowered()and applicant.applicationStatus=="applied")
     end
     secondary:Show();secondary.label:SetText("Decline applicant");secondary:SetEnabled(editable()and empowered())
    else primary.label:SetText("Select an applicant")end
    writeInfo(table.concat(detail,"\n\n"))
   else
    local a=activity and U.Call(C_LFGList.GetActivityInfoTable,activity)
    heading:SetText("Create a group")
    writeInfo("Choose a category and activity above.\n\n"..(a and (a.fullName or a.shortName)or "No activity selected.").."\n\nWoWU creates a listing using Blizzard's generated activity title and your current group. For a custom title, description or advanced requirements, use Advanced listing editor.\n\nCreating a listing is a separate action from searching for a group.")
    primary.label:SetText("Create activity listing");primary:SetEnabled(editable()and empowered()and activity~=nil)
   end
  else
   local g=d and groupInfo(d.id)
   if not g then heading:SetText("Choose a group");writeInfo(view=="Applications"and "Your active applications and invitations appear here."or "Choose a category and optional activity, then Search. The text box filters the returned groups. Searches run only when you press Search.");primary.label:SetText("Apply to group");return end
   d.result=g;d.app=application(d.id)
   heading:SetText(safeText(g.name,"Group"))
   local counts=U.Call(C_LFGList.GetSearchResultMemberCounts,d.id)or {}
   writeInfo(safeText(g.comment).."\n\nLeader: "..safeText(g.leaderName,"Loading...").."\nMembers: "..safeText(g.numMembers).."\nTank "..safeText(counts.TANK, "0").."  /  Healer "..safeText(counts.HEALER,"0").."  /  Damage "..safeText(counts.DAMAGER,"0").."\nMinimum item level: "..safeText(g.requiredItemLevel,"0").."\nDungeon score: "..safeText(g.requiredDungeonScore,"0").."\nVoice: "..safeText(g.voiceChat,"None").."\nStatus: "..safeText(d.app,"none"))
   local invited=d.app=="invited"
   primary.label:SetText(invited and "Accept invitation"or "Apply to group")
   primary:SetEnabled(editable()and (invited or hasRoles()and not g.isDelisted and not g.hasSelf and (d.app==nil or d.app=="none")))
   secondary:Show();secondary.label:SetText(invited and "Decline invitation"or "Cancel application");secondary:SetEnabled(editable()and d.app~=nil and d.app~="none")
  end
 end
 primary:SetScript("OnClick",function()
  if not editable()then return end
  if (view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios")then
   if not empowered()or not queueID or not hasRoles()then return end
   local d=selectedData;local all,player=U.Call(IsLFGDungeonJoinable,queueID)
   if not d or all==false or player==false then notice="This queue's requirements are not met.";dirty=true;return end
   U.Call(SetLFGRoles,false,roles[1],roles[2],roles[3])
   local cat=queueCategory()
   local ok,err=pcall(function()
    ClearAllLFGDungeons(cat);SetLFGDungeon(cat,queueID)
    if view=="Raid Finder"and JoinSingleLFG then JoinSingleLFG(cat,queueID)
    elseif LFG_JoinDungeon then LFG_JoinDungeon(cat,queueID)
    else JoinLFG(cat)end
   end)
   notice=ok and "Queue requested. Waiting for the game's status / role check."or ("Queue could not start: "..safeText(err))
  elseif view=="My Group"then
   if not empowered()then return end
   local entry=U.Call(C_LFGList.GetActiveEntryInfo)
   if entry then if selectedData and selectedData.applicant then
    local applicant=U.Call(C_LFGList.GetApplicantInfo,selectedData.id)
    local members=GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)+(applicant and applicant.numMembers or 0)+(U.Call(C_LFGList.GetNumInvitedApplicantMembers)or 0)
    if not IsInRaid(LE_PARTY_CATEGORY_HOME)and members>(MAX_PARTY_MEMBERS or 4)+1 then
     if StaticPopupDialogs.LFG_LIST_INVITING_CONVERT_TO_RAID then StaticPopup_Show("LFG_LIST_INVITING_CONVERT_TO_RAID",nil,nil,selectedData.id);notice="Confirm conversion to a raid before inviting."
     else notice="Convert to a raid in Blizzard's group controls before inviting this applicant."end
    else U.Call(C_LFGList.InviteApplicant,selectedData.id);notice="Invitation requested."end
   end
   elseif activity then
    U.Call(C_LFGList.ClearCreationTextFields);U.Call(C_LFGList.SetEntryTitle,activity,0)
    local success=U.Call(C_LFGList.CreateListing,{activityIDs={activity},isAutoAccept=false,isCrossFactionListing=crossFaction,isPrivateGroup=false,generalPlaystyle=Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.None or 0,requiredItemLevel=0,requiredDungeonScore=0,requiredPvpRating=0})
    notice=success and "Listing requested. Waiting for server confirmation."or "The game could not create this listing. Check requirements or use Advanced listing editor."
   end
  elseif selectedData then
   local state=application(selectedData.id)
   if state=="invited"then U.Call(C_LFGList.AcceptInvite,selectedData.id);notice="Invitation acceptance requested."
   elseif hasRoles()then U.Call(C_LFGList.ApplyToGroup,selectedData.id,roles[1],roles[2],roles[3]);notice="Application requested. Check Applications for its status."end
  end
  dirty=true
 end)
 secondary:SetScript("OnClick",function()
  if not editable()then return end
  if (view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios")then if empowered()then U.Call(LeaveLFG,queueCategory())end
  elseif view=="My Group"then if empowered()and selectedData and selectedData.applicant then U.Call(C_LFGList.DeclineApplicant,selectedData.id)end
  elseif selectedData then
   if application(selectedData.id)=="invited"then U.Call(C_LFGList.DeclineInvite,selectedData.id)else U.Call(C_LFGList.CancelApplication,selectedData.id)end
  end
  notice=nil;dirty=true
 end)
 local remove=U.Button(root,160,"Delist my group",function()if editable()and empowered()then U.Call(C_LFGList.RemoveListing);notice="Delisting requested.";dirty=true end end)
 remove:SetPoint("TOPRIGHT",-18,-190);remove:Hide()
 refresh=function()
  if not root:IsShown()then return end
  dirty=nil
  if view=="PvP"then
   if not pvp then
    pvp=WoWU_CreateMistsPVP(root,function()if InCombatLockdown()then return end;view="Dungeon Finder";refresh()end,function()
     if InCombatLockdown()then return end
     local filter=Enum.LFGListFilter and Enum.LFGListFilter.PvP or 0
     local ids=U.Call(C_LFGList.GetAvailableCategories,filter)or {}
     category=ids[1]or category;activity=nil;selected=nil;selectedData=nil;searchCategory=nil
     populateActivities();view="Premade Groups";refresh()
    end)
   end
   pvp:Show();return
  end
  if pvp then pvp:Hide()end
  if InCombatLockdown()then
   for _,b in ipairs(roleButtons)do b:Disable()end
   for _,b in pairs(tabs)do b:Disable()end
   primary:Disable();secondary:Disable();native:Disable();remove:Disable();searchButton:Disable();categoryMenu:Disable();activityMenu:Disable();cross:Disable()
   categoryMenu:Close();activityMenu:Close();message:SetText("Dungeon Finder controls are unavailable during combat.");return
  end
  for _,b in pairs(tabs)do b:Enable()end
  categoryMenu:Enable();activityMenu:Enable()
  updateRoles()
  for name,b in pairs(tabs)do WoWU_Theme.Tab(b,view==name)end
  local browse=view=="Premade Groups"or view=="My Group"
  listPanel:ClearAllPoints();listPanel:SetPoint("TOPLEFT",14,browse and -240 or -195);listPanel:SetPoint("BOTTOMLEFT",14,43)
  local categoryInfo=category and U.Call(C_LFGList.GetLfgCategoryInfo or C_LFGList.GetCategoryInfo,category)
  if categoryInfo and categoryInfo.allowCrossFaction==false then crossFaction=false end
  cross:SetShown(browse);cross:SetEnabled(editable()and categoryInfo~=nil and categoryInfo.allowCrossFaction~=false);cross.label:SetText("Cross-faction: "..(crossFaction and "on"or "off"));WoWU_Theme.Tab(cross,crossFaction)
  categoryMenu:SetShown(browse);activityMenu:SetShown(browse);searchButton:SetShown(view=="Premade Groups");searchButton:SetEnabled(editable()and not searching and category~=nil)
  remove:SetShown(view=="My Group"and U.Call(C_LFGList.HasActiveEntryInfo)==true);remove:SetEnabled(editable()and empowered())
  local data={}
  if (view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios")then data=queueRows()
  elseif view=="My Group"then
   if U.Call(C_LFGList.HasActiveEntryInfo)then
    for _,id in ipairs(U.Call(C_LFGList.GetApplicants)or {})do
     local a=U.Call(C_LFGList.GetApplicantInfo,id)
     if a then local name=U.Call(C_LFGList.GetApplicantMemberInfo,id,1);data[#data+1]={id=id,name=safeText(name,"Applicant"),sub=safeText(a.numMembers).." players  /  "..safeText(a.applicationStatus),applicant=true}end
    end
   end
  elseif view=="Applications"then
   for _,id in ipairs(U.Call(C_LFGList.GetApplications)or {})do local d=resultRow(id);if d then data[#data+1]=d end end
  elseif searchCategory==category then
   local _,results=U.Call(C_LFGList.GetSearchResults)
   for _,id in ipairs(results or {})do local d=resultRow(id);if d and not d.result.isDelisted then data[#data+1]=d end end
  end
  local q=string.lower(filter:GetText()or "");local filtered={};local found
  for _,d in ipairs(data)do if q==""or string.find(string.lower(d.name.." "..d.sub),q,1,true)then filtered[#filtered+1]=d;if d.id==selected then found=d end end end
  selectedData=found;if not found then selected=nil;queueID=nil end
  if #filtered==0 then filtered[1]={name=searching and "Searching..."or "No entries to show",sub=view=="Premade Groups"and "Choose a category and press Search."or "Requirements, filters or activity availability may limit this list."}end
  list.rowHeight=(view=="Dungeon Finder"or view=="Raid Finder"or view=="Scenarios")and 82 or 58
  list:SetData(filtered,function(d)if d.id then clickRow(d)end end,selected)
  detailRefresh()
  local canUse,reason=U.Call(C_LFGInfo.CanPlayerUsePremadeGroup)
  if view~="Dungeon Finder"and view~="Raid Finder"and view~="Scenarios"and canUse==false then primary:Disable();searchButton:Disable();notice=safeText(reason,"Premade groups are unavailable for this character.")end
  local lfd=U.Call(GetLFGMode,LE_LFG_CATEGORY_LFD or 1);local lfr=U.Call(GetLFGMode,LE_LFG_CATEGORY_RF or 3);local scenario=U.Call(GetLFGMode,LE_LFG_CATEGORY_SCENARIO or 4)
  message:SetText((notice and notice.."   /   "or "").."Dungeon queue: "..safeText(lfd,"none").."   /   Raid queue: "..safeText(lfr,"none").."   /   Scenarios: "..safeText(scenario,"none"))
 end
 root:SetScript("OnShow",function()
  local loaded,why=U.Load("Blizzard_GroupFinder");if not loaded then message:SetText(why);return end
  if QueueUpdater then
   U.Call(QueueUpdater.RequestInfo,QueueUpdater)
   if not queueRef then U.Call(QueueUpdater.AddRef,QueueUpdater);queueRef=true end
  end
  local _,tank,healer,damage=U.Call(GetLFGRoles);if tank~=nil then roles={tank,healer,damage}end
  local categories={}
  for _,id in ipairs(U.Call(C_LFGList.GetAvailableCategories,0)or {})do
   local c=U.Call(C_LFGList.GetLfgCategoryInfo or C_LFGList.GetCategoryInfo,id)
   if c then categories[#categories+1]={id=id,name=c.name}end
  end
  if not category and categories[1]then category=categories[1].id end
  categoryMenu:SetOptions(categories,category);populateActivities();refresh()
 end)
 root:SetScript("OnHide",function()
  filter:ClearFocus();categoryMenu:Close();activityMenu:Close();GameTooltip:Hide()
  if queueRef and QueueUpdater then U.Call(QueueUpdater.RemoveRef,QueueUpdater);queueRef=false end
 end)
 local events=CreateFrame("Frame",nil,root)
 for _,event in ipairs({"LFG_UPDATE","LFG_QUEUE_STATUS_UPDATE","LFG_UPDATE_RANDOM_INFO","LFG_LOCK_INFO_RECEIVED","LFG_ROLE_CHECK_UPDATE","LFG_PROPOSAL_UPDATE","LFG_LIST_SEARCH_RESULTS_RECEIVED","LFG_LIST_SEARCH_FAILED","LFG_LIST_SEARCH_RESULT_UPDATED","LFG_LIST_APPLICATION_STATUS_UPDATED","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICANT_LIST_UPDATED","LFG_LIST_APPLICANT_UPDATED","LFG_LIST_ENTRY_CREATION_FAILED","GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_SPECIALIZATION_CHANGED","PLAYER_LEVEL_UP","PLAYER_ENTERING_WORLD"})do U.Call(events.RegisterEvent,events,event)end
 events:SetScript("OnEvent",function(_,event)
  dirty=true
  if event=="LFG_LIST_SEARCH_RESULTS_RECEIVED"then searching=nil;notice=nil
  elseif event=="LFG_LIST_SEARCH_FAILED"then searching=nil;notice="Search failed or was throttled. Wait a moment, then press Search again."
  elseif event=="LFG_LIST_ENTRY_CREATION_FAILED"then notice="The server rejected this listing. Check requirements or use Advanced listing editor."end
 end)
 local elapsed=0;root:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.3 then return end;elapsed=0
  if searching and GetTime()-(searchAt or 0)>20 then searching=nil;notice="Search timed out. Press Search to retry.";dirty=true end
  if dirty then refresh()end
 end)
 return root
end
