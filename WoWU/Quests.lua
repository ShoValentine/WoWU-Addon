-- WoWU Quest Journal: parchment pages, area chapters and native quest rewards.
local function framed(parent)
    local f=CreateFrame('Frame',nil,parent,'BackdropTemplate')
    WoWU_Theme.Backdrop(f,{bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=18,insets={left=5,right=5,top=5,bottom=5}})
    WoWU_Theme.Color(f,.075,.10,.12,.97)
    WoWU_Theme.Panel(f)
    return f
end
local function label(parent,size,colour)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    f:SetFont('Fonts\\FRIZQT__.TTF',size,'')
    WoWU_Theme.TextColor(f,unpack(colour or { .94,.79,.49 }))
    f:SetJustifyH('LEFT')
    f:SetJustifyV('TOP')
    return f
end
local function safeCall(fn,...)
    if type(fn)~='function' then return nil end
    local function pack(...) return {n=select('#',...),...} end
    local result=pack(pcall(fn,...))
    if result[1] then return unpack(result,2,result.n) end
end
local function ink(parent,size,heading)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    t:SetFont(heading and 'Fonts\\MORPHEUS.TTF' or 'Fonts\\FRIZQT__.TTF',size,'')
    t:SetTextColor(.18,.105,.045)
    t:SetShadowOffset(0,0)
    t:SetJustifyH('LEFT');t:SetJustifyV('TOP');t:SetWordWrap(true)
    return t
end
local function nativeArt(texture,atlas)
    if safeCall(C_Texture and C_Texture.GetAtlasInfo,atlas) then
        texture:SetAtlas(atlas);return true
    end
    return false
end
local function parchment(frame)
    local t=frame:CreateTexture(nil,'BACKGROUND',nil,2)
    t:SetPoint('TOPLEFT',7,-7);t:SetPoint('BOTTOMRIGHT',-7,7)
    if not nativeArt(t,'QuestDetailsBackgrounds') then
        t:SetTexture('Interface\\AddOns\\WoWU\\Textures\\Gilded\\Parchment')
    end
end
function WoWU_BuildQuests(parent)
    local left=framed(parent)
    left:SetPoint('TOPLEFT',10,-9)
    left:SetPoint('BOTTOMLEFT',10,9)
    left:SetWidth(375)
    parchment(left)
    local right=framed(parent)
    right:SetPoint('TOPLEFT',left,'TOPRIGHT',9,0)
    right:SetPoint('BOTTOMRIGHT',parent,'BOTTOMRIGHT',-10,9)
    parchment(right)
    local header=ink(left,24,true)
    header:SetPoint('TOPLEFT',16,-15)
    header:SetText('Quest Journal')
    local counter=ink(left,12)
    counter:SetPoint('TOPLEFT',16,-43)
    local search=CreateFrame('EditBox',nil,left,'InputBoxTemplate')
    search:SetPoint('TOPLEFT',22,-66);search:SetPoint('TOPRIGHT',-39,-66);search:SetHeight(28)
    search:SetAutoFocus(false);search:SetMaxLetters(80)
    local searchHint=search:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
    searchHint:SetPoint('LEFT',5,0);searchHint:SetText('Find a quest or area...')
    search:SetScript('OnEditFocusGained',function()searchHint:Hide()end)
    search:SetScript('OnEditFocusLost',function()searchHint:SetShown(search:GetText()=='')end)
    search:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
    search:SetScript('OnEscapePressed',function(self)self:SetText('');self:ClearFocus()end)
    local listScroll=CreateFrame('ScrollFrame',nil,left,'UIPanelScrollFrameTemplate')
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(listScroll) end
    listScroll:SetPoint('TOPLEFT',13,-107)
    listScroll:SetPoint('BOTTOMRIGHT',-31,15)
    local listChild=CreateFrame('Frame',nil,listScroll)
    listChild:SetSize(385,600)
    listScroll:SetScrollChild(listChild)
    local function headerButton(text,width,offset,fn)
        local b=CreateFrame('Button',nil,right,'UIPanelButtonTemplate')
        b:SetSize(width,42)
        b:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',offset,13)
        b:SetText(text);b.label=b:GetFontString();b.label:SetFont('Fonts\\FRIZQT__.TTF',15,'')
        b:SetScript('OnClick',fn)
        return b
    end
    local selectedQuestID
    local notice=ink(right,13)
    notice:SetPoint('BOTTOMLEFT',right,'BOTTOMLEFT',20,62)
    notice:SetWidth(620)
    notice:SetJustifyH('LEFT')
    notice:SetText('')
    local noticeSerial=0
    local function confirm(msg)
        noticeSerial=noticeSerial+1
        local serial=noticeSerial
        notice:SetAlpha(1)
        notice:SetText(msg)
        if C_Timer and C_Timer.After then
            C_Timer.After(1.7,function()
                if serial~=noticeSerial then return end
                if UIFrameFadeOut then
                    UIFrameFadeOut(notice,0.7,1,0)
                else
                    notice:SetText('')
                end
            end)
        end
    end
    local function focusQuest()
        if not selectedQuestID then return false end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            local ok=pcall(C_SuperTrack.SetSuperTrackedQuestID,selectedQuestID)
            return ok
        end
        return false
    end
    local trackButton=headerButton('Navigate',126,-154,function()
        if WoWUNavigation then local _,message=WoWUNavigation.StartQuest(selectedQuestID);confirm(message)
        elseif focusQuest() then confirm('Tracking this Quest') else confirm('Unable to track quest') end
    end)
    local mapButton=headerButton('Show on Map',140,-9,function()
        if not selectedQuestID then return end
        local id=selectedQuestID
        focusQuest()
        -- Open the selected quest through Blizzard's
        -- QuestMapFrame_OpenToQuestDetails(id). It selects the quest and lets
        -- Blizzard resolve its actual map, rather than guessing a UiMap ID.
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn,'Blizzard_QuestLog')
        elseif LoadAddOn then
            pcall(LoadAddOn,'Blizzard_QuestLog')
        end
        -- Dock the native map first, then invoke Blizzard's quest-open API.
        if WoWU_ShowPage then WoWU_ShowPage('Map') end
        local function openBlizzardQuest()
            if WoWUMistsQuests then
                local ok,message=WoWUMistsQuests.ShowOnMap(id)
                if not ok then confirm(message)end
                return ok
            end
            if WoWUClassicQuestLocation then
                local m=WoWUClassicQuestLocation(id,safeCall(C_Map.GetBestMapForUnit,'player'))
                local map=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame
                if m and map and map.SetMapID then
                    map:SetMapID(m);return true
                end
                return false
            end
            if QuestMapFrame_OpenToQuestDetails then
                return pcall(QuestMapFrame_OpenToQuestDetails,id)
            end
            return false
        end
        if not openBlizzardQuest() then
            confirm('Quest map details unavailable')
        end
    end)
    local watchButton
    if WoWUClient and (WoWUClient.classicMajor==1 or WoWUClient.classicMajor==5) then
        watchButton=headerButton('Track',110,-525,function()
            if not selectedQuestID then return end
            local watched=WoWUQuestLog.IsQuestWatched(selectedQuestID)
            local fn=watched and WoWUQuestLog.RemoveQuestWatch or WoWUQuestLog.AddQuestWatch
            safeCall(fn,selectedQuestID)
            watchButton.label:SetText(watched and 'Track'or 'Untrack')
            confirm(watched and 'Removed from the Dashboard tracker.'or 'Added to the Dashboard tracker.')
        end)
    end
    local function canAbandon(id)
        local q=WoWUQuestLog or C_QuestLog or {}
        local index=id and safeCall(q.GetLogIndexForQuestID,id)
        if not index or index<=0 then return false end
        if type(q.CanAbandonQuest)=='function'then return safeCall(q.CanAbandonQuest,id)==true end
        return type(q.AbandonQuest or AbandonQuest)=='function'and type(q.SetAbandonQuest or SetAbandonQuest)=='function'
    end
    local function abandonConfirmed(data)
        if not data or not data.questID then return end
        if InCombatLockdown and InCombatLockdown()then confirm('Abandon quests after combat.');return end
        if StaticPopup_FindVisible and (StaticPopup_FindVisible('ABANDON_QUEST')or StaticPopup_FindVisible('ABANDON_QUEST_WITH_ITEMS'))then confirm('Finish the other quest-abandon confirmation first.');return end
        local q=WoWUQuestLog or C_QuestLog or {};local id=data.questID
        local index=safeCall(q.GetLogIndexForQuestID,id)
        if not index or index<=0 or not canAbandon(id)then confirm('This quest is no longer in your log or cannot be abandoned.');return end
        local old=safeCall(q.GetSelectedQuest)
        local selectQuest=q.SetSelectedQuest
        if type(selectQuest)~='function'then confirm('Quest selection is unavailable on this client.');return end
        local function restoreSelection()
            if old and old~=id then local i=safeCall(q.GetLogIndexForQuestID,old);if i and i>0 then safeCall(selectQuest,old)end end
        end
        local ok=pcall(selectQuest,id)
        if not ok or safeCall(q.GetSelectedQuest)~=id then restoreSelection();confirm('The quest selection changed. Please try again.');return end
        local set=q.SetAbandonQuest or SetAbandonQuest
        local abandon=q.AbandonQuest or AbandonQuest
        if type(set)~='function'or type(abandon)~='function'then restoreSelection();confirm('Abandoning is unavailable on this client.');return end
        -- SetAbandonQuest uses the selected quest (no arguments). Prepare and
        -- validate it immediately before the confirmed action, never on preview.
        ok=pcall(set)
        local matches=false
        if type(q.GetAbandonQuest)=='function'then matches=safeCall(q.GetAbandonQuest)==id
        elseif type(GetAbandonQuestName)=='function'then matches=safeCall(GetAbandonQuestName)==data.title and safeCall(q.GetSelectedQuest)==id end
        if not ok or not matches then restoreSelection();confirm('Unable to verify the quest to abandon. No quest was abandoned.');return end
        ok=pcall(abandon);restoreSelection()
        confirm(ok and 'Abandon request sent for '..data.title..'.'or 'The game could not abandon this quest.')
    end
    StaticPopupDialogs.WOWU_ABANDON_QUEST={
        text='Abandon "%s"?\n\nQuest progress and related quest items may be lost.',
        button1='Abandon',button2=CANCEL or 'Cancel',timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnAccept=function(_,data)abandonConfirmed(data)end,
    }
    local abandonButton=headerButton('Abandon',120,-298,function()
        local q=WoWUQuestLog or C_QuestLog or {};local id=selectedQuestID
        if InCombatLockdown and InCombatLockdown()then confirm('Abandon quests after combat.');return end
        if not canAbandon(id)then confirm('Select a quest that can be abandoned.');return end
        local questTitle=safeCall(q.GetTitleForQuestID,id)
        if not questTitle then confirm('The quest is no longer available.');return end
        StaticPopup_Show('WOWU_ABANDON_QUEST',questTitle,nil,{questID=id,title=questTitle})
    end)
    parent:HookScript('OnHide',function()StaticPopup_Hide('WOWU_ABANDON_QUEST')end)
    local detailScroll=CreateFrame('ScrollFrame',nil,right,'UIPanelScrollFrameTemplate')
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(detailScroll) end
    detailScroll:SetPoint('TOPLEFT',20,-20)
    detailScroll:SetPoint('BOTTOMRIGHT',-33,80)
    local detailChild=CreateFrame('Frame',nil,detailScroll)
    detailChild:SetSize(685,750)
    detailScroll:SetScrollChild(detailChild)

    local title=ink(detailChild,27,true)
    title:SetPoint('TOPLEFT',8,-6);title:SetWidth(620)
    local questLevel=ink(detailChild,12)
    questLevel:SetPoint('TOPLEFT',title,'BOTTOMLEFT',0,-8)
    local objectiveHeader=ink(detailChild,21,true)
    objectiveHeader:SetPoint('TOPLEFT',questLevel,'BOTTOMLEFT',0,-22)
    objectiveHeader:SetText('Objectives')
    local objectiveText=ink(detailChild,16)
    objectiveText:SetPoint('TOPLEFT',objectiveHeader,'BOTTOMLEFT',0,-12)
    objectiveText:SetWidth(620)
    objectiveText:SetWordWrap(true)

    local descriptionHeader=ink(detailChild,23,true)
    descriptionHeader:SetPoint('TOPLEFT',objectiveText,'BOTTOMLEFT',0,-27)
    descriptionHeader:SetText('Description')
    local description=ink(detailChild,16)
    description:SetPoint('TOPLEFT',descriptionHeader,'BOTTOMLEFT',0,-12)
    description:SetWidth(620)
    description:SetWordWrap(true)

    local rewardsHeader=CreateFrame('Frame',nil,detailChild,'BackdropTemplate')
    rewardsHeader:SetPoint('TOPLEFT',description,'BOTTOMLEFT',-8,-25)
    rewardsHeader:SetSize(636,60)
    rewardsHeader:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'})
    rewardsHeader:SetBackdropColor(.24,.12,.045,1)
    local rewardBanner=rewardsHeader:CreateTexture(nil,'ARTWORK')
    rewardBanner:SetAllPoints()
    -- Some Classic atlas entries exist without the corresponding Retail art.
    -- Always provide a real texture on Classic rather than a green missing file.
    if WoWUClient and WoWUClient.isClassic or not nativeArt(rewardBanner,'questlog-reward-header-top')then
        rewardBanner:SetColorTexture(.24,.12,.045,1)
    end
    local rewardHeading=rewardsHeader:CreateFontString(nil,'OVERLAY','GameFontNormal')
    rewardHeading:SetFont('Fonts\\MORPHEUS.TTF',25,'')
    rewardHeading:SetTextColor(.91,.79,.64);rewardHeading:SetShadowOffset(0,0)
    rewardHeading:SetPoint('CENTER',0,-2);rewardHeading:SetText('Rewards')
    local rewardsText=ink(detailChild,14)
    rewardsText:SetPoint('TOPLEFT',rewardsHeader,'BOTTOMLEFT',8,-14)
    rewardsText:SetWidth(620)
    local rewardButtons={}
    local function clearRewardButtons()
        for _,b in ipairs(rewardButtons) do b:Hide() end
    end
    local moneyText
    local function showRewardItems(questID)
        clearRewardButtons()
        local items={}
        local xp=safeCall(GetQuestLogRewardXP,questID)
        if type(xp)=='number' and xp>0 then
            items[#items+1]={name=tostring(xp)..' XP',texture='Interface\\Icons\\XP_Icon',summary='Experience'}
        end
        local money=safeCall(GetQuestLogRewardMoney,questID)
        if type(money)=='number' and money>0 then
            items[#items+1]={name=moneyText(money),texture='Interface\\Icons\\INV_Misc_Coin_01',summary='Money'}
        end
        local function add(choice,index)
            local fn=choice and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
            local name,texture,count=safeCall(fn,index,questID)
            if type(name)~='string' or name=='' then name='Quest reward (loading)' end
            if name then
                local kind=choice and 'choice' or 'reward'
                local itemLink=safeCall(GetQuestLogItemLink,kind,index,questID)
                items[#items+1]={name=name,texture=texture,count=count,itemLink=itemLink,index=index,choice=choice,kind=kind,questID=questID}
            end
        end
        local n=safeCall(GetNumQuestLogRewards,questID)
        for i=1,math.min(tonumber(n) or 0,16) do add(false,i) end
        local choices=safeCall(GetNumQuestLogChoices,questID)
        for i=1,math.min(tonumber(choices) or 0,16) do add(true,i) end
        for i,item in ipairs(items) do
            local b=rewardButtons[i]
            if not b then
                b=CreateFrame('Button',nil,detailChild,'BackdropTemplate')
                b:SetHeight(66)
                b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
                b:SetBackdropColor(.20,.12,.055,.16);b:SetBackdropBorderColor(.45,.30,.13,.7)
                b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('LEFT',8,0);b.icon:SetSize(44,44)
                b.name=ink(b,14);b.name:SetPoint('TOPLEFT',62,-10);b.name:SetPoint('TOPRIGHT',-8,-10);b.name:SetHeight(32)
                b.kind=ink(b,11);b.kind:SetPoint('BOTTOMLEFT',62,9)
                b.count=b:CreateFontString(nil,'OVERLAY','NumberFontNormal')
                b.count:SetPoint('BOTTOMRIGHT',b.icon,'BOTTOMRIGHT',-2,1)
                b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight','ADD')
                b:SetScript('OnEnter',function(self)
                    local gesture=detailScroll.WoWUGesture
                    if gesture and gesture.down and gesture.dragging then return end
                    if not GameTooltip then return end
                    local data=self.rewardData
                    GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                    if data.summary then
                        GameTooltip:SetText(data.summary);GameTooltip:AddLine(data.name,1,1,1,true);GameTooltip:Show();return
                    end
                    -- Prefer the quest's reward link: reward info's sixth return
                    -- is not an item ID on every Forever client build.
                    local link=data.itemLink or safeCall(GetQuestLogItemLink,data.kind,data.index,data.questID)
                    local populated=false
                    if type(link)=='string' and link~='' then
                        populated=pcall(GameTooltip.SetHyperlink,GameTooltip,link)
                    end
                    if not populated and GameTooltip.SetQuestLogItem and safeCall(WoWUQuestLog and WoWUQuestLog.GetSelectedQuest)==data.questID then
                        -- Native quest item API can build the complete tooltip
                        -- without knowing the underlying item ID.
                        populated=pcall(GameTooltip.SetQuestLogItem,GameTooltip,data.kind,data.index)
                    end
                    if not populated then GameTooltip:SetText(data.name or 'Quest reward') end
                    GameTooltip:Show()
                end)
                b:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end);WoWUDetails.BindHover(b,false)
                rewardButtons[i]=b
            end
            b.rewardData=item;b.icon:SetTexture(item.texture or 134400)
            b.name:SetText(item.name)
            b.kind:SetText(item.summary or (item.choice and 'Choose one reward' or 'You will receive'))
            b.count:SetText((tonumber(item.count) or 0)>1 and tostring(item.count) or '')
            local width=math.max(100,(detailChild:GetWidth()-28)/2)
            b:SetWidth(width)
            b:ClearAllPoints();b:SetPoint('TOPLEFT',rewardsText,'BOTTOMLEFT',((i-1)%2)*(width+12),-16-math.floor((i-1)/2)*74)
            b:Show()
        end
        rewardsText:SetText(#items>0 and 'Rewards for completing this quest:' or 'No reward information available from the quest log.')
        return math.ceil(#items/2)*74
    end
    moneyText=function(value)
        value=math.floor(tonumber(value) or 0)
        local gold=math.floor(value/10000)
        local silver=math.floor((value%10000)/100)
        local copper=value%100
        local t={}
        if gold>0 then t[#t+1]=gold..'|TInterface\\MoneyFrame\\UI-GoldIcon:15:15|t' end
        if silver>0 or gold>0 then t[#t+1]=silver..'|TInterface\\MoneyFrame\\UI-SilverIcon:15:15|t' end
        t[#t+1]=copper..'|TInterface\\MoneyFrame\\UI-CopperIcon:15:15|t'
        return table.concat(t,'  ')
    end
    local rows={}
    local groupButtons={}
    local collapsedGroups={}
    local questRows={}
    local function getQuestInfo(index)
        local info=safeCall(WoWUQuestLog and WoWUQuestLog.GetInfo,index)
        if type(info)=='table' then return info end
        return nil
    end
    local questReadyToTurnIn
    local displayedQuestID
    local function refreshDetail()
        local previousScroll=detailScroll:GetVerticalScroll()
        local info
        for _,row in ipairs(questRows) do
            if row.questID==selectedQuestID then info=row break end
        end
        if not info then
            displayedQuestID=nil
            detailScroll:SetVerticalScroll(0)
            title:SetText('Select a quest')
            questLevel:SetText('Your adventures are recorded here.')
            objectiveHeader:Hide();descriptionHeader:Hide()
            description:SetText('')
            objectiveText:SetText('Choose a quest from the journal on the left.')
            detailChild:SetHeight(math.max(1,detailScroll:GetHeight()))
            rewardsHeader:Hide();rewardsText:Hide();clearRewardButtons();trackButton:Disable();mapButton:Disable();abandonButton:Disable()
            if watchButton then watchButton:Disable()end
            return
        end
        trackButton:Enable();mapButton:Enable()
        abandonButton:SetEnabled(canAbandon(selectedQuestID))
        if watchButton then watchButton:Enable();watchButton.label:SetText(safeCall(WoWUQuestLog.IsQuestWatched,selectedQuestID)and 'Untrack'or 'Track')end
        title:SetText(info.title or 'Quest')
        questLevel:SetText((info.level and info.level>0 and ('Level '..info.level..'  |  ') or '')..(questReadyToTurnIn(info) and 'Ready to turn in' or 'In progress'))
        objectiveHeader:Show();descriptionHeader:Show()
        local questID=info.questID
        -- Forever exposes narrative/objective instructions via the legacy
        -- quest-log-index API, in addition to WoWUQuestLog's numeric objectives.
        local index=info.logIndex
        if (not index or index<=0) and WoWUQuestLog and WoWUQuestLog.GetLogIndexForQuestID then
            index=safeCall(WoWUQuestLog.GetLogIndexForQuestID,questID)
        end
        if (not index or index<=0) and GetQuestLogIndexByID then
            index=safeCall(GetQuestLogIndexByID,questID)
        end
        local narrative, instruction
        if index and index>0 and GetQuestLogQuestText then
            narrative,instruction=safeCall(WoWUQuestLog and WoWUQuestLog.GetLogText or GetQuestLogQuestText,index)
        end
        if (type(narrative)~='string' or narrative=='') and WoWUQuestLog and WoWUQuestLog.GetQuestDescription then
            narrative=safeCall(WoWUQuestLog.GetQuestDescription,questID)
        end
        description:SetText((type(narrative)=='string' and narrative~='') and narrative or
            'No quest description was returned by the game client.')
        local objectives=safeCall(WoWUQuestLog and WoWUQuestLog.GetQuestObjectives,questID)
        local lines={}
        if type(objectives)=='table' then
            for _,obj in ipairs(objectives) do
                local line=obj.text or obj.description or 'Objective'
                if obj.numFulfilled and obj.numRequired and obj.numRequired>0 then
                    line=line..' ('..obj.numFulfilled..'/'..obj.numRequired..')'
                end
                if obj.finished then line='|TInterface\\RaidFrame\\ReadyCheck-Ready:17:17:0:0|t '..line else line='- '..line end
                table.insert(lines,line)
            end
        end
        -- Not every quest has countable objectives. Courier, dialogue and
        -- travel quests often use only the narrative objective instructions.
        if #lines==0 and type(instruction)=='string' and instruction~='' then
            table.insert(lines,instruction)
        end
        if #lines==0 then
            table.insert(lines,questReadyToTurnIn(info) and 'Quest objectives complete.' or
                'This quest has no listed progress counters. Check the Blizzard quest journal for details.')
        end
        objectiveText:SetText(table.concat(lines,'\n\n'))
        rewardsHeader:Show();rewardsText:Show()
        local extraRewardHeight=showRewardItems(questID)
        detailChild:SetHeight(math.max(620,title:GetStringHeight()+questLevel:GetStringHeight()+description:GetStringHeight()+objectiveText:GetStringHeight()+rewardsText:GetStringHeight()+extraRewardHeight+285))
        -- QUEST_LOG_UPDATE can arrive during a swipe or while reading. Only a
        -- different quest should jump to the top; preserve routine refreshes.
        local maximum=math.max(0,detailChild:GetHeight()-detailScroll:GetHeight())
        local offset=displayedQuestID==questID and math.min(previousScroll,maximum) or 0
        if detailScroll:GetVerticalScroll()~=offset then detailScroll:SetVerticalScroll(offset) end
        displayedQuestID=questID
        for _,button in ipairs(rows) do
            local selected=(button.questID==selectedQuestID)
            button:SetBackdropColor(.48,.29,.085,selected and .34 or(button.alternate and .10 or .035))
            button:SetBackdropBorderColor(.48,.28,.08,selected and 1 or .32)
            button.accent:SetColorTexture(selected and .88 or(button.ready and .14 or .42),selected and .55 or(button.ready and .48 or .28),selected and .12 or .10,selected and 1 or .8)
        end
    end
    questReadyToTurnIn = function(info)
        if not info or not info.questID then return false end
        if WoWUQuestLog and WoWUQuestLog.IsComplete then
            local ok, complete=pcall(WoWUQuestLog.IsComplete,info.questID)
            if ok and complete~=nil then return complete == true or complete == 1 end
        end
        -- Older clients return completion as the sixth GetQuestLogTitle result.
        if GetQuestLogTitle and info.logIndex then
            local ok,_,_,_,_,_,complete=pcall(GetQuestLogTitle,info.logIndex)
            if ok and complete~=nil then return complete == true or complete == 1 end
        end
        return info.isComplete == true or info.isComplete == 1
    end
    local function refreshList()
        wipe(questRows)
        local groups={}
        local query=search:GetText():lower()
        local matched=0
        local currentGroup=nil
        local count=safeCall(WoWUQuestLog and WoWUQuestLog.GetNumQuestLogEntries) or 0
        local active=0
        local function newGroup(name)
            local group={name=name,quests={}}
            groups[#groups+1]=group
            return group
        end
        for index=1,count do
            local info=getQuestInfo(index)
            if info then
                if info.isHeader then
                    currentGroup=newGroup((info.title and info.title~='') and info.title or 'Other Quests')
                elseif info.questID then
                    if not currentGroup then currentGroup=newGroup('Other Quests') end
                    info.logIndex=index
                    questRows[#questRows+1]=info
                    if query==''or(info.title or ''):lower():find(query,1,true)or currentGroup.name:lower():find(query,1,true)then
                        currentGroup.quests[#currentGroup.quests+1]=info;matched=matched+1
                    end
                    active=active+1
                end
            end
        end
        for i=#groups,1,-1 do if #groups[i].quests==0 then table.remove(groups,i)end end
        counter:SetText(query==''and(active..' active quests')or(matched..' of '..active..' quests'))
        local exists=false
        for _,group in ipairs(groups)do for _,info in ipairs(group.quests)do
            if info.questID==selectedQuestID then exists=true end
        end end
        if not exists then selectedQuestID=groups[1]and groups[1].quests[1]and groups[1].quests[1].questID or nil end

        local y=4
        local usedRows=0
        for g,group in ipairs(groups) do
            local headerButton=groupButtons[g]
            if not headerButton then
                headerButton=CreateFrame('Button',nil,listChild,'BackdropTemplate')
                headerButton:SetHeight(48)
                headerButton:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
                headerButton:SetBackdropColor(.19,.105,.035,.94);headerButton:SetBackdropBorderColor(.52,.34,.12,.9)
                headerButton.name=ink(headerButton,19,true)
                headerButton.name:SetTextColor(1,.84,.48)
                headerButton.name:SetPoint('LEFT',12,0)
                headerButton.name:SetPoint('RIGHT',headerButton,'RIGHT',-78,0)
                headerButton.name:SetHeight(40)
                headerButton.name:SetJustifyV('MIDDLE')
                headerButton.count=ink(headerButton,13);headerButton.count:SetTextColor(.96,.83,.60)
                headerButton.count:SetPoint('RIGHT',headerButton,'RIGHT',-29,0)
                headerButton.count:SetJustifyH('RIGHT')
                headerButton.arrow=ink(headerButton,18);headerButton.arrow:SetTextColor(1,.85,.52)
                headerButton.arrow:SetPoint('RIGHT',headerButton,'RIGHT',-11,0)
                headerButton:SetScript('OnClick',function(self)
                    if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(listScroll) then return end
                    collapsedGroups[self.groupName]=not collapsedGroups[self.groupName]
                    refreshList()
                end)
                groupButtons[g]=headerButton
            end
            headerButton.groupName=group.name
            headerButton:ClearAllPoints()
            headerButton:SetPoint('TOPLEFT',listChild,'TOPLEFT',3,-y)
            headerButton:SetPoint('RIGHT',listChild,'RIGHT',-6,0)
            headerButton.name:SetText(group.name)
            headerButton.count:SetText(tostring(#group.quests))
            headerButton.arrow:SetText(query==''and collapsedGroups[group.name] and '+' or '-')
            headerButton:Show()
            y=y+58
            if query~=''or not collapsedGroups[group.name] then
                for _,info in ipairs(group.quests) do
                    usedRows=usedRows+1
                    local b=rows[usedRows]
                    if not b then
                        b=CreateFrame('Button',nil,listChild,'BackdropTemplate')
                        b:SetHeight(82)
                        b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
                        b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square','ADD')
                        b.accent=b:CreateTexture(nil,'ARTWORK');b.accent:SetPoint('TOPLEFT',5,-5);b.accent:SetPoint('BOTTOMLEFT',5,5);b.accent:SetWidth(4)
                        b.questIcon=b:CreateTexture(nil,'ARTWORK');b.questIcon:SetSize(25,25);b.questIcon:SetPoint('TOPLEFT',14,-13)
                        b.name=ink(b,16)
                        b.name:SetPoint('TOPLEFT',47,-10)
                        b.name:SetPoint('TOPRIGHT',-40,-8)
                        b.name:SetHeight(41)
                        b.tick=b:CreateTexture(nil,'OVERLAY')
                        b.tick:SetTexture('Interface\\RaidFrame\\ReadyCheck-Ready')
                        b.tick:SetSize(23,23)
                        b.tick:SetPoint('RIGHT',b,'RIGHT',-13,0)
                        b.level=ink(b,12)
                        b.level:SetPoint('BOTTOMLEFT',47,10)
                        b:SetScript('OnClick',function(self)
                            if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(listScroll) then return end
                            selectedQuestID=self.questID
                            if WoWUNavigation then WoWUNavigation.SelectQuest(selectedQuestID) end
                            refreshDetail()
                        end)
                        rows[usedRows]=b
                    end
                    b:ClearAllPoints()
                    b:SetPoint('TOPLEFT',listChild,'TOPLEFT',3,-y)
                    b:SetPoint('RIGHT',listChild,'RIGHT',-6,0)
                    b.questID=info.questID;b.listOffset=y
                    b.name:SetText(info.title or 'Quest')
                    b.ready=questReadyToTurnIn(info);b.alternate=usedRows%2==0
                    b.questIcon:SetTexture(b.ready and 'Interface\\GossipFrame\\ActiveQuestIcon'or 'Interface\\GossipFrame\\AvailableQuestIcon')
                    b.tick:SetShown(b.ready)
                    local tracked=safeCall(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)==info.questID
                    b.level:SetText('Lv '..tostring(info.level or '?')..'  |  '..(b.ready and 'Ready to turn in'or tracked and 'Tracked'or 'In progress'))
                    b:Show()
                    y=y+89
                end
            end
        end
        if usedRows>0 then y=y+7 end
        for i=usedRows+1,#rows do rows[i]:Hide() end
        for i=#groups+1,#groupButtons do groupButtons[i]:Hide() end
        listChild:SetHeight(math.max(listScroll:GetHeight(),y+7))
        refreshDetail()
    end
    search:SetScript('OnTextChanged',function(self)searchHint:SetShown(self:GetText()==''and not self:HasFocus());listScroll:SetVerticalScroll(0);refreshList()end)
    function WoWU_SelectQuest(id,fromMap)
        if InCombatLockdown and InCombatLockdown() then return false end
        local index=safeCall(WoWUQuestLog and WoWUQuestLog.GetLogIndexForQuestID,id)
        if not index or index<=0 then return false end
        search:SetText('');selectedQuestID=id
        if WoWUNavigation then WoWUNavigation.SelectQuest(id) end
        wipe(collapsedGroups)
        if WoWU_ShowPage then WoWU_ShowPage('Quests') end
        refreshList()
        for _,row in ipairs(rows) do
            if row.questID==id and row:IsShown() then
                listScroll:SetVerticalScroll(math.min(row.listOffset or 0,math.max(0,listChild:GetHeight()-listScroll:GetHeight())))
                break
            end
        end
        return true
    end
    local eventFrame=CreateFrame('Frame')
    eventFrame:RegisterEvent('QUEST_LOG_UPDATE')
    eventFrame:RegisterEvent('QUEST_ACCEPTED')
    eventFrame:RegisterEvent('QUEST_REMOVED')
    eventFrame:RegisterEvent('QUEST_TURNED_IN')
    eventFrame:SetScript('OnEvent',function()
        if parent:IsShown() then refreshList() end
    end)
    local function resizePages()
        local width=parent:GetWidth()
        if width and width>0 then left:SetWidth(math.max(280,math.min(395,width*.30))) end
        listChild:SetWidth(math.max(1,listScroll:GetWidth()))
        detailChild:SetWidth(math.max(1,detailScroll:GetWidth()))
        local textWidth=math.max(1,detailChild:GetWidth()-16)
        for _,text in ipairs({title,questLevel,objectiveText,description,rewardsText}) do text:SetWidth(textWidth) end
        rewardsHeader:SetWidth(detailChild:GetWidth())
        notice:SetWidth(math.max(1,right:GetWidth()-40))
        local actions={};if watchButton then actions[#actions+1]=watchButton end
        actions[#actions+1]=abandonButton;actions[#actions+1]=trackButton;actions[#actions+1]=mapButton
        local gap=8;local buttonWidth=math.min(150,(right:GetWidth()-28-gap*(#actions-1))/#actions)
        for i,b in ipairs(actions)do b:SetWidth(buttonWidth);b:ClearAllPoints();b:SetPoint('BOTTOMRIGHT',right,'BOTTOMRIGHT',-14-(#actions-i)*(buttonWidth+gap),13)end
    end
    listScroll:HookScript('OnSizeChanged',function() resizePages();if parent:IsShown() then refreshList() end end)
    detailScroll:HookScript('OnSizeChanged',function() resizePages();if parent:IsShown() then refreshDetail() end end)
    parent:HookScript('OnShow',function() resizePages();refreshList() end)
    resizePages()
    refreshList()
end
