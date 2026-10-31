local N=WoWUNavigation
local E={};WoWUExplorer=E
local function store()
    local s=N.State();s.explorer=s.explorer or {bookmarks={},filters={},characters={},nextID=1}
    local e=s.explorer;e.bookmarks=e.bookmarks or {};e.filters=e.filters or {};e.characters=e.characters or {};e.nextID=e.nextID or 1
    return e
end
local function character()
    local e=store();local id=N.Text(N.Call(UnitGUID,"player"),"player")
    e.characters[id]=e.characters[id] or {visits={},rares={}}
    return e.characters[id]
end
local function here()
    local map=N.Number(N.Call(C_Map and C_Map.GetBestMapForUnit,"player"))
    local x,y=N.Vector(N.Call(C_Map and C_Map.GetPlayerMapPosition,map,"player"))
    if map and x then return {mapID=map,x=x,y=y} end
end
local function shownMap()
    local map=WoWU_GetActiveMap and WoWU_GetActiveMap()or WorldMapFrame
    return map and map.WoWUNavigationDocked and N.Call(map.GetMapID,map) or N.Call(C_Map and C_Map.GetBestMapForUnit,"player")
end
local function enabled(key)
    local filters=store().filters;local value=filters[key]
    if value==nil and key=='otherServices'then value=filters.pois end
    return value~=false
end
E.IsEnabled=enabled
-- Read-only copies for the Compendium; reuse recorded locations, never infer a spawn.

function E.RareSightings()

    local result={}

    for _,p in pairs(character().rares)do

        result[#result+1]={kind="sighting",name=p.name,mapID=p.mapID,x=p.x,y=p.y,category="rares"}

    end

    for _,p in ipairs(store().bookmarks)do

        if p.kind=="rare"then result[#result+1]={kind="rare",name=p.name,mapID=p.mapID,x=p.x,y=p.y,category="rares"}end

    end

    return result

end

function E.SetEnabled(key,value)store().filters[key]=value==true;E.filterRevision=(E.filterRevision or 0)+1 end
local function mapName(id)
    local info=N.Call(C_Map and C_Map.GetMapInfo,id);return info and info.name or tostring(id)
end
function E.Save(point,name,kind)
    if not point or not N.Coordinates(point.x,point.y) then return false,"Location unavailable." end
    local e=store();local id=e.nextID;e.nextID=id+1
    local clean=(name or ""):gsub("^%s+",""):gsub("%s+$",""):sub(1,80)
    e.bookmarks[#e.bookmarks+1]={id=id,kind=kind or "bookmark",name=clean~="" and clean or mapName(point.mapID),mapID=point.mapID,x=point.x,y=point.y}
    return true,"Saved location."
end
local function corpse()
    if not N.IsDead() then return nil end
    local saved=character().death;local current=here()
    for _,id in ipairs({saved and saved.mapID or 0,current and current.mapID or 0}) do
        if id>0 then
            local x,y=N.Vector(N.Call(C_DeathInfo and C_DeathInfo.GetCorpseMapPosition,id))
            if x then return {kind="corpse",icon="Interface\\Icons\\Ability_Rogue_FeignDeath",category="corpse",name="Your corpse",mapID=id,x=x,y=y} end
        end
    end
    if saved then return {kind="corpse",icon="Interface\\Icons\\Ability_Rogue_FeignDeath",category="corpse",name="Death location",mapID=saved.mapID,x=saved.x,y=saved.y} end
end
N.RegisterSource("corpse",corpse)
local function classify(info)
    local atlas=string.lower(N.Text(info.atlasName,""))
    if atlas:find("innkeeper",1,true) or atlas:find("resting",1,true) then return "inns" end
    if atlas:find("mail",1,true) then return "mail" end
    if atlas:find("repair",1,true) then return "repairs" end
    if atlas:find("trainer",1,true) then return "trainers" end
    if atlas:find("rare",1,true) then return "rares" end
    if atlas:find("loot",1,true)or atlas:find("treasure",1,true)then return "treasures"end
    return "pois"
end
E.icons={repairs="Interface\\MINIMAP\\TRACKING\\Repair",flights="Interface\\MINIMAP\\TRACKING\\FlightMaster",inns="Interface\\MINIMAP\\TRACKING\\Innkeeper",
    mail="Interface\\MINIMAP\\TRACKING\\Mailbox",trainers="Interface\\MINIMAP\\TRACKING\\Profession",
    bookmarks="Interface\\Icons\\INV_Misc_Map_01",rares="Interface\\Icons\\Ability_Creature_Cursed_02",
    pois="Interface\\Icons\\INV_Misc_Spyglass_03",treasures="Interface\\Icons\\INV_Misc_TreasureChest01",quests="Interface\\GossipFrame\\AvailableQuestIcon"}
local serviceIndex={}
for _,r in ipairs(WoWUServiceLocations or {}) do
    serviceIndex[r[1]]=serviceIndex[r[1]] or {};table.insert(serviceIndex[r[1]],r)
end
function E.Points(map)
    if N.IsDead() then local c=corpse();return c and {c} or {} end
    local result={};local seen={};local current=here()

    local function add(p)
        local visibility=p and p.category=='pois'and(p.kind=='service'or p.referenceKind=='service')and 'otherServices'or p and(p.category or p.kind)
        if p and enabled(visibility) and p.mapID and N.Coordinates(p.x,p.y) then
            local key=p.id and (p.kind..":"..p.id) or (p.mapID..":"..(p.category or p.kind)..":"..math.floor(p.x*500)..":"..math.floor(p.y*500))
            if seen[key] then return end;seen[key]=true
            p.icon=p.icon or E.icons[p.category];result[#result+1]=p
        end
    end
    local friendly=N.Call(UnitFactionGroup,"player")=="Horde" and "H" or "A"
    for _,r in ipairs(serviceIndex[map] or {}) do
        if r[6]:find(friendly,1,true) then
            add({kind="service",category=r[2],name=r[3],mapID=r[1],x=r[4],y=r[5],
                icon=r[2]=="trainers" and (r[7]:find("Class",1,true) and "Interface\\MINIMAP\\TRACKING\\Class" or nil),
                note=r[7]~="" and r[7] or "Known service location"})
        end
    end
    for _,p in pairs(store().services or {}) do if p.mapID==map then add(p) end end
    local nodes=N.Call(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap,map)
    local faction=N.Call(UnitFactionGroup,"player")
    if type(nodes)=="table" then for _,node in ipairs(nodes) do
        if node.faction==0 or node.faction==(faction=="Horde" and 1 or faction=="Alliance" and 2 or -1) then
            local x,y=N.Vector(node.position)
            add({kind="flight",category="flights",name=node.name,mapID=map,x=x,y=y,note=node.isUndiscovered and "Undiscovered flight master" or "Flight master"})
        end
    end end
    local ids=N.Call(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap,map)
    if type(ids)=="table" then for _,id in ipairs(ids) do
        local info=N.Call(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo,map,id)
        if info then
            local x,y=N.Vector(info.position);local category=classify(info)
            local atlas=string.lower(N.Text(info.atlasName,''))
            local service=category=='pois'and(atlas:find('banker',1,true)or atlas:find('auction',1,true)or atlas:find('vendor',1,true)or atlas:find('stable',1,true)or atlas:find('transmog',1,true)or atlas:find('barber',1,true))
            add({kind=service and 'service'or 'poi',category=category,name=info.name,mapID=map,x=x,y=y,note=info.description or "Map location"})
        end
    end end
    -- Indexed by client and zone. Keep every coordinate in the catalogue, but
    -- show one per entity/category, closest to the player on the current map.
    local choices={};local native={}
    for _,p in ipairs(result)do
        local key=math.floor(p.x*500)..":"..math.floor(p.y*500)
        native[key]=native[key]or {};native[key][#native[key]+1]=p
    end
    for _,r in ipairs((WoWULocationData or {})[map]or {})do
        local visibility=r[1]=='pois'and r[7]=='service'and 'otherServices'or r[1]
        if enabled(visibility)and (r[5]==""or r[5]:find(friendly,1,true))then
            local key=r[1]..":"..r[7]..":"..(r[6]~=0 and r[6]or r[2])
            -- A chest/object ID can describe many independent containers.
            if r[7]=="treasure"or r[7]=="poi"or r[1]=="mail"then key=key..":"..math.floor(r[3]*500)..":"..math.floor(r[4]*500)end
            local score=current and current.mapID==map and ((r[3]-current.x)^2+(r[4]-current.y)^2)or 0
            local previous=choices[key]
            if not previous or score<previous.score then choices[key]={row=r,score=score}end
        end
    end
    local sources={Q="QuestieDB",S="SilverDragon",M="MapNotes"}
    for _,choice in pairs(choices)do
        local r=choice.row
        local duplicate=false;local gx,gy=math.floor(r[3]*500),math.floor(r[4]*500)
        for dx=-1,1 do for dy=-1,1 do
            for _,p in ipairs(native[(gx+dx)..":"..(gy+dy)]or {})do
                if (p.category==r[1]or p.name==r[2])and (p.x-r[3])^2+(p.y-r[4])^2<.002^2 then duplicate=true;break end
            end
        end end
        local note=r[1]=="rares"and "Known rare location; not a live spawn"or r[1]=="treasures"and "Known treasure location; may require a quest, event or phase"or r[7]=="service"and "Known service location"or "Known notable location; availability may vary"
        if r[9]and r[9]~=""then note=r[9]..". "..note end
        if not duplicate then add({kind="reference",referenceKind=r[7],category=r[1],name=r[2],mapID=map,x=r[3],y=r[4],note=note.." ("..(sources[r[8]]or "Imported")..")",sourceEntityID=r[6]})end
    end
    for _,p in ipairs(store().bookmarks) do
        add({kind=p.kind,category=p.kind=="rare" and "rares" or "bookmarks",id=p.id,name=p.name,mapID=p.mapID,x=p.x,y=p.y,note=p.kind=="rare" and "Saved rare location" or mapName(p.mapID)})
    end
    for _,p in pairs(character().rares) do
        add({kind="sighting",category="rares",name=p.name,mapID=p.mapID,x=p.x,y=p.y,note="Seen near your position; not a live spawn"})
    end
    local c=corpse();if c then c.category="corpse";add(c) end
    if current then
        for _,p in ipairs(result) do
            local target=N.PointDestination(p,current.mapID)
            if target then p.distance=target.distance end
        end
        table.sort(result,function(a,b)
            if a.distance~=b.distance then return (a.distance or math.huge)<(b.distance or math.huge) end
            return (a.name or "")<(b.name or "")
        end)
    end
    return result
end
function E.Clusters(map)
    local groups={};local pois=N.Call(WoWUQuestLog and WoWUQuestLog.GetQuestsOnMap,map)
    local w,h=N.MapWorldSize(map)
    if type(pois)~="table" or not N.Number(w) or not N.Number(h) then return groups end
    local seen={}
    for _,p in ipairs(pois) do
        local x,y=N.Coordinates(p.x,p.y)
        if x and p.questID and not seen[p.questID] and (not p.childDepth or p.childDepth==0) then
            seen[p.questID]=true;local group
            for _,g in ipairs(groups) do if ((x-g.x)*w)^2+((y-g.y)*h)^2<=250^2 then group=g;break end end
            if not group then group={kind="cluster",mapID=map,x=x,y=y,quests={}};groups[#groups+1]=group end
            group.quests[#group.quests+1]={id=p.questID,x=x,y=y}
        end
    end
    for _,g in ipairs(groups) do
        local best,distance
        for _,q in ipairs(g.quests) do
            local t=N.PointDestination({mapID=map,x=q.x,y=q.y},N.Call(C_Map.GetBestMapForUnit,"player"))
            if not best or t and (not distance or t.distance<distance) then best=q;distance=t and t.distance end
        end
        g.questID=best.id;g.x=best.x;g.y=best.y
        g.name=#g.quests.." quest"..(#g.quests==1 and "" or "s").." in this area"
        g.note="Navigate to nearest quest: "..(N.Call(WoWUQuestLog.GetTitleForQuestID,best.id) or tostring(best.id))
    end
    return groups
end
local function observe()
    local p=here();if not p or N.Call(UnitIsGhost,"player") then return end
    local c=character();local v=c.visits[p.mapID] or {cells={},name=mapName(p.mapID)};c.visits[p.mapID]=v
    v.cells[math.min(19,math.floor(p.x*20))..":"..math.min(19,math.floor(p.y*20))]=true
    local areas=N.Call(C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition,p.mapID,CreateVector2D(p.x,p.y))
    v.areas=v.areas or {};if type(areas)=="table" then for _,id in ipairs(areas) do v.areas[id]=true end end
end
local event=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","ZONE_CHANGED_NEW_AREA","MAP_EXPLORATION_UPDATED"}) do event:RegisterEvent(e) end
event:SetScript("OnEvent",function(_,e)
    local c=character();local state=N.State()
    if e=="PLAYER_DEAD" then c.death=here();c.corpseStarted=nil end
    N.cacheTime=nil
    if not N.IsDead() and (e=="PLAYER_UNGHOST" or e=="PLAYER_ENTERING_WORLD") then
        -- Migrate the older implementation, which replaced the saved destination.
        if state.active and state.active.kind=="corpse" then
            state.active=c.previous and c.previous.active;state.stopped=c.previous and c.previous.stopped or false
        end
        c.death=nil;c.previous=nil;c.corpseStarted=nil
    end
    if e=="PLAYER_TARGET_CHANGED" then
        local class=N.Call(UnitClassification,"target")
        if class=="rare" or class=="rareelite" then
            local p=here();local name=N.Text(N.Call(UnitName,"target"))
            if p and name then p.name=name;c.rares[p.mapID..":"..name]=p end
        end
    end
    if e=="ZONE_CHANGED_NEW_AREA" or e=="MAP_EXPLORATION_UPDATED" or e=="PLAYER_ENTERING_WORLD" then pcall(observe) end
end)
local sample=0;event:SetScript("OnUpdate",function(_,dt) sample=sample+dt;if sample>=10 then sample=0;pcall(observe) end end)

-- Remember actually encountered services where the static database is incomplete.
-- Interaction records are explicitly approximate player positions, not NPC spawns.
local services=CreateFrame("Frame")
services:RegisterEvent("TRAINER_SHOW");services:RegisterEvent("MAIL_SHOW");services:RegisterEvent("MERCHANT_SHOW")
services:SetScript("OnEvent",function(_,eventName)
    if N.IsDead() then return end
    if eventName=="MERCHANT_SHOW" and not N.Call(CanMerchantRepair) then return end
    local p=here();if not p then return end
    p.category=eventName=="MERCHANT_SHOW" and "repairs" or eventName=="MAIL_SHOW" and "mail" or "trainers";p.kind="service"
    p.name=p.category=="mail" and "Mailbox" or N.Text(N.Call(UnitName,"npc"),p.category=="repairs" and "Repair merchant" or "Trainer")
    p.note="Encountered nearby; approximate interaction position"
    local e=store();e.services=e.services or {}
    e.services[p.mapID..":"..p.category..":"..p.name..":"..math.floor(p.x*100)..":"..math.floor(p.y*100)]=p
end)

function WoWU_BuildExplorer(parent)
    local panel=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    panel:SetPoint("TOPRIGHT",-9,-9);panel:SetPoint("BOTTOMRIGHT",-9,9);panel:SetWidth(294)
    WoWU_Theme.Panel(panel,"inset",false)
    local function text(p,value,size,x,y,width)
        local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal");t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
        t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetWordWrap(true);t:SetText(value);WoWU_Theme.TextColor(t,.95,.83,.6);return t
    end
    local function button(p,value,width,height,fn)
        local b=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");b:SetSize(width,height);b:SetText(value);b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",14,"");b:SetScript("OnClick",fn);return b
    end
    text(panel,"Map destinations",20,12,-16,270)
    local section,query="Services",""
    local selected,refresh,cache,cacheMap,menu,refreshMenu;local keyboard,lastEdit,search,name;local rows={};local refreshing=false;local emptyNotice=false
    local status=text(panel,"Tap a place, then Navigate.",13,12,0,268);status:ClearAllPoints();status:SetPoint("BOTTOMLEFT",12,10);status:SetHeight(54);status:SetJustifyV('TOP')
    local function reset()cache=nil;selected=nil end
    local menuButton=button(panel,'Services - Menu',268,40,function()
        if search then search:ClearFocus()end;if name then name:ClearFocus()end;if keyboard then keyboard:Hide()end
        if menu:IsShown()then menu:Hide()else refreshMenu();menu:Show()end
    end);menuButton:SetPoint('TOPLEFT',12,-48)
    search=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');search:SetPoint('TOPLEFT',18,-98);search:SetSize(196,34);search:SetAutoFocus(false);search:SetMaxLetters(80)
    local placeholder=text(search,'Find a place...',14,0,-7,188)
    local function placeholderState()placeholder:SetShown(search:GetText()==''and not search:HasFocus())end
    search:SetScript('OnTextChanged',function(self)query=(self:GetText()or ''):lower();reset();if refresh then refresh(true)end;placeholderState()end)
    search:SetScript('OnEditFocusGained',function()if menu then menu:Hide()end;placeholderState()end);search:SetScript('OnEditFocusLost',placeholderState)
    search:SetScript('OnEnterPressed',function(self)self:ClearFocus()end);search:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
    name=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');name:SetPoint('TOPLEFT',18,-143);name:SetSize(190,30);name:SetAutoFocus(false);name:SetMaxLetters(80)
    local nameHint=text(name,'Saved name (optional)',12,0,-7,182)
    name:SetScript('OnTextChanged',function(self)nameHint:SetShown(self:GetText()=='')end)
    local rareMark=CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate');rareMark:SetSize(30,30);rareMark:SetPoint('TOPLEFT',214,-143)
    local rareLabel=text(rareMark,'Rare',12,28,-8,42)
    name:SetScript('OnEditFocusGained',function(self)lastEdit=self end)
    name:SetScript('OnEnterPressed',function(self)self:ClearFocus()end);name:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
    search:HookScript('OnEditFocusGained',function(self)lastEdit=self end)
    local keys=button(panel,'Keys',60,34,function()
        if not WoWUKeyboard then return end
        if menu then menu:Hide()end
        if not keyboard then keyboard=WoWUKeyboard.Create(parent,{draggable=true})end
        if keyboard:IsShown()then keyboard:Hide()else keyboard:Open(lastEdit and lastEdit:IsVisible()and lastEdit or search,nil,'Done')end
    end);keys:SetPoint('TOPRIGHT',-12,-98)
    local saveHere=button(panel,'Save here',130,36,function()
        local _,msg=E.Save(here(),name:GetText(),rareMark:GetChecked()and 'rare'or 'bookmark');status:SetText(msg);cache=nil;refresh()
    end);saveHere:SetPoint('TOPLEFT',12,-177)
    local savePin=button(panel,'Place map pin',130,36,function()
        if E.pinMode then E.CancelPin();status:SetText('Pin placement cancelled.');return end
        local _,msg=E.BeginPin(name:GetText(),rareMark:GetChecked()and 'rare'or 'bookmark',function(message)status:SetText(message);cache=nil;refresh()end);status:SetText(msg)
    end);savePin:SetPoint('TOPLEFT',150,-177)
    local countLabel=text(panel,'',12,12,-138,268)
    local scroll=CreateFrame('ScrollFrame',nil,panel,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',10,-160);scroll:SetPoint('BOTTOMRIGHT',-30,162)
    local body=CreateFrame('Frame',nil,scroll);body:SetSize(250,1);scroll:SetScrollChild(body);WoWU_Theme.Scrollbar(scroll)
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
    local captions={flights='Flight masters',inns='Inns',mail='Mailboxes',trainers='Trainers',repairs='Repairs',pois='Notable locations',treasures='Treasures',rares='Rare locations',bookmarks='Saved places'}
    local sectionNames={Services='Services',Rares='Rares',POIs='Places',Bookmarks='Saved',Exploration='Explored'}
    -- The popout is an addon-owned panel confined to the companion sidebar.
    menu=CreateFrame('Frame',nil,panel,'BackdropTemplate');menu:SetWidth(280);menu:SetPoint('TOPLEFT',7,-91);menu:SetFrameLevel(panel:GetFrameLevel()+80);menu:EnableMouse(true);WoWU_Theme.Panel(menu);menu:Hide()
    local menuTitle=text(menu,'Map menu',17,12,-14,200)
    local menuHint=text(menu,'Choose a section.',12,12,-43,252);menuHint:SetHeight(32)
    local menuMode='root';local choices={};local checks={}
    local menuEntries={{'Services','Services'},{'Places','POIs'},{'Rares','Rares'},{'Saved places','Bookmarks'},{'Exploration','Exploration'}}
    local serviceFilters={{'flights','Flight masters'},{'inns','Inns'},{'mail','Mailboxes'},{'trainers','Trainers'},{'repairs','Repairs'},{'otherServices','Banks, vendors and other services'}}
    local placeFilters={{'pois','Notable locations and entrances'},{'treasures','Treasures'}}
    local menuBack=button(menu,'Back',116,34,function()menuMode='root';refreshMenu()end);menuBack:SetPoint('TOPRIGHT',-12,-10)
    local menuDone=button(menu,'Done',252,36,function()menu:Hide()end)
    refreshMenu=function()
        for _,b in ipairs(choices)do b:Hide()end;for _,b in ipairs(checks)do b:Hide()end
        menuBack:SetShown(menuMode~='root');menuTitle:SetText(menuMode=='root'and 'Map menu'or sectionNames[menuMode]or 'Map options');menuTitle:SetWidth(menuMode=='root'and 240 or 135)
        if menuMode=='root'then
            menuHint:SetText('Choose what to browse. Services and Places also have map visibility options.')
            for i,entry in ipairs(menuEntries)do
                local b=choices[i]
                if not b then b=button(menu,'',252,38,function(self)
                    if E.pinMode then E.CancelPin()end
                    section=self.section;reset();search:SetText('');refresh(true)
                    if section=='Services'or section=='POIs'or section=='Rares'then menuMode=section;refreshMenu()else menu:Hide()end
                end);choices[i]=b end
                b.section=entry[2];b:SetText(entry[1]);b:ClearAllPoints();b:SetPoint('TOPLEFT',14,-80-(i-1)*42);b:Show()
            end
            menu:SetHeight(342);menuDone:ClearAllPoints();menuDone:SetPoint('TOPLEFT',14,-296)
        else
            menuHint:SetText('Tick the categories to show on your map and minimap. Changes apply immediately.')
            local list=menuMode=='Services'and serviceFilters or menuMode=='POIs'and placeFilters or {{'rares','Rare locations'}}
            for i,entry in ipairs(list)do
                local b=checks[i]
                if not b then
                    b=CreateFrame('CheckButton',nil,menu,'UICheckButtonTemplate');b:SetSize(34,34)
                    b.label=text(b,'',14,40,-5,198);b.label:SetHeight(36)
                    b:SetScript('OnClick',function(self)E.SetEnabled(self.key,self:GetChecked()and true or false);cache=nil;selected=nil;refresh(true);refreshMenu()end)
                    local tap=CreateFrame('Button',nil,b);tap:SetPoint('TOPLEFT',b,'TOPRIGHT',0,3);tap:SetSize(202,40)
                    tap:SetScript('OnClick',function()b:SetChecked(not enabled(b.key));b:GetScript('OnClick')(b)end)
                    checks[i]=b
                end
                b.key=entry[1];b.label:SetText(entry[2]);b:SetChecked(enabled(entry[1]));b:ClearAllPoints();b:SetPoint('TOPLEFT',16,-80-(i-1)*42);b:Show()
            end
            local h=80+#list*42;menu:SetHeight(h+58);menuDone:ClearAllPoints();menuDone:SetPoint('TOPLEFT',14,-h-8)
        end
    end
    menu:HookScript('OnHide',function()menuMode='root' end)
    scroll.WoWUTouchBlocked=function()return menu:IsShown()or keyboard and keyboard:IsShown()end
    local function data()
        if not cache then
            cache={};cacheMap=shownMap()
            if section=='Exploration'then
                for id,v in pairs(character().visits)do local n,a=0,0;for _ in pairs(v.cells)do n=n+1 end;for _ in pairs(v.areas or {})do a=a+1 end;cache[#cache+1]={name=v.name or tostring(id),note=n..' visited cells; '..a..' observed areas. Recorded since installation.',mapID=id,exploration=true}end
                table.sort(cache,function(a,b)return a.name<b.name end)
            elseif section=='Bookmarks'then
                for _,p in ipairs(store().bookmarks)do
                    local t=N.PointDestination(p,cacheMap);local info=N.Call(C_Map and C_Map.GetMapInfo,p.mapID)
                    cache[#cache+1]={name=p.name,id=p.id,kind=p.kind,category='bookmarks',mapID=p.mapID,x=p.x,y=p.y,distance=t and t.distance,icon=E.icons.bookmarks,note=info and info.name or 'Saved location',saved=true}
                end
                table.sort(cache,function(a,b)if a.distance~=b.distance then return(a.distance or math.huge)<(b.distance or math.huge)end;return a.name<b.name end)
            else
                for _,p in ipairs(E.Points(cacheMap))do
                    local matches=section=='Services'and(p.category=='flights'or p.category=='inns'or p.category=='mail'or p.category=='trainers'or p.category=='repairs'or p.category=='pois'and(p.kind=='service'or p.referenceKind=='service'))
                        or section=='POIs'and(p.category=='treasures'or p.category=='pois'and p.kind~='service'and p.referenceKind~='service')or section=='Rares'and p.category=='rares'
                    if matches and p.mapID==cacheMap then cache[#cache+1]=p end
                end
            end
        end
        local out={}
        for _,p in ipairs(cache)do if query==''or ((p.name or '')..' '..(p.note or '')..' '..(captions[p.category]or '')):lower():find(query,1,true)then out[#out+1]=p end end
        return out
    end
    local function identity(p)return p and ((p.kind or '')..':'..(p.id or '')..':'..(p.mapID or '')..':'..(p.x or '')..':'..(p.y or '')..':'..(p.name or ''))end
    local function details()
        if not selected then return end
        WoWUDetails.Show({icon=selected.icon,lines={{left=selected.name,color={1,.82,.3}},{left=selected.note or 'Saved map location',color={1,1,1}},{left=selected.distance and (math.floor(selected.distance+.5)..' yards from your last list update.')or 'Distance unavailable from this map.',color={.8,.8,.8}}}},panel)
    end
    local info=button(panel,'Destination details',268,33,details);info:SetPoint('BOTTOMLEFT',12,118)
    local rename=button(panel,'Rename',130,33,function()
        if not selected or not selected.saved then status:SetText('Select a saved place first.');return end
        local value=(name:GetText()or ''):gsub('^%s+',''):gsub('%s+$',''):sub(1,80);if value==''then status:SetText('Enter the new name above the list.');return end
        for _,p in ipairs(store().bookmarks)do if p.id==selected.id then p.name=value;selected.name=value;cache=nil;refresh();status:SetText('Saved place renamed.');return end end
    end);rename:SetPoint('TOPLEFT',12,-217)
    local delete=button(panel,'Delete',130,33,function()
        if not selected or not selected.saved then status:SetText('Select a saved place first.');return end
        for i,p in ipairs(store().bookmarks)do if p.id==selected.id then local active=N.State().active;if active and active.id==p.id and active.kind==p.kind then N.Stop()end;table.remove(store().bookmarks,i);selected=nil;cache=nil;refresh();status:SetText('Saved place deleted.');return end end
    end);delete:SetPoint('TOPRIGHT',-12,-217)
    local navigate=button(panel,'Navigate',172,42,function()
        if not selected or not selected.x then status:SetText('Choose a destination from the list first.');return end
        local ok,msg;if selected.questID then ok,msg=N.StartQuest(selected.questID)else ok,msg=N.SetDestination(selected)end
        status:SetText(ok and ('Navigating to '..selected.name)or msg or 'Guidance is unavailable here.')
    end);navigate:SetPoint('BOTTOMLEFT',12,70)
    local stop=button(panel,'Stop',90,42,function()local _,msg=N.Stop();status:SetText(msg or 'Navigation stopped.')end);stop:SetPoint('BOTTOMRIGHT',-12,70)
    refresh=function(resetScroll)
        if not panel:IsVisible()or refreshing then return end;refreshing=true
        local map=shownMap();if cacheMap and map~=cacheMap then reset();cacheMap=map end
        local saved=section=='Bookmarks';name:SetShown(saved);rareMark:SetShown(saved);saveHere:SetShown(saved);savePin:SetShown(saved)
        countLabel:ClearAllPoints();countLabel:SetPoint('TOPLEFT',12,saved and -258 or -138)
        scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',10,saved and -280 or -160);scroll:SetPoint('BOTTOMRIGHT',-30,162)
        menuButton:SetText((sectionNames[section]or 'Destinations')..' - Menu')
        local list=data();countLabel:SetText(#list..(#list==1 and ' place' or ' places')..' - swipe to browse')
        body:SetHeight(math.max(1,#list*76))
        local maximum=math.max(0,body:GetHeight()-scroll:GetHeight())
        if resetScroll then if WoWU_StopTouchScroll then WoWU_StopTouchScroll(scroll,true)end;scroll:SetVerticalScroll(0)elseif scroll:GetVerticalScroll()>maximum then scroll:SetVerticalScroll(maximum)end
        local first=math.max(1,math.floor(scroll:GetVerticalScroll()/76)+1)
        local size=math.max(1,math.min(16,math.ceil(math.max(1,scroll:GetHeight())/76)+2))
        for i=1,size do
            local index=first+i-1;local p=list[index];local row=rows[i]
            if not row then
                row=CreateFrame('Button',nil,body,'BackdropTemplate');row:SetSize(248,72);WoWU_Theme.Panel(row);WoWU_Theme.Button(row)
                row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(28,28);row.icon:SetPoint('TOPLEFT',8,-12)
                row.title=text(row,'',16,43,-8,195);row.title:SetHeight(38)
                row.note=text(row,'',12,43,-49,195);row.note:SetHeight(18)
                row:SetScript('OnClick',function(self)
                    if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll)then return end
                    if menu:IsShown()then menu:Hide()end
                    selected=self.point;if selected.saved then name:SetText(selected.name);rareMark:SetChecked(selected.kind=='rare')end
                    status:SetText(selected.exploration and selected.note or ('Selected: '..selected.name..'. Tap Navigate or Destination details.'));refresh()
                end);rows[i]=row
            end
            if p then
                row.point=p;row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(index-1)*76);row.title:SetText(p.name);row.icon:SetTexture(p.icon or E.icons[p.category]or E.icons.pois)
                row.note:SetText(p.exploration and 'Observed exploration'or ((p.distance and (math.floor(p.distance+.5)..' yd - ')or '')..(captions[p.category]or 'Location')))
                local chosen=identity(selected)==identity(p);WoWU_Theme.Border(row,chosen and 1 or .65,chosen and .85 or .65,chosen and .3 or .65,1);row:Show()
            else row:Hide()end
        end
        for i=size+1,#rows do rows[i]:Hide()end
        navigate:SetEnabled(selected~=nil and selected.x~=nil);info:SetEnabled(selected~=nil);info:Show();rename:SetShown(saved);delete:SetShown(saved);rename:SetEnabled(selected and selected.saved or false);delete:SetEnabled(selected and selected.saved or false)
        if #list==0 then
            emptyNotice=true;status:SetText(query~=''and 'No matches. Try a shorter name or another section.'or saved and 'Save your current position or place a map pin to begin.'or 'No locations are currently visible. Open the menu to check which map categories are ticked.')
        elseif emptyNotice then emptyNotice=false;status:SetText('Tap a place, then Navigate or Destination details.')end
        refreshing=false
    end
    scroll:HookScript('OnVerticalScroll',function()if refresh and not refreshing then refresh()end end)
    panel:HookScript('OnShow',function()reset();cacheMap=shownMap();refresh(true);status:SetText('Search or choose a place, then tap Navigate.')end)
    panel:HookScript('OnHide',function()menu:Hide();if keyboard then keyboard:Hide()end;search:ClearFocus();name:ClearFocus();if E.CancelPin then E.CancelPin()end end)
    local elapsed=0;panel:SetScript('OnUpdate',function(_,dt)
        elapsed=elapsed+dt;if elapsed<3 then return end;elapsed=0
        -- Keep entries under the finger stable while browsing, paging or selecting.
        if not selected and not menu:IsShown()and scroll:GetVerticalScroll()==0 and not(IsMouseButtonDown and IsMouseButtonDown('LeftButton'))then cache=nil end
        refresh()
    end)
    refresh(true)
end
