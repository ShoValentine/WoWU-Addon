-- WoWU spellbook: native book artwork and independent pages; no embedded Blizzard frames.
local spellBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local function font(parent, size, color)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    WoWU_Theme.TextColor(t,unpack(color or {0.94,0.80,0.55}))
    t:SetJustifyH("LEFT")
    return t
end
local function frame(parent, color)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=17,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Color(f,unpack(color or {.10,.13,.15,.97}))
    WoWU_Theme.Panel(f)
    return f
end
local function smallButton(parent,text,w,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w,36)
    WoWU_Theme.Backdrop(b,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(b,.22,.23,.22,1);WoWU_Theme.Border(b,.61,.48,.30,1)
    local t=font(b,14);t:SetPoint("CENTER");t:SetText(text);b.label=t
    b:SetScript("OnClick",callback);return b
end
local function call(fn,...)
    if type(fn)~="function"then return end
    local function pack(...)return {n=select("#",...),...}end
    local result=pack(pcall(fn,...));if result[1]then return unpack(result,2,result.n)end
end
local function atlas(texture,name)
    if call(C_Texture and C_Texture.GetAtlasInfo,name)then texture:SetAtlas(name);texture:Show();return true end
    texture:Hide();return false
end
local function ink(parent,size)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF",size,"");t:SetTextColor(.18,.105,.045);t:SetJustifyH("LEFT");return t
end
function WoWU_BuildSpells(panel)
    local spells,sections,visible,selected={},{},{},nil
    local filter,search,category="All","","Class"
    local showUnlearned=true
    local spread,leaves=1,{}
    local refresh,rebuild,selectSpell,openFlyout
    local dirty,searchAt=false,nil
    local top=CreateFrame("Frame",nil,panel)
    top:SetPoint("TOPLEFT",16,-8);top:SetPoint("TOPRIGHT",-16,-8);top:SetHeight(44)
    local categoryButtons={}
    local className=UnitClass("player")or "Class"
    for i,entry in ipairs({{"Class",className},{"General",GENERAL or "General"},{"Pet",PET or "Pet"}})do
        local key=entry[1];local b=smallButton(top,entry[2],130,function()category=key;spread=1;if refresh then refresh()end end)
        b:SetPoint("LEFT",(i-1)*138,0);categoryButtons[key]=b
    end
    local filterButton=smallButton(top,"All spells",120,function()
        filter=filter=="All"and "Active"or filter=="Active"and "Passive"or "All";spread=1;refresh()
    end);filterButton:SetPoint("RIGHT",-430,0)
    local futureButton=smallButton(top,"Unlearned: on",150,function()showUnlearned=not showUnlearned;spread=1;refresh()end);futureButton:SetPoint("RIGHT",-272,0)
    local searchBox=CreateFrame("EditBox",nil,top,"InputBoxTemplate")
    searchBox:SetSize(250,28);searchBox:SetAutoFocus(false);searchBox:SetPoint("RIGHT",-6,0);searchBox:SetMaxLetters(80)
    local searchHint=font(searchBox,12,{.6,.57,.5});searchHint:SetPoint("LEFT",6,0);searchHint:SetText("Search abilities...")
    searchBox:SetScript("OnTextChanged",function(self)search=string.lower(self:GetText()or "");searchHint:SetShown(search=="");searchAt=GetTime()+.18 end)
    searchBox:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    searchBox:SetScript("OnEnterPressed",function(self)self:ClearFocus();spread=1;refresh()end)
    local book=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    book:SetPoint("TOPLEFT",10,-60);book:SetPoint("BOTTOMRIGHT",-10,12);WoWU_Theme.Panel(book)
    local pageLeft=book:CreateTexture(nil,"BACKGROUND",nil,1);pageLeft:SetPoint("TOPLEFT",4,-4);pageLeft:SetPoint("BOTTOMRIGHT",book,"BOTTOM",0,4)
    local pageRight=book:CreateTexture(nil,"BACKGROUND",nil,1);pageRight:SetPoint("TOPLEFT",book,"TOP",0,-4);pageRight:SetPoint("BOTTOMRIGHT",-4,4)
    if not atlas(pageLeft,"spellbook-background-evergreen-left")then pageLeft:SetTexture("Interface\\AddOns\\WoWU\\Textures\\Spellbook\\RetailLeft");pageLeft:SetTexCoord(0,806/1024,0,805/1024);pageLeft:Show()end
    if not atlas(pageRight,"spellbook-background-evergreen-right")then pageRight:SetTexture("Interface\\AddOns\\WoWU\\Textures\\Spellbook\\RetailRight");pageRight:SetTexCoord(0,807/1024,0,805/1024);pageRight:Show()end
    local ribbon=book:CreateTexture(nil,"BACKGROUND",nil,2);ribbon:SetPoint("TOP",0,-3);ribbon:SetSize(45,350);if not atlas(ribbon,"spellbook-background-evergreen-ribbon")then ribbon:SetTexture("Interface\\AddOns\\WoWU\\Textures\\Spellbook\\RetailRibbon");ribbon:SetTexCoord(0,102/128,0,557/1024);ribbon:Show()end
    local leafFrames={}
    for i=1,2 do
        local f=CreateFrame("Frame",nil,book)
        if i==1 then f:SetPoint("TOPLEFT",20,-12);f:SetPoint("BOTTOMRIGHT",book,"BOTTOM",-20,45)
        else f:SetPoint("TOPLEFT",book,"TOP",20,-12);f:SetPoint("BOTTOMRIGHT",-20,45)end
        leafFrames[i]=f
    end
    local rows,headers={},{ }
    local pageLabel=ink(book,13);pageLabel:SetPoint("BOTTOMRIGHT",-120,20)
    local count=ink(book,12);count:SetPoint("BOTTOMLEFT",32,20)
    local prev=smallButton(book,"<",40,function()spread=math.max(1,spread-1);refresh()end);prev:SetPoint("BOTTOMRIGHT",-70,10)
    local nextPage=smallButton(book,">",40,function()spread=spread+1;refresh()end);nextPage:SetPoint("LEFT",prev,"RIGHT",6,0)
    local empty=ink(book,18);empty:SetPoint("TOPLEFT",45,-45);empty:SetWidth(900);empty:SetText("No spells match these filters.");empty:Hide()
    local right=frame(panel);right:SetSize(435,570);right:SetPoint("RIGHT",panel,"RIGHT",-20,-22);right:SetFrameStrata("DIALOG");right:Hide()
    local close=CreateFrame("Button",nil,right,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",function()right:Hide()end)
    local detailIcon=right:CreateTexture(nil,"ARTWORK");detailIcon:SetSize(52,52);detailIcon:SetPoint("TOPLEFT",18,-22)
    local detailName=font(right,20);detailName:SetPoint("TOPLEFT",detailIcon,"TOPRIGHT",12,-2);detailName:SetPoint("TOPRIGHT",-62,-24);detailName:SetHeight(50);detailName:SetWordWrap(true)
    local detailKind=font(right,13,{.72,.70,.64});detailKind:SetPoint("TOPLEFT",18,-86);detailKind:SetWidth(390)
    local hint=font(right,14,{.77,.72,.63});hint:SetPoint("TOPLEFT",20,-115);hint:SetWidth(390);hint:SetText("Tap a spell to inspect it.")
    -- The same per-character Dashboard shortcuts used by Bags.
    local function shortcutList()
        if not WoWUDB then return nil end
        local key=(UnitGUID and UnitGUID("player")) or ((UnitName("player") or "player").."-"..(GetRealmName and GetRealmName() or "realm"))
        return WoWUDashboardLayout and WoWUDashboardLayout.Shortcuts(key) or (WoWUDB.shortcuts and WoWUDB.shortcuts[key])
    end
    local function shortcutIndex(id)
        local list=shortcutList()
        if not list or not id then return nil end
        for i,e in ipairs(list) do if e.kind=="spell" and tonumber(e.id)==tonumber(id) then return i end end
        return nil
    end
    local function allowed(entry)
        return entry and entry.id and entry.known and not entry.passive and not entry.offSpec and entry.bank==spellBank and entry.type~="Flyout"
    end
    local pin, hotbar
    local pinLabel, hotbarLabel
    local notice=font(right,12,{.84,.78,.61})
    notice:SetWidth(365);notice:SetJustifyH("RIGHT")
    notice:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-18,65)
    local noticeTime=0
    local function feedback(message,fade)
        notice:SetText(message or "");notice:SetAlpha(1)
        noticeTime=fade and 2.4 or 0
    end
    local fader=CreateFrame("Frame",nil,right)
    fader:SetScript("OnUpdate",function(_,elapsed)
        if noticeTime<=0 then return end
        noticeTime=math.max(0,noticeTime-elapsed)
        if noticeTime<.65 then notice:SetAlpha(noticeTime/.65) end
        if noticeTime==0 then notice:SetText("");notice:SetAlpha(1) end
    end)
    local function updateButtons()
        if not pinLabel then return end
        local eligible=allowed(selected)
        pinLabel:SetText(eligible and (shortcutIndex(selected.id) and "- Dashboard" or "+ Dashboard") or "+ Dashboard")
        pin:SetEnabled(eligible and true or false)
        hotbar:SetEnabled(eligible and true or false)
        if hotbarLabel then hotbarLabel:SetText(WoWUController and WoWUController.active and "+ Pad"or "+ Hotbar")end
        local alpha=eligible and 1 or .45
        pin:SetAlpha(alpha);hotbar:SetAlpha(alpha)
    end
    pin=smallButton(right,"",160,function()
        if not allowed(selected) then feedback("Only active spells can be added.");return end
        local index=shortcutIndex(selected.id)
        if index then
            local list=shortcutList()
            if list then
                table.remove(list,index)
                if WoWU_RefreshDashboard then WoWU_RefreshDashboard() end
                feedback("Removed from Dashboard.",true)
            end
        else
            local ok=WoWU_AddShortcut and WoWU_AddShortcut("spell",selected.id,selected.name,selected.icon)
            feedback(ok and "Added to Dashboard." or ("Dashboard full ("..WoWUDashboardLayout.QuickLimit().." slots). Change the limit in Settings > Dashboard."),ok)
        end
        updateButtons()
    end)
    pinLabel=pin:CreateFontString(nil,"OVERLAY","GameFontNormal")
    pinLabel:SetFont("Fonts\\FRIZQT__.TTF",14,"");pinLabel:SetPoint("CENTER")
    pin:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-18,20)
    hotbar=smallButton(right,"",145,function()
        if not allowed(selected) then feedback("Only active spells can be added.");return end
        if WoWUController and WoWUController.active then
            local ok,message=WoWUController.BeginAssignment("spell",selected.id,selected.name,selected.icon,feedback)
            if not ok then feedback(message)else right:Hide()end
            return
        end
        if InCombatLockdown and InCombatLockdown() then feedback("Cannot change the hotbar during combat.");return end
        if not (GetActionInfo and PlaceAction and ClearCursor) then feedback("Action bar API unavailable.");return end
        local slot
        for i=1,120 do
            if not GetActionInfo(i) then slot=i;break end
        end
        if not slot then feedback("No empty action-bar slots found.");return end
        ClearCursor()
        local picked=false
        if WoWUSpellBook and WoWUSpellBook.PickupSpellBookItem then
            local ok=pcall(WoWUSpellBook.PickupSpellBookItem,selected.slot,selected.bank or spellBank)
            picked=ok and (not CursorHasSpell or CursorHasSpell())
        end
        if not picked and PickupSpell then
            local ok=pcall(PickupSpell,selected.id)
            picked=ok and (not CursorHasSpell or CursorHasSpell())
        end
        if not picked then ClearCursor();feedback("Could not pick up this spell.");return end
        local ok=pcall(PlaceAction,slot)
        ClearCursor()
        if ok then feedback("Added to hotbar slot "..slot..".",true)
        else feedback("Unable to place spell on the hotbar.") end
    end)
    hotbarLabel=hotbar:CreateFontString(nil,"OVERLAY","GameFontNormal")
    hotbarLabel:SetFont("Fonts\\FRIZQT__.TTF",14,"");hotbarLabel:SetPoint("CENTER");hotbarLabel:SetText("+ Hotbar")
    hotbar:SetPoint("BOTTOMRIGHT",pin,"BOTTOMLEFT",-8,0)
    if WoWUController then WoWUController.AddModeListener(updateButtons)end
    -- Scrollable, live Blizzard tooltip in the large spell-inspector space.
    local tipScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(tipScroll) end
    tipScroll:SetPoint("TOPLEFT",right,"TOPLEFT",14,-115)
    tipScroll:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-31,103)
    local tipContent=CreateFrame("Frame",nil,tipScroll)
    tipContent:SetSize(360,1)
    tipScroll:SetScrollChild(tipContent)
    tipScroll:EnableMouseWheel(true)
    tipScroll:SetScript("OnMouseWheel",function(self,delta)
        local maximum=math.max(0,tipContent:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(maximum,self:GetVerticalScroll()-delta*38)))
    end)
    local tip=CreateFrame("GameTooltip","WoWU_SpellDetailTooltip",tipContent,"GameTooltipTemplate")
    tip:SetOwner(tipContent,"ANCHOR_NONE");tip:SetClampedToScreen(false)
    tip:ClearAllPoints();tip:SetPoint("TOPLEFT",tipContent,"TOPLEFT",0,0)
    tip:Hide()
    local function fitInspectorTooltip()
        local width=math.max(1,tipScroll:GetWidth()-4)
        tipContent:SetWidth(width)
        if tip:IsShown()then
            tip:SetScale(width/math.max(1,tip:GetWidth()))
            tipContent:SetHeight(math.max(tipScroll:GetHeight(),tip:GetHeight()*tip:GetScale()+16))
        end
    end
    local function refreshInspectorTooltip(entry)
        tip:Hide();tip:SetScale(1)
        if not entry then return end
        tip:SetOwner(tipContent,"ANCHOR_NONE");tip:SetClampedToScreen(false)
        tip:ClearAllPoints();tip:SetPoint("TOPLEFT",tipContent,"TOPLEFT",0,0)
        local ok=false
        if tip.SetSpellBookItem and entry.slot then
            local kind=entry.bank or spellBank;if WoWUSpellBook and WoWUSpellBook.legacy then kind=kind==(WoWUSpellBook.PetBank or 1)and 'pet'or 'spell'end
            ok=pcall(tip.SetSpellBookItem,tip,entry.slot,kind)
        end
        if (not ok or tip:NumLines()==0) and entry.id and tip.SetSpellByID then
            ok=pcall(tip.SetSpellByID,tip,entry.id)
        end
        if ok and tip:NumLines()>0 then
            tip:Show()
            fitInspectorTooltip()
            tipScroll:SetVerticalScroll(0)
        end
    end
    tipScroll:HookScript("OnSizeChanged",fitInspectorTooltip)
    local inspectorSide="RIGHT"
    local function positionInspector(owner)
        if owner then
            local x=owner:GetCenter();local middle=book:GetCenter()
            if x and middle then inspectorSide=x<middle and "RIGHT"or "LEFT"end
        end
        right:SetSize(math.min(470,math.max(300,book:GetWidth()/2-28)),math.max(240,book:GetHeight()-20))
        right:ClearAllPoints();right:SetPoint("TOP"..inspectorSide,book,"TOP"..inspectorSide,inspectorSide=="RIGHT"and -12 or 12,-8)
    end
    selectSpell=function(entry,owner)
        positionInspector(owner);GameTooltip:Hide()
        selected=entry
        feedback("")
        updateButtons()
        if not entry then detailIcon:SetTexture(nil);detailName:SetText("Select a spell");detailKind:SetText("");hint:SetText("Tap a spell to inspect it.");refreshInspectorTooltip(nil);return end
        detailIcon:SetTexture(entry.icon or 134400)
        detailName:SetText(entry.name or "Unknown spell")
        detailKind:SetText(entry.offSpec and "Inactive specialization" or not entry.known and (entry.level and entry.level>0 and "Learned at level "..entry.level or "Not learned") or entry.passive and "Passive" or entry.bank~=spellBank and "Pet ability" or "Active spell")
        hint:SetText("")
        refreshInspectorTooltip(entry)
    end
    local flyout=frame(panel);flyout:SetSize(460,470);flyout:SetPoint("CENTER");flyout:SetFrameStrata("DIALOG");flyout:Hide()
    local flyoutTitle=font(flyout,20);flyoutTitle:SetPoint("TOPLEFT",18,-18);flyoutTitle:SetWidth(390)
    local flyoutClose=CreateFrame("Button",nil,flyout,"UIPanelCloseButton");WoWU_Theme.CloseButton(flyoutClose);flyoutClose:SetPoint("TOPRIGHT",-4,-4);flyoutClose:SetScript("OnClick",function()flyout:Hide()end)
    local flyoutScroll=CreateFrame("ScrollFrame",nil,flyout,"UIPanelScrollFrameTemplate");flyoutScroll:SetPoint("TOPLEFT",14,-58);flyoutScroll:SetPoint("BOTTOMRIGHT",-32,16)
    local flyoutBody=CreateFrame("Frame",nil,flyoutScroll);flyoutBody:SetSize(400,1);flyoutScroll:SetScrollChild(flyoutBody);WoWU_EnableTouchScroll(flyoutScroll)
    local flyoutRows={}
    openFlyout=function(entry,origin)
        flyout.origin=origin
        local _,_,num=call(GetFlyoutInfo,entry.actionID or entry.id);local found=0
        for i=1,(num or 0)do
            local id,override,known,name=call(GetFlyoutSlotInfo,entry.actionID or entry.id,i)
            id=override and override~=0 and override or id
            local info=id and call(C_Spell and C_Spell.GetSpellInfo,id)
            if id and (known or showUnlearned)then
                found=found+1;local b=flyoutRows[found]
                if not b then
                    b=smallButton(flyoutBody,"",392,function()end);b:SetHeight(58);flyoutRows[found]=b
                    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(36,36);b.icon:SetPoint("LEFT",8,0)
                    b.name=font(b,14);b.name:SetPoint("LEFT",b.icon,"RIGHT",10,0);b.name:SetWidth(325)
                    b:SetScript("OnClick",function(self)if WoWU_TouchTapAllowed(flyoutScroll)then flyout:Hide();selectSpell(self.entry,flyout.origin or self);right:Show();refreshInspectorTooltip(self.entry)end end)
                    b:SetScript("OnEnter",function()GameTooltip:Hide()end);b:SetScript("OnLeave",function()GameTooltip:Hide()end)
                end
                b.entry={id=id,name=(info and info.name)or name,icon=info and info.iconID,passive=false,type="Spell",known=known and not entry.offSpec,offSpec=entry.offSpec,bank=entry.bank}
                b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(found-1)*64);b.icon:SetTexture(b.entry.icon or 134400);b.name:SetText(b.entry.name);b:SetAlpha(b.entry.known and 1 or .5);b:Show()
            end
        end
        for i=found+1,#flyoutRows do flyoutRows[i]:Hide()end
        flyoutBody:SetHeight(math.max(1,found*64));flyoutTitle:SetText(found>0 and entry.name or "No spells available in this group");right:Hide();flyout:Show();flyoutScroll:SetVerticalScroll(0)
    end
    -- Track the press from the book or a child spell button. A release can
    -- deliver OnClick before the next OnUpdate, so every release samples the
    -- final pointer position before deciding whether this was a tap.
    local swipe={down=false,blocked=false,serial=0}
    local function sampleSwipe()
        if not swipe.down or not GetCursorPosition then return end
        local x,y=GetCursorPosition()
        swipe.dx=(x-swipe.x)/swipe.scale;swipe.dy=(y-swipe.y)/swipe.scale
        if swipe.dx*swipe.dx+swipe.dy*swipe.dy>12*12 then swipe.blocked=true;GameTooltip:Hide()end
    end
    local function beginSwipe(_,mouse)
        if mouse~="LeftButton"or not GetCursorPosition then return end
        swipe.serial=swipe.serial+1;swipe.down=true;swipe.blocked=false
        swipe.x,swipe.y=GetCursorPosition();swipe.scale=math.max(.001,book:GetEffectiveScale()or 1);swipe.dx,swipe.dy=0,0
    end
    local function finishSwipe()
        if not swipe.down then return swipe.blocked end
        sampleSwipe();swipe.down=false
        local dx,dy=swipe.dx or 0,swipe.dy or 0
        if math.abs(dx)>=math.max(55,book:GetWidth()*.06)and math.abs(dx)>math.abs(dy)*1.4 then
            swipe.blocked=true
            local serial,direction=swipe.serial,dx<0 and 1 or -1
            C_Timer.After(0,function()
                if swipe.serial~=serial or not book:IsShown()then return end
                right:Hide();flyout:Hide()
                spread=spread+direction;refresh()
            end)
        end
        return swipe.blocked
    end
    local function releaseSwipe(_,mouse)if mouse=="LeftButton"then finishSwipe()end end
    book:EnableMouse(true)
    book:SetScript("OnMouseDown",beginSwipe);book:SetScript("OnMouseUp",releaseSwipe)
    book:HookScript("OnUpdate",function()
        if not swipe.down then return end
        sampleSwipe()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton")then finishSwipe()end
    end)
    book:HookScript("OnHide",function()swipe.down=false;swipe.blocked=false;swipe.serial=swipe.serial+1 end)
    local function getRow(i)
        if rows[i]then return rows[i]end
        local b=CreateFrame("Button",nil,book,"BackdropTemplate");rows[i]=b;b:SetHeight(60)
        b.highlight=b:CreateTexture(nil,"BACKGROUND");b.highlight:SetAllPoints();b.highlight:SetColorTexture(.55,.34,.12,.16);b.highlight:Hide()
        b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(38,38);b.icon:SetPoint("LEFT",12,0)
        b.mask=b:CreateMaskTexture();b.mask:SetSize(38,38);b.mask:SetPoint("CENTER",b.icon)
        b.rim=b:CreateTexture(nil,"OVERLAY");b.rim:SetPoint("TOPLEFT",b.icon,"TOPLEFT",-10,3);b.rim:SetPoint("BOTTOMRIGHT",b.icon,"BOTTOMRIGHT",3,-8)
        b.label=ink(b,14);b.label:SetPoint("TOPLEFT",b.icon,"TOPRIGHT",12,4);b.label:SetPoint("TOPRIGHT",-6,-7);b.label:SetHeight(34);b.label:SetWordWrap(true)
        b.sub=ink(b,11);b.sub:SetPoint("BOTTOMLEFT",b.icon,"BOTTOMRIGHT",12,-4);b.sub:SetPoint("BOTTOMRIGHT",-6,7);b.sub:SetHeight(16)
        b:SetScript("OnClick",function(self)
            if finishSwipe()then return end
            if self.entry.type=="Flyout"then openFlyout(self.entry,self)else flyout:Hide();selectSpell(self.entry,self);right:Show();refreshInspectorTooltip(self.entry)end
            refresh()
        end)
        b:SetScript("OnEnter",function()GameTooltip:Hide()end)
        b:SetScript("OnLeave",function()GameTooltip:Hide()end)
        b:SetScript("OnMouseDown",beginSwipe);b:SetScript("OnMouseUp",releaseSwipe)
        return b
    end
    local function getHeader(i)
        if headers[i]then return headers[i]end
        local f=CreateFrame("Frame",nil,book);headers[i]=f;f:SetHeight(40)
        f.label=ink(f,21);f.label:SetPoint("TOPLEFT",8,0);f.label:SetPoint("TOPRIGHT",-8,0);f.label:SetHeight(28)
        f.line=f:CreateTexture(nil,"ARTWORK");f.line:SetPoint("BOTTOMLEFT",0,1);f.line:SetPoint("BOTTOMRIGHT",-4,1);f.line:SetHeight(10)
        if not atlas(f.line,"spellbook-divider")then f.line:SetColorTexture(.3,.16,.06,.45);f.line:SetHeight(1);f.line:Show()end
        return f
    end
    refresh=function()
        for _,b in ipairs(rows)do b:Hide()end
        for _,h in ipairs(headers)do h:Hide()end
        leaves={};visible={}
        local width=math.max(300,leafFrames[1]:GetWidth());local height=math.max(170,leafFrames[1]:GetHeight())
        local columns=2;local rowHeight=70;local leaf,y=nil,20
        local function newLeaf()leaf={};leaves[#leaves+1]=leaf;y=20 end
        for _,section in ipairs(sections)do
            if section.category==category then
                local data={}
                for _,e in ipairs(section.entries)do
                    if (showUnlearned or e.known)and (filter=="All"or (filter=="Passive")==e.passive)
                        and (search==""or string.find(string.lower((e.name or "").." "..(e.subName or "").." "..section.name),search,1,true))then
                        data[#data+1]=e;visible[#visible+1]=e
                    end
                end
                local cursor=1
                while cursor<=#data do
                    if not leaf or y+42+rowHeight>height then newLeaf()end
                    leaf[#leaf+1]={header=section.name..(cursor>1 and " (continued)"or ""),y=y};y=y+44
                    local availableRows=math.max(1,math.floor((height-y)/rowHeight))
                    local take=math.min(#data-cursor+1,availableRows*columns);local rowCount=math.ceil(take/columns)
                    for j=0,take-1 do leaf[#leaf+1]={entry=data[cursor+j],x=math.floor(j/rowCount)*width/columns,y=y+(j%rowCount)*rowHeight}end
                    y=y+rowCount*rowHeight+20;cursor=cursor+take
                    if cursor<=#data then newLeaf()end
                end
            end
        end
        local spreads=math.max(1,math.ceil(#leaves/2));spread=math.max(1,math.min(spread,spreads))
        local rowIndex,headerIndex=0,0
        for side=1,2 do
            for _,element in ipairs(leaves[(spread-1)*2+side]or {})do
                local parent=leafFrames[side]
                if element.header then
                    headerIndex=headerIndex+1;local h=getHeader(headerIndex);h:SetParent(parent);h:ClearAllPoints();h:SetPoint("TOPLEFT",0,-element.y);h:SetWidth(width);h.label:SetText(element.header);h:Show()
                else
                    rowIndex=rowIndex+1;local b=getRow(rowIndex);local e=element.entry
                    b:SetParent(parent);b:ClearAllPoints();b:SetPoint("TOPLEFT",element.x,-element.y);b:SetWidth(width/columns-4);b.entry=e
                    b.icon:SetTexture(e.icon or 134400);b.icon:SetDesaturated(not e.known);b.icon:SetAlpha(e.known and 1 or .48)
                    b.icon:RemoveMaskTexture(b.mask)
                    if atlas(b.mask,e.passive and "talents-node-circle-mask"or "spellbook-item-spellicon-mask")then b.icon:AddMaskTexture(b.mask)end
                    local rim=e.passive and (e.known and "talents-node-circle-gray"or "spellbook-item-iconframe-passive-inactive")or (e.known and "spellbook-item-iconframe"or "spellbook-item-iconframe-inactive")
                    b.rim:ClearAllPoints()
                    if e.passive then b.rim:SetPoint("TOPLEFT",b.icon,"TOPLEFT",-2,2);b.rim:SetPoint("BOTTOMRIGHT",b.icon,"BOTTOMRIGHT",2,-2)
                    else b.rim:SetPoint("TOPLEFT",b.icon,"TOPLEFT",-10,3);b.rim:SetPoint("BOTTOMRIGHT",b.icon,"BOTTOMRIGHT",3,-8)end
                    if not atlas(b.rim,rim)then b.rim:SetTexture(WoWU_Theme.assets.rim);b.rim:Show()end
                    b.label:SetText(e.name);b.label:SetTextColor(e.known and .16 or .39,e.known and .09 or .28,e.known and .035 or .15)
                    local sub=e.passive and "Passive"or e.type=="Flyout"and "Spell group >"or e.subName or ""
                    if not e.known then sub=e.offSpec and "Inactive specialization"or e.level and e.level>0 and "Level "..e.level or "Not learned"end
                    b.sub:SetText(sub);b.sub:SetTextColor(.37,.25,.13)
                    b.highlight:SetShown(selected and selected.id==e.id and selected.bank==e.bank and selected.slot==e.slot);b:Show()
                end
            end
        end
        empty:SetShown(#visible==0);count:SetText(#visible.." abilities | Tap to inspect | Swipe left / right to turn pages")
        pageLabel:SetText("Page "..spread.." / "..spreads);prev:SetEnabled(spread>1);nextPage:SetEnabled(spread<spreads)
        for key,b in pairs(categoryButtons)do WoWU_Theme.Tab(b,key==category)end
        filterButton.label:SetText(filter=="All"and "All spells"or filter=="Active"and "Active only"or "Passives only")
        futureButton.label:SetText("Unlearned: "..(showUnlearned and "on"or "off"))
        updateButtons()
    end
    rebuild=function()
        dirty=false;spells={};sections={}
        if not (WoWUSpellBook and WoWUSpellBook.GetSpellBookSkillLineInfo and WoWUSpellBook.GetSpellBookItemInfo)then empty:SetText("Spellbook information is unavailable on this client.");refresh();return end
        local types=Enum and Enum.SpellBookItemType or {None=0,FutureSpell=2,Flyout=4}
        local general=Enum and Enum.SpellBookSkillLineIndex and Enum.SpellBookSkillLineIndex.General or 1
        local function append(section,slot,bank)
            local item=call(WoWUSpellBook.GetSpellBookItemInfo,slot,bank)
            if not item or not item.name or item.itemType==types.None then return end
            local offSpec=item.isOffSpec==true or section.offSpec==true
            local known=item.itemType~=types.FutureSpell and not offSpec
            local e={slot=slot,id=item.spellID or item.actionID,actionID=item.actionID,name=item.name,subName=item.subName or "",icon=item.iconID,
                passive=item.isPassive==true,type=item.itemType==types.Flyout and "Flyout"or "Spell",offSpec=offSpec,known=known,bank=bank,
                level=call(WoWUSpellBook.GetSpellBookItemLevelLearned,slot,bank)}
            section.entries[#section.entries+1]=e;spells[#spells+1]=e
        end
        for line=1,math.min(call(WoWUSpellBook.GetNumSpellBookSkillLines)or 0,100)do
            local info=call(WoWUSpellBook.GetSpellBookSkillLineInfo,line)
            if info and not info.shouldHide then
                local section={name=info.name or className,category=(line==general or info.isGuild)and "General"or "Class",offSpec=type(info.offSpecID)=="number"and info.offSpecID>0,entries={}}
                for slot=(info.itemIndexOffset or 0)+1,(info.itemIndexOffset or 0)+math.min(info.numSpellBookItems or 0,500)do append(section,slot,spellBank)end
                table.sort(section.entries,function(a,b)if a.known~=b.known then return a.known end;return a.name<b.name end)
                sections[#sections+1]=section
            end
        end
        local petBank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
        local petCount=call(WoWUSpellBook.HasPetSpells)or 0
        if type(petCount)~="number"then petCount=0 end
        if petCount>0 then
            local section={name=UnitName("pet")or PET or "Pet",category="Pet",entries={}}
            for slot=1,math.min(petCount,100)do append(section,slot,petBank)end
            sections[#sections+1]=section
        end
        categoryButtons.Pet:SetShown(petCount>0);if category=="Pet"and petCount==0 then category="Class";spread=1 end
        if selected then
            local old=selected;selected=nil
            for _,entry in ipairs(spells)do if entry.id==old.id and entry.bank==old.bank and entry.slot==old.slot then selected=entry;break end end
            if not old.slot and call(WoWUSpellBook.IsSpellKnown,old.id,old.bank)==true then selected=old end
        end
        selectSpell(selected);refresh()
    end
    local events=CreateFrame("Frame",nil,panel)
    for _,name in ipairs({"SPELLS_CHANGED","SPELL_TEXT_UPDATE","PLAYER_SPECIALIZATION_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_LEVEL_UP","LEARNED_SPELL_IN_TAB","PET_BAR_UPDATE","UNIT_PET","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"})do call(events.RegisterEvent,events,name)end
    events:SetScript("OnEvent",function()dirty=true end)
    local elapsed=0;panel:HookScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
        if dirty then rebuild()elseif searchAt and GetTime()>=searchAt then searchAt=nil;spread=1;refresh()end
    end)
    book:SetScript("OnSizeChanged",function()if refresh then refresh()end end)
    book:EnableMouseWheel(true)
    book:SetScript("OnMouseWheel",function(_,delta)spread=spread+(delta>0 and -1 or 1);refresh()end)
    panel:HookScript("OnShow",rebuild)
    panel:HookScript("OnHide",function()right:Hide();flyout:Hide();tip:Hide();GameTooltip:Hide();searchBox:ClearFocus()end)
    right:HookScript("OnShow",function()if selected then refreshInspectorTooltip(selected)end end)
    right:HookScript("OnHide",function()tip:Hide()end)
    selectSpell(nil)
end
