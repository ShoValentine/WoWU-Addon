-- WoWU-owned Retail banking. Native bank frame stays open offscreen while this page is visible.
local function call(fn,...)
    if type(fn)~='function' then return end
    local function pack(...)return {n=select('#',...),...}end
    local r=pack(pcall(fn,...));if r[1]then return unpack(r,2,r.n)end
end
local function text(parent,size,caption)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    t:SetFont('Fonts\\FRIZQT__.TTF',size,'');WoWU_Theme.TextColor(t,.94,.81,.56)
    t:SetText(caption or '');return t
end
local function panel(parent)
    local f=CreateFrame('Frame',nil,parent,'BackdropTemplate');WoWU_Theme.Panel(f);return f
end
local function button(parent,caption,width,fn)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(width,34);b:SetText(caption);b:SetScript('OnClick',fn);return b
end
local function money(amount)
    return GetMoneyString and GetMoneyString(amount or 0) or tostring(math.floor((amount or 0)/10000))..' gold'
end
function WoWU_BuildBank(parent,normalFrames)
    if not (WoWUClient and WoWUClient.isRetail and C_Bank and Enum and Enum.BankType and C_Container)then return end
    local character,account=Enum.BankType.Character,Enum.BankType.Account
    local bankType,selectedTab=character,nil
    local opened,active,multi=false,false,false
    local tabs,tabButtons={},{}
    local selection={inventory={},bank={}}
    local queue,pending,runSerial=nil,nil,0
    local moved,skipped=0,0
    local nativeState
    local refresh,activate,deactivate,step,beginTransfer
    local view=CreateFrame('Frame',nil,parent)
    view:SetAllPoints();view:SetFrameLevel(parent:GetFrameLevel()+25);view:Hide()
    local left,right=panel(view),panel(view)
    left:SetPoint('TOPLEFT',10,-52);left:SetPoint('BOTTOMRIGHT',view,'BOTTOM',-78,53)
    right:SetPoint('TOPLEFT',view,'TOP',78,-52);right:SetPoint('BOTTOMRIGHT',-10,53)
    local heading=text(view,22,'Bank');heading:SetPoint('TOPLEFT',20,-14)
    local status=text(view,12,'');status:SetPoint('BOTTOMLEFT',20,13);status:SetPoint('BOTTOMRIGHT',-20,13)
    status:SetHeight(30);status:SetWordWrap(true);status:SetJustifyH('LEFT')
    local function say(message)status:SetText(message or '')end
    local function busy()return queue~=nil end
    local function usable(kind)
        return opened and active and parent:IsVisible() and not InCombatLockdown() and call(C_Bank.CanUseBank,kind)==true
    end
    local function item(bag,slot)return call(C_Container.GetContainerItemInfo,bag,slot)end
    local function slotCount(bag)return call(C_Container.GetContainerNumSlots,bag)or 0 end
    local function location(bag,slot)
        return ItemLocation and ItemLocation:CreateFromBagAndSlot(bag,slot)
    end
    local function snapshot(bag,slot)
        local info=item(bag,slot);if not info or not info.itemID then return end
        return {bag=bag,slot=slot,id=info.itemID,link=info.hyperlink or call(C_Container.GetContainerItemLink,bag,slot),count=info.stackCount or 1,
            guid=call(C_Item and C_Item.GetItemGUID,location(bag,slot))}
    end
    local function matches(s)
        local info=s and item(s.bag,s.slot)
        if not info or info.isLocked or info.itemID~=s.id or info.hyperlink~=s.link or (info.stackCount or 1)~=s.count then return false end
        return not s.guid or call(C_Item.GetItemGUID,location(s.bag,s.slot))==s.guid
    end
    local function key(bag,slot)return bag..':'..slot end
    local function inventoryBags()
        local result={};for bag=0,WoWUClient.LastBag()do result[#result+1]=bag end;return result
    end
    local function clearSelection()wipe(selection.inventory);wipe(selection.bank)end
    local function stop(message)
        queue,pending=nil,nil;runSerial=runSerial+1
        if message then say(message)end
    end
    -- Moving rather than hiding the native frame avoids its OnHide closing the banker interaction.
    local function parkNative()
        local f=BankFrame;if not f or not f:IsShown()then return end
        if not nativeState then
            nativeState={frame=f,points={},clamped=f:IsClampedToScreen()}
            for i=1,f:GetNumPoints()do nativeState.points[i]={f:GetPoint(i)}end
        end
        f:SetClampedToScreen(false);f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-3000)
    end
    local function restoreNative()
        local s=nativeState;nativeState=nil
        if not s then return end
        s.frame:ClearAllPoints()
        for _,p in ipairs(s.points)do s.frame:SetPoint(unpack(p))end
        s.frame:SetClampedToScreen(s.clamped)
    end
    local personal=button(view,'Personal Bank',140,function()
        if busy()then say('Stop the transfer before changing banks.');return end
        bankType=character;selectedTab=nil;clearSelection();refresh()
    end);personal:SetPoint('TOPRIGHT',-265,-9)
    local warband=button(view,'Warband Bank',140,function()
        if busy()then say('Stop the transfer before changing banks.');return end
        bankType=account;selectedTab=nil;clearSelection();refresh()
    end);warband:SetPoint('TOPRIGHT',-117,-9)
    local close=button(view,'Close',95,function()
        stop();if C_Bank.CloseBankFrame then C_Bank.CloseBankFrame()end
    end);close:SetPoint('TOPRIGHT',-14,-9)
    local counts=text(view,12,'');counts:SetPoint('CENTER',view,'CENTER',0,-58);counts:SetWidth(142);counts:SetWordWrap(true)
    local toBank=button(view,'To Bank >',126,function()beginTransfer('inventory',false)end);toBank:SetPoint('CENTER',view,'CENTER',0,92)
    local toBags=button(view,'< To Bags',126,function()beginTransfer('bank',false)end);toBags:SetPoint('CENTER',view,'CENTER',0,44)
    local selectButton=button(view,'Select Items',126,function()
        if busy()then return end
        multi=not multi;clearSelection();refresh();say(multi and 'Tap items to select several stacks, then choose a transfer arrow.'or 'Tap one item, then choose a transfer arrow.')
    end);selectButton:SetPoint('CENTER',view,'CENTER',0,-7)
    local clear=button(view,'Clear selection',126,function()
        if busy()then stop('Transfer stopped. Completed moves are kept.')end
        clearSelection();refresh()
    end);clear:SetPoint('CENTER',view,'CENTER',0,-112)
    local grids={}
    for _,entry in ipairs({{'inventory',left,'Inventory'},{'bank',right,'Personal Bank'}})do
        local side,f=entry[1],entry[2]
        local title=text(f,17,entry[3]);title:SetPoint('TOPLEFT',16,-15)
        local capacity=text(f,12,'');capacity:SetPoint('TOPRIGHT',-16,-17)
        local sc=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate')
        sc:SetPoint('TOPLEFT',12,-48);sc:SetPoint('BOTTOMRIGHT',-32,60)
        if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(sc)end
        local body=CreateFrame('Frame',nil,sc);body:SetSize(400,1);sc:SetScrollChild(body)
        grids[side]={frame=f,title=title,capacity=capacity,scroll=sc,body=body,buttons={},bags={}}
    end
    grids.bank.scroll:SetPoint('BOTTOMRIGHT',-32,87)
    local empty=text(right,14,'');empty:SetPoint('TOPLEFT',20,-145);empty:SetPoint('RIGHT',-30,0);empty:SetWordWrap(true);empty:SetJustifyH('LEFT')
    local reagentButton=button(left,'Deposit all reagents',210,function()beginTransfer('inventory',true)end)
    reagentButton:SetPoint('BOTTOMLEFT',12,12)
    local balance=text(right,12,'');balance:SetPoint('BOTTOMLEFT',14,59)
    local deposit=button(right,'Deposit money',160,function()
        if busy()or not usable(account)or not call(C_Bank.CanDepositMoney,account)then say('Warband money deposits are unavailable here.');return end
        StaticPopup_Show('WOWU_BANK_MONEY')
    end);deposit:SetPoint('BOTTOMLEFT',12,12)
    local function sortedSelection(side)
        local list={};for _,s in pairs(selection[side])do list[#list+1]=s end
        table.sort(list,function(a,b)return a.bag==b.bag and a.slot<b.slot or a.bag<b.bag end);return list
    end
    local function drawGrid(side,bags)
        local g=grids[side];g.bags=bags
        local scale=tonumber(WoWU_GetPreference('bagIconScale'))or 1
        local size=math.floor(62*math.max(.6,math.min(1.6,scale))+.5)
        local width=math.max(size,g.scroll:GetWidth());local columns=math.max(1,math.floor((width+5)/(size+5)))
        local oldOffset=g.scroll:GetVerticalScroll();local index,free,total=0,0,0
        g.body:SetWidth(width)
        for _,bag in ipairs(bags)do
            for slot=1,slotCount(bag)do
                index=index+1;total=total+1
                local info=item(bag,slot);if not info then free=free+1 end
                local b=g.buttons[index]
                if not b then
                    b=CreateFrame('Button',nil,g.body,'BackdropTemplate')
                    WoWU_Theme.Backdrop(b,{bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
                    WoWU_Theme.Color(b,.13,.16,.17,1)
                    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',3,-3);b.icon:SetPoint('BOTTOMRIGHT',-3,3)
                    b.count=b:CreateFontString(nil,'OVERLAY','NumberFontNormal');b.count:SetPoint('BOTTOMRIGHT',-4,4)
                    b.mark=b:CreateTexture(nil,'OVERLAY',nil,7);b.mark:SetAllPoints();b.mark:SetColorTexture(1,.8,.2,.35)
                    b.tick=b:CreateTexture(nil,'OVERLAY',nil,7);b.tick:SetSize(22,22);b.tick:SetPoint('TOPLEFT',1,-1);b.tick:SetTexture('Interface\\RaidFrame\\ReadyCheck-Ready')
                    b:SetScript('OnClick',function(self)
                        if busy()or not usable(bankType)then return end
                        if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(g.scroll)then return end
                        local s=snapshot(self.bag,self.slot);if not s then return end
                        if not s.link then call(C_Item.RequestLoadItemDataByID,s.id);say('Item data is still loading. Tap this item again in a moment.');return end
                        if CursorHasItem()then say('Place the item on your cursor before selecting a transfer.');return end
                        local k=key(self.bag,self.slot);local previous=selection[side][k]
                        if not multi then clearSelection()end
                        selection[side][k]=not previous and s or nil
                        say(s.link or 'Item selected');refresh()
                    end)
                    b:SetScript('OnEnter',function(self)
                        local gesture=g.scroll.WoWUGesture;if gesture and gesture.dragging then return end
                        if GameTooltip and item(self.bag,self.slot)then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetBagItem(self.bag,self.slot);GameTooltip:Show()end
                    end)
                    b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);WoWUDetails.BindHover(b,function()return multi end)
                    g.buttons[index]=b
                end
                b.bag,b.slot=bag,slot;b:ClearAllPoints();b:SetSize(size,size)
                b:SetPoint('TOPLEFT',((index-1)%columns)*(size+5),-math.floor((index-1)/columns)*(size+5))
                b.icon:SetTexture(info and info.iconFileID);b.count:SetText(info and info.stackCount>1 and info.stackCount or '')
                local chosen=selection[side][key(bag,slot)]
                if chosen and not busy()and not matches(chosen)then selection[side][key(bag,slot)]=nil;chosen=nil end
                b.mark:SetShown(chosen~=nil);b.tick:SetShown(chosen~=nil)
                local q=info and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
                if q then b:SetBackdropBorderColor(q.r,q.g,q.b,1)else WoWU_Theme.Border(b,.35,.35,.34,1)end
                b:SetAlpha(info and info.isLocked and .5 or 1);b:Show()
            end
        end
        for i=index+1,#g.buttons do g.buttons[i]:Hide()end
        g.body:SetHeight(math.max(1,math.ceil(index/columns)*(size+5)-5))
        g.scroll:SetVerticalScroll(math.min(oldOffset,math.max(0,g.body:GetHeight()-g.scroll:GetHeight())))
        g.capacity:SetText(free..' / '..total..' free')
    end
    local function getTabs()
        local result=call(C_Bank.FetchPurchasedBankTabData,bankType)
        return type(result)=='table'and result or {}
    end
    local function refreshTabs()
        tabs=getTabs()
        local found=false;for _,tab in ipairs(tabs)do if tab.ID==selectedTab then found=true end end
        if not found then selectedTab=tabs[1]and tabs[1].ID or nil;wipe(selection.bank)end
        local cols=math.max(1,math.floor((right:GetWidth()-32)/112))
        local purchase=call(C_Bank.FetchNextPurchasableBankTabData,bankType)
        for i=1,#tabs+(purchase and 1 or 0)do
            local b=tabButtons[i]
            if not b then
                b=button(right,'',106,function(self)
                    if busy()then say('Stop the transfer before changing tabs.');return end
                    if self.purchase then
                        if not usable(bankType)then return end
                        local data=call(C_Bank.FetchNextPurchasableBankTabData,bankType)
                        if not data then say('No further bank tabs are available.');return end
                        if not data.canAfford then say('The next bank tab costs '..money(data.tabCost)..'. You do not have enough money.');return end
                        if not call(C_Bank.CanPurchaseBankTab,bankType)then say('This bank tab cannot be purchased here.');return end
                        StaticPopup_Show('WOWU_BANK_BUY_TAB',money(data.tabCost),nil,{kind=bankType,cost=data.tabCost})
                    else selectedTab=self.tabID;wipe(selection.bank);grids.bank.scroll:SetVerticalScroll(0);refresh()end
                end)
                local t=b:GetFontString();t:SetWidth(90);t:SetWordWrap(false);tabButtons[i]=b
            end
            local tab=tabs[i];b.tabID=tab and tab.ID;b.purchase=not tab
            b:ClearAllPoints();b:SetPoint('TOPLEFT',14+((i-1)%cols)*112,-42-math.floor((i-1)/cols)*38)
            b:SetText(tab and (tab.name~=''and tab.name or 'Tab '..i)or '+ Buy tab')
            b:SetAlpha(tab and tab.ID~=selectedTab and .7 or 1);b:SetEnabled(not busy()and usable(bankType));b:Show()
        end
        for i=#tabs+(purchase and 1 or 0)+1,#tabButtons do tabButtons[i]:Hide()end
        local rows=math.max(1,math.ceil((#tabs+(purchase and 1 or 0))/cols))
        grids.bank.scroll:ClearAllPoints();grids.bank.scroll:SetPoint('TOPLEFT',12,-48-rows*38);grids.bank.scroll:SetPoint('BOTTOMRIGHT',-32,87)
        local canUse=usable(bankType)
        empty:SetShown(not canUse or not selectedTab)
        empty:SetText(not canUse and 'This bank is not accessible at the current banker, or is temporarily locked.'or 'Purchase a bank tab to begin using this storage.')
        grids.bank.title:SetText(bankType==account and 'Warband Bank'or 'Personal Bank')
        return canUse and selectedTab and {selectedTab}or {}
    end
    refresh=function()
        if not active then return end
        personal:SetEnabled(not busy()and call(C_Bank.CanViewBank,character)==true)
        warband:SetEnabled(not busy()and call(C_Bank.CanViewBank,account)==true)
        local bankBags=refreshTabs()
        drawGrid('inventory',inventoryBags());drawGrid('bank',bankBags)
        local nleft,nright=#sortedSelection('inventory'),#sortedSelection('bank')
        counts:SetText(nleft..' inventory\n'..nright..' bank selected')
        toBank:SetEnabled(not busy()and usable(bankType)and selectedTab~=nil and nleft>0)
        toBags:SetEnabled(not busy()and usable(bankType)and nright>0)
        selectButton:SetText(multi and 'Select Items: ON'or 'Select Items');selectButton:SetEnabled(not busy())
        clear:SetText(busy()and 'Stop transfer'or 'Clear selection')
        reagentButton:SetEnabled(not busy()and usable(bankType)and selectedTab~=nil)
        balance:SetShown(bankType==account);balance:SetText('Warband funds: '..money(call(C_Bank.FetchDepositedMoney,account)))
        deposit:SetShown(bankType==account);deposit:SetEnabled(not busy()and usable(account)and call(C_Bank.CanDepositMoney,account)==true)
    end
    local function destinationBags(q)
        if q.side=='bank'then return inventoryBags()end
        if not q.reagents then return {q.tab}end
        local result={q.tab};for _,tab in ipairs(getTabs())do if tab.ID~=q.tab then result[#result+1]=tab.ID end end;return result
    end
    local function destination(s,bags)
        local getInfo=C_Item.GetItemInfo or GetItemInfo
        local maxStack=select(8,call(getInfo,s.link or s.id))or 1
        local family=call(C_Item.GetItemFamily,s.link or s.id)or 0
        local firstEmpty
        for _,bag in ipairs(bags)do
            local _,bagFamily=call(C_Container.GetContainerNumFreeSlots,bag)
            local accepts=not bagFamily or bagFamily==0 or (bit and bit.band(family,bagFamily)~=0)
            if accepts then
                for slot=1,slotCount(bag)do
                    local info=item(bag,slot)
                    if not info then firstEmpty=firstEmpty or {bag=bag,slot=slot,count=0}
                    elseif not info.isLocked and info.hyperlink==s.link and (info.stackCount or 1)+s.count<=maxStack then
                        return {bag=bag,slot=slot,count=info.stackCount or 1}
                    end
                end
            end
        end
        return firstEmpty
    end
    local function acknowledge()
        if not pending then return end
        local s,d=pending.source,pending.destination
        local src,dst=item(s.bag,s.slot),item(d.bag,d.slot)
        if not src and dst and not dst.isLocked and dst.itemID==s.id and dst.hyperlink==s.link and (dst.stackCount or 1)==d.count+s.count then
            pending=nil;moved=moved+1;selection[queue.side][key(s.bag,s.slot)]=nil
            say('Transferred '..moved..' stack(s)'..(skipped>0 and '; skipped '..skipped or '')..'...')
            local serial=runSerial;C_Timer.After(.12,function()if serial==runSerial then step()end end)
        end
    end
    step=function()
        local q=queue;if not q or pending then return end
        if not usable(q.kind)or bankType~=q.kind or not parent:IsVisible()then stop('Transfer stopped: bank access changed.');refresh();return end
        if CursorHasItem()then stop('Transfer stopped: the cursor is holding an item.');refresh();return end
        local s=table.remove(q.items,1)
        if not s then stop('Transferred '..moved..' stack(s).'..(skipped>0 and ' Skipped '..skipped..' changed, locked or ineligible stack(s).'or ''));refresh();return end
        local allowed=q.side=='bank'or call(C_Bank.IsItemAllowedInBankType,q.kind,location(s.bag,s.slot))==true
        if not s.link or not matches(s)or not allowed then
            skipped=skipped+1
            local serial=runSerial;C_Timer.After(.05,function()if serial==runSerial then step()end end);return
        end
        local d=destination(s,destinationBags(q))
        if not d then stop('Transfer stopped: no compatible space for the next stack. '..moved..' stack(s) transferred.');refresh();return end
        -- Only empty slots or a matching stack able to hold the ENTIRE source are eligible. Never swap unrelated items.
        if not matches(s)then stop('Transfer stopped: the selected stack changed.');refresh();return end
        if q.side=='inventory'and q.kind==account and not q.refundApproved and call(C_Item.CanBeRefunded,location(s.bag,s.slot))then
            stop('Transfer stopped: this item now requires confirmation of lost refund eligibility. Select it again.');refresh();return
        end
        local ok,err=pcall(C_Container.PickupContainerItem,s.bag,s.slot)
        if not ok or not CursorHasItem()then stop('Transfer blocked by the game: '..tostring(err or 'item could not be picked up'));refresh();return end
        local target=item(d.bag,d.slot)
        local targetUnchanged=d.count==0 and not target or d.count>0 and target and not target.isLocked and target.hyperlink==s.link and target.stackCount==d.count
        if queue~=q or not usable(q.kind)or not targetUnchanged then
            if CursorHasItem()then ClearCursor()end
            stop('Transfer stopped: bank access or the destination changed. The held item was returned.');refresh();return
        end
        pending={source=s,destination=d}
        ok,err=pcall(C_Container.PickupContainerItem,d.bag,d.slot)
        if not ok or CursorHasItem()then
            -- We own this cursor pickup. Return it to its original slot before stopping.
            if CursorHasItem()then ClearCursor()end
            stop('Transfer stopped: '..tostring(err or 'the destination rejected this item')..'. Check the item and any Blizzard prompt.');refresh();return
        end
        if queue~=q then refresh();return end
        local serial=runSerial
        C_Timer.After(.15,function()if serial==runSerial and queue then acknowledge()end end)
        C_Timer.After(4,function()
            if serial==runSerial and pending and pending.source==s then
                stop('Transfer paused: the game did not confirm the move. Check your bags before trying again.');refresh()
            end
        end)
    end
    local function start(items,side,reagents,refundApproved)
        if busy()or not usable(bankType)or not selectedTab or CursorHasItem()then say('Transfer unavailable. Clear your cursor and keep the bank open.');return end
        queue={items=items,side=side,reagents=reagents,kind=bankType,tab=selectedTab,refundApproved=refundApproved};pending=nil;moved,skipped=0,0;runSerial=runSerial+1
        refresh();step()
    end
    beginTransfer=function(side,reagents)
        if busy()or not usable(bankType)then say('Bank transfers are unavailable right now.');return end
        local items={};local uncached=0
        if reagents then
            for _,bag in ipairs(inventoryBags())do for slot=1,slotCount(bag)do
                local s=snapshot(bag,slot)
                if s then
                    local reagent=select(17,call(C_Item.GetItemInfo or GetItemInfo,s.link or s.id))
                    if reagent and s.link then items[#items+1]=s
                    elseif reagent==nil or not s.link then uncached=uncached+1;call(C_Item.RequestLoadItemDataByID,s.id)end
                end
            end end
        else items=sortedSelection(side)end
        if uncached>0 then say('Some item data is still loading. Tap Deposit all reagents again in a moment.');return end
        if #items==0 then say(reagents and 'No crafting reagents found in your inventory.'or 'Select an item first.');return end
        local refundable=false
        if side=='inventory'and bankType==account then
            for _,s in ipairs(items)do if call(C_Item.CanBeRefunded,location(s.bag,s.slot))then refundable=true;break end end
        end
        if refundable then
            StaticPopup_Show('WOWU_BANK_REFUND',nil,nil,{items=items,side=side,reagents=reagents,kind=bankType,tab=selectedTab})
        else start(items,side,reagents)end
    end
    StaticPopupDialogs.WOWU_BANK_REFUND={
        text='One or more selected items are refundable. Depositing them into the Warband Bank ends their refund eligibility. Continue?',
        button1=CONTINUE or 'Continue',button2=CANCEL or 'Cancel',timeout=0,whileDead=false,hideOnEscape=true,
        OnShow=function(dialog)dialog:ClearAllPoints();dialog:SetPoint('CENTER',view,'CENTER',0,0)end,
        OnAccept=function(_,data)if data and data.kind==bankType and data.tab==selectedTab then start(data.items,data.side,data.reagents,true)end end,
    }
    StaticPopupDialogs.WOWU_BANK_BUY_TAB={
        text='Purchase the next bank tab for %s?',button1=YES,button2=NO,timeout=0,whileDead=false,hideOnEscape=true,
        OnShow=function(dialog)dialog:ClearAllPoints();dialog:SetPoint('CENTER',view,'CENTER',0,0)end,
        OnAccept=function(_,data)
            if not data or busy()or data.kind~=bankType or not usable(data.kind)then return end
            local nextTab=call(C_Bank.FetchNextPurchasableBankTabData,data.kind)
            if not nextTab or nextTab.tabCost~=data.cost or not nextTab.canAfford or not call(C_Bank.CanPurchaseBankTab,data.kind)then say('Purchase conditions changed. Select Buy tab again.');return end
            local ok,err=pcall(C_Bank.PurchaseBankTab,data.kind)
            say(ok and 'Bank tab purchase requested.'or 'Bank tab purchase blocked: '..tostring(err))
        end,
    }
    StaticPopupDialogs.WOWU_BANK_MONEY={
        text='Deposit into your Warband Bank',button1='Deposit',button2=CANCEL or 'Cancel',hasMoneyInputFrame=1,
        timeout=0,whileDead=false,hideOnEscape=true,
        OnShow=function(dialog)dialog:ClearAllPoints();dialog:SetPoint('CENTER',view,'CENTER',0,0)end,
        OnAccept=function(dialog)
            if busy()or not usable(account)or not call(C_Bank.CanDepositMoney,account)then say('Warband deposits are no longer available.');return end
            local amount=MoneyInputFrame_GetCopper(dialog.MoneyInputFrame)
            if not amount or amount<=0 or amount>GetMoney()or amount~=math.floor(amount)then say('Enter an amount above zero that you can afford.');return end
            local ok,err=pcall(C_Bank.DepositMoney,account,amount)
            say(ok and 'Warband deposit requested: '..money(amount)or 'Deposit blocked: '..tostring(err))
        end,
        OnHide=function(dialog)MoneyInputFrame_ResetMoney(dialog.MoneyInputFrame)end,
    }
    local function closePrompts()
        for _,name in ipairs({'WOWU_BANK_REFUND','WOWU_BANK_BUY_TAB','WOWU_BANK_MONEY'})do StaticPopup_Hide(name)end
    end
    deactivate=function()
        if not active then return end
        stop();closePrompts();active=false;clearSelection();view:Hide();restoreNative()
        if GameTooltip then GameTooltip:Hide()end
        for _,f in ipairs(normalFrames)do f:Show()end
    end
    activate=function()
        if not opened or InCombatLockdown()or not WoWU_MainFrame or not WoWU_MainFrame:IsVisible()then return end
        if WoWUInteractions then WoWUInteractions.Release()end
        if not parent:IsVisible()then WoWU_ShowPage('Bags')end
        if not parent:IsVisible()then return end
        if active then refresh();return end
        if parent.WoWUDeactivateMerchant then parent.WoWUDeactivateMerchant()end
        active=true
        for _,f in ipairs(normalFrames)do f:Hide()end
        view:Show();parkNative()
        if CloseAllBags then CloseAllBags(BankFrame)end
        if not call(C_Bank.CanUseBank,bankType)then bankType=call(C_Bank.CanUseBank,character)and character or account;selectedTab=nil end
        refresh();say('Tap an item, then transfer it. Select Items lets you choose multiple stacks.')
    end
    local dirty=false
    local events=CreateFrame('Frame')
    for _,event in ipairs({'BANKFRAME_OPENED','BANKFRAME_CLOSED','BANK_TABS_CHANGED','BANK_TAB_SETTINGS_UPDATED','PLAYERBANKSLOTS_CHANGED','PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED','BAG_UPDATE_DELAYED','ITEM_LOCK_CHANGED','ACCOUNT_MONEY','PLAYER_MONEY','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','UI_ERROR_MESSAGE'})do
        pcall(events.RegisterEvent,events,event)
    end
    events:SetScript('OnEvent',function(_,event,_,message)
        if event=='BANKFRAME_OPENED'then
            opened=true;C_Timer.After(0,function()if opened then activate()end end)
        elseif event=='BANKFRAME_CLOSED'then
            opened=false;deactivate()
        elseif event=='PLAYER_REGEN_DISABLED'then
            if active then stop('Bank transfers are unavailable during combat.');closePrompts();dirty=true end
        elseif event=='PLAYER_REGEN_ENABLED'then
            if opened and parent:IsVisible()then activate()end
        elseif event=='UI_ERROR_MESSAGE'and busy()then
            stop('Transfer stopped: '..tostring(message or 'the game rejected this action'));dirty=true
        elseif active then
            if queue and pending then acknowledge()end
            dirty=true
        end
    end)
    events:SetScript('OnUpdate',function()if dirty then dirty=false;refresh()end end)
    parent:HookScript('OnHide',deactivate)
    parent:HookScript('OnShow',function()if opened then C_Timer.After(0,function()if parent:IsVisible()then activate()end end)end end)
    view:HookScript('OnSizeChanged',function()if active then dirty=true end end)
    parent.WoWUDeactivateBank=deactivate
    parent.WoWURefreshBank=function()if active then refresh()end end
end
