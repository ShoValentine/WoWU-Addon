-- WoWU More: native views, Blizzard shortcuts and interface settings.
local function text(parent, size, color)
    local s=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    s:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    WoWU_Theme.TextColor(s,unpack(color or {0.95,0.82,0.55}))
    s:SetJustifyH("LEFT")
    return s
end
local function box(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=13,
        insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(f,.12,.16,.18,.98)
    WoWU_Theme.Panel(f)
    return f
end
local journalName=WoWUClient.ModuleName("Adventure Guide")
local tabs=WoWUClient.FilterModules({"Professions","Achievements","Collections",
            "Social","Talents","Legacy","Settings","Adventure","Adventure Guide","Dungeon Finder","Housing Dashboard","Shop"})
function WoWU_BuildMore(parent)
    local selected=nil
    local currentRows={}
    local populate
    local landing=CreateFrame("Frame",nil,parent)
    landing:SetAllPoints()
    local shortcutStatus=text(landing,14,{.95,.82,.55})
    shortcutStatus:SetPoint("BOTTOMLEFT",30,8);shortcutStatus:SetWidth(1160);shortcutStatus:SetText("")
    local detail=box(parent)
    detail:SetPoint("TOPLEFT",parent,"TOPLEFT",15,-15)
    detail:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-15,15)
    detail:Hide()

    local heading=text(detail,22)
    heading:SetPoint("TOPLEFT",23,-22)
    local hint=text(detail,13,{.7,.7,.65})
    hint:SetPoint("TOPLEFT",23,-59)
    hint:SetWidth(790)
    local scroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",18,-94)
    scroll:SetPoint("BOTTOMRIGHT",-34,16)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    local body=CreateFrame("Frame",nil,scroll)
    body:SetSize(750,550)
    scroll:SetScrollChild(body)

    local settingsFrames={}
    WoWU_BuildExtraSettings(detail,settingsFrames)
    local professionView = WoWU_CreateProfessions and WoWU_CreateProfessions(parent)
    local achievementView = WoWUClient.ModuleAvailable('Achievements')and WoWU_CreateAchievements and WoWU_CreateAchievements(parent)
    local talentView = CreateFrame("Frame",nil,parent)
    talentView:SetAllPoints(parent)
    talentView:Hide()
    if WoWU_BuildTalents then WoWU_BuildTalents(talentView) end
    local legacyView
    local socialView
    local compendiumView
    local collectionsView
    local retailViews={}
    local function goHome()
        if InCombatLockdown and InCombatLockdown() then print("WoWU: return to More after combat.");return end
        selected=nil
        detail:Hide()
        for _,control in ipairs(settingsFrames) do control:Hide() end
        if professionView then professionView:Hide() end
        if achievementView then achievementView:Hide() end
        talentView:Hide()
        if socialView then socialView:Hide() end
        if legacyView then legacyView:Hide() end
        if compendiumView then compendiumView:Hide() end
        if collectionsView then collectionsView:Hide() end
        for _,view in pairs(retailViews)do view:Hide()end
        shortcutStatus:SetText("")
        landing:Show()
    end
    socialView=WoWU_CreateSocial and WoWU_CreateSocial(parent,goHome)
    legacyView=WoWU_CreateLegacy and WoWU_CreateLegacy(parent,goHome)
    local back=CreateFrame("Button",nil,detail,"BackdropTemplate")
    back:SetSize(152,52)
    back:SetPoint("TOPRIGHT",-22,-15)
    WoWU_Theme.Backdrop(back,{bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize=15,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(back,.35,.27,.17,1)
    WoWU_Theme.Border(back,.72,.53,.29,1)
    local backLabel=text(back,18)
    backLabel:SetPoint("CENTER")
    backLabel:SetText("< Back")
    back:SetScript("OnClick",goHome)
    back:Hide()

    -- Native item/spell icons avoid missing Unicode glyphs in FRIZQT.
    local icons={"Interface\\Icons\\Trade_BlackSmithing","Interface\\Icons\\Achievement_General",
        "Interface\\Icons\\INV_Misc_Book_09",
        "Interface\\Icons\\INV_Misc_GroupLooking",
        "Interface\\Icons\\Ability_Marksmanship","Interface\\Icons\\Spell_Holy_BlessingOfStrength",
        "Interface\\Icons\\Trade_Engineering","Interface\\Icons\\INV_Misc_Map_01","Interface\\Icons\\INV_Misc_Book_11"}
    local tiles={}
    local function layoutTiles()
        if InCombatLockdown and InCombatLockdown() then return end
        local width=landing:GetWidth()
        local tileWidth=math.max(80,(width-80)/3)
        local rowCount=math.ceil(#tabs/3)
        local tileHeight=math.min(194,math.max(100,(landing:GetHeight()-58-(rowCount-1)*16)/rowCount))
        for i,b in ipairs(tiles) do
            local row=math.floor((i-1)/3)
            local count=math.min(3,#tabs-row*3)
            local rowWidth=count*tileWidth+(count-1)*18
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",landing,"TOPLEFT",(width-rowWidth)/2+((i-1)%3)*(tileWidth+18),-16-row*(tileHeight+16))
            b:SetSize(tileWidth,tileHeight)
            if b.icon then b.icon:ClearAllPoints();b.icon:SetPoint("TOP",0,tileHeight<160 and -18 or -35);b.icon:SetSize(tileHeight<160 and 44 or 56,tileHeight<160 and 44 or 56)end
            if b.label then b.label:ClearAllPoints();b.label:SetPoint("BOTTOM",0,tileHeight<160 and 20 or 32)end
        end
    end
    local moduleActions={}
    WoWU_OpenMoreModule=function(name) name=WoWUClient.ModuleName(name);if name=="Group Finder"then name="Dungeon Finder"end;if moduleActions[name] then moduleActions[name]() end end
    for i,name in ipairs(tabs) do
        local b=CreateFrame("Button",nil,landing,"BackdropTemplate")
        tiles[i]=b
        b:SetSize(300,194)
        WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize=18,insets={left=5,right=5,top=5,bottom=5}})
        WoWU_Theme.Color(b,.15,.19,.20,1)
        WoWU_Theme.Panel(b)
        local icon=b:CreateTexture(nil,"ARTWORK")
        icon:SetSize(56,56);icon:SetPoint("TOP",0,-35)
        local original={Professions=1,Achievements=2,Collections=3,Social=4,Talents=5,Legacy=6,Settings=7,Adventure=8,Compendium=9}
        local retailIcons={[journalName]="Interface\\Icons\\INV_Misc_Book_17",["Dungeon Finder"]="Interface\\Icons\\INV_Misc_GroupLooking",["Housing Dashboard"]="Interface\\Icons\\INV_Misc_Rune_01",Shop="Interface\\Icons\\INV_Misc_Coin_01"}
        icon:SetTexture(retailIcons[name]or icons[original[name]]);icon:SetTexCoord(.07,.93,.07,.93);b.icon=icon
        local rim=WoWU_Theme.IconRim(b,icon,70)
        b:HookScript("OnSizeChanged",function()local size=b:GetHeight()<160 and 56 or 70;rim:SetSize(size,size)end)
        local label=text(b,21)
        label:SetPoint("BOTTOM",0,32)
        label:SetText(name)
        label:SetWidth(300);label:SetJustifyH("CENTER");b.label=label
        if name=="Social" then
            local elapsed=0
            b:HookScript("OnUpdate",function(_,dt)
                elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
                local unread=WoWUSocial and WoWUSocial.unread or 0
                label:SetText(unread>0 and ("Social ("..unread..")") or "Social")
            end)
        end
        b:SetScript("OnEnter",function(self) WoWU_Theme.Color(self,.29,.25,.18,1) end)
        b:SetScript("OnLeave",function(self) WoWU_Theme.Color(self,.15,.19,.20,1) end)
        local function openModule()
            if InCombatLockdown and InCombatLockdown() then shortcutStatus:SetText("Open More sections after combat.");return end
            if name=="Adventure" then if WoWU_OpenAdventure then WoWU_OpenAdventure() end;return end
            if name=="Housing Dashboard"or name=="Shop"then
                local ok,message=WoWU_OpenRetailShortcut(name);shortcutStatus:SetText(message or "");return
            end
            selected=name
            landing:Hide()
            if professionView then professionView:Hide() end
            if achievementView then achievementView:Hide() end
            talentView:Hide()
        if socialView then socialView:Hide() end
            if legacyView then legacyView:Hide() end
            if compendiumView then compendiumView:Hide() end
        if collectionsView then collectionsView:Hide() end
            for _,view in pairs(retailViews)do view:Hide()end
            if name==journalName or name=="Dungeon Finder"then
                detail:Hide()
                if not retailViews[name]then
                    local builder
                    if WoWUClient.classicMajor==5 then builder=name==journalName and WoWU_CreateMistsGuide or WoWU_CreateMistsDungeonFinder
                    elseif WoWUClient.isClassic and WoWUClassicModules then builder=name==journalName and WoWUClassicModules.Guide or WoWUClassicModules.GroupFinder
                    else builder=name==journalName and WoWU_CreateRetailGuide or WoWU_CreateRetailGroupFinder end
                    local ok,view=pcall(builder,parent,goHome)
                    if not ok then goHome();shortcutStatus:SetText(name.." could not open: "..tostring(view));return end
                    retailViews[name]=view
                end
                retailViews[name]:Show()
            elseif name=="Collections" then
                detail:Hide()
                if not collectionsView then
                    local ok,view=pcall(WoWU_CreateCollections,parent)
                    if not ok then goHome();shortcutStatus:SetText("Collections could not open: "..tostring(view));return end
                    collectionsView=view
                end
                collectionsView:Show()
            elseif name=="Compendium" then
                detail:Hide()
                if not compendiumView then
                    local ok,view=pcall(WoWU_CreateCompendium,parent)
                    if ok then compendiumView=view else
                        print("WoWU Compendium: "..tostring(view));goHome();shortcutStatus:SetText("Compendium could not open; the error was printed in chat.");return
                    end
                end
                compendiumView:Show()
            elseif name=="Social" and socialView then
                detail:Hide()
                socialView:Show()
            elseif name=="Talents" then
                detail:Hide()
                talentView:Show()
            elseif name=="Legacy" and legacyView then
                detail:Hide()
                legacyView:Show()
            elseif name=="Professions" and professionView then
                detail:Hide()
                professionView:Show()
            elseif name=="Achievements" and achievementView then
                detail:Hide()
                achievementView:Show()
            else
                detail:Show()
                populate()
            end
        end
        moduleActions[name]=openModule
        b:SetScript("OnClick",openModule)
    end
    layoutTiles()
    landing:HookScript("OnSizeChanged",layoutTiles)
    landing:HookScript("OnShow",layoutTiles)
    local function clear()
        for _,row in ipairs(currentRows) do row:Hide();row:ClearAllPoints() end
        wipe(currentRows)
    end
    local function row(label,value,index)
        local line=CreateFrame("Frame",nil,body)
        line:SetHeight(37)
        line:SetPoint("TOPLEFT",9,-(index-1)*41)
        line:SetPoint("TOPRIGHT",-12,-(index-1)*41)
        local name=text(line,15,{.88,.83,.72})
        name:SetPoint("LEFT",8,0)
        name:SetWidth(470)
        name:SetText(label or "")
        local v=text(line,14,{.94,.77,.43})
        v:SetPoint("RIGHT",-9,0)
        v:SetJustifyH("RIGHT")
        v:SetText(tostring(value or ""))
        local shade=line:CreateTexture(nil,"BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(.22,.27,.27,(index%2==0) and .6 or .25)
        currentRows[#currentRows+1]=line
    end
    local function safeCall(fn,...)
        if type(fn)~="function" then return nil end
        local ok,a,b,c,d=pcall(fn,...)
        if ok then return a,b,c,d end
    end
    populate = function()
        if not parent:IsShown() or not detail:IsShown() then return end
        clear()
        local settings=selected=="Settings"
        for _,control in ipairs(settingsFrames) do control:SetShown(settings) end
        scroll:SetShown(not settings)
        heading:SetText(selected)
        local n=0
        local function add(a,b) n=n+1;row(a,b,n) end
        local function empty(msg) add(msg,"") end
        if selected=="Achievements" then
            hint:SetText("Achievements overview; native achievement browsing is planned.")
            if type(GetTotalAchievementPoints)=="function" then
                add("Achievement Points",safeCall(GetTotalAchievementPoints) or 0)
            else empty("Achievement data unavailable on this build.") end
        elseif selected=="Calendar" then
            hint:SetText("Calendar integration is planned for a later version.")
            empty("Use Blizzard's calendar for event management.")
        elseif selected=="Settings" then
            hint:SetText("Choose a category. Changes are saved automatically.")
        elseif selected=="Legacy" then
            hint:SetText("Account-wide Legacy buffs")
            empty("Legacy controls are not ready. Try /reload.")
        elseif selected=="Professions" then
            hint:SetText("Learned professions and skill levels; no protected crafting actions.")
            local getProfs=GetProfessions
            local getInfo=GetProfessionInfo
            if type(getProfs)=="function" and type(getInfo)=="function" then
                local ids={getProfs()}
                for _,id in ipairs(ids) do
                    if id then
                        local name,icon,rank,maxRank=safeCall(getInfo,id)
                        if name then add(name,(rank or "?").." / "..(maxRank or "?")) end
                    end
                end
            end
            if n==0 then empty("Profession information unavailable on this build.") end
        end
        body:SetHeight(math.max(550,n*41+20))
        scroll:SetVerticalScroll(0)
        scroll:SetPoint("TOPLEFT",18,-94)
    end
    local events=CreateFrame("Frame",nil,parent)
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_MONEY","SKILL_LINES_CHANGED",
        "UPDATE_FACTION","CURRENCY_DISPLAY_UPDATE","GUILD_ROSTER_UPDATE","PLAYER_REGEN_ENABLED"}) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_ENABLED" then shortcutStatus:SetText("");layoutTiles() end
        if parent:IsShown() then populate() end
    end)
    parent:HookScript("OnShow",function() if detail:IsShown() then populate() end end)
    -- Top-level More tab is a home button, even while More is already selected.
    WoWU_ResetMore = goHome
end
