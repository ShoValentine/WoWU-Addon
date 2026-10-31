-- WoWU achievements v0.9.6: read-only achievement browser.
-- Never change or parent Blizzard's own AchievementFrame.
local function safe(fn,...)
    if type(fn) ~= "function" then return nil end
    local ok,a,b,c,d,e,f,g,h,j,k=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,j,k end
end
local function text(parent,size,colour)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    WoWU_Theme.TextColor(t,unpack(colour or {.95,.80,.51}))
    t:SetJustifyH("LEFT")
    return t
end
local function frame(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Color(f,.09,.13,.15,.98);WoWU_Theme.Panel(f)
    return f
end
local function scroller(panel)
    local sf=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(sf) end
    sf:SetPoint("TOPLEFT",12,-12);sf:SetPoint("BOTTOMRIGHT",-30,12)
    local body=CreateFrame("Frame",nil,sf)
    body:SetSize(300,620);sf:SetScrollChild(body)
    return sf,body
end

-- Draw completion marks as geometry, avoiding unsupported font glyphs.
local function mark(parent)
    local f=CreateFrame("Frame",nil,parent);f:SetSize(20,20)
    f.a=f:CreateLine(nil,"OVERLAY");f.b=f:CreateLine(nil,"OVERLAY")
    f.a:SetThickness(3);f.b:SetThickness(3)
    function f:SetComplete(done)
        local r,g,b=done and .2 or .95,done and .95 or .2,.18
        self.a:SetColorTexture(r,g,b,1);self.b:SetColorTexture(r,g,b,1)
        if done then
            self.a:SetStartPoint("TOPLEFT",self,2,-10);self.a:SetEndPoint("TOPLEFT",self,8,-16)
            self.b:SetStartPoint("TOPLEFT",self,8,-16);self.b:SetEndPoint("TOPLEFT",self,18,-3)
        else
            self.a:SetStartPoint("TOPLEFT",self,4,-4);self.a:SetEndPoint("TOPLEFT",self,16,-16)
            self.b:SetStartPoint("TOPLEFT",self,4,-16);self.b:SetEndPoint("TOPLEFT",self,16,-4)
        end
    end
    return f
end
function WoWU_CreateAchievements(parent)
    local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();root:Hide()
    local heading=text(root,23);heading:SetPoint("TOPLEFT",24,-17);heading:SetText("Achievements")
    local points=text(root,14);points:SetPoint("TOPRIGHT",-24,-24)
    local categories=frame(root);categories:SetPoint("TOPLEFT",14,-65);categories:SetPoint("BOTTOMLEFT",14,14);categories:SetWidth(260)
    local middle=frame(root);middle:SetPoint("TOPLEFT",categories,"TOPRIGHT",10,0);middle:SetPoint("BOTTOMLEFT",categories,"BOTTOMRIGHT",10,0);middle:SetWidth(420)
    local details=frame(root);details:SetPoint("TOPLEFT",middle,"TOPRIGHT",10,0);details:SetPoint("BOTTOMRIGHT",-14,14)
    local background=details:CreateTexture(nil,"BACKGROUND",nil,1);background:SetPoint("TOPLEFT",6,-6);background:SetPoint("BOTTOMRIGHT",-6,6);background:SetTexture(WoWU_Theme.assets.marble);if WoWU_Theme.light then background:SetVertexColor(1,1,1,.25)else background:SetVertexColor(.42,.29,.16,.65)end
    local catScroll,catBody=scroller(categories)
    local listScroll,listBody=scroller(middle)
    local detailScroll,detailBody=scroller(details)
    for _,scroll in ipairs({catScroll,listScroll,detailScroll})do WoWU_Theme.Scrollbar(scroll)end
    local listTitle=text(middle,16);listTitle:SetPoint("TOPLEFT",15,-15);listTitle:SetWidth(385)
    listScroll:ClearAllPoints();listScroll:SetPoint("TOPLEFT",12,-49);listScroll:SetPoint("BOTTOMRIGHT",-30,12)
    local catRows,achRows,criteria={},{},{}
    local expanded,categoryData,children,ordered={},{},{},{}
    local current="recent";local selected;local allAchievements={};local recent={}
    local refresh,drawCategories,drawList,inspect
    local icon=detailBody:CreateTexture(nil,"ARTWORK");icon:SetSize(64,64);icon:SetPoint("TOPLEFT",10,-12);WoWU_Theme.IconRim(detailBody,icon,76)
    local name=text(detailBody,19);name:SetPoint("TOPLEFT",84,-12);name:SetWordWrap(true)
    local completion=mark(detailBody);completion:SetPoint("TOPLEFT",84,-68)
    local meta=text(detailBody,12);meta:SetPoint("LEFT",completion,"RIGHT",7,0)
    local description=text(detailBody,15,{.88,.82,.69});description:SetPoint("TOPLEFT",10,-106);description:SetWordWrap(true)
    local progress=CreateFrame("StatusBar",nil,detailBody,"BackdropTemplate");progress:SetHeight(19);progress:SetStatusBarTexture(WoWU_Theme.assets.statusbar);progress:SetStatusBarColor(.7,.51,.13);progress:SetMinMaxValues(0,1)
    WoWU_Theme.Backdrop(progress,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12});WoWU_Theme.Fill(progress,.06,.04,.02,1)
    local progressText=text(progress,12);progressText:SetPoint("CENTER")
    local function width(body,scroll)
        local w=math.max(100,scroll:GetWidth()-4);body:SetWidth(w);return w
    end
    local function achievement(id)
        local a,n,pts,done,month,day,year,desc,flags,texture=safe(GetAchievementInfo,id)
        if not a then return end
        return {id=a,name=n or "Achievement",points=pts or 0,done=done,month=month,day=day,year=year,description=desc or "",icon=texture,
            dateKey=(year or 0)*10000+(month or 0)*100+(day or 0)}
    end
    inspect=function(id,reset)
        selected=id
        for _,row in ipairs(criteria)do row:Hide()end
        local w=width(detailBody,detailScroll);name:SetWidth(w-90);description:SetWidth(w-20)
        local a=id and achievement(id)
        if not a then
            icon:Hide();completion:Hide();meta:SetText("");progress:Hide();name:SetText("Achievement details")
            description:SetText(current=="recent" and "No recently unlocked achievements are available yet. Browse the categories to find your next goal." or "Select an achievement to view its objectives.")
            detailBody:SetHeight(detailScroll:GetHeight());return
        end
        icon:SetTexture(a.icon or 134400);icon:Show();name:SetText(a.name);completion:Show();completion:SetComplete(a.done)
        local dateText=a.done and a.month and a.day and a.year and string.format(" | %02d/%02d/%04d",a.day,a.month,a.year<100 and 2000+a.year or a.year) or ""
        meta:SetText((a.done and "Unlocked" or "Incomplete").." | "..a.points.." points"..dateText);meta:SetWidth(w-115)
        description:SetText(a.description)
        local y=math.max(126,110+description:GetStringHeight()+18)
        local count=tonumber((safe(GetAchievementNumCriteria,id)))or 0;local completed=0
        progress:ClearAllPoints();progress:SetPoint("TOPLEFT",10,-y);progress:SetWidth(w-20);y=y+36
        for i=1,count do
            local label,_,done,quantity,required=safe(GetAchievementCriteriaInfo,id,i)
            if done then completed=completed+1 end
            local row=criteria[i]
            if not row then
                row=CreateFrame("Frame",nil,detailBody);row.mark=mark(row);row.mark:SetPoint("TOPLEFT",1,-5)
                row.label=text(row,14,{.88,.84,.73});row.label:SetPoint("TOPLEFT",30,-5);row.label:SetWordWrap(true);criteria[i]=row
            end
            row:ClearAllPoints();row:SetPoint("TOPLEFT",8,-y);row:SetWidth(w-16);row.mark:SetComplete(done)
            local amount=type(quantity)=="number" and type(required)=="number" and required>1 and (" ("..quantity.."/"..required..")")or ""
            row.label:SetWidth(w-54);row.label:SetText((label or "Objective")..amount)
            local h=math.max(34,row.label:GetStringHeight()+16);row:SetHeight(h);row:Show();y=y+h+4
        end
        progress:SetShown(count>0);progress:SetValue(count>0 and completed/count or 0);progressText:SetText(completed.." / "..count.." objectives")
        detailBody:SetHeight(math.max(detailScroll:GetHeight(),y+12));if reset then detailScroll:SetVerticalScroll(0)end
    end
    drawList=function(reset)
        local ids=current=="recent" and recent or (categoryData[current] and categoryData[current].achievements or {})
        listTitle:SetText(current=="recent" and "Recently unlocked achievements" or categoryData[current] and categoryData[current].name or "Achievements")
        local w=width(listBody,listScroll)
        for i,id in ipairs(ids)do
            local a=allAchievements[id] or achievement(id)
            local b=achRows[i]
            if not b then
                b=CreateFrame("Button",nil,listBody,"BackdropTemplate");b.label=text(b,14);b.label:SetPoint("TOPLEFT",58,-10);b.label:SetWordWrap(true)
                b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(40,40);b.icon:SetPoint("TOPLEFT",9,-11)
                b.mark=mark(b);b.mark:SetPoint("BOTTOMRIGHT",-8,7)
                b.meta=text(b,11,{.75,.70,.57});b.meta:SetPoint("BOTTOMLEFT",58,10)
                b:SetScript("OnClick",function(self)if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(listScroll)then return end;inspect(self.id,true);drawList(false)end)
                achRows[i]=b
            end
            b.id=id;b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(i-1)*78);b:SetSize(w,72)
            WoWU_Theme.Backdrop(b,{bgFile=WoWU_Theme.assets.marble,edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
            WoWU_Theme.Fill(b,a and a.done and .24 or .09,a and a.done and .18 or .11,.08,.96);WoWU_Theme.Border(b,selected==id and 1 or .62,selected==id and .82 or .49,.22,1)
            b.label:SetWidth(w-70);b.label:SetHeight(33);b.label:SetText(a and a.name or "Loading achievement...")
            b.icon:SetTexture(a and a.icon or 134400);b.mark:SetComplete(a and a.done);b.meta:SetText(a and (a.points.." points | "..(a.done and "Unlocked" or "Incomplete"))or "");b:Show()
        end
        for i=#ids+1,#achRows do achRows[i]:Hide()end
        listBody:SetHeight(math.max(listScroll:GetHeight(),#ids*78));if reset then listScroll:SetVerticalScroll(0)end
        local found=false;for _,id in ipairs(ids)do if id==selected then found=true;break end end
        if not found then inspect(ids[1],true)end
        if #ids==0 then inspect(nil,true)end
    end
    drawCategories=function()
        local entries={{name="Recently unlocked",id="recent",depth=0}}
        local emitted={}
        local function append(id,depth)
            if emitted[id]then return end;emitted[id]=true
            local d=categoryData[id];if not d or d.hidden then return end
            local hasChildren=#(children[id]or {})>0
            entries[#entries+1]={id=id,name=d.name,depth=depth,header=hasChildren}
            if hasChildren and expanded[id]then
                if #d.achievements>0 then entries[#entries+1]={id=id,name="Overview",depth=depth+1}end
                for _,child in ipairs(children[id])do append(child,depth+1)end
            end
        end
        for _,id in ipairs(ordered)do local d=categoryData[id];if d and (d.parent==-1 or not categoryData[d.parent])then append(id,0)end end
        local w=width(catBody,catScroll);local y=0
        for i,e in ipairs(entries)do
            local b=catRows[i]
            if not b then
                b=CreateFrame("Button",nil,catBody,"BackdropTemplate");b.label=text(b,14);b.label:SetJustifyV("MIDDLE");b.label:SetWordWrap(true);catRows[i]=b
                b:SetScript("OnClick",function(self)
                    if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(catScroll)then return end
                    local e=self.entry
                    if e.header then expanded[e.id]=not expanded[e.id]else current=e.id;selected=nil;drawList(true)end
                    drawCategories()
                end)
            end
            b.entry=e;b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y);b:SetSize(w,e.header and 36 or 43)
            b.label:ClearAllPoints();b.label:SetPoint("LEFT",8+math.min(e.depth,4)*13,0);b.label:SetPoint("RIGHT",-8,0)
            b.label:SetText((e.header and (expanded[e.id] and "- "or "+ ")or "")..e.name)
            WoWU_Theme.Backdrop(b,{bgFile=WoWU_Theme.assets.marble,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
            WoWU_Theme.Fill(b,e.header and .3 or .07,e.header and .13 or .10,.035,.95)
            WoWU_Theme.Border(b,current==e.id and not e.header and 1 or .5,.39,.15,1)
            WoWU_Theme.TextColor(b.label,e.header and 1 or .9,e.header and .8 or .84,e.header and .2 or .68);b:Show();y=y+b:GetHeight()+4
        end
        for i=#entries+1,#catRows do catRows[i]:Hide()end
        catBody:SetHeight(math.max(catScroll:GetHeight(),y));catScroll:SetVerticalScroll(math.min(catScroll:GetVerticalScroll(),math.max(0,y-catScroll:GetHeight())))
    end
    refresh=function(reset)
        categoryData={};children={};ordered={};allAchievements={};recent={}
        points:SetText("Total points: "..tostring(safe(GetTotalAchievementPoints)or 0))
        local source=safe(GetCategoryList)or {};local pairsInOrder={}
        for key,id in pairs(source)do if type(key)=="number" and type(id)=="number"then pairsInOrder[#pairsInOrder+1]={key,id}end end
        table.sort(pairsInOrder,function(a,b)return a[1]<b[1]end)
        for _,entry in ipairs(pairsInOrder)do
            local id=entry[2];local n,parentID=safe(GetCategoryInfo,id)
            if n then
                categoryData[id]={name=n,parent=parentID or -1,achievements={},hidden=n=="Do Not Display"}
                ordered[#ordered+1]=id;children[parentID or -1]=children[parentID or -1]or {};table.insert(children[parentID or -1],id)
            end
        end
        local function hidden(id,seen)
            local d=categoryData[id];if not d then return false end
            if d.hidden then return true end
            seen=seen or {};if seen[id]then return false end;seen[id]=true
            return hidden(d.parent,seen)
        end
        for _,id in ipairs(ordered)do
            local d=categoryData[id];d.hidden=hidden(id)
            if not d.hidden then
                local count=tonumber((safe(GetCategoryNumAchievements,id)))or 0
                for i=1,count do
                    local achievementID=safe(GetAchievementInfo,id,i)
                    if achievementID then
                        d.achievements[#d.achievements+1]=achievementID
                        if not allAchievements[achievementID]then
                            local a=achievement(achievementID);allAchievements[achievementID]=a
                            if a and a.done then recent[#recent+1]=achievementID end
                        end
                    end
                end
            end
        end
        local latestOrder={}
        if type(GetLatestCompletedAchievements)=="function"then
            local latest={pcall(GetLatestCompletedAchievements)}
            if latest[1]then for i=2,#latest do latestOrder[latest[i]]=i end end
        end
        table.sort(recent,function(a,b)
            local x,y=allAchievements[a],allAchievements[b]
            if x.dateKey~=y.dateKey then return x.dateKey>y.dateKey end
            if latestOrder[a] or latestOrder[b]then return (latestOrder[a]or math.huge)<(latestOrder[b]or math.huge)end
            return x.name<y.name
        end)
        while #recent>30 do table.remove(recent)end
        -- Only sibling categories are sorted; children never escape their parent.
        for _,ids in pairs(children)do table.sort(ids,function(a,b)return categoryData[a].name<categoryData[b].name end)end
        if current~="recent" and not categoryData[current]then current="recent"end
        drawCategories();drawList(reset);if selected then inspect(selected,reset)end
    end
    root:HookScript("OnShow",function()current="recent";selected=nil;refresh(true)end)
    local events=CreateFrame("Frame",nil,root);local dirty=false
    for _,event in ipairs({"ACHIEVEMENT_EARNED","CRITERIA_UPDATE","RECEIVED_ACHIEVEMENT_LIST"})do events:RegisterEvent(event)end
    events:SetScript("OnEvent",function()dirty=true end)
    local elapsed=0
    root:HookScript("OnUpdate",function(_,dt)elapsed=elapsed+dt;if dirty and elapsed>.5 then dirty=false;elapsed=0;refresh(false)end end)
    return root
end
