-- Character information owned by WoWU; never embeds native character panels.
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c,d,e,f,g,h,i,j,k,l,m=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
    return nil
end
local function count(fn) return math.min(5000,math.max(0,tonumber((safe(fn))) or 0)) end
local function progress(a,b)
    if type(a)=="number" and type(b)=="number" and b>0 then return a.." / "..b,a/b end
    return "",nil
end
local standings={"Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted"}
function WoWU_GetCharacterDetailRows(tab)
    local rows={}
    local function add(r) rows[#rows+1]=r end
    if tab=="Skills" then
        if WoWUClient.isRetail then
            for _,d in ipairs(WoWUClient.Professions())do
                local value,ratio=progress(d.rank,d.max)
                add({name=d.name,value=value,ratio=ratio,description="Profession skill. Retail does not use the old weapon-skill and language progression list."})
            end
        end
        local api=not WoWUClient.isRetail and C_SkillInfo or nil
        for i=1,(WoWUClient.isRetail and 0 or count(api and api.GetNumSkillLines or GetNumSkillLines)) do
            local d=safe(api and api.GetSkillLineInfo,i)
            if not d and not api then
                local n,h,c,r,_,_,m,_,_,_,_,_,desc=safe(GetSkillLineInfo,i)
                if n then d={name=n,isHeader=h,isCollapsed=not c,rank=r,maxRank=m,description=desc} end
            end
            if d and (not d.parentSkillLineID or d.parentSkillLineID==0) and
                (d.isHeader and d.skillID~=7 or not d.isHeader and d.skillLineCategoryID~=7) then
                local value,ratio=progress(d.rank,d.maxRank)
                add({name=d.name,value=value,ratio=ratio,description=d.description,header=d.isHeader,
                    collapsed=d.isCollapsed,index=i,kind="skill"})
            end
        end
    elseif tab=="Currencies" then
        local api=C_CurrencyInfo
        for i=1,count(api and api.GetCurrencyListSize or GetCurrencyListSize) do
            local d=safe(api and api.GetCurrencyListInfo,i)
            if not d and not api then
                local n,h,e,_,_,q,icon=safe(GetCurrencyListInfo,i)
                if n then d={name=n,isHeader=h,isHeaderExpanded=e,quantity=q,iconFileID=icon} end
            end
            if d then add({name=d.name,value=not d.isHeader and tostring(d.quantity or 0) or "",
                header=d.isHeader,collapsed=not d.isHeaderExpanded,index=i,kind="currency"}) end
        end
    elseif tab=="Reputation" then
        local api=C_Reputation
        for i=1,count(api and api.GetNumFactions or GetNumFactions) do
            local d=safe(api and api.GetFactionDataByIndex,i)
            if not d and not api then
                local n,desc,r,lo,hi,v,_,_,h,c,withRep=safe(GetFactionInfo,i)
                if n then d={name=n,description=desc,reaction=r,currentReactionThreshold=lo,
                    nextReactionThreshold=hi,currentStanding=v,isHeader=h,isCollapsed=c,isHeaderWithRep=withRep} end
            end
            if d then
                local value,ratio="",nil
                if not d.isHeader or d.isHeaderWithRep then
                    local standing=_G["FACTION_STANDING_LABEL"..tostring(d.reaction)] or standings[d.reaction] or ""
                    if type(d.currentStanding)=="number" and type(d.currentReactionThreshold)=="number" and type(d.nextReactionThreshold)=="number" then
                        value,ratio=progress(d.currentStanding-d.currentReactionThreshold,d.nextReactionThreshold-d.currentReactionThreshold)
                    end
                    value=standing..(value~="" and (" ("..value:gsub("%s+","")..")") or "")
                    if WoWUClient.isRetail and d.factionID then
                        local renown=safe(C_MajorFactions and C_MajorFactions.GetMajorFactionData,d.factionID)
                        if renown and renown.renownLevel then
                            local amount;amount,ratio=progress(renown.renownReputationEarned,renown.renownLevelThreshold)
                            value="Renown "..renown.renownLevel..(amount~=""and (" ("..amount..")")or "")
                        elseif safe(C_Reputation and C_Reputation.IsFactionParagon,d.factionID)then
                            local earned,threshold,_,pending=safe(C_Reputation.GetFactionParagonInfo,d.factionID)
                            if earned and threshold and threshold>0 then
                                local amount;amount,ratio=progress(pending and threshold or earned%threshold,threshold)
                                value="Paragon ("..amount..")"..(pending and " - Reward ready"or "")
                            end
                        end
                    end
                end
                add({name=d.name,value=value,ratio=ratio,description=d.description,header=d.isHeader,
                    collapsed=d.isCollapsed,index=i,kind="reputation",reaction=d.reaction,standing=_G["FACTION_STANDING_LABEL"..tostring(d.reaction)] or standings[d.reaction]})
            end
        end
    elseif tab=="Statistics" then
        -- Same category/row API as Blizzard_Statistics/Camelot/StatisticsFrame.lua.
        local categories=safe(GetStatisticsCategoryList) or {}
        local ordered,byID,children={},{},{}
        for k,id in pairs(categories)do if type(k)=="number" and id then ordered[#ordered+1]={k,id}end end
        table.sort(ordered,function(a,b)return a[1]<b[1]end)
        for _,entry in ipairs(ordered)do
            local id=entry[2];local name,parent=safe(GetCategoryInfo,id)
            if name then byID[id]={name=name,parent=parent};children[parent or -1]=children[parent or -1] or {};table.insert(children[parent or -1],id)end
        end
        local emitted={}
        local function append(id,ancestors,depth)
            if emitted[id] or not byID[id]then return end;emitted[id]=true
            add({name=byID[id].name,header=true,kind="statistics",index=id,ancestors=ancestors,depth=depth})
            local path={};for _,v in ipairs(ancestors)do path[#path+1]=v end;path[#path+1]=id
            local n=tonumber((safe(GetCategoryNumAchievements,id)))or 0
            for j=1,n do
                local quantity,skip,statID
                if WoWUClient.isRetail or WoWUClient.isClassic then
                    statID=safe(GetAchievementInfo,id,j)
                    if statID then quantity=safe(GetStatistic,statID)end
                else quantity,skip,statID=safe(GetStatistic,id,j)end
                if not skip and statID then
                    local _,name=safe(GetAchievementInfo,statID);local value=tonumber(quantity)
                    add({name=name or UNKNOWN or tostring(statID),value=value and value>0 and tostring(value) or "--",category=id,ancestors=path,depth=depth+1})
                end
            end
            for _,child in ipairs(children[id]or {})do append(child,path,depth+1)end
        end
        for _,entry in ipairs(ordered)do local d=byID[entry[2]];if d and (not d.parent or d.parent==-1 or not byID[d.parent])then append(entry[2],{},0)end end
        for _,entry in ipairs(ordered)do append(entry[2],{},0)end

    end
    if #rows==0 then add({name="No "..string.lower(tab).." data available.",value=""}) end
    return rows
end

function WoWU_ToggleCharacterHeader(d)
    if InCombatLockdown and InCombatLockdown() then return false end
    local fn
    if d.kind=="skill" then
        local a=C_SkillInfo or _G;fn=d.collapsed and a.ExpandSkillHeader or a.CollapseSkillHeader
    elseif d.kind=="reputation" then
        local a=C_Reputation or _G;fn=d.collapsed and a.ExpandFactionHeader or a.CollapseFactionHeader
    elseif d.kind=="currency" then
        local a=C_CurrencyInfo or _G;fn=a.ExpandCurrencyList
        if type(fn)=="function" then return pcall(fn,d.index,d.collapsed) end
    end
    if type(fn)=="function" then return pcall(fn,d.index) end
    return false
end

function WoWU_CreateCharacterDetails(parent,stats)
    local root=CreateFrame("Frame",nil,parent);root:SetAllPoints()
    local active="Stats"
    local tabs,rows,collapsed={},{},{}
    local selectedKey
    local function label(p,size)
        local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
        t:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(t,.94,.79,.49);t:SetJustifyH("LEFT")
        return t
    end
    local scroll=CreateFrame("ScrollFrame",nil,root,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",14,-108);scroll:SetPoint("BOTTOMRIGHT",-30,14)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(400,600);scroll:SetScrollChild(body)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    WoWU_Theme.Scrollbar(scroll)
    function root:Refresh(reset)
        if not root:IsVisible() then return end
        local data=active=="Stats" and stats() or WoWU_GetCharacterDetailRows(active)
        local width=math.max(100,scroll:GetWidth());body:SetWidth(width)
        local index,y=0,0
        for _,d in ipairs(data) do
            local hidden=false
            for _,id in ipairs(d.ancestors or {})do if collapsed[id]then hidden=true;break end end
            if not hidden then
                index=index+1
                local b=rows[index]
                if not b then
                    b=CreateFrame("Button",nil,body,"BackdropTemplate");rows[index]=b
                    b.shade=b:CreateTexture(nil,"BACKGROUND");b.shade:SetAllPoints()
                    b.meter=CreateFrame("StatusBar",nil,b,"BackdropTemplate");b.meter:SetStatusBarTexture(WoWU_Theme.assets.statusbar);b.meter:SetMinMaxValues(0,1)
                    WoWU_Theme.Backdrop(b.meter,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
                    WoWU_Theme.Fill(b.meter,.025,.025,.025,1);WoWU_Theme.Border(b.meter,.65,.50,.23,1)
                    b.meterText=label(b.meter,12);b.meterText:SetPoint("CENTER");b.meterText:SetJustifyH("CENTER");WoWU_Theme.TextColor(b.meterText,1,1,.9);b.meterText:SetShadowOffset(1,-1)
                    b.description=label(b,12);WoWU_Theme.TextColor(b.description,.87,.83,.72);b.description:SetWordWrap(true);b.description:SetJustifyV("TOP")
                    b.name=label(b,14);b.name:SetPoint("TOPLEFT",7,-6)
                    b.value=label(b,12);b.value:SetPoint("BOTTOMRIGHT",-7,8);b.value:SetJustifyH("RIGHT")
                    b:SetScript("OnClick",function(self)
                        if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end
                        local r=self.data
                        if not r then return end
                        if not r.header then
                            selectedKey=selectedKey==self.key and nil or self.key;root:Refresh();return
                        end
                        if r.kind=="statistics" then collapsed[r.index]=not collapsed[r.index]
                        elseif not WoWU_ToggleCharacterHeader(r) then return end
                        root:Refresh()
                    end)
                    b:SetScript("OnEnter",function(self)
                        if self.data and self.data.description and GameTooltip then
                            GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(self.data.name)
                            GameTooltip:AddLine(self.data.description,1,1,1,true);GameTooltip:Show()
                        end
                    end)
                    b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);WoWUDetails.BindHover(b,false)
                end
                local key=active..":"..tostring(d.index or d.name)
                b.data=d;b.key=key;b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y)
                local closed=d.kind=="statistics" and collapsed[d.index] or d.collapsed
                local indent=math.min(40,(d.depth or 0)*12)
                local hasBar=d.ratio~=nil and not d.header
                local h=d.header and 34 or 50
                b.name:ClearAllPoints();b.value:ClearAllPoints();b.description:ClearAllPoints()
                b.name:SetPoint("TOPLEFT",9+indent,-(d.header and 9 or 10));b.name:SetWidth(hasBar and width*.44-indent or width-100-indent)
                b.name:SetHeight(d.header and 20 or 35);b.name:SetWordWrap(true)
                b.name:SetText((d.header and (closed and "+  " or "-  ")or "")..(d.name or ""))
                b.value:SetPoint("TOPRIGHT",-9,-12);b.value:SetWidth(82);b.value:SetJustifyH("RIGHT");b.value:SetText(d.value or "");b.value:SetShown(not hasBar and not d.header)
                b.meter:ClearAllPoints();b.meter:SetPoint("TOPRIGHT",-8,-10);b.meter:SetSize(width*.49,25);b.meter:SetShown(hasBar)
                if hasBar then
                    b.meter:SetValue(math.max(0,math.min(1,d.ratio)))
                    local color=d.kind=="reputation" and FACTION_BAR_COLORS and FACTION_BAR_COLORS[d.reaction]
                    b.meter:SetStatusBarColor(color and color.r or .12,color and color.g or .38,color and color.b or .78)
                    b.meterText:SetFont("Fonts\\FRIZQT__.TTF",d.kind=="reputation" and 11 or 12,"");b.meterText:SetWordWrap(false);b.meterText:SetWidth(width*.49-10);b.meterText:SetText(d.value or "")
                end
                local expanded=not d.header and selectedKey==key
                b.description:SetShown(expanded)
                if expanded then
                    b.description:SetPoint("TOPLEFT",10,-52);b.description:SetWidth(width-20)
                    b.description:SetText((d.kind=="reputation" and ((d.value or "").."\n")or "")..(d.description or d.name or ""))
                    h=64+b.description:GetStringHeight()
                end
                if d.header then
                    WoWU_Theme.Backdrop(b,{bgFile=WoWU_Theme.assets.marble,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
                    WoWU_Theme.Fill(b,.28,.12,.035,.95);WoWU_Theme.Border(b,.67,.5,.2,1)
                    WoWU_Theme.TextColor(b.name,1,.82,.16)
                else WoWU_Theme.Backdrop(b,nil);WoWU_Theme.TextColor(b.name,.94,.90,.80)end
                b.shade:SetColorTexture(.8,.69,.4,expanded and .17 or index%2==0 and .05 or 0)
                b:SetSize(width,h);b:Show();y=y+h+4

            end
        end
        for i=index+1,#rows do rows[i]:Hide();rows[i].data=nil end
        body:SetHeight(math.max(scroll:GetHeight(),y))
        scroll:SetVerticalScroll(reset and 0 or math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
        for _,b in ipairs(tabs) do WoWU_Theme.Tab(b,b.tab==active) end
    end
    function root:RefreshStats() if active=="Stats" then self:Refresh() end end
    local detailTabs={"Stats","Skills","Currencies","Reputation","Statistics"}
    if WoWUClient.isClassic and (WoWUClient.classicMajor or 0)<3 then detailTabs={"Stats","Skills","Reputation"}end
    for i,name in ipairs(detailTabs) do
        local b=CreateFrame("Button",nil,root,"BackdropTemplate");tabs[i]=b;b.tab=name
        WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        local t=label(b,13);t:SetPoint("CENTER");t:SetJustifyH("CENTER");t:SetText(name);b.label=t;WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)
        b:SetScript("OnClick",function() active=name;selectedKey=nil;root:Refresh(true) end)
    end
    local function layout()
        local w=math.max(100,parent:GetWidth()-28)
        for i,b in ipairs(tabs) do
            local n=i<=3 and 3 or 2;local col=i<=3 and i-1 or i-4
            local bw=(w-(n-1)*6)/n
            b:ClearAllPoints();b:SetPoint("TOPLEFT",14+col*(bw+6),i<=3 and -14 or -58);b:SetSize(bw,38)
        end
        root:Refresh()
    end
    root:HookScript("OnShow",layout);root:HookScript("OnSizeChanged",layout)
    local event=CreateFrame("Frame",nil,root)
    for _,e in ipairs({"SKILL_LINES_CHANGED","UPDATE_FACTION","CURRENCY_DISPLAY_UPDATE","CRITERIA_UPDATE","PLAYER_ENTERING_WORLD"}) do pcall(event.RegisterEvent,event,e) end
    event:SetScript("OnEvent",function() root:Refresh() end)
    layout();return root
end
