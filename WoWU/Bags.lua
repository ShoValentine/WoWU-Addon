-- WoWU: unified bag inventory and persistent tooltip inspector.
-- Every occupied or empty slot in the player's carried bags appears in one grid.
local DEFAULT_SLOT = 62
local GAP = 5
local QUALITY = ITEM_QUALITY_COLORS or {}
local comparisonSlots = {
    INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_BODY={4},
    INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7},
    INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11,12},
    INVTYPE_TRINKET={13,14}, INVTYPE_CLOAK={15}, INVTYPE_WEAPON={16,17},
    INVTYPE_WEAPONMAINHAND={16}, INVTYPE_WEAPONOFFHAND={17}, INVTYPE_2HWEAPON={16,17},
    INVTYPE_SHIELD={17}, INVTYPE_HOLDABLE={17}, INVTYPE_RANGED={18},
    INVTYPE_RANGEDRIGHT={18}, INVTYPE_THROWN={18}, INVTYPE_RELIC={18}, INVTYPE_TABARD={19},
    INVTYPE_BAG={20,21,22,23}, INVTYPE_QUIVER={20,21,22,23},
}
local comparisonNames = {
    [11]="Ring 1", [12]="Ring 2", [13]="Trinket 1", [14]="Trinket 2",
    [16]="Main Hand", [17]="Off Hand", [18]="Ranged",
    [20]="Bag 1", [21]="Bag 2", [22]="Bag 3", [23]="Bag 4",
}

local function makeBorder(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    WoWU_Theme.Backdrop(f,{
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 17, insets = {left=4,right=4,top=4,bottom=4},
    })
    WoWU_Theme.Color(f,0.06, 0.09, 0.11, 0.98)
    WoWU_Theme.Panel(f)
    return f
end
local function label(parent, size, color, text)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetFont("Fonts\\FRIZQT__.TTF",size, "")
    WoWU_Theme.TextColor(f,unpack(color))
    f:SetText(text)
    return f
end

function WoWU_BuildBags(parent)
    WoWU_BagsPanel=parent
    local SLOT, COLS = DEFAULT_SLOT, 11
    local left = makeBorder(parent)
    left:SetPoint("TOPLEFT", 10, -9)
    left:SetPoint("BOTTOMLEFT", 10, 9)
    left:SetPoint("RIGHT", parent, "LEFT", 813, 0)  -- ~2/3 of available content width

    local right = makeBorder(parent)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 9, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 75)
    local actions=makeBorder(parent)
    actions:SetPoint("TOPLEFT", right, "BOTTOMLEFT", 0, -7)
    actions:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 9)

    local info = label(left, 14, {0.91,0.77,0.49}, "Bags")
    info:SetPoint("TOPLEFT", 16, -14)
    local countText = label(left, 13, {0.72,0.73,0.69}, "")
    countText:Hide()

    local scroll = CreateFrame("ScrollFrame", "WoWU_BagsScroll", left, "UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    scroll.WoWUTouchBlocked=function()return CursorHasItem and CursorHasItem()end
    scroll:SetPoint("TOPLEFT", 13, -45)
    scroll:SetPoint("BOTTOMRIGHT", -32, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(COLS*(SLOT+GAP), 600)
    scroll:SetScrollChild(content)

    local selectedTitle = label(right, 16, {0.95,0.81,0.56}, "Item Inspector")
    selectedTitle:SetPoint("TOP", right, "TOP", 0, -16)
    local tipInfo = label(right, 12, {0.68,0.71,0.68}, "Tap an item to inspect it")
    tipInfo:SetPoint("TOP", right, "TOP", 0, -43)
    tipInfo:SetWidth(350)
    tipInfo:SetJustifyH("CENTER")

    -- The GameTooltip itself remains a real game tooltip. Its scroll child is
    -- oversized when necessary so long tooltips can be swiped or wheel-scrolled.
    local tipScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(tipScroll) end
    tipScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 12, -72)
    tipScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -32, 160)
    local tipContent = CreateFrame("Frame", nil, tipScroll)
    tipContent:SetSize(360, 1)
    tipScroll:SetScrollChild(tipContent)
    if tipScroll.SetClipsChildren then tipScroll:SetClipsChildren(true)end
    tipScroll:EnableMouseWheel(true)
    tipScroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        local maximum = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 34)))
    end)
    local tip = CreateFrame("GameTooltip", "WoWU_BagItemTooltip", tipContent, "GameTooltipTemplate")
    if WoWUAuctionPrices and WoWUAuctionPrices.AttachTooltip then WoWUAuctionPrices.AttachTooltip(tip)end
    tip:SetOwner(tipContent, "ANCHOR_NONE")
    tip:SetClampedToScreen(false)
    tip:ClearAllPoints()
    tip:SetPoint("TOP", tipContent, "TOP", 0, 0)
    tip:SetScale(1.1)
    tip:Hide()
    -- Private tooltips leave Blizzard's hover/comparison tooltips untouched.
    local comparisons = {}
    for i=1,4 do
        local heading=label(tipContent,13,{.95,.81,.56},"")
        heading:SetJustifyH("CENTER")
        local equipped=CreateFrame("GameTooltip","WoWU_BagEquippedTooltip"..i,tipContent,"GameTooltipTemplate")
        if WoWUAuctionPrices and WoWUAuctionPrices.AttachTooltip then WoWUAuctionPrices.AttachTooltip(equipped)end
        equipped:SetOwner(tipContent,"ANCHOR_NONE")
        equipped:SetClampedToScreen(false)
        equipped:Hide();heading:Hide()
        local difference=label(tipContent,17,{.95,.81,.56},"");difference:SetJustifyH("LEFT");difference:SetWordWrap(true);difference:Hide()
        comparisons[i]={heading=heading,tip=equipped,difference=difference}
    end
    local function fitTooltip(tooltip,offset)
        tooltip:SetClampedToScreen(false)
        local width=math.max(1,tipScroll:GetWidth())
        tooltip:SetScale(width/math.max(1,tooltip:GetWidth()))
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOP",tipContent,"TOP",0,-offset/tooltip:GetScale())
        return offset+tooltip:GetHeight()*tooltip:GetScale()
    end
    -- Use an independent instance of Blizzard's comparison logic. The global
    -- manager and its shopping tooltips remain available for normal mouse hover.
    local nativeComparison
    local nativeTips={}
    if TooltipComparisonManager and C_TooltipComparison and C_TooltipComparison.GetItemComparisonInfo then
        nativeComparison={}
        for key,value in pairs(TooltipComparisonManager) do
            if type(value)=="function" then nativeComparison[key]=value end
        end
        for i=1,2 do
            local equipped=CreateFrame("GameTooltip","WoWU_BagNativeComparison"..i,tipContent,"ShoppingTooltipTemplate")
            equipped:SetOwner(tipContent,"ANCHOR_NONE")
            equipped:SetClampedToScreen(false)
            equipped:Hide()
            nativeTips[i]=equipped
        end
        -- A private owner avoids changing the selected item's shoppingTooltips.
        local comparisonOwner=CreateFrame("Frame",nil,tipContent)
        comparisonOwner.shoppingTooltips=nativeTips
        nativeComparison.owner=comparisonOwner
        nativeComparison.AnchorShoppingTooltips=function(self,primary,secondary)
            local offset=self.startOffset
            for i,shown in ipairs({primary and true or false,secondary and true or false}) do
                local equipped=nativeTips[i]
                equipped:SetShown(shown)
                if shown then
                    -- Leave room above the tooltip for Blizzard's Equipped tab.
                    offset=offset+38
                    offset=fitTooltip(equipped,offset)
                    self.hasComparison=true
                end
            end
            self.endOffset=offset
        end
    end
    local function showDifference(link,equipLoc,slots,i,slot,offset)
        local entry=comparisons[i]
        if not entry or not WoWUDetails or not WoWUDetails.StatDifferences then return offset end
        if equipLoc=="INVTYPE_2HWEAPON"and i~=#slots then return offset end
        local baseline={}
        if equipLoc=="INVTYPE_2HWEAPON"then
            for _,weaponSlot in ipairs({16,17})do local equipped=GetInventoryItemLink("player",weaponSlot);if equipped then baseline[#baseline+1]=equipped end end
        else local equipped=GetInventoryItemLink("player",slot);if equipped then baseline[1]=equipped end end
        local title=equipLoc=="INVTYPE_2HWEAPON"and "Selected minus main hand + off hand:"or "Selected minus equipped:"
        local summary=entry.difference;summary:ClearAllPoints();summary:SetPoint("TOPLEFT",tipContent,"TOPLEFT",6,-offset-12)
        summary:SetWidth(math.max(1,tipScroll:GetWidth()-12));summary:SetText(title.."\n"..WoWUDetails.StatDifferences(link,baseline));summary:Show()
        return offset+summary:GetStringHeight()+30
    end
    local function showComparisons(link,offset)
        local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
        local equipLoc=link and getInfo and select(9,getInfo(link))
        local slots=comparisonSlots[equipLoc]
        if nativeComparison and link then
            -- Recalculate after an equipment change even if the bag item is the same.
            nativeComparison:Clear()
            nativeComparison.startOffset=offset
            nativeComparison.endOffset=offset
            nativeComparison.hasComparison=false
            local ok=pcall(nativeComparison.CompareItem,nativeComparison,{hyperlink=link},nativeComparison.owner,tip)
            if ok and nativeComparison.hasComparison then
                local height=nativeComparison.endOffset
                for i,slot in ipairs(slots or {})do height=showDifference(link,equipLoc,slots,i,slot,height)end
                return height,true
            end
            nativeComparison:Clear()
            for _,equipped in ipairs(nativeTips) do equipped:Hide() end
        end
        if not slots then return offset,false end
        for i,slot in ipairs(slots) do
            local entry=comparisons[i]
            offset=offset+18
            entry.heading:ClearAllPoints()
            entry.heading:SetPoint("TOP",tipContent,"TOP",0,-offset)
            entry.heading:SetWidth(math.max(1,tipScroll:GetWidth()))
            local suffix=comparisonNames[slot]
            local title="Currently Equipped"..(suffix and " - "..suffix or "")
            local equippedLink=GetInventoryItemLink("player",slot)
            entry.heading:SetText(title..(not equippedLink and " (empty)" or ""))
            entry.heading:Show()
            offset=offset+entry.heading:GetStringHeight()+8
            if equippedLink then
                entry.tip:SetOwner(tipContent,"ANCHOR_NONE");entry.tip:SetClampedToScreen(false)
                entry.tip:ClearLines()
                entry.tip:SetInventoryItem("player",slot)
                entry.tip:Show()
                offset=fitTooltip(entry.tip,offset)
            end
            offset=showDifference(link,equipLoc,slots,i,slot,offset)
        end
        return offset,true
    end

    local selectedBag, selectedSlot = nil, nil
    local updateDisenchant
    local useButton = CreateFrame("Button", nil, actions, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    useButton:SetSize(110,36)
    useButton:SetPoint("TOP",actions,"TOP",-100,-11)
    -- Secure action buttons must explicitly register click types on modern clients.
    -- The left-button-specific attributes keep this action unambiguous.
    -- Modern WoW clients can process action buttons on key-down. Register
    -- both phases and explicitly choose release-time activation for touch.
    useButton:RegisterForClicks("AnyDown", "AnyUp")
    useButton:SetAttribute("useOnKeyDown", false)
    useButton:SetAttribute("type", "item")
    useButton:SetAttribute("type1", "item")
    useButton:SetText("Use / Equip")
    useButton:Disable()
    -- Initialize the inspector status before registering callbacks, so the
    -- Dashboard pin click always closes over a valid local FontString.
    local inspectorStatus=label(right,11,{.83,.75,.58},"")
    inspectorStatus:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-13,51)
    inspectorStatus:SetWidth(320)
    inspectorStatus:SetJustifyH("RIGHT")
    -- Fade transient confirmations, while keeping actionable errors readable.
    local noticeTime=0
    local function showNotice(text, transient)
        inspectorStatus:SetText(text or "")
        inspectorStatus:SetAlpha(1)
        noticeTime=transient and 2.4 or 0
    end
    local noticeFader=CreateFrame("Frame",nil,right)
    noticeFader:SetScript("OnUpdate",function(_,elapsed)
        if noticeTime<=0 then return end
        noticeTime=math.max(0,noticeTime-elapsed)
        if noticeTime<0.65 then inspectorStatus:SetAlpha(noticeTime/0.65) end
        if noticeTime==0 then inspectorStatus:SetText("");inspectorStatus:SetAlpha(1) end
    end)
    local function shortcutList()
        if not WoWUDB then return nil end
        local key=(UnitGUID and UnitGUID("player")) or ((UnitName("player") or "player").."-"..(GetRealmName and GetRealmName() or "realm"))
        return WoWUDashboardLayout and WoWUDashboardLayout.Shortcuts(key)or (WoWUDB.shortcuts and WoWUDB.shortcuts[key])
    end
    local function shortcutIndex(itemID)
        if not itemID then return nil end
        local list=shortcutList()
        if not list then return nil end
        for i,entry in ipairs(list) do
            if entry.kind=="item" and tonumber(entry.id)==tonumber(itemID) then return i end
        end
        return nil
    end
    local function selectedItemID()
        if selectedBag==nil or selectedSlot==nil then return nil end
        local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(selectedBag,selectedSlot)
        return info and info.itemID
    end
    local pin=CreateFrame("Button",nil,right,"BackdropTemplate")
    pin:SetHeight(33);pin:SetPoint("BOTTOMLEFT",right,"BOTTOM",4,12);pin:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-13,12)
    WoWU_Theme.Backdrop(pin,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(pin,.24,.27,.23,1);WoWU_Theme.Border(pin,.68,.52,.28,1)
    local pinLabel=label(pin,12,{.95,.8,.55},"+ Dashboard");pinLabel:SetPoint("CENTER")
    local protect=CreateFrame("Button",nil,right,"UIPanelButtonTemplate")
    protect:SetPoint("BOTTOMLEFT",13,79);protect:SetPoint("BOTTOMRIGHT",-13,79);protect:SetHeight(34)
    protect:SetText("Protect Item")
    local protectLabel=protect:GetFontString()
    local pad=CreateFrame("Button",nil,right,"BackdropTemplate")
    pad:SetPoint("BOTTOMLEFT",right,"BOTTOMLEFT",13,12);pad:SetPoint("BOTTOMRIGHT",right,"BOTTOM",-4,12);pad:SetHeight(33)
    WoWU_Theme.Backdrop(pad,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    WoWU_Theme.Color(pad,.24,.27,.23,1);WoWU_Theme.Border(pad,.68,.52,.28,1)
    local padLabel=label(pad,12,{.95,.8,.55},"+ Pad");padLabel:SetPoint("CENTER");pad:Hide()
    pad:SetScript("OnClick",function()
        local id=selectedItemID();if not id then showNotice("Select an item first.");return end
        local name=C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)or (GetItemInfo and GetItemInfo(id))
        local icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)or (GetItemIcon and GetItemIcon(id))
        local ok,message=WoWUController.BeginAssignment("item",id,name,icon,showNotice)
        if not ok then showNotice(message)end
    end)
    local function updatePin()
        pinLabel:SetText(shortcutIndex(selectedItemID()) and "- Dashboard" or "+ Dashboard")
        local id=selectedItemID()
        protect:SetEnabled(id~=nil)
        protectLabel:SetText(WoWUQoL.IsProtected(id)and "Remove Protection"or "Protect Item")
        local active=WoWUController and WoWUController.active
        pad:SetShown(active==true);pad:SetEnabled(id~=nil)
        tipScroll:ClearAllPoints();tipScroll:SetPoint("TOPLEFT",right,"TOPLEFT",12,-72)
        tipScroll:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-32,160)
    end
    if WoWUController then WoWUController.AddModeListener(updatePin)end
    protect:SetScript("OnClick",function()
        local id=selectedItemID();if not id then return end
        local value=not WoWUQoL.IsProtected(id);WoWUQoL.Protect(id,value)
        updatePin();if parent.WoWURefreshBags then parent.WoWURefreshBags()end
        showNotice(value and "All copies protected from WoWU auto-selling."or "Auto-sell protection removed.",true)
    end)
    pin:SetScript("OnClick",function()
        if selectedBag==nil then showNotice("Select an item first.");return end
        local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(selectedBag,selectedSlot)
        if not info or not info.itemID then showNotice("Item details unavailable.");return end
        local index=shortcutIndex(info.itemID)
        if index then
            local list=shortcutList()
            if list then
                table.remove(list,index)
                if WoWU_RefreshDashboard then WoWU_RefreshDashboard() end
                showNotice("Removed from Dashboard.",true)
            end
        else
            local ok=WoWU_AddShortcut and WoWU_AddShortcut("item",info.itemID,info.hyperlink or "Item",info.iconFileID)
            showNotice(ok and "Added to Dashboard." or ("Dashboard full ("..WoWUDashboardLayout.QuickLimit().." slots). Change the limit in Settings > Dashboard."),ok)
        end
        updatePin()
    end)
    if WoWU_BuildDisenchant then
        updateDisenchant=WoWU_BuildDisenchant(parent,right,pin,showNotice,function() return selectedBag,selectedSlot end)
    end
    local function actionButton(title,x,fn)
        local b=CreateFrame("Button",nil,actions,"UIPanelButtonTemplate")
        b:SetSize(88,36);b:SetPoint("TOP",actions,"TOP",x,-11)
        b:SetText(title)
        b:SetScript("OnClick",fn)
        return b
    end
    local function combat() return InCombatLockdown and InCombatLockdown() end
    local lastSecureTarget
    local function updateSecureUse()
        if updateDisenchant then updateDisenchant() end
        if combat() then inspectorStatus:SetText("Actions locked during combat.");return end
        if selectedBag ~= nil and selectedSlot ~= nil then
            -- SecureActionButton item target uses 'bag slot' syntax.
            local target = tostring(selectedBag).." "..tostring(selectedSlot)
            if lastSecureTarget ~= target then
                useButton:SetAttribute("item", target)
                useButton:SetAttribute("item1", target)
                lastSecureTarget = target
            end
            useButton:Enable()
        else
            if lastSecureTarget ~= nil then
                useButton:SetAttribute("item", nil)
                useButton:SetAttribute("item1", nil)
                lastSecureTarget = nil
            end
            useButton:Disable()
        end
    end
    actionButton("Split",4,function()
        if combat() then inspectorStatus:SetText("Splitting is unavailable in combat.");return end
        if selectedBag==nil then return end
        local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(selectedBag,selectedSlot)
        local qty=info and info.stackCount or 0
        if qty<2 then inspectorStatus:SetText("Select a stack containing at least two items.");return end
        local split=C_Container and C_Container.SplitContainerItem
        if type(split)=="function" then
            split(selectedBag,selectedSlot,math.floor(qty/2))
            inspectorStatus:SetText("Half the stack is on your cursor. Tap an empty bag slot.")
        else inspectorStatus:SetText("Stack splitting isn't available on this client.") end
    end)
    -- Deletion deliberately has two separate user clicks: Drop then Confirm.
    -- Never try to remove a cursor item we didn't explicitly pick up.
    local pendingDrop
    local dropButton=actionButton("Drop",104,function()
        if combat() then inspectorStatus:SetText("Cannot destroy items in combat.");return end
        if selectedBag==nil or selectedSlot==nil then
            inspectorStatus:SetText("Select an item before using Drop.");return
        end
        if CursorHasItem and CursorHasItem() then
            inspectorStatus:SetText("Place or clear the item currently held by your cursor first.");return
        end
        local info=C_Container and C_Container.GetContainerItemInfo
            and C_Container.GetContainerItemInfo(selectedBag,selectedSlot)
        if not info or not info.itemID or info.isLocked then
            inspectorStatus:SetText("Selected item is missing or locked.");return
        end
        pendingDrop={bag=selectedBag,slot=selectedSlot,itemID=info.itemID,
            hyperlink=info.hyperlink or ("Item "..tostring(info.itemID))}
        StaticPopup_Show("WOWU_CONFIRM_DROP", pendingDrop.hyperlink)
    end)
    if not StaticPopupDialogs["WOWU_CONFIRM_DROP"] then
        StaticPopupDialogs["WOWU_CONFIRM_DROP"]={
            text="Permanently destroy %s? This cannot be undone.",
            button1="Destroy", button2=CANCEL or "Cancel",
            OnAccept=function()
                local target=pendingDrop
                pendingDrop=nil
                if not target or combat() then return end
                if CursorHasItem and CursorHasItem() then
                    inspectorStatus:SetText("Cursor is holding another item. Deletion cancelled.")
                    return
                end
                if not C_Container or type(C_Container.PickupContainerItem)~="function"
                    or type(DeleteCursorItem)~="function" then
                    inspectorStatus:SetText("This client does not expose direct item deletion.")
                    return
                end
                local info=C_Container.GetContainerItemInfo(target.bag,target.slot)
                if not info or info.itemID~=target.itemID or info.isLocked then
                    inspectorStatus:SetText("Item changed or is locked. Deletion cancelled.")
                    return
                end
                local ok=pcall(C_Container.PickupContainerItem,target.bag,target.slot)
                if not ok or not (CursorHasItem and CursorHasItem()) then
                    inspectorStatus:SetText("Blizzard prevented picking up this item.")
                    return
                end
                local deleted=pcall(DeleteCursorItem)
                if not deleted then
                    inspectorStatus:SetText("Blizzard blocked deletion. Item may remain on the cursor.")
                else
                    inspectorStatus:SetText("Deletion requested. Confirm any further Blizzard prompt.")
                end
            end,
            OnCancel=function() pendingDrop=nil end,
            timeout=0, whileDead=false, hideOnEscape=true, preferredIndex=3,
        }
    end
    local clean=actionButton("Clean Up",232,function()
        if combat() then inspectorStatus:SetText("Cleanup unavailable in combat.");return end
        if WoWUClient and WoWUClient.isClassic and WoWUBagSort then
            local _,message=WoWUBagSort.Start(function(status)inspectorStatus:SetText(status)end)
            inspectorStatus:SetText(message)
        elseif C_Container and type(C_Container.SortBags)=="function" then
            local ok=pcall(C_Container.SortBags)
            inspectorStatus:SetText(ok and "Requested Blizzard bag sorting." or "Blizzard blocked bag sorting.")
        else inspectorStatus:SetText("Blizzard bag sorting API is unavailable.") end
    end)
    clean:ClearAllPoints()
    clean:SetPoint("TOPRIGHT",left,"TOPRIGHT",-14,-8)
    clean:SetParent(left)

    local buttons = {}
    local refresh
    local bagData = {}
    local function getSlots(bag)
        if C_Container and C_Container.GetContainerNumSlots then
            return C_Container.GetContainerNumSlots(bag) or 0
        end
        if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
        return 0
    end
    local function getItem(bag, slot)
        if C_Container and C_Container.GetContainerItemInfo then
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                return info.iconFileID, info.stackCount or 1, info.quality, info.isLocked, info.hyperlink
            end
        end
        if GetContainerItemInfo then
            local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
            return texture, count, quality, locked, GetContainerItemLink and GetContainerItemLink(bag, slot)
        end
    end
    local function displayTip()
        updatePin()
        tip:Hide()
        if nativeComparison then nativeComparison:Clear() end
        for _,equipped in ipairs(nativeTips) do equipped:Hide() end
        for _,entry in ipairs(comparisons) do entry.tip:Hide();entry.heading:Hide();entry.difference:Hide() end
        tipContent:SetHeight(1)
        tipScroll:SetVerticalScroll(0)
        if selectedBag == nil then
            tipInfo:SetText("Tap an item to inspect it.") 
            updateSecureUse()
            return
        end
        local texture, _, _, _, link = getItem(selectedBag, selectedSlot)
        if not texture then
            selectedBag, selectedSlot = nil, nil
            tipInfo:SetText("Tap an item to inspect it")
            updateSecureUse()
            return
        end
        tip:SetOwner(tipContent, "ANCHOR_NONE")
        tip:SetClampedToScreen(false)
        tip:ClearAllPoints()
        tip:SetPoint("TOP", tipContent, "TOP", 0, 0)
        if tip.SetBagItem then
            tip:SetBagItem(selectedBag, selectedSlot)
            tip:Show()
            tipContent:SetWidth(math.max(1, tipScroll:GetWidth()))
            local height,comparing=showComparisons(link,fitTooltip(tip,0))
            tipContent:SetHeight(math.max(tipScroll:GetHeight(), height + 12))
            tipScroll:SetVerticalScroll(0)
            tipInfo:SetText(comparing and "Selected item above; equipped gear below (scroll to compare)" or "Selected item (tap another slot to change focus)")
        else
            tipInfo:SetText("Item tooltips are unavailable on this client.")
        end
        updateSecureUse()
    end
    local function makeSlot(i)
        local button = CreateFrame("Button", nil, content, "BackdropTemplate")
        button:SetSize(SLOT,SLOT)
        button:SetPoint("TOPLEFT", (i%COLS)*(SLOT+GAP), -math.floor(i/COLS)*(SLOT+GAP))
        WoWU_Theme.Backdrop(button,{ bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        WoWU_Theme.Color(button,0.14,0.18,0.20,1)
        WoWU_Theme.Border(button,0.34,0.35,0.33,1)
        local icon = button:CreateTexture(nil,"ARTWORK")
        icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3)
        button.icon = icon
        local num = label(button,13,{1,1,1},"")
        num:SetPoint("BOTTOMRIGHT",-6,5)
        num:SetShadowOffset(1,-1)
        button.num=num
        local de=label(button,12,{.85,.55,1},"DE?")
        de:SetPoint("TOPLEFT",5,-5);de:SetShadowColor(0,0,0,1);de:SetShadowOffset(1,-1);de:Hide()
        button.disenchant=de
        local protected=button:CreateTexture(nil,"OVERLAY")
        protected:SetSize(17,17);protected:SetPoint("TOPRIGHT",-4,-4);protected:SetTexture("Interface\\Icons\\INV_Shield_04");protected:Hide()
        button.protected=protected
        -- Focus outline remains on the selected slot, independently of rarity.
        local focus=button:CreateTexture(nil,"OVERLAY",nil,7)
        focus:SetTexture("Interface\\Buttons\\WHITE8X8")
        focus:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
        focus:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
        focus:SetVertexColor(1,.82,.34,.22)
        focus:Hide()
        button.focus=focus
        local focusBorder=CreateFrame("Frame",nil,button,"BackdropTemplate")
        focusBorder:SetAllPoints(button)
        focusBorder:SetFrameLevel(button:GetFrameLevel()+3)
        WoWU_Theme.Backdrop(focusBorder,{edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=19})
        WoWU_Theme.Border(focusBorder,1,.85,.30,1)
        focusBorder:EnableMouse(false)
        focusBorder:Hide()
        button.focusBorder=focusBorder
        local lock=button:CreateTexture(nil,"OVERLAY")
        lock:SetAllPoints(icon);lock:SetColorTexture(0.1,0.1,0.1,0.45);lock:Hide()
        button.lock=lock
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnMouseDown",function(self,mouse)if mouse=="LeftButton"then self.pressTime=GetTime()end end)
        button:SetScript("OnClick", function(self,mouse)
            if self.ignoreDropClick then return end
            if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll) then return end
            if self.bag==nil then return end
            if CursorHasItem and CursorHasItem()then
                if not combat()and C_Container and C_Container.PickupContainerItem then
                    WoWU_StopTouchScroll(scroll,true);C_Container.PickupContainerItem(self.bag,self.slot)
                end
                return
            end
            local _, _, _, _, link = getItem(self.bag,self.slot)
            if not link then
                if CursorHasItem and CursorHasItem() and C_Container and C_Container.PickupContainerItem and not combat() then
                    C_Container.PickupContainerItem(self.bag,self.slot)
                end
                return
            end
            if (SpellIsTargeting and SpellIsTargeting())or(SpellCanTargetItem and SpellCanTargetItem())or(SpellCanTargetItemID and SpellCanTargetItemID())then
                if combat()then showNotice("Apply items outside combat.");return end
                if (SpellCanTargetItem and SpellCanTargetItem())or(SpellCanTargetItemID and SpellCanTargetItemID())then
                    local fn=C_Container and C_Container.UseContainerItem or UseContainerItem
                    if fn then local ok,err=pcall(fn,self.bag,self.slot);showNotice(ok and "Item target selected."or tostring(err),ok)end
                else showNotice("This targeting cursor cannot be applied to a bag item.")end
                return
            end
            if parent.WoWUMailActive and MailFrame and MailFrame.selectedTab==2 and mouse=="LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() then
                if combat() then showNotice("Attach items after combat.");return end
                if SpellIsTargeting and SpellIsTargeting()then showNotice("Clear the spell targeting cursor before attaching mail items.");return end
                local ok,err=pcall(C_Container.UseContainerItem,self.bag,self.slot)
                showNotice(ok and "Attachment requested. Review it in Send Mail before sending."or tostring(err),ok)
                return
            end
            if IsShiftKeyDown() and ChatEdit_InsertLink then
                ChatEdit_InsertLink(link)
            elseif IsControlKeyDown() and DressUpItemLink then
                DressUpItemLink(link)
            elseif mouse == "RightButton" then
                selectedBag,selectedSlot=self.bag,self.slot
                showNotice("")
                refresh()

            else
                selectedBag,selectedSlot=self.bag,self.slot
                showNotice("")
                refresh()

            end
        end)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart",function(self)
            if combat() or self.bag==nil then return end
            -- A quick swipe scrolls. A deliberate hold transfers ownership to
            -- inventory dragging and stops both tracking and inertia.
            if WoWU_IsLocked()and GetTime()-(self.pressTime or GetTime())<.35 then return end
            if C_Container and type(C_Container.PickupContainerItem)=="function" then
                WoWU_StopTouchScroll(scroll,true)
                C_Container.PickupContainerItem(self.bag,self.slot)
            end
        end)
        button:SetScript("OnReceiveDrag",function(self)
            if combat() or self.bag==nil then return end
            if CursorHasItem and CursorHasItem()and C_Container and type(C_Container.PickupContainerItem)=="function" then
                self.ignoreDropClick=true
                C_Timer.After(0,function()self.ignoreDropClick=nil end)
                WoWU_StopTouchScroll(scroll,true)
                C_Container.PickupContainerItem(self.bag,self.slot)
            end
        end)
        -- Hover must never change selection. The inspector stays pinned to the
        -- item chosen by a tap/click, including when the finger leaves the slot.
        buttons[i+1]=button
        return button
    end
    refresh = function()
        local oldSlot,oldCols=SLOT,COLS
        local oldOffset=scroll:GetVerticalScroll()
        local scale=tonumber(WoWU_GetPreference and WoWU_GetPreference("bagIconScale")) or 1
        if scale~=scale then scale=1 end
        SLOT=math.floor(DEFAULT_SLOT*math.max(.6,math.min(1.6,scale))+.5)
        local width=math.max(SLOT,scroll:GetWidth())
        COLS=math.max(1,math.floor((width+GAP)/(SLOT+GAP)))
        content:SetWidth(width)
        local index, occupied, total = 0,0,0
        -- Bag IDs 0 to NUM_BAG_SLOTS are backpack + equipped inventory bags.
        for bag=0,WoWUClient.LastBag() do
            for slot=1,getSlots(bag) do
                local icon,count,quality,locked,link=getItem(bag,slot)
                local b=buttons[index+1] or makeSlot(index)
                b:SetSize(SLOT,SLOT)
                b:ClearAllPoints();b:SetPoint("TOPLEFT",(index%COLS)*(SLOT+GAP),-math.floor(index/COLS)*(SLOT+GAP))
                b.num:SetFont("Fonts\\FRIZQT__.TTF",math.max(10,math.min(16,math.floor(SLOT*.21))),"")
                b.disenchant:SetFont("Fonts\\FRIZQT__.TTF",math.max(9,math.min(14,math.floor(SLOT*.19))),"")
                b.protected:SetSize(math.max(12,math.floor(SLOT*.27)),math.max(12,math.floor(SLOT*.27)))
                b.bag,b.slot=bag,slot
                b.icon:SetTexture(icon)
                b.icon:SetShown(icon~=nil)
                b.num:SetText(icon and count and count>1 and tostring(count) or "")
                b.lock:SetShown(locked and icon~=nil or false)
                local data=C_Container.GetContainerItemInfo(bag,slot)
                b.protected:SetShown(data and WoWUQoL.IsProtected(data.itemID)or false)
                b.disenchant:SetShown(icon~=nil and WoWUDisenchant and WoWUDisenchant.Candidate(bag,slot) and true or false)
                local q=quality and QUALITY[quality]
                local focused=(selectedBag==bag and selectedSlot==slot and icon~=nil)
                b.focus:SetShown(focused)
                b.focusBorder:SetShown(focused)
                if q then
                    b:SetBackdropBorderColor(q.r,q.g,q.b,1)
                else
                    WoWU_Theme.Border(b,0.35,0.35,0.34,1)
                end
                b:Show()
                index=index+1; total=total+1
                if icon then occupied=occupied+1 end
            end
        end
        for i=index+1,#buttons do
            buttons[i].focus:Hide()
            buttons[i].focusBorder:Hide()
            buttons[i]:Hide()
        end
        content:SetHeight(math.max(1,math.ceil(index/COLS)*(SLOT+GAP)-GAP))
        if oldSlot~=SLOT or oldCols~=COLS then
            local first=math.floor(oldOffset/(oldSlot+GAP))*oldCols
            oldOffset=math.floor(first/COLS)*(SLOT+GAP)
        end
        scroll:SetVerticalScroll(math.max(0,math.min(oldOffset,math.max(0,content:GetHeight()-scroll:GetHeight()))))
        countText:SetText(occupied.." / "..total.." slots")
        displayTip()
    end
    -- Re-resolve the receipt's full item link after sorting/moving items, then
    -- focus its actual current slot. Never equip or consume the item here.
    function WoWU_ShowBagItem(link)
        if combat() then return false,"Open Bags after combat." end
        if not link then return false,"Item reference unavailable." end
        local index=0
        for bag=0,WoWUClient.LastBag() do
            for slot=1,getSlots(bag) do
                local _,_,_,_,current=getItem(bag,slot)
                if current==link then
                    selectedBag,selectedSlot=bag,slot
                    WoWU_ShowPage("Bags");showNotice("");refresh()
                    local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
                    scroll:SetVerticalScroll(math.min(maximum,math.max(0,math.floor(index/COLS)*(SLOT+GAP)-12)))
                    return true
                end
                index=index+1
            end
        end
        return false,"That item is no longer in your carried bags."
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ITEM_LOCK_CHANGED")
    events:RegisterEvent("SKILL_LINES_CHANGED")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    parent.WoWURefreshBags=refresh
    WoWU_RefreshBags=function()refresh();if parent.WoWURefreshBank then parent.WoWURefreshBank()end;if parent.WoWURefreshMerchant then parent.WoWURefreshMerchant()end end
    scroll:HookScript("OnSizeChanged",function()if parent:IsShown() then refresh()end end)
    events:SetScript("OnEvent", refresh)
    parent:SetScript("OnShow", refresh)
    refresh()
    local originalLeft={}
    for i=1,left:GetNumPoints()do originalLeft[i]={left:GetPoint(i)}end
    parent.WoWUSetMailLayout=function(enabled,context)
        parent.WoWUMailActive=enabled and context~='bank'
        left:ClearAllPoints()
        if enabled then
            left:SetPoint("TOPLEFT",parent,"TOPLEFT",10,-9);left:SetPoint("BOTTOMRIGHT",parent,"BOTTOM",-12,9)
            right:Hide();actions:Hide();info:SetText(context=='bank'and 'Inventory - drag items between your bags and bank'or "Inventory - tap items to attach in Send Mail")
        else
            for _,p in ipairs(originalLeft)do left:SetPoint(unpack(p))end
            right:Show();actions:Show();info:SetText("Bags")
        end
        refresh()
    end
    if WoWU_BuildBank then WoWU_BuildBank(parent,{left,right,actions})end
    if WoWU_BuildMerchant then WoWU_BuildMerchant(parent,{left,right,actions})end
    if WoWU_BuildAuctionHouse then WoWU_BuildAuctionHouse(parent,{left,right,actions})end
end
