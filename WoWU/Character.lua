-- WoWU: live character paper doll and attributes for WoW Forever.
local GOLD = {0.94,0.79,0.49}
local SLOTS = {
    {1,'Head'}, {2,'Neck'}, {3,'Shoulder'}, {15,'Back'},
    {5,'Chest'}, {4,'Shirt'}, {19,'Tabard'}, {9,'Wrist'},
    {10,'Hands'}, {6,'Waist'}, {7,'Legs'}, {8,'Feet'},
    {11,'Finger 1'}, {12,'Finger 2'}, {13,'Trinket 1'}, {14,'Trinket 2'},
    {16,'Main Hand'}, {17,'Off Hand'},
}
local function frame(parent)
    local f = CreateFrame('Frame',nil,parent,'BackdropTemplate')
    WoWU_Theme.Backdrop(f,{bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=18,insets={left=5,right=5,top=5,bottom=5}})
    WoWU_Theme.Color(f,.075,.10,.12,.96)
    WoWU_Theme.Panel(f)
    return f
end
local function text(parent,size,txt,color)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    f:SetFont('Fonts\\FRIZQT__.TTF',size,'')
    WoWU_Theme.TextColor(f,unpack(color or GOLD))
    f:SetText(txt or '')
    f:SetJustifyH('LEFT')
    return f
end
local function safeNumber(v)
    if not WoWUClient.Public(v) or type(v)~='number' then return '-' end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(math.floor(v))
end
function WoWU_BuildCharacter(parent)
    local left=frame(parent)
    left:SetPoint('TOPLEFT',10,-9)
    left:SetPoint('BOTTOMLEFT',10,9)
    left:SetWidth(680)
    local right=frame(parent)
    right:SetPoint('TOPLEFT',left,'TOPRIGHT',9,0)
    right:SetPoint('BOTTOMRIGHT',parent,'BOTTOMRIGHT',-10,9)

    local who=text(left,19,'',GOLD)
    who:SetPoint('TOPLEFT',18,-16)
    local model=CreateFrame('PlayerModel',nil,left)
    model:SetPoint('TOPLEFT',60,-62)
    model:SetPoint('BOTTOMRIGHT',-60,105)
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(1.25)
    local slots={}
    local itemButtons={}
    local function updateSlot(b)
        local texture=GetInventoryItemTexture('player',b.slot)
        b.icon:SetTexture(texture or 'Interface\\PaperDoll\\UI-PaperDoll-Slot-'..b.slot)
        if not texture then b.icon:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark'); b.icon:SetDesaturated(true) else b.icon:SetDesaturated(false) end
        local link=GetInventoryItemLink('player',b.slot)
        -- Forever builds may expose item info through C_Item instead of the
        -- legacy global GetItemInfo. Missing/uncached data is not an error.
        local quality, itemName
        if link then
            if type(GetItemInfo) == 'function' then
                itemName, _, quality = GetItemInfo(link)
            elseif C_Item and type(C_Item.GetItemInfo) == 'function' then
                itemName, _, quality = C_Item.GetItemInfo(link)
            end
        end
        -- The link's displayed name is immediately available even before item cache loads.
        if not itemName and link then itemName = link:match('%[(.-)%]') end
        b.itemLabel:SetText(itemName or (texture and 'Loading...' or b.slotName))
        local c=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c then b.itemLabel:SetTextColor(c.r,c.g,c.b) else b.itemLabel:SetTextColor(.75,.72,.66) end
        if c then b:SetBackdropBorderColor(c.r,c.g,c.b,1) else WoWU_Theme.Border(b,.45,.40,.31,1) end
        b:SetAlpha(texture and 1 or .58)
    end
    for i,entry in ipairs(SLOTS) do
        local slot,name=entry[1],entry[2]
        local b=CreateFrame('Button',nil,left,'BackdropTemplate')
        b.slot=slot
        b.slotName=name
        b:SetSize(53,53)
        -- Two columns at the sides, and a pair of weapon slots beneath the model.
        if i<=8 then b:SetPoint('TOPLEFT',18,-66-(i-1)*62)
        elseif i<=16 then b:SetPoint('TOPRIGHT',-18,-66-(i-9)*62)
        else b:SetPoint('BOTTOM',left,'BOTTOM',i==17 and -38 or 38,24) end
        WoWU_Theme.Backdrop(b,{bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
        WoWU_Theme.Color(b,.12,.14,.17,.95)
        WoWU_Theme.Border(b,.45,.40,.31,1)
        b.icon=b:CreateTexture(nil,'ARTWORK')
        b.icon:SetPoint('TOPLEFT',5,-5);b.icon:SetPoint('BOTTOMRIGHT',-5,5)
        b.itemLabel=text(left,12,name,{.75,.72,.66})
        b.itemLabel:SetHeight(36)
        b.itemLabel:SetWidth(160)
        b.itemLabel:SetWordWrap(true)
        if i<=8 then
            b.itemLabel:SetPoint('LEFT',b,'RIGHT',6,0)
        elseif i<=16 then
            b.itemLabel:SetJustifyH('RIGHT')
            b.itemLabel:SetPoint('RIGHT',b,'LEFT',-6,0)
        else
            b.itemLabel:SetWidth(125)
            b.itemLabel:SetJustifyH('CENTER')
            b.itemLabel:SetPoint('BOTTOM',b,'TOP',0,3)
        end
        b.WoWUItemSlot=slot;b:EnableMouse(true)
        b:RegisterForClicks('LeftButtonUp','RightButtonUp')
        b:SetScript('OnEnter',function(self)
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            if not GameTooltip:SetInventoryItem('player',slot) then GameTooltip:SetText(name) end
            GameTooltip:Show()
        end)
        b:SetScript('OnLeave',function() GameTooltip:Hide() end);WoWUDetails.BindHover(b,false)
        b:SetScript('OnClick',function(self,button)
            if IsModifiedClick('DRESSUP') then DressUpItemLink(GetInventoryItemLink('player',slot) or '')
            elseif IsModifiedClick('CHATLINK') and ChatEdit_InsertLink then ChatEdit_InsertLink(GetInventoryItemLink('player',slot) or '')
            -- Right-click intentionally does nothing. Calling ToggleCharacter here
            -- taints Blizzard's character panel on WoW Forever (secret values).
            end
        end)
        slots[#slots+1]=b
    end
    local orientation=text(left,12,'Drag the model to rotate | Tap gear for item details',{.72,.70,.63})
    orientation:SetPoint('BOTTOM',0,7)
    model:EnableMouse(true)
    model:SetScript('OnMouseDown',function(self) self.dragStart=GetCursorPosition() end)
    model:SetScript('OnMouseUp',function(self) self.dragStart=nil end)
    model:SetScript('OnUpdate',function(self)
        if self.dragStart then
            local x=GetCursorPosition()
            self:SetFacing((self:GetFacing() or 0)+(x-self.dragStart)*.01)
            self.dragStart=x
        end
    end)

    local statsData={}
    local function stat(i,k,v) statsData[i]={name=k,value=v or "--"} end
    local details=WoWU_CreateCharacterDetails(right,function() return statsData end)
    local function update()
        if not parent:IsShown() or WoWUClient.isRetail and InCombatLockdown() then return end
        local name=UnitName('player') or 'Adventurer'
        local level=UnitLevel('player') or '?'
        local _,class=UnitClass('player')
        who:SetText(name..'  |  Level '..level..'  '..(class or ''))
        for _,b in ipairs(slots) do updateSlot(b) end
        local _,strength=UnitStat('player',1)
        local _,agility=UnitStat('player',2)
        local _,stamina=UnitStat('player',3)
        local _,intellect=UnitStat('player',4)
        local baseArmor,effectiveArmor=UnitArmor('player')
        stat(1,'Strength',safeNumber(strength));stat(2,'Agility',safeNumber(agility))
        stat(3,'Stamina',safeNumber(stamina));stat(4,'Intellect',safeNumber(intellect))
        stat(5,'Armor',safeNumber(effectiveArmor or baseArmor))
        stat(6,'Health',safeNumber(UnitHealthMax('player')))
        stat(7,'Melee Crit',GetCritChance and string.format('%.1f%%',GetCritChance()) or '-')
        stat(8,'Spell Crit',GetSpellCritChance and string.format('%.1f%%',GetSpellCritChance(2) or 0) or '-')
        stat(9,'Haste',GetHaste and string.format('%.1f%%',GetHaste()) or '-')
        stat(10,'Mastery',GetMasteryEffect and string.format('%.1f%%',GetMasteryEffect()) or '-')
        local avg=GetAverageItemLevel and select(2,GetAverageItemLevel())
        stat(11,'Equipped iLvl',avg and string.format('%.1f',avg) or '-')
        local spec=GetSpecialization and GetSpecialization()
        local specName=spec and GetSpecializationInfo and select(2,GetSpecializationInfo(spec))
        stat(12,'Specialization',specName or '-')
        details:RefreshStats()
    end
    local events=CreateFrame('Frame',nil,parent)
    for _,e in ipairs({'PLAYER_EQUIPMENT_CHANGED','UNIT_STATS','UNIT_AURA','PLAYER_LEVEL_UP','PLAYER_ENTERING_WORLD','PLAYER_SPECIALIZATION_CHANGED','COMBAT_RATING_UPDATE','UNIT_MAXHEALTH','GET_ITEM_INFO_RECEIVED','PLAYER_REGEN_ENABLED'}) do pcall(events.RegisterEvent,events,e) end
    events:SetScript('OnEvent',function(_,event,unit)
        if (event=='UNIT_STATS' or event=='UNIT_AURA' or event=='UNIT_MAXHEALTH') and unit~='player' then return end
        update()
    end)
    parent:HookScript('OnShow',function()
        if model.SetUnit then model:SetUnit('player') end
        update()
    end)
    -- Update after the panel has been attached, as the player may not exist during login.
    if parent:IsShown() then model:SetUnit('player');update() end
end
