if not WoWUClient.isForever then return end
-- Forever's account-wide trait trees, inspected inside WoWU like Talents.
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,result=pcall(fn,...)
    if ok then return result end
end
local function nonempty(value) return type(value)=="string" and value~="" and value or nil end
local requestedSpellData={}
local function trees()
    if type(LegacyTreeData)=="table" then return LegacyTreeData end
    local c=Constants and Constants.LegacyConsts or {}
    return {
        {treeID=c.LEGACY_TREE_PROFESSIONS_ID,name=LEGACY_TREE_PROFESSIONS or "Professions"},
        {treeID=c.LEGACY_TREE_ADVENTURE_ID,name=LEGACY_TREE_ADVENTURE or "Adventure"},
        {treeID=c.LEGACY_TREE_PROGRESSION_ID,name=LEGACY_TREE_PROGRESSION or "Progression"},
    }
end
function WoWU_GetLegacyTree(index)
    local tree=trees()[index]
    if not tree or not tree.treeID or not C_Traits then return nil,"Legacy trees are unavailable on this client." end
    local config=safe(C_Traits.GetConfigIDByTreeID,tree.treeID)
    if not config or config<=0 then return nil,"Legacy is not unlocked or its data is not ready yet." end
    local ids=safe(C_Traits.GetTreeNodes,tree.treeID)
    if type(ids)~="table" then return nil,"Legacy tree data is not ready yet." end
    local result={name=tree.name,treeID=tree.treeID,configID=config,nodes={}}
    for _,id in ipairs(ids) do
        local info=safe(C_Traits.GetNodeInfo,config,id)
        if info and info.isVisible~=false and type(info.posX)=="number" and type(info.posY)=="number" then
            local node={id=id,x=info.posX,y=info.posY,rank=info.currentRank or 0,maxRank=info.maxRanks or 1,
                available=info.isAvailable~=false,edges=info.visibleEdges or {},entries={}}
            local active=info.activeEntry and info.activeEntry.entryID
            for _,entryID in ipairs(info.entryIDs or {}) do
                local entry=safe(C_Traits.GetEntryInfo,config,entryID)
                local definition=entry and safe(C_Traits.GetDefinitionInfo,entry.definitionID)
                if definition then
                    -- Blizzard's TalentDisplay uses spellID for this entry;
                    -- overriddenSpellID describes a different, replaced spell.
                    local spellID=definition.spellID
                    local spell=spellID and safe(C_Spell and C_Spell.GetSpellInfo,spellID)
                    local spellDescription=spellID and safe(C_Spell and C_Spell.GetSpellDescription,spellID)
                    if spellID and (not spell or not spellDescription) and not requestedSpellData[spellID] then
                        requestedSpellData[spellID]=true
                        safe(C_Spell and C_Spell.RequestLoadSpellData,spellID)
                    end
                    local e={id=entryID,spellID=spellID,name=nonempty(definition.overrideName) or (spell and spell.name) or "Legacy buff",
                        icon=definition.overrideIcon or (spell and spell.iconID) or 134400,
                        description=nonempty(definition.overrideDescription) or nonempty(spellDescription) or "Description unavailable.",
                        active=entryID==active}
                    node.entries[#node.entries+1]=e
                    if not node.entry or e.active then node.entry=e end
                end
            end
            if node.entry then result.nodes[#result.nodes+1]=node end
        end
    end
    local currency=safe(C_Traits.GetTreeCurrencyInfo,config,tree.treeID,false)
    result.currency=type(currency)=="table" and currency[1] or nil
    result.pending=safe(C_Traits.ConfigHasStagedChanges,config)==true
    return result
end

local function label(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(f,.95,.82,.55);f:SetJustifyH("LEFT")
    return f
end
local function box(kind,parent,w,h)
    local f=CreateFrame(kind,nil,parent,"BackdropTemplate")
    if w and h then f:SetSize(w,h) end
    WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Color(f,.09,.12,.14,.98);WoWU_Theme.Border(f,.74,.65,.47,1)
    if kind=="Frame" then WoWU_Theme.Panel(f) end
    return f
end
local function button(parent,caption,w,h)
    local b=box("Button",parent,w,h);b.label=label(b,16);b.label:SetPoint("CENTER");b.label:SetText(caption);WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);return b
end
function WoWU_CreateLegacy(parent,onBack)
    local panel=CreateFrame("Frame",nil,parent);panel:SetAllPoints(parent);panel:Hide()
    local title=label(panel,23);title:SetPoint("TOPLEFT",18,-15);title:SetText("Legacy")
    local status=label(panel,14);status:SetPoint("TOPLEFT",18,-110);status:SetWidth(1180)
    local view=box("Frame",panel);view:SetPoint("TOPLEFT",12,-142);view:SetPoint("BOTTOMRIGHT",-370,16)
    local art=view:CreateTexture(nil,"BACKGROUND");art:SetPoint("TOPLEFT",5,-5);art:SetPoint("BOTTOMRIGHT",-5,5);art:SetTexture(WoWU_Theme.assets.marble);art:SetAlpha(.5)
    local scroll=CreateFrame("ScrollFrame",nil,view,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",8,-8);scroll:SetPoint("BOTTOMRIGHT",-29,38)
    local canvas=CreateFrame("Frame",nil,scroll);canvas:SetSize(800,530);scroll:SetScrollChild(canvas)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    local sideways=CreateFrame("Slider",nil,view,"BackdropTemplate")
    sideways:SetPoint("BOTTOMLEFT",20,14);sideways:SetPoint("BOTTOMRIGHT",-33,14);sideways:SetHeight(18)
    sideways:SetOrientation("HORIZONTAL");sideways:SetMinMaxValues(0,0);sideways:SetValueStep(1)
    if sideways.SetObeyStepOnDrag then sideways:SetObeyStepOnDrag(true) end
    WoWU_Theme.Backdrop(sideways,{bgFile="Interface\\Buttons\\WHITE8X8"});WoWU_Theme.Color(sideways,.23,.26,.25,.8)
    sideways:SetThumbTexture(WoWU_Theme.assets.thumb)
    sideways:GetThumbTexture():SetSize(28,28)
    sideways:SetScript("OnValueChanged",function(_,value) scroll:SetHorizontalScroll(value) end)
    local detail=box("Frame",panel,338,1);detail:SetPoint("TOPRIGHT",-16,-142);detail:SetPoint("BOTTOMRIGHT",-16,16)
    local heading=label(detail,19);heading:SetPoint("TOPLEFT",16,-16);heading:SetText("Account-wide buff")
    local detailScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT",16,-52);detailScroll:SetPoint("BOTTOMRIGHT",-29,114)
    local detailBody=CreateFrame("Frame",nil,detailScroll);detailBody:SetSize(290,530);detailScroll:SetScrollChild(detailBody)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(detailScroll) end
    local description=label(detailBody,16);description:SetPoint("TOPLEFT");description:SetWidth(290);description:SetWordWrap(true)
    local active,selected,dirty=1,nil,true
    local selectedEntry,currentData,refresh
    local spend=button(detail,"Spend 1 point",300,34);spend:SetPoint("BOTTOM",0,65)
    local apply=button(detail,"Apply changes",148,34);apply:SetPoint("BOTTOMLEFT",13,20)
    local undo=button(detail,"Undo pending",148,34);undo:SetPoint("BOTTOMRIGHT",-13,20)
    local choice=button(panel,"Next choice",160,34);choice:SetPoint("TOPRIGHT",-18,-60);choice:Hide()
    local function editable()return currentData and not (InCombatLockdown and InCombatLockdown()) and not UnitIsDeadOrGhost("player")end

    local nodes,lines,tabs={},{},{}
    local function describe(node,reset)
        local parts={"Select a buff to see its ranks and description.\n\nChoose a buff, spend points, then Apply changes. Undo pending discards all unapplied changes in this Legacy build."}
        if node then
            parts={"Rank "..node.rank.." / "..node.maxRank}
            if not node.available then parts[#parts+1]="Requirements not met" end
            for _,e in ipairs(node.entries) do
                parts[#parts+1]=e.name..((#node.entries>1 and e.active) and " (selected)" or "").."\n"..e.description
            end
        end
        heading:SetText(node and node.entry.name or "Account-wide buff")
        heading:SetWidth(300)
        if node then selectedEntry=selectedEntry or node.entry.id end
        spend:SetEnabled(node~=nil and editable() and safe(C_Traits.CanPurchaseRank,currentData.configID,node.id,selectedEntry)==true)
        choice:SetShown(node~=nil and #node.entries>1)
        apply:SetEnabled(editable() and currentData.pending==true)
        undo:SetEnabled(editable() and currentData.pending==true)
        description:SetText(table.concat(parts,"\n\n"));detailBody:SetHeight(math.max(530,description:GetStringHeight()+20))
        if reset then detailScroll:SetVerticalScroll(0) end
    end
    refresh=function(reset)
        dirty=false
        for _,b in ipairs(nodes) do b:Hide() end
        for _,line in ipairs(lines) do line:Hide() end
        for i,b in ipairs(tabs) do WoWU_Theme.Color(b,i==active and .35 or .09,i==active and .27 or .12,i==active and .17 or .14,1) end
        local data,message=WoWU_GetLegacyTree(active)
        currentData=data
        if not data or #data.nodes==0 then
            status:SetText(message or "No Legacy buffs are available yet.");describe(nil,true)
            canvas:SetSize(math.max(1,scroll:GetWidth()),math.max(1,scroll:GetHeight()));sideways:Hide();scroll:SetHorizontalScroll(0);return
        end
        local c=data.currency
        status:SetText(data.name.."  |  "..(c and (tostring(c.quantity).." points available | "..tostring(c.spentInTree or 0).." spent here") or "Account-wide buffs")..(data.pending and "  |  Changes pending - Apply when ready" or ""))
        local xs,ys,seenX,seenY={},{},{},{}
        for _,n in ipairs(data.nodes) do
            if not seenX[n.x] then xs[#xs+1]=n.x;seenX[n.x]=true end
            if not seenY[n.y] then ys[#ys+1]=n.y;seenY[n.y]=true end
        end
        table.sort(xs);table.sort(ys)
        for i,v in ipairs(xs) do seenX[v]=i end
        for i,v in ipairs(ys) do seenY[v]=i end
        local width=math.max(scroll:GetWidth(),(#xs-1)*132+140)
        local height=math.max(scroll:GetHeight(),(#ys-1)*120+140)
        canvas:SetSize(width,height)
        local maxX=math.max(0,width-scroll:GetWidth())
        sideways:SetMinMaxValues(0,maxX);sideways:SetShown(maxX>0)
        sideways:SetValue(reset and 0 or math.min(scroll:GetHorizontalScroll(),maxX))
        scroll:SetVerticalScroll(reset and 0 or math.min(scroll:GetVerticalScroll(),math.max(0,height-scroll:GetHeight())))
        local byID,chosen={},nil
        for i,node in ipairs(data.nodes) do
            local b=nodes[i]
            if not b then
                b=box("Button",canvas,56,56)
                b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("TOPLEFT",5,-5);b.icon:SetPoint("BOTTOMRIGHT",-5,5)
                b.rank=label(b,13);b.rank:SetPoint("BOTTOM",0,-3)
                b.name=label(b,11);b.name:SetPoint("TOP",b,"BOTTOM",0,-5);b.name:SetWidth(124);b.name:SetHeight(40);b.name:SetWordWrap(true);b.name:SetJustifyH("CENTER");b.name:SetJustifyV("TOP")
                b:SetScript("OnClick",function(self)
                    if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end
                    selected=self.node.id;selectedEntry=nil;describe(self.node,true)
                end)
                b:SetScript("OnEnter",function(self)
                    if self.node and self.node.entry.spellID then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetSpellByID(self.node.entry.spellID);GameTooltip:Show()end
                end)
                b:SetScript("OnLeave",function()GameTooltip:Hide()end);WoWUDetails.BindHover(b,true)
                nodes[i]=b
            end
            node.px=#xs==1 and width/2 or 50+(seenX[node.x]-1)*(width-100)/(#xs-1)
            node.py=45+(seenY[node.y]-1)*120
            b:ClearAllPoints();b:SetPoint("CENTER",canvas,"TOPLEFT",node.px,-node.py)
            local canSpend=safe(C_Traits.CanPurchaseRank,data.configID,node.id,node.entry.id)==true
            b.node=node;b.icon:SetTexture(node.entry.icon);b.icon:SetDesaturated(node.rank==0 and not canSpend)
            b.rank:SetText(node.rank.."/"..node.maxRank);b.name:SetText(node.entry.name)
            WoWU_Theme.Border(b,(node.rank>0 or canSpend) and .3 or .58,(node.rank>0 or canSpend) and .9 or .43,.26,1);b:Show()
            byID[node.id]=node;if node.id==selected then chosen=node end
        end
        local used=0
        if canvas.CreateLine then
            for _,node in ipairs(data.nodes) do
                for _,edge in ipairs(node.edges) do
                    local target=byID[edge.targetNode]
                    if target then
                        used=used+1;local line=lines[used]
                        if not line then line=canvas:CreateLine(nil,"ARTWORK");line:SetThickness(2);lines[used]=line end
                        line:SetStartPoint("TOPLEFT",canvas,node.px,-node.py);line:SetEndPoint("TOPLEFT",canvas,target.px,-target.py)
                        line:SetColorTexture(edge.isActive and .8 or .35,edge.isActive and .65 or .32,.22,1);line:Show()
                    end
                end
            end
        end
        describe(chosen,reset)
    end
    for i,tree in ipairs(trees()) do
        local index=i;local b=button(panel,tree.name,240,38);b:SetPoint("TOPLEFT",18+(i-1)*248,-60)
        b:SetScript("OnClick",function() active=index;selected=nil;selectedEntry=nil;refresh(true) end);tabs[i]=b
    end
    choice:SetScript("OnClick",function()
        if not currentData then return end
        for _,node in ipairs(currentData.nodes)do if node.id==selected then
            local idx=1;for i,e in ipairs(node.entries)do if e.id==selectedEntry then idx=i%#node.entries+1;break end end
            selectedEntry=node.entries[idx].id;node.entry=node.entries[idx];describe(node,true);return
        end end
    end)
    spend:SetScript("OnClick",function()
        if not editable() or not selected or not selectedEntry then return end
        local config=currentData.configID
        if not safe(C_Traits.CanPurchaseRank,config,selected,selectedEntry)then status:SetText("This buff's requirements are not met.");return end
        local node=safe(C_Traits.GetNodeInfo,config,selected)
        if node and #node.entryIDs>1 and (not node.activeEntry or node.activeEntry.entryID~=selectedEntry)then
            if not safe(C_Traits.SetSelection,config,selected,selectedEntry)then status:SetText("The game could not select this buff.");return end
            local after=safe(C_Traits.GetNodeInfo,config,selected)
            if after and after.currentRank>node.currentRank then refresh(false);return end
        end
        local ok=safe(C_Traits.PurchaseRank,config,selected);refresh(false)
        if not ok then status:SetText("The game could not allocate a point. Check requirements.")end
    end)
    apply:SetScript("OnClick",function()
        if not editable()then return end
        local ok=safe(C_Traits.CommitConfig,currentData.configID);refresh(false)
        status:SetText(ok and "Legacy changes submitted." or "The game could not apply changes. Pending choices remain.")
    end)
    undo:SetScript("OnClick",function()if editable()then safe(C_Traits.RollbackConfig,currentData.configID);refresh(false)end end)
    local events=CreateFrame("Frame",nil,panel)
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","TRAIT_CONFIG_CREATED","TRAIT_CONFIG_LIST_UPDATED","TRAIT_CONFIG_UPDATED","TRAIT_NODE_CHANGED","TRAIT_NODE_ENTRY_UPDATED","TRAIT_TREE_CURRENCY_INFO_UPDATED","SPELL_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","TRAIT_CONFIG_COMMIT_FAILED"}) do pcall(events.RegisterEvent,events,event) end
    events:SetScript("OnEvent",function(_,event) dirty=true;if event=="TRAIT_CONFIG_COMMIT_FAILED" then status:SetText("The game could not apply these Legacy changes.")end end)
    panel:HookScript("OnShow",function() refresh(false) end)
    panel:HookScript("OnUpdate",function() if dirty then refresh(false) end end)
    scroll:HookScript("OnSizeChanged",function() dirty=true end)
    describe(nil,true)
    return panel
end
