-- WoWU Professions v0.9: native two-over-three dashboard and details.
-- Native recipe data with direct, user-triggered crafting.
local Trade=WoWUProfessionAPI or C_TradeSkillUI
local function safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h end
end
local function txt(parent,size,color)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    WoWU_Theme.TextColor(t,unpack(color or {.95,.78,.46}))
    t:SetJustifyH("LEFT")
    return t
end
local function framed(parent,button,secure)
    local f=CreateFrame(button and "Button" or "Frame",nil,parent,secure and "BackdropTemplate,SecureActionButtonTemplate" or "BackdropTemplate")
    WoWU_Theme.Backdrop(f,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=18,insets={left=4,right=4,top=4,bottom=4}})
    WoWU_Theme.Color(f,.095,.12,.14,.98)
    WoWU_Theme.Panel(f)
    return f
end
local function rawProfessions()
    if Trade and Trade.KnownProfessions then return Trade.KnownProfessions()end
    local ids={safe(GetProfessions)};local records={};local primary={}
    for i=1,6 do
        if ids[i] then
            local name,icon,rank,maxRank,_,_,skillLine=safe(GetProfessionInfo,ids[i])
            if name then
                local r={name=name,icon=icon,rank=rank or 0,max=maxRank or 0,skillLine=skillLine}
                records[skillLine or name]=r;if i<=2 then primary[i]=r end
            end
        end
    end
    return {primary[1] or {name="Primary profession",unlearned=true},primary[2] or {name="Secondary profession",unlearned=true},
        records[185] or records.Cooking or {name="Cooking",unlearned=true},
        records[356] or records.Fishing or {name="Fishing",unlearned=true},
        (WoWUClient.isRetail and (records[794] or {name="Archaeology",unlearned=true}) or records[129] or records["First Aid"] or {name="First Aid",unlearned=true})}
end
local function knownProfessions()
    local list=rawProfessions()
    for _,d in ipairs(list)do
        if d.skillLine==186 then d.openSpell=2656;d.recipeName=safe(C_Spell and C_Spell.GetSpellName,2656)or safe(GetSpellInfo,2656)or d.recipeName or d.name end
        if d.skillLine==182 then d.passive=true end
    end
    return list
end
local function getRecipes(expectedName,expectedSkill)
    -- The trade-skill recipe list is a global cache for the currently opened trade skill.
    -- Never show recipes from a recognisably different profession.
    local loadedName
    local base=safe(Trade and Trade.GetBaseProfessionInfo)
    local retailMatches=expectedSkill and base and base.professionID==expectedSkill
    if Trade and type(Trade.GetTradeSkillLine)=="function" then
        local a,b=safe(Trade.GetTradeSkillLine)
        loadedName=type(a)=="string" and a or (type(b)=="string" and b or nil)
        if expectedSkill==186 and loadedName then
            local mining=safe(C_Spell and C_Spell.GetSpellName,2575)or safe(GetSpellInfo,2575)
            local smelting=safe(C_Spell and C_Spell.GetSpellName,2656)or safe(GetSpellInfo,2656)
            if loadedName==mining or loadedName==smelting then retailMatches=true end
        end
        if not retailMatches and loadedName and expectedName and string.lower(loadedName)~=string.lower(expectedName) then
            return {},true
        end
    end
    local found={}
    if not Trade or type(Trade.GetAllRecipeIDs)~="function" or type(Trade.GetRecipeInfo)~="function" then return found end
    local ids=safe(Trade.GetAllRecipeIDs)
    if type(ids)~="table" then return found end
    for _,id in ipairs(ids) do
        local info=safe(Trade.GetRecipeInfo,id)
        if type(info)=="table" and info.learned and info.name then
            local professionMatches = retailMatches or false
            if not retailMatches and Trade and type(Trade.GetTradeSkillLineForRecipe)=="function" then
                local _, professionName = safe(Trade.GetTradeSkillLineForRecipe,id)
                professionMatches = (loadedName and
                    string.lower(loadedName)==string.lower(expectedName or ""))
                    or (type(professionName)=="string"
                    and string.lower(professionName)==string.lower(expectedName or ""))
            elseif not retailMatches then
                professionMatches = loadedName and string.lower(loadedName)==string.lower(expectedName or "")
            end
            if professionMatches then
                found[#found+1]={id=id,name=info.name,icon=info.icon,
                    craftable=info.craftable,category=info.categoryID,difficulty=info.relativeDifficulty,difficultyColor=info.difficultyColor,hyperlink=info.hyperlink,disabled=info.disabled,disabledReason=info.disabledReason,available=safe(Trade.GetCraftableCount,id)}
            end
        end
    end
    table.sort(found,function(a,b)return a.name<b.name end)
    return found
end
function WoWU_CreateProfessions(parent)
    if WoWUClient.isClassic and not (Trade and Trade.isMists) and WoWUClassicModules then return WoWUClassicModules.Professions(parent)end
    local root=CreateFrame("Frame",nil,parent)
    root:SetAllPoints()
    root:Hide()
    local overview=CreateFrame("Frame",nil,root)
    overview:SetAllPoints()
    local details=CreateFrame("Frame",nil,root)
    details:SetAllPoints()
    details:Hide()
    local fishingPage=WoWUFishing and WoWUFishing.Create(root,function()overview:Show()end)
    WoWU_OpenFishing=function()if fishingPage then details:Hide();overview:Hide();fishingPage:Show()end end
    local cookingFire=CreateFrame("Button",nil,details,"UIPanelButtonTemplate,SecureActionButtonTemplate")
    cookingFire:SetSize(155,38);cookingFire:SetPoint("TOP",details,"TOP",0,-20)
    cookingFire:SetText("Cooking Fire");cookingFire:RegisterForClicks("AnyDown","AnyUp")
    cookingFire:SetAttribute("useOnKeyDown",false);cookingFire:SetAttribute("spell1",818)
    cookingFire:SetAttribute("type1","spell");cookingFire:Hide()
    local function updateFire(data)
        if InCombatLockdown and InCombatLockdown()then return end
        local cooking=data and data.skillLine==185 and not data.unlearned
        cookingFire:SetShown(cooking and true or false)
        local known=safe(WoWUSpellBook and WoWUSpellBook.IsSpellKnown,818)or safe(IsPlayerSpell,818)or safe(IsSpellKnown,818)
        cookingFire:SetEnabled(cooking and known and true or false)
    end
    local fillRecipes
    local selectedIndex=1
    local selectedRecipe=nil
    local records={}
    local cards={}
    local cardCount=5
    local cardPos={{15,-15,592,328},{623,-15,592,328},{15,-355,389,315},{419,-355,389,315},{823,-355,389,315}}
    local detailTitle=txt(details,24)
    detailTitle:SetPoint("TOPLEFT",27,-25)
    local detailSub=txt(details,15,{.71,.72,.69})
    detailSub:SetPoint("TOPLEFT",27,-65)
    local back=framed(details,true)
    back:SetSize(120,40)
    back:SetPoint("TOPRIGHT",-26,-17)
    local btxt=txt(back,17);btxt:SetPoint("CENTER");btxt:SetText("Professions")
    back:SetScript("OnClick",function() details:Hide();overview:Show() end)
    local left=framed(details)
    left:SetPoint("TOPLEFT",19,-112);left:SetPoint("BOTTOMLEFT",19,15);left:SetWidth(440)
    local right=framed(details)
    right:SetPoint("TOPLEFT",left,"TOPRIGHT",12,0)
    right:SetPoint("BOTTOMRIGHT",-19,120)
    local footer=framed(details)
    footer:SetPoint("TOPLEFT",right,"BOTTOMLEFT",0,-8)
    footer:SetPoint("BOTTOMRIGHT",-19,15)
    local rightScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(rightScroll) end
    rightScroll:SetPoint("TOPLEFT",10,-9)
    rightScroll:SetPoint("BOTTOMRIGHT",-29,9)
    local rightBody=CreateFrame("Frame",nil,rightScroll)
    rightBody:SetSize(650,480)
    rightScroll:SetScrollChild(rightBody)
    if rightScroll.SetClipsChildren then rightScroll:SetClipsChildren(true)end
    local recipeTitle=txt(left,16);recipeTitle:SetPoint("TOPLEFT",18,-54);recipeTitle:SetText("Known Recipes")
    local scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll) end
    scroll:SetPoint("TOPLEFT",14,-82);scroll:SetPoint("BOTTOMRIGHT",-30,14)
    local scrollChild=CreateFrame("Frame",nil,scroll)
    scrollChild:SetSize(610,600)
    scroll:SetScrollChild(scrollChild)
    local search=CreateFrame("EditBox",nil,left,"InputBoxTemplate");search:SetPoint("TOPLEFT",20,-12);search:SetSize(240,32);search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local onlyCraftable=CreateFrame("CheckButton",nil,left,"UICheckButtonTemplate");onlyCraftable:SetSize(28,28);onlyCraftable:SetPoint("TOPRIGHT",-130,-14)
    local filterLabel=txt(left,12);filterLabel:SetPoint("LEFT",onlyCraftable,"RIGHT",2,0);filterLabel:SetText("Have materials")
    search:SetScript("OnTextChanged",function()if fillRecipes then fillRecipes()end end)
    onlyCraftable:SetScript("OnClick",function()if fillRecipes then fillRecipes()end end)
    local skillBar=CreateFrame("StatusBar",nil,details);skillBar:SetPoint("TOPLEFT",27,-88);skillBar:SetSize(430,14);skillBar:SetStatusBarTexture(WoWU_Theme.assets.statusbar);skillBar:SetStatusBarColor(1,.55,.12)
    local categoryRows={}
    local recipeRows={}
    local inspectTitle=txt(rightBody,21);inspectTitle:SetPoint("TOPLEFT",18,-20)
    inspectTitle:SetWidth(420)
    local inspectIcon=rightBody:CreateTexture(nil,"ARTWORK")
    inspectIcon:SetSize(65,65);inspectIcon:SetPoint("TOPLEFT",18,-68)
    local inspectText=txt(rightBody,15,{.76,.77,.73})
    inspectText:SetPoint("TOPLEFT",18,-145);inspectText:SetWidth(410)
    inspectText:SetText("Select a recipe to inspect its information.")
    local tooltip = CreateFrame("GameTooltip","WoWU_ProfessionTooltip",rightBody,"GameTooltipTemplate")
    tooltip:SetOwner(rightBody,"ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT",rightBody,"TOPLEFT",12,-155)
    tooltip:SetScale(1)
    tooltip:SetClampedToScreen(false)
    if WoWUAuctionPrices and WoWUAuctionPrices.AttachTooltip then WoWUAuctionPrices.AttachTooltip(tooltip)end
    tooltip:SetFrameStrata("MEDIUM")

    local reagentTitle=txt(rightBody,17)
    reagentTitle:SetPoint("TOPLEFT",rightBody,"TOPLEFT",18,-210)
    reagentTitle:SetText("Reagents")
    local reagentRows={}
    local function bagCount(itemID)
        if not itemID then return nil end
        -- Modern Forever may remove the global GetItemCount. Count bag slots directly.
        if C_Container and type(C_Container.GetContainerNumSlots)=="function"
            and type(C_Container.GetContainerItemInfo)=="function" then
            local total=0
            local success=false
            for bag=0,WoWUClient.LastBag() do
                local num=safe(C_Container.GetContainerNumSlots,bag)
                if type(num)=="number" then
                    success=true
                    for slot=1,num do
                        local info=safe(C_Container.GetContainerItemInfo,bag,slot)
                        if type(info)=="table" and info.itemID==itemID then
                            total=total+(info.stackCount or info.quantity or 1)
                        end
                    end
                end
            end
            if success then return total end
        end
        if C_Item and type(C_Item.GetItemCount)=="function" then
            local total=safe(C_Item.GetItemCount,itemID,false,false,false)
            if type(total)=="number" then return total end
        end
        if type(GetItemCount)=="function" then
            return safe(GetItemCount,itemID)
        end
        return nil
    end
    local function updateReagents(recipe)
        for _,r in ipairs(reagentRows) do r:Hide() end
        rightBody:SetHeight(480)
        if not recipe then return end
        local schematic = Trade and safe(Trade.GetRecipeSchematic,recipe.id,false)
        local slots=type(schematic)=="table" and schematic.reagentSlotSchematics or nil
        if type(slots)~="table" then
            reagentTitle:SetText("Reagents (not available)")
            return
        end
        reagentTitle:SetText("Reagents")
        local n=0
        for _,group in ipairs(slots) do
            local choices=group.reagents
            if type(choices)=="table" then
                for _,reagent in ipairs(choices) do
                    n=n+1

                    local r=reagentRows[n]
                    if not r then
                        r=CreateFrame("Button",nil,rightBody,"BackdropTemplate")
                        r:SetSize(415,52);WoWU_Theme.Tab(r,false);WoWU_Theme.Button(r)
                        r.icon=r:CreateTexture(nil,"ARTWORK")
                        r.icon:SetSize(38,38)
                        r.icon:SetPoint("LEFT",8,0)
                        r.label=txt(r,16,{.86,.84,.75})
                        r.label:SetPoint("LEFT",r.icon,"RIGHT",10,0)
                        r.label:SetWidth(340)
                        r:SetScript('OnClick',function(self)
                            if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(rightScroll)then return end
                            if self.itemID and WoWUReagents then WoWUReagents.Show(self.itemID,self,self.required,self.owned,self.alternative)end
                        end)
                        reagentRows[n]=r
                    end
                    local id=reagent.itemID or reagent.itemId
                    local required=group.quantityRequired or reagent.quantityRequired or 1
                    local itemName,idTexture,owned=reagent.name,reagent.icon,reagent.owned
                    if id and C_Item then
                        itemName=safe(C_Item.GetItemNameByID,id)or itemName
                        idTexture=safe(C_Item.GetItemIconByID,id)or idTexture
                    end
                    owned=bagCount(id)or owned
                    r.itemID=id;r.required=required;r.owned=owned;r.alternative=#choices>1
                    r:SetEnabled(id~=nil)
                    r:SetWidth(math.max(250,rightBody:GetWidth()-36));r.label:SetWidth(math.max(170,r:GetWidth()-68))
                    r.icon:SetTexture(idTexture or 134400)
                    WoWU_Theme.TextColor(r.label,owned and owned>=required and .9 or 1,owned and owned>=required and .84 or .25,owned and owned>=required and .65 or .2)
                    r.label:SetText((itemName or ("Item "..tostring(id or "?")))..
                        "    "..tostring(owned or "?").."/"..tostring(required))
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT",reagentTitle,"BOTTOMLEFT",0,-8-(n-1)*58)
                    r:Show()
                end
            end
        end
        if n==0 then reagentTitle:SetText("Reagents (none listed)") end
        rightBody:SetHeight(math.max(480,275+n*58))
    end
    local amount=1
    local amountLabel=txt(footer,16)
    amountLabel:SetPoint("BOTTOMLEFT",footer,"BOTTOMLEFT",18,52)
    local function updateAmount() amountLabel:SetText("Craft amount:  "..amount) end
    local dec=framed(footer,true);dec:SetSize(42,36)
    dec:SetPoint("BOTTOMLEFT",footer,"BOTTOMLEFT",20,10)
    local dl=txt(dec,23);dl:SetPoint("CENTER");dl:SetText("-")
    dec:SetScript("OnClick",function() amount=math.max(1,amount-1);updateAmount() end)
    local inc=framed(footer,true);inc:SetSize(42,36)
    inc:SetPoint("LEFT",dec,"RIGHT",55,0)
    local il=txt(inc,23);il:SetPoint("CENTER");il:SetText("+")
    inc:SetScript("OnClick",function() amount=math.min(1000,amount+1);updateAmount() end)
    updateAmount()
    local notice=txt(footer,12,{.84,.69,.47})
    notice:SetPoint("TOPLEFT",footer,"TOPLEFT",18,-8)
    notice:SetWidth(620);notice:SetHeight(28);notice:SetWordWrap(true)
    notice:SetText(WoWUClient.isRetail and 'Craft uses default basic reagents. Open Profession for quality, optional reagents and special targets.'or 'Crafting requires a direct button click and a loaded profession.')

    local function inspect(recipe)
        local changed=not selectedRecipe or not recipe or selectedRecipe.id~=recipe.id
        selectedRecipe=recipe
        tooltip:Hide()
        rightBody:SetWidth(math.max(300,rightScroll:GetWidth()))
        inspectTitle:SetWidth(math.max(220,rightBody:GetWidth()-36));inspectText:SetWidth(math.max(220,rightBody:GetWidth()-36))
        tooltip:SetScale(1)
        tooltip:SetOwner(rightBody,"ANCHOR_NONE")
        tooltip:ClearAllPoints();tooltip:SetPoint("TOPLEFT",rightBody,"TOPLEFT",12,-155)
        inspectTitle:SetText(recipe and recipe.name or "Recipe Details")
        inspectIcon:SetTexture(recipe and recipe.icon or nil)
        if not recipe then
            inspectText:SetText("Select a recipe on the left.")
            updateReagents(nil)
            return
        end
        inspectText:SetText("")
        updateReagents(recipe)
        -- A recipeID identifies the crafting SPELL, not necessarily its output item.
        local output=Trade and safe(Trade.GetRecipeOutputItemData,recipe.id)
        local link=type(output)=="table" and (output.hyperlink or output.itemLink)
        local itemID=type(output)=="table" and (output.itemID or output.itemId)
        local schematic=safe(Trade.GetRecipeSchematic,recipe.id,false)
        itemID=itemID or (schematic and schematic.outputItemID)
        if Trade and type(Trade.GetRecipeItemLink)=="function" then
            link=link or safe(Trade.GetRecipeItemLink,recipe.id)
        end
        if not itemID and Trade and type(Trade.GetRecipeOutputItemID)=="function" then
            itemID=safe(Trade.GetRecipeOutputItemID,recipe.id)
        end
        if not itemID and type(link)=='string'then itemID=tonumber(link:match('item:(%d+)'))end
        if not link and itemID and C_Item and type(C_Item.GetItemLinkByID)=="function" then
            link=safe(C_Item.GetItemLinkByID,itemID)
        end
        tooltip:ClearLines()
        local shown=false
        local function tryTooltip(method,arg)
            if shown or not arg or type(tooltip[method])~="function" then return end
            local ok=pcall(tooltip[method],tooltip,arg)
            shown=ok and tooltip.NumLines and tooltip:NumLines()>0
        end
        if Trade.SetRecipeTooltip then shown=safe(Trade.SetRecipeTooltip,tooltip,recipe.id)or false else tryTooltip("SetRecipeResultItem",recipe.id)end
        if type(link)=="string" then tryTooltip("SetHyperlink",link) end
        if type(itemID)=="number" then
            tryTooltip("SetItemByID",itemID)
            tryTooltip("SetHyperlink","item:"..itemID)
        end
        -- Fallback to the game's actual recipe SPELL tooltip if result item data is absent.
        if not shown and recipe.id>0 then tryTooltip("SetSpellByID",recipe.id) end
        if shown then
            tooltip:Show()
            tooltip:SetClampedToScreen(false)
            local width=(rightBody:GetWidth()-30)*.6
            local scale=math.max(.1,width/math.max(1,tooltip:GetWidth()))
            tooltip:SetScale(scale);tooltip:ClearAllPoints();tooltip:SetPoint('TOPLEFT',rightBody,'TOPLEFT',(rightBody:GetWidth()-width)/2/scale,-155/scale)
            inspectText:SetText("")
        else
            tooltip:Hide()
            inspectText:SetText("Recipe details are loading. Reagents are listed below.")
        end
        -- Keep reagents immediately below the actual tooltip (or fallback).
        local tooltipHeight=shown and tooltip:GetHeight() * tooltip:GetScale() or 0
        local y=shown and (155+tooltipHeight+12) or 205
        reagentTitle:ClearAllPoints()
        reagentTitle:SetPoint("TOPLEFT",rightBody,"TOPLEFT",18,-y)
        local count=0
        for _,reagentRow in ipairs(reagentRows) do
            if reagentRow:IsShown() then count=count+1 end
        end
        rightBody:SetHeight(math.max(440,y+42+count*58))
        if WoWUReagents and itemID then WoWUReagents.RememberCraft(itemID,recipe.name,records[selectedIndex]and records[selectedIndex].name)end
        if changed then rightScroll:SetVerticalScroll(0) end
    end
    rightScroll:HookScript('OnSizeChanged',function()if details:IsVisible()then inspect(selectedRecipe)end end)
    local tooltipLayoutPending=false
    tooltip:HookScript('OnSizeChanged',function()
        if tooltipLayoutPending or not details:IsVisible()or not tooltip:IsShown()then return end
        tooltipLayoutPending=true
        C_Timer.After(0,function()
            tooltipLayoutPending=false
            if not details:IsVisible()or not tooltip:IsShown()then return end
            local width=(rightBody:GetWidth()-30)*.6
            local scale=math.max(.1,width/math.max(1,tooltip:GetWidth()))
            tooltip:SetScale(scale);tooltip:ClearAllPoints();tooltip:SetPoint('TOPLEFT',rightBody,'TOPLEFT',(rightBody:GetWidth()-width)/2/scale,-155/scale)
            local y=155+tooltip:GetHeight()*scale+12
            reagentTitle:ClearAllPoints();reagentTitle:SetPoint('TOPLEFT',rightBody,'TOPLEFT',18,-y)
            local count=0;for _,r in ipairs(reagentRows)do if r:IsShown()then count=count+1 end end
            rightBody:SetHeight(math.max(440,y+42+count*58))
        end)
    end)

    local openButton=CreateFrame("Button",nil,details,"UIPanelButtonTemplate,SecureActionButtonTemplate")
    openButton:SetSize(175,40)
    openButton:SetPoint("TOPRIGHT",-162,-17)
    local openLabel=txt(openButton,15)
    openLabel:SetPoint("CENTER")
    openLabel:SetText("Open Profession")
    local craftButton=CreateFrame("Button",nil,footer,"UIPanelButtonTemplate")
    craftButton:SetSize(175,40)
    craftButton:SetPoint("BOTTOMRIGHT",footer,"BOTTOMRIGHT",-18,12)
    local craftLabel=txt(craftButton,16)
    craftLabel:SetPoint("CENTER")
    craftLabel:SetText("Craft")
    local allButton=CreateFrame("Button",nil,footer,"UIPanelButtonTemplate");allButton:SetSize(175,40);allButton:SetPoint("RIGHT",craftButton,"LEFT",-10,0)
    local allLabel=txt(allButton,15);allLabel:SetPoint("CENTER");allLabel:SetText("Craft All")

    local function openProfession()
        if InCombatLockdown and InCombatLockdown() then
            notice:SetText("Leave combat before opening a profession.")
            return
        end
        local record=records[selectedIndex]
        local fallbackIDs={Alchemy=171,Blacksmithing=164,Enchanting=333,Engineering=202,Herbalism=182,Inscription=773,Jewelcrafting=755,Leatherworking=165,Mining=186,Skinning=393,Tailoring=197,Cooking=185,Fishing=356,["First Aid"]=129,Archaeology=794}
        local skill=record and (record.skillLine or fallbackIDs[record.name])
        if not skill then
            notice:SetText("No profession skill ID found. Open it with the normal spellbook.")
            return
        end
        if not Trade or type(Trade.OpenTradeSkill)~="function" then
            notice:SetText("OpenTradeSkill is not available on this build.")
            return
        end
        if WoWUClient.isRetail then
            local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
            if loaded and not loaded("Blizzard_Professions")then safe(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,"Blizzard_Professions")end
        end
        local ok,err=pcall(Trade.OpenTradeSkill,skill)
        if not ok or err==false then
            notice:SetText("Could not open "..(record and record.name or "this profession")..". Check that it is learned and available outside combat.")
            return
        end
        notice:SetText("Opening "..(record and record.name or "profession").." recipes...")
    end
    openButton:RegisterForClicks("AnyUp", "AnyDown")
    openButton:SetAttribute("type1", "spell")
    openButton:SetAttribute("useOnKeyDown", false)
    -- This separate secure button executes the equivalent of /cast Profession
    -- on a REAL hardware click, without invoking CastSpellByName from Lua.
    openButton:SetScript("PostClick",function(_,_,down)
        if down then return end
        if WoWUClient.isRetail then openProfession()else notice:SetText("Opening the selected profession...")end
    end)
    local function craft(count)
        if InCombatLockdown and InCombatLockdown() then
            notice:SetText("Cannot craft in combat.")
            return
        end
        if not selectedRecipe then
            notice:SetText("Select a recipe first.")
            return
        end
        if not Trade or type(Trade.CraftRecipe)~="function" then
            notice:SetText("CraftRecipe is not available.")
            return
        end
        local available=safe(Trade.GetCraftableCount,selectedRecipe.id)
        local count=count or amount
        if type(available)=="number" then count=math.min(count,available) end
        if count<1 then notice:SetText("Not enough materials to create this recipe.");return end
        local ok,err
        if WoWUClient.isRetail then
            local schematic=safe(Trade.GetRecipeSchematic,selectedRecipe.id,false)
            local types=Enum and Enum.TradeskillRecipeType
            if schematic and types and ((types.Enchant and schematic.recipeType==types.Enchant)or(types.Salvage and schematic.recipeType==types.Salvage))then
                notice:SetText('Use Open Profession to select the enchantment or salvage target.');return
            end
            -- Match the native transaction's unallocated basic-reagent path.
            -- Empty optional/finishing selections leave basic choices to the game.
            ok,err=pcall(Trade.CraftRecipe,selectedRecipe.id,count,{},schematic and schematic.recipeLevel)
        else ok,err=pcall(Trade.CraftRecipe,selectedRecipe.id,count)end
        if not ok then
            notice:SetText('Craft could not start. Check materials, cooldowns and any special target in Open Profession.')
            return
        end
        if WoWUNotifications and not WoWUClient.isRetail then WoWUNotifications.BeginCraft(selectedRecipe.id,count,selectedRecipe.name)end
        notice:SetText("Requested "..count.." craft(s). Check game feedback.")
    end
    craftButton:SetScript("OnClick",function()craft(amount)end)
    allButton:SetScript("OnClick",function()
        local count=selectedRecipe and safe(Trade.GetCraftableCount,selectedRecipe.id)
        if type(count)=="number" and count>0 then craft(count)else notice:SetText("No craftable quantity available.")end
    end)
    fillRecipes=function()
        for _,f in ipairs(recipeRows) do f:Hide() end
        local recipes,wrongProfession=getRecipes(records[selectedIndex] and (records[selectedIndex].recipeName or records[selectedIndex].name),records[selectedIndex] and records[selectedIndex].skillLine)
        for _,h in ipairs(categoryRows)do h:Hide()end
        local query=string.lower(search:GetText() or "");local list={}
        for _,r in ipairs(recipes)do
            local cat=safe(Trade.GetCategoryInfo,r.category)
            r.categoryName=type(cat)=="table" and cat.name or "Recipes"
            r.categoryOrder=type(cat)=="table" and (cat.uiOrder or cat.orderIndex) or r.category or 0
            if string.lower(r.name):find(query,1,true)and(not onlyCraftable:GetChecked()or (r.available or 0)>0)then list[#list+1]=r end
        end
        table.sort(list,function(a,b)if a.categoryOrder~=b.categoryOrder then return a.categoryOrder<b.categoryOrder end;return a.name<b.name end)
        recipeTitle:SetText("Known Recipes ("..#list..")")
        local y,headerCount,lastCategory=0,0,nil
        local chosen
        for i,recipe in ipairs(list)do
            if lastCategory~=recipe.categoryName then
                lastCategory=recipe.categoryName;headerCount=headerCount+1
                local h=categoryRows[headerCount]
                if not h then h=CreateFrame("Frame",nil,scrollChild,"BackdropTemplate");h:SetSize(376,30);WoWU_Theme.Panel(h);h.label=txt(h,14);h.label:SetPoint("LEFT",10,0);categoryRows[headerCount]=h end
                h:SetPoint("TOPLEFT",2,-y);h.label:SetText(lastCategory);h:Show();y=y+35
            end
            local b=recipeRows[i]
            if not b then
                b=framed(scrollChild,true);b:SetSize(376,41);recipeRows[i]=b
                b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(28,28);b.icon:SetPoint("LEFT",7,0)
                b.label=txt(b,13);b.label:SetPoint("LEFT",b.icon,"RIGHT",8,0);b.label:SetWidth(324)
                b:SetScript("OnClick",function(self)
                    if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(scroll)then return end
                    inspect(self.recipe);allLabel:SetText("Craft All ["..tostring(self.recipe.available or "?").."]");craftButton:SetEnabled(not self.recipe.disabled);allButton:SetEnabled(not self.recipe.disabled and (self.recipe.available or 0)>0)
                end)
            end
            b:ClearAllPoints();b:SetPoint("TOPLEFT",2,-y);y=y+45
            b.icon:SetTexture(recipe.icon or 134400)
            b.label:SetText(recipe.name..(recipe.available and recipe.available>0 and (" ["..recipe.available.."]")or ""))
            local difficulty=Enum and Enum.TradeskillRelativeDifficulty
            local color=recipe.difficultyColor or {.85,.85,.85}
            if difficulty and recipe.difficulty~=nil then
                if recipe.difficulty==difficulty.Optimal then color={1,.5,.15}
                elseif recipe.difficulty==difficulty.Medium then color={1,1,.1}
                elseif recipe.difficulty==difficulty.Easy then color={.25,1,.25}
                elseif recipe.difficulty==difficulty.Trivial then color={.55,.55,.55}end
            end
            WoWU_Theme.TextColor(b.label,unpack(color));b.recipe=recipe;b:Show()
            if selectedRecipe and recipe.id==selectedRecipe.id then chosen=recipe end
        end
        scrollChild:SetHeight(math.max(scroll:GetHeight(),y+8))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,y+8-scroll:GetHeight())))
        chosen=chosen or list[1];inspect(chosen)
        allLabel:SetText("Create All ["..tostring(chosen and chosen.available or 0).."]")
        craftButton:SetEnabled(chosen~=nil and not chosen.disabled)
        allButton:SetEnabled(chosen~=nil and not chosen.disabled and (chosen.available or 0)>0)
        if chosen and chosen.disabledReason then notice:SetText(chosen.disabledReason)end
        if #recipes==0 then inspectText:SetText(wrongProfession and "Open this profession to load its recipes."or "Open the profession to load recipes. Gathering professions may not have a crafting list.")end
    end
    local function openDetail(i)
        local data=records[i]
        if not data or data.passive then return end
        if data.skillLine==356 and not data.unlearned and fishingPage then
            details:Hide();overview:Hide();if not fishingPage:IsShown()then fishingPage:Show()end;return
        end
        if fishingPage then fishingPage:Hide()end
        if selectedIndex~=i then selectedRecipe=nil;search:SetText("");scroll:SetVerticalScroll(0) end
        selectedIndex=i
        updateFire(data)
        if not (InCombatLockdown and InCombatLockdown()) then
            openButton:SetAttribute("type1",not WoWUClient.isRetail and not data.unlearned and "spell" or nil)
            openButton:SetAttribute("spell1",not data.unlearned and (data.openSpell or data.name)or nil)
        end
        skillBar:SetMinMaxValues(0,math.max(1,data.max or 1));skillBar:SetValue(data.rank or 0)
        detailTitle:SetText(data.name)
        detailSub:SetText(data.unlearned and "Not yet trained" or ((data.rank or 0).." / "..(data.max or 0).." skill"))
        overview:Hide();details:Show();fillRecipes()
    end
    for i=1,cardCount do
        local pos=cardPos[i]or cardPos[5]
        local c=framed(overview,true,true);cards[i]=c
        c:SetPoint("TOPLEFT",pos[1],pos[2]);c:SetSize(pos[3],pos[4])
        local texture=c:CreateTexture(nil,"BACKGROUND",nil,1)
        texture:SetPoint("TOPLEFT",6,-6);texture:SetPoint("BOTTOMRIGHT",-6,6)
        texture:SetColorTexture(.26,.22,.16,.38)
        c.icon=c:CreateTexture(nil,"ARTWORK");c.icon:SetSize(i<=2 and 58 or 46,i<=2 and 58 or 46)
        c.icon:SetPoint("TOPLEFT",22,-52)
        c.name=txt(c,i<=2 and 24 or 20);c.name:SetPoint("TOPLEFT",18,-14)
        c.rank=txt(c,15,{.86,.82,.73});c.rank:SetPoint("LEFT",c.icon,"RIGHT",13,0)
        local bar=CreateFrame("StatusBar",nil,c)
        bar:SetStatusBarTexture(WoWU_Theme.assets.statusbar)
        bar:SetStatusBarColor(.91,.57,.17)
        bar:SetHeight(18)
        bar:SetPoint("TOPLEFT",20,i<=2 and -141 or -128)
        bar:SetPoint("TOPRIGHT",-20,i<=2 and -141 or -128)
        bar:SetMinMaxValues(0,1)
        c.bar=bar
        local bg=c:CreateTexture(nil,"BACKGROUND")
        bg:SetColorTexture(.05,.06,.07,.94)
        bg:SetPoint("TOPLEFT",bar,-3,3);bg:SetPoint("BOTTOMRIGHT",bar,3,-3)
        c.message=txt(c,15,{.7,.72,.68})
        c.message:SetPoint("TOPLEFT",21,i<=2 and -199 or -181)
        c.message:SetWidth(pos[3]-43)
        c:RegisterForClicks("AnyUp", "AnyDown")
        c:SetAttribute("useOnKeyDown",false)
        c:SetScript("PostClick",function(_,_,down)
            if down or (InCombatLockdown and InCombatLockdown())or (records[i]and records[i].passive)then return end
            openDetail(i)
            local data=records[i]
            if WoWUClient.isRetail and data and not data.unlearned and data.skillLine~=356 then openProfession()
            else notice:SetText("Select a recipe to view materials and create items.")end
        end)
        c:SetScript("OnEnter",function(self)WoWU_Theme.Border(self,.91,.70,.34,1)end)
        c:SetScript("OnLeave",function(self)WoWU_Theme.Border(self,.59,.43,.24,1)end)
    end
    local function layoutCards()
        if InCombatLockdown and InCombatLockdown()then return end
        local w,h=overview:GetWidth(),overview:GetHeight();if w<=0 or h<=0 then return end
        local pad,gap=15,16;local topH=(h-2*pad-gap)*.52;local bottomH=h-2*pad-gap-topH
        for i,c in ipairs(cards)do
            local cols=i<=2 and 2 or (cardCount-2);local width=(w-2*pad-(cols-1)*gap)/cols
            local index=i<=2 and i-1 or i-3
            c:ClearAllPoints();c:SetPoint("TOPLEFT",pad+index*(width+gap),i<=2 and -pad or -(pad+topH+gap));c:SetSize(width,i<=2 and topH or bottomH)
            c.message:SetWidth(width-43)
        end
    end
    overview:HookScript("OnSizeChanged",layoutCards)
    local function refresh()
        layoutCards()
        records=knownProfessions()
        for i,c in ipairs(cards) do
            local d=records[i]
            if d then
                c:Show();c.name:SetText(d.name)
                -- Profession activation is a secure spell action bound to the actual click.
                -- Never change protected attributes while in combat.
                if not (InCombatLockdown and InCombatLockdown()) then
                    c:SetAttribute("type1",not WoWUClient.isRetail and not d.unlearned and not d.passive and d.skillLine~=356 and "spell" or nil)
                    c:SetAttribute("spell1",not d.unlearned and not d.passive and d.skillLine~=356 and (d.openSpell or d.name)or nil)
                end
                if not (InCombatLockdown and InCombatLockdown())then c:EnableMouse(not d.passive)end
                c.icon:SetTexture(d.icon or 134400)
                c.rank:SetText(d.unlearned and "Not learned" or ((d.rank or 0).." / "..(d.max or 0)))
                c.bar:SetMinMaxValues(0,math.max(1,d.max or 1))
                c.bar:SetValue(math.max(0,d.rank or 0))
                c.message:SetText(d.unlearned and "Visit a trainer to learn this profession." or d.passive and "Gathering profession - no crafting recipes."or d.skillLine==356 and "Open your Fishing Companion and session catch net."or d.skillLine==186 and "Tap to open Smelting recipes."or "Tap to inspect recipes and skill information")
            else c:Hide() end
        end
        if details:IsShown() then openDetail(selectedIndex) end
    end
    local eventFrame=CreateFrame("Frame",nil,root)
    for _,event in ipairs({"SPELLS_CHANGED","SKILL_LINES_CHANGED","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_UPDATE","TRADE_SKILL_FILTER_UPDATE","TRADE_SKILL_CLOSE","PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","TRADE_SKILL_SHOW","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED"}) do
        pcall(eventFrame.RegisterEvent,eventFrame,event)
    end
    local pending=false
    eventFrame:SetScript("OnEvent",function()
        if pending or not root:IsVisible()then return end
        pending=true;C_Timer.After(.1,function()pending=false;if root:IsVisible()then refresh()end end)
    end)
    if Trade and Trade.Bind then Trade.Bind(root,function(name)
        records=knownProfessions()
        for i,d in ipairs(records)do if (d.recipeName or d.name)==name then openDetail(i);return end end
    end)end
    root:HookScript("OnShow",function()refresh()end)
    return root
end
