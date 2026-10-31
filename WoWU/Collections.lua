-- Independent collection browser. Never reparents or calls the native journal UI.
local function call(fn,...)
    if type(fn)~="function" then return end
    local function packed(...) return {n=select("#",...),...} end
    local result=packed(pcall(fn,...))
    if result[1] then return unpack(result,2,result.n) end
end
local function label(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetFont("Fonts\\FRIZQT__.TTF",size or 15,"")
    WoWU_Theme.TextColor(f,1,.82,.4);f:SetJustifyH("LEFT");return f
end
local function atlas(tex,name)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then tex:SetAtlas(name);return true end
end
local function panel(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    WoWU_Theme.Panel(f)
    return f
end
local function button(parent,title,w)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(w or 140,32);b:SetText(title);return b
end
function WoWU_CreateCollections(parent)
    local availableKinds={"Appearances","Mounts","Companions","Toys"}
    if WoWUClient.isClassic then
        if (WoWUClient.classicMajor or 0)<3 and WoWUClassicModules then return WoWUClassicModules.InventoryCollections(parent)end
        availableKinds={}
        if C_MountJournal and C_MountJournal.GetMountIDs then availableKinds[#availableKinds+1]='Mounts'end
        if C_PetJournal and C_PetJournal.GetNumPets then availableKinds[#availableKinds+1]='Companions'end
        if #availableKinds==0 and WoWUClassicModules then return WoWUClassicModules.InventoryCollections(parent)end
    end
    local root=CreateFrame("Frame",nil,parent);root:SetPoint("TOPLEFT",12,-12);root:SetPoint("BOTTOMRIGHT",-12,12);root:Hide()
    local kind=availableKinds[1];local category=1;local page=1;local filter=1
    local rows,cards,entries,categories={},{},{},{}
    local selected,refresh,render,inspect
    local catalogs,currentCatalog={},nil
    local itemEntries,requestedItems={},{}
    local metadataDirty,searchDeadline,previewKey
    local categoryNames,categorySlots={},{}
    local title=label(root,22);title:SetPoint("TOP",0,-16);title:SetText("Collections")
    local tabs={}
    for i,name in ipairs(availableKinds) do
        local b=button(root,name,155);b:SetPoint("TOPLEFT",22+(i-1)*160,-47);tabs[name]=b
        b:SetScript("OnClick",function()if InCombatLockdown()then return end;kind=name;selected=nil;page=1;refresh()end)
    end
    local search=CreateFrame("EditBox",nil,root,"InputBoxTemplate")
    search:SetSize(220,28);search:SetPoint("TOPRIGHT",-195,-48);search:SetAutoFocus(false)
    local searchHint=label(search,13);searchHint:SetPoint("LEFT",5,0);searchHint:SetText("Search collections");searchHint:SetTextColor(.6,.6,.6)
    search:SetScript("OnEditFocusGained",function()searchHint:Hide()end)
    search:SetScript("OnEditFocusLost",function()searchHint:SetShown(search:GetText()=="")end)
    search:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    local filterButton=button(root,"All",155);filterButton:SetPoint("TOPRIGHT",-24,-47)
    local catButton=button(root,"Head",230);catButton:SetPoint("TOPLEFT",22,-88)
    local categoryMenu=panel(root);categoryMenu:SetFrameLevel(root:GetFrameLevel()+30)
    categoryMenu:SetPoint("TOPLEFT",catButton,"BOTTOMLEFT",0,-2);categoryMenu:Hide()
    local categoryChoices={}
    local count=label(root,14);count:SetPoint("LEFT",catButton,"RIGHT",20,0)
    local left=panel(root);left:SetPoint("TOPLEFT",16,-129);left:SetPoint("BOTTOMRIGHT",root,"BOTTOMLEFT",430,58)
    local right=panel(root);right:SetPoint("TOPLEFT",left,"TOPRIGHT",8,0);right:SetPoint("BOTTOMRIGHT",-16,58)
    local scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",12,-12);scroll:SetPoint("BOTTOMRIGHT",-30,12)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(350,1);scroll:SetScrollChild(body)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    local nameText=label(right,20);nameText:SetPoint("TOPLEFT",20,-18);nameText:SetPoint("TOPRIGHT",-20,-18)
    local model=CreateFrame("PlayerModel",nil,right);model:SetPoint("TOPLEFT",16,-48);model:SetPoint("BOTTOMRIGHT",-16,124)
    local creatureZoom=1.9
    local function frameCreature(self)self:SetPortraitZoom(0);self:SetCamDistanceScale(creatureZoom);self:SetPosition(0,0,0)end
    model:SetScript("OnModelLoaded",frameCreature)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseWheel",function(self,delta)creatureZoom=math.max(.7,math.min(4,creatureZoom-delta*.15));frameCreature(self)end)
    local zoomOut=button(right,"-",32);zoomOut:SetPoint("TOPRIGHT",-20,-48)
    local zoomIn=button(right,"+",32);zoomIn:SetPoint("RIGHT",zoomOut,"LEFT",-4,0)

    local dress=CreateFrame("DressUpModel",nil,right);dress:SetAllPoints(model);dress:Hide()
    local appearanceZoom=1.45
    local function frameDress(self)self:SetPortraitZoom(0);self:SetCamDistanceScale(appearanceZoom);self:SetPosition(0,0,0)end
    dress:SetScript("OnModelLoaded",frameDress)
    local function zoomPreview(delta)
        if kind=="Appearances"then appearanceZoom=math.max(.65,math.min(3.5,appearanceZoom+delta));frameDress(dress)
        else creatureZoom=math.max(.7,math.min(4,creatureZoom+delta));frameCreature(model)end
    end
    dress:EnableMouseWheel(true);dress:SetScript("OnMouseWheel",function(_,delta)zoomPreview(-delta*.15)end)
    zoomOut:SetScript("OnClick",function()zoomPreview(.2)end)
    zoomIn:SetScript("OnClick",function()zoomPreview(-.2)end)
    zoomOut:SetFrameLevel(dress:GetFrameLevel()+5);zoomIn:SetFrameLevel(dress:GetFrameLevel()+5)
    for _,m in ipairs({model,dress}) do
        m:EnableMouse(true);m:SetScript("OnMouseDown",function(self)self.dragX=GetCursorPosition()end)
        m:SetScript("OnMouseUp",function(self)self.dragX=nil end)
        m:SetScript("OnUpdate",function(self)
            if not self.dragX then return end
            if not IsMouseButtonDown("LeftButton") then self.dragX=nil;return end
            local x=GetCursorPosition();self:SetFacing(self:GetFacing()+(x-self.dragX)*.012);self.dragX=x
        end)
        m:SetScript("OnHide",function(self)self.dragX=nil end)
    end
    local description=label(right,14);WoWU_Theme.TextColor(description,.9,.85,.73)
    description:SetPoint("BOTTOMLEFT",20,57);description:SetPoint("BOTTOMRIGHT",-20,57);description:SetHeight(98);description:SetJustifyV("TOP")
    local action=button(right,"Summon",160);action:SetPoint("BOTTOM",0,16)
    local mountPad=button(right,"+ Pad",135);mountPad:SetPoint("BOTTOMLEFT",16,54);mountPad:Hide()
    local mountDashboard=button(right,"+ Dashboard",155);mountDashboard:SetPoint("BOTTOMRIGHT",-16,54);mountDashboard:Hide()
    local toyIcon=CreateFrame("Frame",nil,right,"BackdropTemplate");toyIcon:SetSize(160,160);toyIcon:SetPoint("TOP",0,-60);toyIcon:Hide()
    WoWU_Theme.Backdrop(toyIcon,{edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=14,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Border(toyIcon,.65,.55,.3,1)
    toyIcon.texture=toyIcon:CreateTexture(nil,"ARTWORK");toyIcon.texture:SetPoint("TOPLEFT",6,-6);toyIcon.texture:SetPoint("BOTTOMRIGHT",-6,6)
    local toyScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    toyScroll:SetPoint("TOPLEFT",24,-239);toyScroll:SetPoint("BOTTOMRIGHT",-34,62);toyScroll:Hide()
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(toyScroll)end
    local toyContent=CreateFrame("Frame",nil,toyScroll);toyContent:SetSize(360,1);toyScroll:SetScrollChild(toyContent)
    local toyTip=CreateFrame("GameTooltip","WoWU_CollectionToyTooltip",toyContent,"GameTooltipTemplate")
    toyTip:SetOwner(toyContent,"ANCHOR_NONE");toyTip:SetClampedToScreen(false);toyTip:SetPoint("TOPLEFT");toyTip:Hide()
    local sizingToy=false
    local function sizeToyTip()
        if sizingToy then return end;sizingToy=true
        local width=math.max(1,toyScroll:GetWidth()-4)
        toyContent:SetWidth(width)
        local scale=math.min(1.3,width/math.max(1,toyTip:GetWidth()))
        toyTip:SetScale(math.max(.6,scale))
        local height=toyTip:GetHeight()*toyTip:GetScale()
        toyContent:SetHeight(math.max(toyScroll:GetHeight(),height+20))
        toyTip:ClearAllPoints()
        toyTip:SetPoint("TOP",toyContent,"TOP",0,-math.max(10,(toyScroll:GetHeight()-height)/2)/toyTip:GetScale())
        sizingToy=false
    end
    toyTip:HookScript("OnSizeChanged",sizeToyTip)
    toyScroll:HookScript("OnSizeChanged",sizeToyTip)
    -- An independent secure button avoids protecting the browser's frame tree.
    local toyAction=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate,SecureActionButtonTemplate,SecureHandlerStateTemplate")
    toyAction:SetSize(160,32);toyAction:SetText("Use Toy");toyAction:RegisterForClicks("AnyDown","AnyUp");toyAction:SetAttribute("useOnKeyDown",false)
    toyAction:SetAttribute("type","toy");toyAction:SetFrameStrata("DIALOG");toyAction:Hide()
    toyAction:SetAttribute("_onstate-combat",[[if newstate=="combat"then self:Hide()end]])
    RegisterStateDriver(toyAction,"combat","[combat] combat; peace")
    local function toyEligible()
        return root:IsVisible()and kind=="Toys"and selected and selected.owned
    end
    toyAction:SetScript("OnUpdate",function(self)
        if not InCombatLockdown()and not toyEligible()then self:Hide();self:SetAttribute("toy",nil)end
    end)
    toyAction:SetScript("PreClick",function(self)
        if not InCombatLockdown()and not toyEligible()then self:SetAttribute("toy",nil);self:Hide()end
    end)
    local footer=label(root,13);footer:SetPoint("BOTTOMLEFT",24,22);footer:SetWidth(750)
    local previous=button(root,"Previous",100);previous:SetPoint("BOTTOMRIGHT",-205,16)
    local nextPage=button(root,"Next",100);nextPage:SetPoint("BOTTOMRIGHT",-24,16)
    local pageText=label(root,13);pageText:SetPoint("RIGHT",nextPage,"LEFT",-12,0)
    local function inCombat()return InCombatLockdown and InCombatLockdown()end
    local function mountShortcutIndex(e)
        local key=UnitGUID("player")or ((UnitName("player")or "player").."-"..GetRealmName())
        local list=WoWUDashboardLayout and WoWUDashboardLayout.Shortcuts(key)
        for i,s in ipairs(list or {})do if s.kind=="spell"and s.id==e.spell then return list,i end end
    end
    local function updateMountButtons()
        local eligible=kind=="Mounts"and selected and selected.owned and selected.spell
        mountDashboard:SetShown(not not eligible)
        mountPad:SetShown(not not eligible and WoWUController and WoWUController.active or false)
        if eligible then local _,index=mountShortcutIndex(selected);mountDashboard:SetText(index and "- Dashboard"or "+ Dashboard")end
    end
    mountPad:SetScript("OnClick",function()
        if not selected or kind~="Mounts"or not selected.owned then return end
        local ok,msg=WoWUController.BeginAssignment("spell",selected.spell,selected.name,selected.icon,function(message)footer:SetText(message)end)
        if not ok then footer:SetText(msg)end
    end)
    mountDashboard:SetScript("OnClick",function()
        if not selected or kind~="Mounts"or not selected.owned then return end
        local list,index=mountShortcutIndex(selected)
        if index then table.remove(list,index);if WoWU_RefreshDashboard then WoWU_RefreshDashboard()end;footer:SetText("Removed from Dashboard.")
        else local ok=WoWU_AddShortcut("spell",selected.spell,selected.name,selected.icon,{mountID=selected.id});footer:SetText(ok and "Added to Dashboard."or "Dashboard is full. Change its limit in Settings.")end
        updateMountButtons()
    end)
    if WoWUController then WoWUController.AddModeListener(updateMountButtons)end
    local function matches(e)
        if filter==2 and not e.owned then return false end
        if filter==3 and e.owned then return false end
        local q=string.lower(search:GetText() or "")
        return q=="" or string.find(string.lower(e.name or ""),q,1,true) or string.find(tostring(e.id),q,1,true)
    end
    local function filterCatalog()
        entries={};local owned=0;local data=currentCatalog and currentCatalog.data or {}
        for _,e in ipairs(data)do if e.owned then owned=owned+1 end;if matches(e)then entries[#entries+1]=e end end
        table.sort(entries,function(a,b)
            if a.owned~=b.owned then return not not a.owned end
            if currentCatalog.appearance then
                if a.order~=b.order then return a.order<b.order end
                return a.id<b.id
            end
            return a.name<b.name
        end)
        count:SetText(owned.." / "..#data.." collected   -   "..#entries.." shown")
    end
    local function fillItemName(e)
        if not e.itemID then return end
        local name=call(C_Item and C_Item.GetItemNameByID,e.itemID)or call(C_Item and C_Item.GetItemInfo or GetItemInfo,e.itemID)
        if name then e.name=name;e.namePending=nil end
        e.icon=e.icon or call(C_Item and C_Item.GetItemIconByID or GetItemIcon,e.itemID)
    end
    local function resolveAppearance(e)
        if e.resolved then return end
        e.resolved=true
        local api=C_TransmogCollection or {}
        local sources=call(api.GetAppearanceSources,e.id,e.category,e.location)or {}
        local source=sources[1]
        for _,s in ipairs(sources)do if s.isCollected then source=s;break end end
        if not source then return end
        local info=call(api.GetSourceInfo,source.sourceID)or source
        e.sourceID=source.sourceID;e.itemID=info.itemID;e.icon=info.icon
        e.link=info.itemLink or (e.itemID and "item:"..e.itemID)
        e.name=info.name or e.name;e.namePending=not info.name
        if e.itemID then
            itemEntries[e.itemID]=itemEntries[e.itemID]or setmetatable({},{__mode="k"});itemEntries[e.itemID][e]=true
            fillItemName(e)
            if e.namePending and not requestedItems[e.itemID]then
                requestedItems[e.itemID]=true;call(C_Item and C_Item.RequestLoadItemDataByID,e.itemID)
            end
        end
    end
    local function build()
        local cacheKey=kind..":"..(kind=="Appearances"and category or 0)
        if catalogs[cacheKey]then currentCatalog=catalogs[cacheKey];filterCatalog();return end
        local data={}
        if kind=="Mounts" then
            local api=C_MountJournal or {}
            for _,id in ipairs(call(api.GetMountIDs) or {}) do
                local n,spell,icon,active,usable,source,fav,factionSpecific,faction,hidden,owned=call(api.GetMountInfoByID,id)
                if n and not hidden then
                    local display,desc,sourceText=call(api.GetMountInfoExtraByID,id)
                    data[#data+1]={id=id,name=n,spell=spell,icon=icon,owned=owned,display=display,description=desc,source=sourceText,active=active,usable=usable}
                end
            end
        elseif kind=="Companions" then
            local api=C_PetJournal or {}
            for i=1,(call(api.GetNumPets) or 0) do
                local id,species,owned,custom,level,fav,revoked,n,icon=call(api.GetPetInfoByIndex,i)
                if n then
                    local _,_,_,creature,source,desc,_,_,_,_,_,display=call(api.GetPetInfoBySpeciesID,species)
                    data[#data+1]={id=id or species,species=species,petID=id,name=custom or n,icon=icon,owned=owned,display=display,creature=creature,description=desc,source=source}
                end
            end
        elseif kind=="Toys"then
            local api=C_ToyBox or {}
            for i=1,(call(api.GetNumFilteredToys)or 0)do
                local id=call(api.GetToyFromIndex,i)
                if id then
                    local _,n,icon=call(api.GetToyInfo,id)
                    data[#data+1]={id=id,itemID=id,name=n or ("Toy "..id),icon=icon,owned=call(PlayerHasToy,id)==true,description=""}
                end
            end
        else
            local api=C_TransmogCollection or {}
            local location=call(TransmogUtil and TransmogUtil.GetTransmogLocation,categorySlots[category] or "MAINHANDSLOT",Enum and Enum.TransmogType and Enum.TransmogType.Appearance or 0,false)
            local locationData=location and location:GetData()
            for _,v in ipairs(call(api.GetCategoryAppearances,category,locationData) or {}) do
                data[#data+1]={id=v.visualID,order=v.uiOrder or v.visualID,name="Appearance "..v.visualID,owned=v.isCollected,category=category,location=locationData,description="Select an appearance to preview it on your character."}
            end
        end
        currentCatalog={data=data,appearance=kind=="Appearances"};catalogs[cacheKey]=currentCatalog;filterCatalog()
    end
    inspect=function(e)
        if inCombat()then return end
        if not root:IsVisible()then toyAction:Hide();return end
        local canZoom=kind=="Appearances"or kind=="Mounts"or kind=="Companions"
        zoomOut:SetShown(canZoom);zoomIn:SetShown(canZoom)
        nameText:SetJustifyH(kind=="Toys"and "CENTER"or "LEFT")
        selected=e;nameText:SetText(e and e.name or "Select a collectible")
        description:SetShown(kind~="Toys")
        if kind~="Toys"or not e then toyScroll:Hide();toyTip:Hide()end
        updateMountButtons()
        local key=kind..":"..tostring(e and e.id)..":"..tostring(e and e.sourceID)
        if kind=="Toys"and e and e.owned and root:IsVisible()then
            toyAction:SetAttribute("toy",e.id);toyAction:SetEnabled(not not e.owned)
            toyAction:SetScale(action:GetEffectiveScale()/UIParent:GetEffectiveScale())
            local x,y=action:GetCenter();if x and y then toyAction:ClearAllPoints();toyAction:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y);toyAction:Show()end
        else toyAction:Hide()end
        if e then description:SetText((e.owned and "|cff40ff40Collected|r"or "|cffaaaaaaNot collected|r").."\n"..(e.description or "").."\n"..(e.source or ""))end
        if e and kind=="Appearances"then description:SetText((e.owned and "|cff40ff40Collected|r"or "|cffaaaaaaNot collected|r").."\nPreview only. Visit a transmogrifier to apply appearances.")end
        if e and (kind=="Mounts"or kind=="Companions")then
            local active
            if kind=="Mounts"then local _,_,_,value=call(C_MountJournal and C_MountJournal.GetMountInfoByID,e.id);active=value
            else active=call(C_PetJournal and C_PetJournal.IsCurrentlySummoned,e.petID)end
            action:SetEnabled(not not e.owned);action:SetText(active and "Dismiss"or "Summon")
        end
        if key==previewKey then return end
        previewKey=key
        model:ClearModel();dress:ClearModel();model:Hide();dress:Hide();action:Hide();toyIcon:Hide()
        if not e then description:SetText("");return end
        description:SetText((e.owned and "|cff40ff40Collected|r" or "|cffaaaaaaNot collected|r").."\n"..(e.description or "").."\n"..(e.source or ""))
        if kind=="Appearances" then
            dress:ClearAllPoints();dress:SetPoint("TOPLEFT",right,"TOPLEFT",16,-48);dress:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-16,94)
            description:ClearAllPoints();description:SetPoint("BOTTOMLEFT",20,18);description:SetPoint("BOTTOMRIGHT",-20,18);description:SetHeight(66)
            if e.sourceID then dress:Show();dress:SetUnit("player");call(dress.TryOn,dress,e.sourceID);frameDress(dress);dress:SetFacing(.4)end
            description:SetText((e.owned and "|cff40ff40Collected|r" or "|cffaaaaaaNot collected|r").."\nPreview only. Visit a transmogrifier to apply appearances.")
        elseif kind=="Toys"then
            toyIcon.texture:SetTexture(e.icon or 134400);toyIcon:Show()
            toyScroll:Show();toyTip:SetOwner(toyContent,"ANCHOR_NONE");toyTip:SetClampedToScreen(false);toyTip:ClearAllPoints();toyTip:SetPoint("TOPLEFT",toyContent,"TOPLEFT")
            local ok,result=false,nil
            if toyTip.SetToyByItemID then ok,result=pcall(toyTip.SetToyByItemID,toyTip,e.id)end
            if not ok or result==false then pcall(toyTip.SetHyperlink,toyTip,"item:"..e.id)end
            toyTip:Show();sizeToyTip();toyScroll:SetVerticalScroll(0)
        else
            local bottom=kind=="Mounts"and 100 or 57
            description:ClearAllPoints();description:SetPoint("BOTTOMLEFT",20,bottom);description:SetPoint("BOTTOMRIGHT",-20,bottom);description:SetHeight(60)
            model:ClearAllPoints();model:SetPoint("TOPLEFT",right,"TOPLEFT",16,-48);model:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-16,kind=="Mounts"and 170 or 124)
            model:Show()
            if e.display then call(model.SetDisplayInfo,model,e.display) elseif e.creature then call(model.SetCreature,model,e.creature) end
            frameCreature(model);model:SetFacing(.4);action:Show();action:SetEnabled(not not e.owned)
            local active=kind=="Mounts" and e.active or (kind=="Companions" and call(C_PetJournal.IsCurrentlySummoned,e.petID))
            action:SetText(active and "Dismiss" or "Summon")
        end
    end
    action:SetScript("OnClick",function()
        if not selected or not selected.owned then return end
        if InCombatLockdown() then footer:SetText("Summon or dismiss after combat.");return end
        local ok,err
        if kind=="Mounts" then
            local active=select(4,C_MountJournal.GetMountInfoByID(selected.id))
            ok,err=pcall(active and C_MountJournal.Dismiss or C_MountJournal.SummonByID,selected.id)
        elseif kind=="Companions" and selected.petID then
            local active=call(C_PetJournal.IsCurrentlySummoned,selected.petID)
            ok,err=pcall(active and C_PetJournal.DismissSummonedPet or C_PetJournal.SummonPetByGUID,selected.petID)
        end
        footer:SetText(ok and "" or ("Action unavailable: "..tostring(err or "not summonable")))
    end)
    render=function()
        if inCombat()then root.deferred=true;return end
        for _,b in ipairs(rows) do b:Hide() end
        for _,b in ipairs(cards) do b:Hide() end
        local appearance=kind=="Appearances"
        left:ClearAllPoints();left:SetPoint("TOPLEFT",16,-129);left:SetPoint("BOTTOMLEFT",16,58)
        left:SetWidth(math.max(300,root:GetWidth()*(appearance and .61 or .37)))
        scroll:SetShown(not appearance)
        local perPage=appearance and 12 or 60
        local pages=math.max(1,math.ceil(#entries/perPage));page=math.max(1,math.min(page,pages))
        previous:SetEnabled(page>1);nextPage:SetEnabled(page<pages);pageText:SetText(page.." / "..pages)
        local w=left:GetWidth();body:SetWidth(w-46)
        for i=1,math.min(perPage,#entries-(page-1)*perPage) do
            local e=entries[(page-1)*perPage+i]
            if appearance then
                local b=cards[i]
                if not b then
                    b=CreateFrame("Button",nil,left);cards[i]=b
                    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(54,54);b.icon:SetPoint("CENTER",0,9)
                    b.border=b:CreateTexture(nil,"OVERLAY");b.border:SetAllPoints()
                    b.name=label(b,11);b.name:SetPoint("BOTTOMLEFT",5,7);b.name:SetPoint("BOTTOMRIGHT",-5,7);b.name:SetHeight(23)
                    b:SetScript("OnClick",function(self)inspect(self.entry)end)
                    b:SetScript("OnEnter",function(self)if kind~="Appearances"and self.entry.link then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.entry.link);GameTooltip:Show() end end)
                    b:SetScript("OnLeave",function()GameTooltip:Hide()end);WoWUDetails.BindHover(b,function()return kind=="Toys"or kind=="Appearances"end)
                end
                local cw=(w-30)/4;local ch=(left:GetHeight()-30)/3
                b:ClearAllPoints();b:SetPoint("TOPLEFT",12+((i-1)%4)*cw,-12-math.floor((i-1)/4)*ch);b:SetSize(cw-5,ch-5)
                b.entry=e;b.name:SetText(e.name);b.icon:SetTexture(e.icon or 134400);b.icon:SetDesaturated(not e.owned);b:Show()
                b.border:SetDesaturated(WoWU_Theme.silver or false)
                atlas(b.border,e.owned and "transmog-wardrobe-border-collected" or "transmog-wardrobe-border-uncollected")
            else
                local b=rows[i]
                if not b then
                    b=CreateFrame("Button",nil,body);rows[i]=b;b:SetHeight(53)
                    b.bg=b:CreateTexture(nil,"BACKGROUND");b.bg:SetAllPoints();b.bg:SetColorTexture(.1,.065,.035,WoWU_Theme.light and .08 or .8)
                    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
                    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(40,40);b.icon:SetPoint("LEFT",6,0)
                    b.name=label(b,14);b.name:SetPoint("LEFT",b.icon,"RIGHT",10,0);b.name:SetPoint("RIGHT",-6,0)
                    b:SetScript("OnClick",function(self)if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end;inspect(self.entry)end)
                end
                b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(i-1)*55);b:SetPoint("TOPRIGHT",0,-(i-1)*55);b.entry=e
                b.icon:SetTexture(e.icon);b.icon:SetDesaturated(not e.owned);b.name:SetText(e.name);WoWU_Theme.TextColor(b.name,e.owned and 1 or .55,e.owned and .82 or .55,e.owned and .4 or .55);b:Show()
            end
        end
        body:SetHeight(math.max(1,math.min(perPage,#entries-(page-1)*perPage)*55))
        local found
        if selected then for i=(page-1)*perPage+1,math.min(page*perPage,#entries)do local e=entries[i];if e.id==selected.id then found=e;break end end end
        inspect(found or entries[(page-1)*perPage+1])
        if #entries==0 then
            nameText:SetText("No collectibles found")
            description:SetText("Try clearing the search or changing the filter. Only collection data exposed by this client is displayed.")
        end
    end
    refresh=function()
        if not root:IsVisible() then return end
        if inCombat()then root.deferred=true;return end
        categoryMenu:Hide()
        for n,b in pairs(tabs) do b:SetEnabled(n~=kind) end
        catButton:SetShown(kind=="Appearances")
        catButton:SetText(categoryNames[category] or "Equipment slot")
        footer:SetText(kind=="Appearances"and "Details load per page. Search names from visited pages, or any appearance ID."or kind=="Toys"and "Toys follow the native journal's filters. Select a collected toy to use it."or kind=="Companions"and "Companion list follows the client's journal availability and filters."or "Drag the preview to rotate. Search by name or mount ID.")
        build();render()
    end
    catButton:SetScript("OnClick",function()
        categoryMenu:SetShown(not categoryMenu:IsShown())
        categoryMenu:SetSize(630,math.ceil(#categories/3)*36+20)
        for i,id in ipairs(categories) do
            local b=categoryChoices[i]
            if not b then
                b=button(categoryMenu,"",200);categoryChoices[i]=b
                b:SetScript("OnClick",function(self)category=self.category;categoryMenu:Hide();page=1;selected=nil;refresh()end)
            end
            b.category=id;b:SetText(categoryNames[id] or tostring(id))
            b:ClearAllPoints();b:SetPoint("TOPLEFT",10+((i-1)%3)*205,-10-math.floor((i-1)/3)*36);b:Show()
        end
    end)
    filterButton:SetScript("OnClick",function()filter=filter%3+1;filterButton:SetText(({"All","Collected","Not collected"})[filter]);page=1;refresh()end)
    previous:SetScript("OnClick",function()page=page-1;render();scroll:SetVerticalScroll(0)end)
    nextPage:SetScript("OnClick",function()page=page+1;render();scroll:SetVerticalScroll(0)end)
    search:SetScript("OnTextChanged",function()searchHint:SetShown(search:GetText()==""and not search:HasFocus());page=1;searchDeadline=GetTime()+.15 end)
    root:SetScript("OnShow",function()
        categories={};categoryNames={};categorySlots={}
        -- GetCategoryInfo supplies weapon choices on Forever; armour is defined by slots.
        local armor={{"Head","HEADSLOT"},{"Shoulder","SHOULDERSLOT"},{"Back","BACKSLOT"},{"Chest","CHESTSLOT"},{"Shirt","SHIRTSLOT"},{"Tabard","TABARDSLOT"},{"Wrist","WRISTSLOT"},{"Hands","HANDSSLOT"},{"Waist","WAISTSLOT"},{"Legs","LEGSSLOT"},{"Feet","FEETSLOT"}}
        local slotInfo=call(C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetAllSlotLocationInfo) or {}
        for fallback,entry in ipairs(armor) do
            local id=Enum and Enum.TransmogCollectionType and Enum.TransmogCollectionType[entry[1]] or fallback
            for _,info in ipairs(slotInfo) do if info.slotName==entry[2] and info.collectionType and info.collectionType>0 then id=info.collectionType;break end end
            categories[#categories+1]=id;categoryNames[id]=_G[entry[2]] or entry[1];categorySlots[id]=entry[2]
        end
        local last=LAST_TRANSMOG_COLLECTION_WEAPON_TYPE or 40
        for id=FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE or 12,last do
            local name,isWeapon,_,main,off=call(C_TransmogCollection and C_TransmogCollection.GetCategoryInfo,id)
            if name and isWeapon and not categoryNames[id] then
                categories[#categories+1]=id;categoryNames[id]=name;categorySlots[id]=(off and not main) and "SECONDARYHANDSLOT" or "MAINHANDSLOT"
            end
        end
        if not categoryNames[category] then category=categories[1] or 1 end
        refresh()
    end)
    root:SetScript("OnSizeChanged",function()if root:IsVisible() and render then render() end end)
    root:SetScript("OnHide",function()
        categoryMenu:Hide();search:ClearFocus();GameTooltip:Hide();toyScroll:Hide();toyTip:Hide();model:ClearModel();dress:ClearModel();previewKey=nil
        if not inCombat()then toyAction:Hide();toyAction:SetAttribute("toy",nil)end
    end)
    for _,event in ipairs({"COMPANION_UPDATE","MOUNT_JOURNAL_USABILITY_CHANGED","NEW_MOUNT_ADDED","PET_JOURNAL_LIST_UPDATE","TRANSMOG_COLLECTION_UPDATED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","TOYS_UPDATED","NEW_TOY_ADDED","PLAYER_REGEN_ENABLED"}) do pcall(root.RegisterEvent,root,event) end
    root:SetScript("OnEvent",function(self,event,id,success)
        if event=="GET_ITEM_INFO_RECEIVED"or event=="ITEM_DATA_LOAD_RESULT"then
            if success==false then return end
            if kind=="Toys"and selected and selected.id==id then previewKey=nil;metadataDirty=true end
            for e in pairs(itemEntries[id]or {})do if e.namePending then fillItemName(e);metadataDirty=true end end
            return
        end
        if event=="PLAYER_REGEN_ENABLED"then
            if not self:IsVisible()then toyAction:Hide();return end
            self.deferred=nil;refresh();return
        end
        local prefix=event=="TRANSMOG_COLLECTION_UPDATED"and "Appearances:"or (event=="TOYS_UPDATED"or event=="NEW_TOY_ADDED")and "Toys:"or event=="PET_JOURNAL_LIST_UPDATE"and "Companions:"or "Mounts:"
        for key in pairs(catalogs)do if key:sub(1,#prefix)==prefix then catalogs[key]=nil end end
        if not self:IsVisible()or self.pending then return end
        self.pending=true;C_Timer.After(.25,function()self.pending=false;refresh()end)
    end)
    local nextRender=0
    root:SetScript("OnUpdate",function()
        if inCombat()then return end
        if searchDeadline and GetTime()>=searchDeadline then searchDeadline=nil;refresh()end
        if currentCatalog and currentCatalog.appearance and kind=="Appearances"then
            local budget=GetTime()+.002;local done=0
            -- Visible cards get names/icons first; no thumbnail model is ever created.
            for _,b in ipairs(cards)do if b:IsShown()and b.entry and not b.entry.resolved then
                resolveAppearance(b.entry);metadataDirty=true;done=done+1
                if done>=4 or GetTime()>=budget then break end
            end end
        end
        if metadataDirty and GetTime()>=nextRender then
            metadataDirty=nil;nextRender=GetTime()+.25;filterCatalog();render()
        end
    end)
    return root
end
