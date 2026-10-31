-- Player-triggered secure Disenchant. No ordinary Lua spell-casting or targeting.
local D={spellID=13262};WoWUDisenchant=D
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f,g,h,i,j,k,l,m=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m end
end
local function combat() return InCombatLockdown and InCombatLockdown() end
function D.Available()
    local known=call(WoWUSpellBook and WoWUSpellBook.IsSpellKnown,D.spellID) or call(IsPlayerSpell,D.spellID) or call(IsSpellKnown,D.spellID)
    if not known then return false end
    local skill=call(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,333)
    if skill and skill.rank and skill.rank>0 then return true,skill.rank end
    if GetProfessions and GetProfessionInfo then
        for _,index in pairs({GetProfessions()}) do
            local _,_,rank,_,_,_,skillID=call(GetProfessionInfo,index)
            if skillID==333 and rank and rank>0 then return true,rank end
        end
    end
    -- The learned Disenchant spell is itself an Enchanting ability; use it as
    -- evidence when the client's collapsed skill list cannot expose the rank.
    return true,nil
end
function D.Candidate(bag,slot)
    local available,rank=D.Available()
    if not available then return false,"Learn Enchanting and Disenchant first." end
    local info=call(C_Container and C_Container.GetContainerItemInfo,bag,slot)
    if not info or not info.itemID then return false,"Select an item first." end
    if info.isLocked then return false,"The selected item is locked." end
    local name,link,quality,_,_,_,_,_,equip,_,_,classID=call(C_Item and C_Item.GetItemInfo or GetItemInfo,info.hyperlink or info.itemID)
    if not name then return false,"Item details are loading." end
    if (classID~=2 and classID~=4) or not quality or quality<2 or quality>4 or equip=="INVTYPE_BODY" or equip=="INVTYPE_TABARD" or not equip or equip=="" then
        return false,"This item is not a Disenchant candidate."
    end
    local quest=call(C_Container and C_Container.GetContainerItemQuestInfo,bag,slot)
    if quest and quest.isQuestItem then return false,"Quest items are excluded." end
    -- Honor explicit tooltip restrictions when this client supplies them.
    local tip=call(C_TooltipInfo and C_TooltipInfo.GetBagItem,bag,slot)
    for _,line in ipairs(tip and tip.lines or {}) do
        local value=line.leftText
        if value and ITEM_DISENCHANT_NOT_DISENCHANTABLE and value==ITEM_DISENCHANT_NOT_DISENCHANTABLE then
            return false,"This item cannot be disenchanted."
        end
        if value and rank and ITEM_DISENCHANT_MIN_SKILL then
            local pattern=ITEM_DISENCHANT_MIN_SKILL:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
            pattern=pattern:gsub("%%%%s","(.-)"):gsub("%%%%d","(%%d+)")
            local a,b=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^"..pattern.."$")
            local required=tonumber(b) or tonumber(a)
            if required and rank<required then return false,"Requires Enchanting "..required.."; current rank "..rank.."." end
        end
    end
    return true,"Potential candidate; the game confirms skill and item restrictions.",info
end
D.name="Disenchant"
D.description="This destroys the item to obtain enchanting materials."
local processors={D}
for _,spec in ipairs({{name="Milling",spellID=51005,skill=773,subclass=9,material="herbs",description="This consumes 5 herbs from the selected stack to obtain pigments."},
 {name="Prospecting",spellID=31252,skill=755,subclass=7,material="ore",description="This consumes 5 ore from the selected stack to obtain gems."}})do
 local operation=spec
 function operation.Available()
  return not not (call(WoWUSpellBook and WoWUSpellBook.IsSpellKnown,operation.spellID)or call(IsPlayerSpell,operation.spellID)or call(IsSpellKnown,operation.spellID))
 end
 function operation.Candidate(bag,slot)
  if not operation.Available()then return false,"Learn "..operation.name.." first."end
  local info=call(C_Container and C_Container.GetContainerItemInfo,bag,slot)
  if not info or not info.itemID then return false,"Select an item first."end
  if info.isLocked then return false,"The selected item is locked."end
  local name,_,_,_,_,_,_,_,_,_,_,class,subclass=call(C_Item and C_Item.GetItemInfo or GetItemInfo,info.hyperlink or info.itemID)
  if not name then return false,"Item details are loading."end
  if class~=7 or subclass~=operation.subclass then return false,"Select "..operation.material.." for "..operation.name.."."end
  if (info.stackCount or 1)<5 then return false,"Requires at least 5 in the selected stack."end
  local quest=call(C_Container and C_Container.GetContainerItemQuestInfo,bag,slot)
  if quest and quest.isQuestItem then return false,"Quest items are excluded."end
  return true,"Potential candidate; the game checks material and profession skill restrictions.",info
 end
 processors[#processors+1]=operation
end
local function identity(bag,slot)
    if ItemLocation and C_Item and C_Item.GetItemGUID then
        return call(C_Item.GetItemGUID,ItemLocation:CreateFromBagAndSlot(bag,slot))
    end
end
local function buildProcessing(parent,right,pin,status,getSelection,D,rowLayout)
    local launch=CreateFrame("Button",nil,right,"UIPanelButtonTemplate")
    launch:SetPoint("BOTTOMLEFT",right,"BOTTOMLEFT",13,119);launch:SetPoint("BOTTOMRIGHT",right,"BOTTOMRIGHT",-13,119);launch:SetHeight(30)
    launch:SetText(D.name)
    local dialog=CreateFrame("Frame",nil,parent,"BackdropTemplate");dialog:SetSize(460,230);dialog:SetPoint("CENTER");dialog:SetFrameLevel(parent:GetFrameLevel()+200)
    WoWU_Theme.Panel(dialog,"outer",false);dialog:EnableMouse(true);dialog:Hide()
    local title=dialog:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOP",0,-20);title:SetText(D.name.." selected item?")
    local detail=dialog:CreateFontString(nil,"OVERLAY","GameFontNormal");detail:SetPoint("TOPLEFT",22,-53);detail:SetSize(416,104);detail:SetJustifyH("LEFT");detail:SetWordWrap(true)
    local confirm=CreateFrame("Button",nil,dialog,"UIPanelButtonTemplate,SecureActionButtonTemplate,SecureHandlerStateTemplate")
    confirm:SetSize(220,40);confirm:SetPoint("BOTTOMLEFT",18,22)
    confirm:SetText("Confirm "..D.name)
    confirm:RegisterForClicks("LeftButtonDown","LeftButtonUp");confirm:SetAttribute("useOnKeyDown",false)
    confirm:SetAttribute("_onstate-combat",[[if newstate=="1" then self:SetAttribute("type",nil);self:Hide() end]])
    RegisterStateDriver(confirm,"combat","[combat] 1; 0")
    local cancel=CreateFrame("Button",nil,dialog,"UIPanelButtonTemplate");cancel:SetSize(180,40);cancel:SetPoint("BOTTOMRIGHT",-18,22)
    cancel:SetText("Cancel")
    local pending
    local function clear()
        pending=nil
        if not combat() then confirm:SetAttribute("type",nil);confirm:SetAttribute("target-bag",nil);confirm:SetAttribute("target-slot",nil);dialog:Hide() end
    end
    cancel:SetScript("OnClick",clear)
    local function allowed()
        if combat() then return false,D.name.." is unavailable in combat." end
        if UnitIsDeadOrGhost("player") then return false,D.name.." is unavailable while dead." end
        if CursorHasItem and CursorHasItem() or SpellIsTargeting and SpellIsTargeting() then return false,"Clear the cursor before "..D.name.."." end
        return true
    end
    local function update()
        if combat() then launch:Disable();return end
        local available=D.Available();launch:SetShown(available and true or false);rowLayout()
        local bag,slot=getSelection();local candidate=bag~=nil and D.Candidate(bag,slot)
        local usable=allowed();launch:SetEnabled(candidate and usable and true or false);launch:SetAlpha(candidate and usable and 1 or .45)
    end
    launch:SetScript("OnEnter",function(self)
        local bag,slot=getSelection();local _,reason=allowed()
        if not reason then if bag~=nil then _,reason=D.Candidate(bag,slot) else reason="Select an item first." end end
        if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText(D.name);GameTooltip:AddLine(reason or "Select an item, then confirm to destroy it for materials.",1,.82,.5,true);GameTooltip:Show() end
    end)
    launch:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    launch:SetScript("OnClick",function()
        local ok,why=allowed();if not ok then status(why);return end
        local bag,slot=getSelection();if bag==nil then return end
        local candidate,reason,info=D.Candidate(bag,slot);if not candidate then status(reason);return end
        pending={bag=bag,slot=slot,itemID=info.itemID,link=info.hyperlink,count=info.stackCount,guid=identity(bag,slot)}
        detail:SetText((info.hyperlink or "Selected item").."\n\n"..D.description.." The game checks the required skill and any item restrictions.")
        confirm:SetAttribute("spell",D.spellID);confirm:SetAttribute("target-bag",bag);confirm:SetAttribute("target-slot",slot);confirm:SetAttribute("type","spell")
        confirm:Show();dialog:Show()
    end)
    confirm:SetScript("PreClick",function(self,_,down)
        if down or combat() then return end
        local p=pending;local valid=allowed()
        local bag,slot=getSelection()
        local candidate,_,info
        if p then candidate,_,info=D.Candidate(p.bag,p.slot) end
        if not p or not valid or not candidate or bag~=p.bag or slot~=p.slot or info.itemID~=p.itemID or info.hyperlink~=p.link or info.stackCount~=p.count or p.guid and identity(p.bag,p.slot)~=p.guid then
            self:SetAttribute("type",nil);pending=nil;status("Item or conditions changed. Select the item again.")
        end
    end)
    confirm:SetScript("PostClick",function(_,_,down)
        if down or combat() then return end
        if pending then status(D.name.." requested. Follow any Blizzard prompt. If a targeting cursor remains, choose the item in Blizzard's bags or press Escape.") end
        clear()
    end)
    local events=CreateFrame("Frame")
    for _,event in ipairs({"BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","SKILL_LINES_CHANGED","SPELLS_CHANGED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if event~="GET_ITEM_INFO_RECEIVED" then clear() end;update()
    end)
    parent:HookScript("OnHide",clear)
    update()
    return update,launch,clear
end

-- Share the existing action row; only learned processing abilities occupy it.
function WoWU_BuildDisenchant(parent,right,pin,status,getSelection)
 local entries={}
 local function layout()
  if combat()then return end
  local shown={};for _,entry in ipairs(entries)do if entry.button:IsShown()then shown[#shown+1]=entry end end
  local count=#shown;if count==0 then return end
  local width=(right:GetWidth()-26-(count-1)*6)/count
  for i,entry in ipairs(shown)do
   local b=entry.button;b:ClearAllPoints();b:SetPoint("BOTTOMLEFT",right,"BOTTOMLEFT",13+(i-1)*(width+6),119);b:SetSize(math.max(1,width),30)
   b:SetNormalFontObject(count>1 and "GameFontNormalSmall"or "GameFontNormal")
  end
 end
 for _,operation in ipairs(processors)do
  local update,button,clear=buildProcessing(parent,right,pin,status,getSelection,operation,layout)
  local entry={update=update,button=button,clear=clear};entries[#entries+1]=entry
  button:SetScript("PreClick",function()for _,other in ipairs(entries)do if other~=entry then other.clear()end end end)
 end
 right:HookScript("OnSizeChanged",layout)
 local function update()for _,entry in ipairs(entries)do entry.update()end;layout()end
 update();return update
end
