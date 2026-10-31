-- Private adapter: Mists' indexed trade-skill API feeds the shared WoWU UI.
if not WoWUClient or WoWUClient.classicMajor~=5 then return end
local A={isMists=true}
WoWUProfessionAPI=A
local call=WoWUClient.Call
local rows,categories={},{}
local nextID=0
local identities={}
local function spellName(id)
 return call(C_Spell and C_Spell.GetSpellName,id) or call(GetSpellInfo,id)
end
function A.KnownProfessions()
 local bySkill,primary={},{}
 for _,d in ipairs(WoWUClient.Professions())do
  bySkill[d.skillLine]=d
  d.openSpell=d.skillLine==186 and 2656 or d.spellID or d.name
  d.recipeName=d.skillLine==186 and (spellName(2656)or d.name)or d.name
  if d.skillLine~=185 and d.skillLine~=356 and d.skillLine~=129 and d.skillLine~=794 then primary[#primary+1]=d end
 end
 local result={primary[1]or{name="Primary profession",unlearned=true},primary[2]or{name="Secondary profession",unlearned=true}}
 for _,entry in ipairs({{185,2550,"Cooking"},{356,7620,"Fishing"},{129,3273,"First Aid"}})do
  result[#result+1]=bySkill[entry[1]]or{name=spellName(entry[2])or entry[3],unlearned=true}
 end
 return result
end
A.GetTradeSkillLine=function()return call(GetTradeSkillLine)end
function A.GetBaseProfessionInfo()
 local name=call(GetTradeSkillLine)
 for _,d in ipairs(A.KnownProfessions())do
  if not d.unlearned and (name==d.name or name==d.recipeName)then return {professionID=d.skillLine}end
 end
end
local function key(index)
 local name,kind=call(GetTradeSkillInfo,index)
 if not name or kind=='header'or kind=='subheader'then return end
 return (call(GetTradeSkillRecipeLink,index)or '')..'\031'..name..'\031'..(call(GetTradeSkillItemLink,index)or '')
end
local function resolve(id)
 local r=rows[id]
 if not r or call(GetTradeSkillLine)~=r.profession then return end
 if key(r.index)==r.key then return r.index end
 for i=1,call(GetNumTradeSkills)or 0 do if key(i)==r.key then r.index=i;return i end end
end
function A.GetAllRecipeIDs()
 local result={};local profession=call(GetTradeSkillLine)
 local category=0;categories={[0]={name="Recipes",uiOrder=0}}
 local difficulty=Enum and Enum.TradeskillRelativeDifficulty or {}
 for i=1,call(GetNumTradeSkills)or 0 do
  local name,kind,available=call(GetTradeSkillInfo,i)
  if kind=='header'or kind=='subheader'then
   category=i;categories[i]={name=name,uiOrder=i}
  elseif name then
   local identity=tostring(profession)..'\030'..key(i)
   local id=identities[identity]
   if not id then nextID=nextID+1;id=-nextID;identities[identity]=id end
   local linked=call(IsTradeSkillLinked)or call(IsTradeSkillGuild)
   local cooldown=call(GetTradeSkillCooldown,i)
   local disabled=linked or (type(cooldown)=='number'and cooldown>0)
   rows[id]={index=i,key=key(i),profession=profession,name=name,learned=true,icon=call(GetTradeSkillIcon,i),categoryID=category,
    craftable=(available or 0)>0,difficultyColor=({optimal={1,.5,.15},medium={1,1,.1},easy={.25,.75,.25},trivial={.55,.55,.55}})[kind],relativeDifficulty=({optimal=difficulty.Optimal,medium=difficulty.Medium,easy=difficulty.Easy,trivial=difficulty.Trivial})[kind],
    disabled=not not disabled,disabledReason=linked and "Viewing another crafter's recipes."or cooldown and "Recipe is on cooldown."or nil}
   result[#result+1]=id
  end
 end
 return result
end
function A.GetRecipeInfo(id)return resolve(id)and rows[id]end
function A.GetCategoryInfo(id)return categories[id]end
function A.GetTradeSkillLineForRecipe(id)local r=rows[id];return nil,r and r.profession end
function A.GetCraftableCount(id)local i=resolve(id);if not i then return 0 end;local _,_,count=call(GetTradeSkillInfo,i);return count or 0 end
function A.GetRecipeItemLink(id)local i=resolve(id);return i and call(GetTradeSkillItemLink,i)end
function A.GetRecipeOutputItemData(id)return {hyperlink=A.GetRecipeItemLink(id)}end
function A.GetRecipeSchematic(id)
 local i=resolve(id);if not i then return end
 local groups={}
 for n=1,call(GetTradeSkillNumReagents,i)or 0 do
  local name,icon,count,owned=call(GetTradeSkillReagentInfo,i,n)
  local link=call(GetTradeSkillReagentItemLink,i,n)
  groups[#groups+1]={quantityRequired=count or 1,reagents={{itemID=link and tonumber(link:match('item:(%d+)')),name=name,icon=icon,owned=owned}}}
 end
 return {reagentSlotSchematics=groups}
end
function A.SetRecipeTooltip(tooltip,id)
 local i=resolve(id);if not i then return false end
 local ok=pcall(tooltip.SetTradeSkillItem,tooltip,i)
 return ok and tooltip:NumLines()>0
end
function A.CraftRecipe(id,count)
 local i=resolve(id)
 if not i or call(IsTradeSkillLinked)or call(IsTradeSkillGuild)then error('Open your own profession again before crafting.')end
 if InCombatLockdown()then error('Cannot craft in combat.')end
 local cooldown=call(GetTradeSkillCooldown,i)
 if type(cooldown)=='number'and cooldown>0 then error('Recipe is on cooldown.')end
 count=math.min(math.floor(tonumber(count)or 1),A.GetCraftableCount(id))
 if count<1 then error('Not enough materials.')end
 -- Called only from the shared Create / Create All hardware-click handler.
 DoTradeSkill(i,count)
end
-- Hiding the native frame calls CloseTradeSkill and destroys the recipe context.
-- Park it under a SHOWN off-screen parent instead; restore it when leaving WoWU.
function A.Bind(root,onProfession)
 local parking=CreateFrame('Frame',nil,UIParent)
 parking:SetSize(1,1);parking:SetPoint('TOPLEFT',UIParent,'TOPLEFT',-40000,40000)
 local saved,hooked,preparing
 local function restore()
  if not saved or InCombatLockdown()then return end
  local s=saved;saved=nil
  local f=s.frame
  -- Let the panel manager release its slot as well as closing the recipe data.
  f:SetAttribute('UIPanelLayout-enabled',s.panel)
  if HideUIPanel then HideUIPanel(f)else f:Hide()end
  if f:IsShown()then f:Hide()end
  f:SetParent(s.parent);f:SetClampedToScreen(s.clamped);f:SetAlpha(s.alpha)
  f:ClearAllPoints();for _,point in ipairs(s.points)do f:SetPoint(unpack(point))end
 end
 local function park()
  local f=TradeSkillFrame
  if not root:IsVisible()or not f or not f:IsShown()or InCombatLockdown()then return end
  if not saved then
   local points={};for i=1,f:GetNumPoints()do points[i]={f:GetPoint(i)}end
   saved={frame=f,parent=f:GetParent(),points=points,clamped=f:IsClampedToScreen(),alpha=f:GetAlpha(),panel=f:GetAttribute('UIPanelLayout-enabled')}
  end
  f:SetAttribute('UIPanelLayout-enabled',false);f:SetClampedToScreen(false)
  f:SetParent(parking);f:ClearAllPoints();f:SetPoint('TOPLEFT',parking,'TOPLEFT');f:SetAlpha(0)
 end
 local function install()
  if TradeSkillFrame and not hooked then hooked=true;TradeSkillFrame:HookScript('OnShow',park)end
 end
 local events=CreateFrame('Frame')
 for _,event in ipairs({'ADDON_LOADED','TRADE_SKILL_SHOW','TRADE_SKILL_CLOSE','PLAYER_REGEN_ENABLED'})do events:RegisterEvent(event)end
 events:SetScript('OnEvent',function(_,event)
  install()
  if event=='PLAYER_REGEN_ENABLED'and not root:IsVisible()then restore();return end
  if event=='TRADE_SKILL_CLOSE'then if not preparing then restore()end;return end
  if event=='TRADE_SKILL_SHOW'and root:IsVisible()then
   preparing=true
   -- Native filters affect GetNumTradeSkills; WoWU provides its own search/filter.
   call(SetTradeSkillItemNameFilter,'');call(SetTradeSkillItemLevelFilter,0,0)
   call(SetTradeSkillSubClassFilter,0);call(SetTradeSkillInvSlotFilter,0)
   call(TradeSkillOnlyShowMakeable,false);call(TradeSkillOnlyShowSkillUps,false)
   call(ExpandTradeSkillSubClass,0)
   preparing=nil
   park();onProfession(call(GetTradeSkillLine))
   C_Timer.After(0,function()if root:IsVisible()then park()end end)
  end
 end)
 root:HookScript('OnHide',restore)
 root:HookScript('OnShow',function()install();park()end)
 install()
end
