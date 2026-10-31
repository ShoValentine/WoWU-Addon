-- Dashboard Adventure Alerts. Read-only suggestions; no automatic equipment or purchases.
local N=WoWUNavigation
local A={alerts={},upgrades={},dirty=true};WoWUAdventure=A
local function state()
    WoWUDB=WoWUDB or {};WoWUDB.adventure=WoWUDB.adventure or {}
    local key=UnitGUID("player") or "player"
    local all=WoWUDB.adventure;all[key]=all[key] or {}
    local s=all[key];s.options=s.options or {};s.dismissed=s.dismissed or {};s.notified=s.notified or {}
    s.ledger=s.ledger or {started=time(),gained=0,spent=0,items=0,entries={}}
    return s
end
A.State=state
local function enabled(key) if key=="trainer"and WoWUClient.isRetail then return false end;if key=="sounds"then return state().options[key]==true end;return state().options[key]~=false end
A.GetOption=enabled
function A.SetOption(key,value)state().options[key]=value==true;A.Refresh()end
local function itemInfo(link)
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not fn or not link then return end
    local values={pcall(fn,link)}
    if not values[1] or not values[2] then return end
    table.remove(values,1);return values
end
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_2HWEAPON={16},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18}}
local function scanUpgrades()
    local result,seen={},{}
    if not C_Container then return result end
    for bag=0,WoWUClient.LastBag() do
        for slot=1,(N.Call(C_Container.GetContainerNumSlots,bag) or 0) do
            local container=N.Call(C_Container.GetContainerItemInfo,bag,slot)
            local link=container and container.hyperlink
            local info=itemInfo(link)
            if info and slots[info[9]] and not seen[link] and info[5]<=UnitLevel("player") then
                local bestSlot,oldLevel,oldLink
                for _,equipSlot in ipairs(slots[info[9]]) do
                    local current=GetInventoryItemLink("player",equipSlot);local old=itemInfo(current)
                    -- Compare like-for-like armor/weapon types. Never call item level a stat score.
                    local compatible=old and old[12]==info[12] and old[13]==info[13]
                    if compatible and (info[9]~="INVTYPE_2HWEAPON" or old[9]=="INVTYPE_2HWEAPON") and (old[9]~="INVTYPE_2HWEAPON" or info[9]=="INVTYPE_2HWEAPON") then
                        if not oldLevel or old[4]<oldLevel then bestSlot=equipSlot;oldLevel=old[4];oldLink=current end
                    elseif not current and equipSlot~=16 and equipSlot~=17 and info[12]==4 then
                        bestSlot=equipSlot;oldLevel=0;oldLink=nil
                    end
                end
                if bestSlot and info[4]>oldLevel then
                    seen[link]=true;result[#result+1]={key="upgrade:"..link,title=info[1],icon=info[10],link=link,compare=oldLink,popup="Possible Upgrade Found: ["..info[1].."]",
                        detail="Possible upgrade: item level "..oldLevel.." to "..info[4]..". Check stats, proficiency and restrictions before equipping.",kind="upgrade"}
                end
            end
        end
    end
    return result
end
function A.Poll()
    if A.dirty then A.upgrades=scanUpgrades();A.dirty=false end
    A.Refresh()
end
local function currentMap() return N.Call(C_Map and C_Map.GetBestMapForUnit,"player") end
local function classTrainer(record)
    local _,class=UnitClass("player")
    return record[2]=="trainers" and class and string.lower(record[7] or ""):find(string.lower(class),1,true)
end
local trainerRecords
local function classTrainers()
    if trainerRecords then return trainerRecords end;trainerRecords={}
    for _,r in ipairs(WoWUServiceLocations or {})do if classTrainer(r)then trainerRecords[#trainerRecords+1]=r end end
    for mapID,records in pairs(WoWULocationData or {})do for _,r in ipairs(records)do
        if r[1]=='trainers'then local legacy={mapID,r[1],r[2],r[3],r[4],r[5],r[9],r[6]};if classTrainer(legacy)then trainerRecords[#trainerRecords+1]=legacy end end
    end end
    return trainerRecords
end
local function nearestTrainer()
    local map=currentMap();local best,distance
    local faction=UnitFactionGroup("player")=="Horde" and "H" or "A"
    if not map then return end
    for _,r in ipairs(classTrainers()) do
        if classTrainer(r) and r[6]:find(faction,1,true) then
            local p={kind="service",category="trainers",name=r[3],mapID=r[1],x=r[4],y=r[5],icon="Interface\\MINIMAP\\TRACKING\\Class"}
            local t=N.PointDestination(p,map)
            if t and (not distance or t.distance<distance) then best=p;distance=t.distance end
        end
    end
    return best
end
local function trainerSnapshot()
    local id=tonumber((UnitGUID("npc") or ""):match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    local isClass=false
    for _,r in ipairs(classTrainers()) do if r[8]==id then isClass=true;break end end
    if not isClass then return end
    local count=0
    for i=1,(N.Call(GetNumTrainerServices) or 0) do
        local _,kind=N.Call(GetTrainerServiceInfo,i)
        if kind=="available" then count=count+1 end
    end
    local s=state();s.trainer={name=UnitName("npc") or "Class trainer",count=count,level=UnitLevel("player"),at=time()}
    s.trainerReminder=nil;A.dirty=true
end
local function publish(result)
    if WoWUNotifications then
        WoWUNotifications.Collect(function(a)if not state().dismissed[a.key]then result[#result+1]=a end end)
        WoWUNotifications.Observe(result)
    end
    table.sort(result,function(a,b)if(a.priority or 0)~=(b.priority or 0)then return(a.priority or 0)>(b.priority or 0)end;return(a.key or a.title or '')<(b.key or b.title or '')end)
    A.alerts=result
end
function A.Refresh()
    local s=state();local result={}
    local function add(a) if not s.dismissed[a.key] then result[#result+1]=a end end
    local points=WoWU_GetAvailableTalentPoints and WoWU_GetAvailableTalentPoints() or 0
    if points>(s.lastTalentPoints or 0) then s.talentAlertGeneration=(s.talentAlertGeneration or 0)+1 end
    s.lastTalentPoints=points
    if points>0 and enabled("talents")then
        local caption=points..(points==1 and " Talent point is available" or " Talent points are available")
        add({key="talents:"..(s.talentAlertGeneration or 0),kind="talents",priority=100,
            title=caption,popup=caption,detail="Open Talents to allocate your points, then Apply changes to learn them.",
            icon="Interface\\Icons\\Ability_Marksmanship",page="Talents"})
    end
    if N.IsDead() then
        add({key="corpse",title="Return to your corpse",detail="Corpse guidance has priority. Other navigation resumes when you are alive.",icon="Interface\\Icons\\Ability_Rogue_FeignDeath"})
        publish(result);return
    end
    if type(HasNewMail)=="function"then
        local pending=N.Call(HasNewMail)and true or false
        if pending and not s.mailPending then s.mailGeneration=(s.mailGeneration or 0)+1 end
        s.mailPending=pending;A.mailPending=pending
        if pending and enabled("mail")then
            add({key="mail:"..(s.mailGeneration or 0),kind="mail",priority=80,title="You have mail",popup="New mail is waiting at a mailbox.",icon=133469,action='mail',actionText='Open Mail',
                detail="Visit a mailbox to read or collect your mail. WoWU opens mail in Bags while you interact with the mailbox."})
        end
    end
    local bagAlert=WoWUQoL and WoWUQoL.BagAlert()
    if bagAlert and enabled('supplies')then add(bagAlert)end
    if enabled("upgrades") then for _,a in ipairs(A.upgrades) do add(a) end end
    if enabled("trainer") and (s.trainerReminder or s.trainer and s.trainer.count>0) then
        local t=s.trainer;local point=nearestTrainer()
        add({key="trainer:"..(s.trainerReminder or (t.name..":"..t.level..":"..t.count)),kind="trainer",popup=s.trainerReminder and "New skills may be available. Visit your class trainer." or "Training was available at your last visit. Check your class trainer.",title=s.trainerReminder and "Check your class trainer" or "Class training available at last visit",
            detail=s.trainerReminder and "You gained a level. New training may be available; visit your trainer to confirm." or (t.count.." available services at "..t.name.." when last checked. Availability may have changed."),
            icon="Interface\\MINIMAP\\TRACKING\\Class",point=point})
    end
    local targetName=N.Text(N.Call(UnitName,"target"))
    local classification=N.Text(N.Call(UnitClassification,"target"))
    local liveRare=not (WoWUClient.isRetail and InCombatLockdown()) and enabled("rares") and targetName and (classification=="rare" or classification=="rareelite") and not UnitIsDead("target")
    if liveRare then
        local caption=(classification=="rareelite" and "Rare Elite: " or "Rare: ")..targetName.." is lurking nearby."
        local x,y=N.Vector(N.Call(C_Map and C_Map.GetPlayerMapPosition,currentMap(),"player"))
        local point=x and {mapID=currentMap(),x=x,y=y,name=targetName,category='rares'}or nil
        add({key="liveRare:"..(UnitGUID("target") or targetName),kind='rares',title=caption,popup=caption,priority=60,
            detail="Your current target is a living rare creature. Track records your current position, not the creature's exact coordinates.",icon="Interface\\Icons\\Ability_Creature_Cursed_02",point=point,actionText='Track Rare'})
    end
    local map=currentMap()
    if enabled("rares") and map and WoWUExplorer then
        local added=0
        for _,p in ipairs(WoWUExplorer.Points(map)) do
            if p.category=="rares" and not (liveRare and p.name==targetName) then
                local t=N.PointDestination(p,map)
                if t and t.distance<=500 and added<5 then
                    added=added+1;add({key="rare:"..p.mapID..":"..p.name,title="Known rare location: "..p.name,quiet=true,archiveDisabled=true,
                        detail=math.floor(t.distance).." yd away. Saved/native location, not a confirmed live spawn. "..(p.note or ""),icon=p.icon,point=p})
                end
            end
        end
    end
    if enabled("supplies") then
        local free=0
        for bag=0,WoWUClient.LastBag() do free=free+(N.Call(C_Container and C_Container.GetContainerNumFreeSlots,bag) or 0) end
        if free>4 then s.bagEpisode=false end
        if free>0 and free<=4 and not bagAlert then
            if not s.bagEpisode then s.bagEpisode=true;s.bagGeneration=(s.bagGeneration or 0)+1 end
            add({key="bags:"..s.bagGeneration,kind='supplies',title="Bags nearly full",detail=free.." free slots across your bags. Clear some space before collecting more loot.",icon="Interface\\Icons\\INV_Misc_Bag_08",page="Bags"})
        end
        local lowest=1
        for slot=1,19 do local cur,max=N.Call(GetInventoryItemDurability,slot);if cur and max and max>0 then lowest=math.min(lowest,cur/max) end end
        if lowest>=.25 then s.repairEpisode=false end
        if lowest<.25 then
            if not s.repairEpisode then s.repairEpisode=true;s.repairGeneration=(s.repairGeneration or 0)+1 end
            local point
            if map and WoWUExplorer then for _,p in ipairs(WoWUExplorer.Points(map)) do if p.category=="repairs" then point=p;break end end end
            add({key="repair:"..s.repairGeneration,kind='supplies',title="Equipment needs repair",detail="Lowest item durability: "..math.floor(lowest*100).."%.",icon="Interface\\MINIMAP\\TRACKING\\Repair",page='Character',point=point,actionText='Open Character'})
        end
    end
    publish(result)
end
local moneyBaseline,trainerOpen
local function moneyChanged()
    local value=N.Number(N.Call(GetMoney));if not value then return end
    if moneyBaseline then
        local difference=value-moneyBaseline;local ledger=state().ledger
        if difference>0 then ledger.gained=ledger.gained+difference elseif difference<0 then ledger.spent=ledger.spent-difference end
    end
    moneyBaseline=value
end
local function lootMessage(message,sender,...)
    if not WoWUClient.Public(message) or type(message)~="string" then return end
    local link=message:match("(|c%x+|Hitem:.-|h.-|h|r)") or message:match("(|Hitem:.-|h.-|h)")
    if not link then return end
    local selfLoot=false;local amount=1
    for _,format in ipairs({LOOT_ITEM_SELF_MULTIPLE or "",LOOT_ITEM_SELF or "",LOOT_ITEM_CREATED_SELF_MULTIPLE or "",LOOT_ITEM_CREATED_SELF or "",LOOT_ITEM_PUSHED_SELF_MULTIPLE or "",LOOT_ITEM_PUSHED_SELF or ""}) do
        if format~="" then
            local pattern=format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
            pattern=pattern:gsub("%%%%s","(.+)"):gsub("%%%%d","(%%d+)")
            local item,count=message:match("^"..pattern.."$")
            if item then selfLoot=true;amount=tonumber(count) or 1;break end
        end
    end
    if not selfLoot then return end -- Do not count another player's loot.
    local l=state().ledger;l.items=l.items+amount
    table.insert(l.entries,1,{link=link,count=amount,at=time()})
    while #l.entries>50 do table.remove(l.entries) end
    A.dirty=true
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_MONEY","CHAT_MSG_LOOT","PLAYER_LEVEL_UP","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED","TRAINER_SHOW","TRAINER_UPDATE","TRAINER_CLOSED","ZONE_CHANGED_NEW_AREA","PLAYER_TARGET_CHANGED","UPDATE_INVENTORY_DURABILITY","UPDATE_PENDING_MAIL","MAIL_INBOX_UPDATE","MAIL_SHOW","MAIL_CLOSED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,e,...)
    if e=="UPDATE_PENDING_MAIL"or e=="MAIL_INBOX_UPDATE"or e=="MAIL_SHOW"or e=="MAIL_CLOSED"then A.Refresh()
    elseif e=="PLAYER_ENTERING_WORLD" then moneyBaseline=N.Number(N.Call(GetMoney));A.dirty=true
    elseif e=="PLAYER_MONEY" then moneyChanged()
    elseif e=="CHAT_MSG_LOOT" then lootMessage(...)
    elseif e=="PLAYER_LEVEL_UP" and not WoWUClient.isRetail then state().trainerReminder=tonumber((...)) or UnitLevel("player")
    elseif e=="TRAINER_SHOW" then trainerOpen=true;trainerSnapshot()
    elseif e=="TRAINER_UPDATE" and trainerOpen then trainerSnapshot()
    elseif e=="TRAINER_CLOSED" then trainerOpen=false
    elseif e=="BAG_UPDATE_DELAYED" or e=="PLAYER_EQUIPMENT_CHANGED" or e=="GET_ITEM_INFO_RECEIVED" then A.dirty=true end
end)
local function text(parent,value,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal");f:SetFont("Fonts\\FRIZQT__.TTF",size or 13,"");WoWU_Theme.TextColor(f,.95,.83,.57);f:SetJustifyH("LEFT");f:SetText(value);return f
end
local function button(parent,caption,w,h,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(w,h)
    b.label=text(b,caption,13);b.label:SetPoint("CENTER");WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",callback);return b
end
local function redButton(parent,caption,w,h,callback)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,h);b:SetText(caption)
    b.label=b:GetFontString();b.label:SetFont('Fonts\\FRIZQT__.TTF',16,'');b:SetScript('OnClick',callback);return b
end
local function coins(value)
    local sign=value<0 and "-" or "";value=math.floor(math.abs(value))
    return sign..math.floor(value/10000).."g "..math.floor(value%10000/100).."s "..(value%100).."c"
end
function WoWU_BuildAdventure(parent,middle,holder)
    A.dashboard=parent
    local strip=button(middle,"",414,66,function() end)
    strip:SetPoint("TOP",holder,"BOTTOM",0,-8)
    strip:Hide()
    -- Nine-slice dialog art retains proper corners and edges at banner proportions.
    WoWU_Theme.Backdrop(strip,{bgFile=WoWU_Theme.assets.marble,edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true,tileSize=128,edgeSize=28,insets={left=9,right=9,top=9,bottom=9}})
    WoWU_Theme.Fill(strip,.10,.16,.22,1);WoWU_Theme.Border(strip,1,.79,.35,1)
    strip.label:SetWidth(370);strip.label:SetHeight(46);strip.label:SetFont("Fonts\\FRIZQT__.TTF",18,"");strip.label:SetWordWrap(true);strip.label:SetJustifyH("CENTER");strip.label:SetJustifyV("MIDDLE")
    WoWU_Theme.TextColor(strip.label,1,.94,.72);strip.label:SetShadowColor(0,0,0,1);strip.label:SetShadowOffset(WoWU_Theme.light and 0 or 1,WoWU_Theme.light and 0 or -1)
    local glow=CreateFrame("Frame",nil,strip,"BackdropTemplate")
    glow:SetPoint("TOPLEFT",-4,4);glow:SetPoint("BOTTOMRIGHT",4,-4);glow:EnableMouse(false)
    glow:SetFrameLevel(strip:GetFrameLevel())
    WoWU_Theme.Backdrop(glow,{edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=20})
    WoWU_Theme.Border(glow,1,.65,.12,.42)
    strip:SetScript("OnUpdate",function() glow:SetAlpha(.55+.15*math.sin(GetTime()*2)) end)
    local popup
    local view=CreateFrame("Frame",nil,parent,"BackdropTemplate");view:SetAllPoints(parent);view:SetFrameLevel(parent:GetFrameLevel()+100);view:EnableMouse(true);WoWU_Theme.Panel(view,"outer",false);view:Hide()
    local title=text(view,"Adventure Log",27);title:SetPoint("TOPLEFT",24,-20)
    local status=text(view,"",16);status:SetPoint("BOTTOMLEFT",24,18);status:SetWidth(950)
    local close=redButton(view,"Back to Dashboard",210,42,function() view:Hide() end);close:SetPoint("TOPRIGHT",-22,-15)
    local section="Alerts";local refresh;local tabs={}
    for i,name in ipairs({"Alerts","History","Gold / Loot","Options"}) do
        tabs[name]=button(view,name,170,40,function() section=name;if WoWUNotifications then WoWUNotifications.MarkRead()end;refresh(true) end);tabs[name]:SetPoint("TOPLEFT",24+(i-1)*180,-60);tabs[name].label:SetFont('Fonts\\FRIZQT__.TTF',17,'')
    end
    local scroll=CreateFrame("ScrollFrame",nil,view,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",24,-108);scroll:SetPoint("BOTTOMRIGHT",-45,58)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(1050,1);scroll:SetScrollChild(body);WoWU_EnableTouchScroll(scroll);WoWU_Theme.Scrollbar(scroll)
    local rows={}
    local function data()
        if section=="Alerts" then
            local list={};for _,a in ipairs(A.alerts) do list[#list+1]=a end
            if #list==0 then list[1]={title="You are all caught up",detail="Requests, reminders and updates appear here. Previous notifications are kept in History."} end
            return list
        elseif section=="History"then return WoWUNotifications and WoWUNotifications.History()or {}
        elseif section=="Options" then
            return {{title="Equipment upgrade candidates",option="upgrades"},{title="Class trainer reminders",option="trainer"},{title="Rare detections and known locations",option="rares",detail="Only actual rare detections produce a popup. Known locations stay in the log."},{title="Bag space and durability alerts",option="supplies"},{title="New mail notifications",option="mail"},
                {title="Talent points available",option="talents"},{title="Invites, queues, summons and checks",option="requests",detail="The native response buttons remain on WoWU, even if this log category is disabled."},{title="Auction updates",option="auctions"},{title="Crafting finished",option="crafting"},{title="Fishing lure expired",option="fishing"},{title="Calendar event reminders",option="calendar"},{title="Notification sounds",option="sounds"},{title="Quiet during combat",option="quietCombat",detail="Pause ordinary popup banners and sounds during combat. Urgent game prompts remain available."},
                {title="Restore dismissed alerts",detail="Show previously dismissed reminders and candidates again.",resetDismissed=true}}
        end
        local l=state().ledger;local list={
            {title="Gold since reset: "..coins(l.gained-l.spent),detail="Money gained: "..coins(l.gained).."    -    Money spent: "..coins(l.spent)..". Includes all observed money changes, not only loot."},
            {title=l.items.." items received since reset",detail="Started "..date("%d %b %Y %H:%M",l.started)..". The latest 50 item receipts are listed below; quantities are not unique item counts."},
            {title="Reset Gold / Loot",detail="Start a new tracking period for this character.",resetLedger=true}}
        for _,entry in ipairs(l.entries) do
            local info=itemInfo(entry.link)
            list[#list+1]={title=(info and info[1] or entry.link).." x"..entry.count,link=entry.link,icon=info and info[10],
                detail=date("%H:%M",entry.at).."  -  "..(info and ("Vendor value: "..coins((info[11] or 0)*entry.count).." (estimate, not gold earned)") or "Item details loading")}
        end
        return list
    end
    local resetArmed=false
    refresh=function(reset)
        if not view:IsShown() then return end
        for name,tab in pairs(tabs) do WoWU_Theme.Tab(tab,section==name) end
        local list=data();local width=math.max(400,scroll:GetWidth()-4);body:SetWidth(width)
        for i,entry in ipairs(list) do
            local row=rows[i]
            if not row then
                row=button(body,"",width,120,function() end);row.label:Hide();WoWU_Theme.Panel(row)
                row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(44,44);row.icon:SetPoint("TOPLEFT",15,-18)
                row.title=text(row,"",21);row.title:SetPoint("TOPLEFT",74,-14);row.title:SetHeight(28);row.title:SetWordWrap(false)
                row.detail=text(row,"",16);row.detail:SetPoint("TOPLEFT",74,-48);row.detail:SetHeight(60);row.detail:SetWordWrap(true);row.detail:SetJustifyV('TOP');WoWU_Theme.TextColor(row.detail,.94,.9,.8)
                row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.check:SetSize(32,32);row.check:SetPoint("TOPLEFT",12,-12)
                row.check:SetScript("OnClick",function(self)
                    if not WoWU_TouchTapAllowed(scroll) then self:SetChecked(enabled(row.entry.option));return end
                    state().options[row.entry.option]=self:GetChecked() and true or false;A.Refresh();refresh()
                end)
                row.dismiss=redButton(row,"Dismiss",180,38,function()
                    if not WoWU_TouchTapAllowed(scroll) then return end
                    if row.entry.key then if WoWUNotifications then WoWUNotifications.Dismiss(row.entry.key)else state().dismissed[row.entry.key]=true end;A.Refresh();refresh() end
                end);row.dismiss:SetPoint("TOPRIGHT",-8,-8)
                row.action=redButton(row,"",180,42,function()
                    if not WoWU_TouchTapAllowed(scroll) then return end
                    local a=row.entry
                    if a.action or a.prompt then
                        local ok,msg=WoWUNotifications.Act(a);if ok then view:Hide()else status:SetText(msg)end
                    elseif a.kind=="talents" then
                        if InCombatLockdown and InCombatLockdown() then status:SetText("Open Talents after combat.");return end
                        view:Hide();WoWU_ShowPage("Talents")
                    elseif a.link then
                        if InCombatLockdown and InCombatLockdown() then status:SetText("Open Bags after combat.");return end
                        local ok,msg=WoWU_ShowBagItem(a.link)
                        if ok then view:Hide() else status:SetText(msg or "Item is no longer in your bags.");A.dirty=true end
                    elseif a.page then
                        if not InCombatLockdown()then view:Hide();WoWU_ShowPage(a.page)end
                    elseif a.point then local ok,msg=N.SetDestination(a.point);status:SetText(ok and ("Navigating to "..a.point.name) or msg)
                    else status:SetText("No known trainer location is available for navigation here.") end
                end);row.action:SetPoint("BOTTOMRIGHT",-8,8)
                row:SetScript("OnClick",function(self)
                    if not WoWU_TouchTapAllowed(scroll) then return end
                    local a=self.entry
                    if a.action or a.prompt then
                        local ok,msg=WoWUNotifications.Act(a);if ok then view:Hide()else status:SetText(msg)end
                    elseif a.option then state().options[a.option]=not enabled(a.option);A.Refresh();refresh()
                    elseif a.resetDismissed then state().dismissed={};state().notified={};A.Refresh();refresh();status:SetText("Dismissed alerts restored.")
                    elseif a.resetLedger then
                        if not resetArmed then resetArmed=true;status:SetText("Tap Reset Gold / Loot again to clear this character's totals and recent receipts.");return end
                        state().ledger={started=time(),gained=0,spent=0,items=0,entries={}};moneyBaseline=GetMoney();resetArmed=false;refresh();status:SetText("New tracking period started.")
                    elseif a.point then local ok,msg=N.SetDestination(a.point);status:SetText(ok and ("Navigating to "..a.point.name) or msg)
                    elseif a.link then
                        if InCombatLockdown and InCombatLockdown() then status:SetText("Open Bags after combat.");return end
                        local ok,msg=WoWU_ShowBagItem(a.link);if ok then view:Hide() else status:SetText(msg);A.dirty=true end
                    elseif a.page then if not (InCombatLockdown and InCombatLockdown()) then view:Hide();WoWU_ShowPage(a.page) end end
                end)
                row:SetScript("OnEnter",function(self)
                    if self.entry.link and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.entry.link) end
                end)
                row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);WoWUDetails.BindHover(row,false)
                rows[i]=row
            end
            row.entry=entry;row:SetWidth(width);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(i-1)*130)
            row.title:SetWidth(width-290);row.detail:SetWidth(width-290)
            WoWU_Theme.Border(row,entry.requiresAction and 1 or .65,entry.requiresAction and .8 or .65,entry.requiresAction and .3 or .65,1)
            row.title:SetText(entry.title);row.detail:SetText(entry.detail or "Tap the checkbox to change this alert.")
            row.icon:SetTexture(entry.icon);row.icon:SetShown(entry.icon~=nil);row.check:SetShown(entry.option~=nil)
            if entry.option then row.check:SetChecked(enabled(entry.option)) end
            local actionable=entry.action~=nil or entry.prompt~=nil or entry.kind=="talents" or entry.link~=nil or entry.kind=="trainer" or entry.point~=nil or entry.page~=nil
            row.action:SetShown(actionable);row.action:SetText(entry.actionText or(entry.kind=="talents" and "Spend Talent points" or entry.link and "Show in Bag" or entry.page=="Bags"and "Open Bags"or entry.page=="Character"and "Open Character"or entry.kind=="trainer" and "Navigate to Trainer" or "Navigate"))
            row.action:SetEnabled(actionable);row.action:SetAlpha(1)
            row.dismiss:SetShown(entry.key~=nil and entry.key~="corpse"and not entry.requiresAction);row:Show()
        end
        for i=#list+1,#rows do rows[i]:Hide() end
        body:SetHeight(math.max(scroll:GetHeight(),#list*130))
        scroll:SetVerticalScroll(reset and 0 or math.min(scroll:GetVerticalScroll(),math.max(0,body:GetHeight()-scroll:GetHeight())))
    end
    local function openHub()
        if InCombatLockdown and InCombatLockdown() then return false end
        WoWU_ShowPage("Dashboard")
        if A.dirty then A.upgrades=scanUpgrades();A.dirty=false end
        A.Refresh();for _,alert in ipairs(A.alerts) do state().notified[alert.key]=true end;if WoWUNotifications then WoWUNotifications.MarkRead()end
        popup=nil;strip:Hide();view:Show();refresh(true);return true
    end
    WoWU_OpenAdventure=openHub
    strip:SetScript("OnClick",function()
        if popup and popup.kind=="bagfull"then
            if InCombatLockdown()then return end
            state().notified[popup.key]=true;popup=nil;strip:Hide();WoWU_ShowPage("Bags")
        else openHub()end
    end)
    view:SetScript("OnHide",function() resetArmed=false;if GameTooltip then GameTooltip:Hide() end end)
    local elapsed=0;local popupStarted=0
    parent:HookScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
        if WoWUNotifications then WoWUNotifications.Tick()end
        if A.dirty then A.upgrades=scanUpgrades();A.dirty=false end
        A.Refresh()
        local current={};for _,a in ipairs(A.alerts)do current[a.key]=a end
        if popup then
            local active=current[popup.key]
            if not active or (not active.requiresAction and GetTime()-popupStarted>=8)then popup=nil else popup=active end
        end
        for _,a in ipairs(A.alerts)do
            if not a.quiet and not state().notified[a.key]and (not popup or(a.priority or 0)>(popup.priority or 0))then
                if popup then state().notified[popup.key]=nil end;popup=nil;break
            end
        end
        local quiet=enabled('quietCombat')and InCombatLockdown and InCombatLockdown()
        if popup and quiet and not popup.requiresAction then
            -- Defer rather than consume an ordinary alert during combat.
            state().notified[popup.key]=nil;popup=nil
        end
        if view:IsShown()then
            for _,a in ipairs(A.alerts)do state().notified[a.key]=true end
            if WoWUNotifications then WoWUNotifications.MarkRead()end
            popup=nil;strip:Hide()
        else
            if not popup and (not WoWU_GetPreference or WoWU_GetPreference('popups'))then
                for _,a in ipairs(A.alerts)do
                    if not a.quiet and (a.requiresAction or not state().notified[a.key])and (a.requiresAction or not quiet)then
                        popup=a;popupStarted=GetTime();state().notified[a.key]=true;break
                    end
                end
            end
            if WoWU_GetPreference and not WoWU_GetPreference('popups')then popup=nil end
            if popup then
                strip.label:SetText(popup.popup or popup.title);strip:Show()
            else
                strip.label:SetText('');strip:Hide()
            end
        end
        local unread=WoWUNotifications and WoWUNotifications.Unread()or 0
        title:SetText('Adventure Log'..(unread>0 and (' ('..unread..' unread)')or ''))
        refresh()
    end)
    return strip,view
end
