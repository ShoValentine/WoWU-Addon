-- Click-driven details for WoWU controls; native/global tooltip behaviour is unchanged.
WoWUDetails={};local D=WoWUDetails
local bound=setmetatable({},{__mode="k"});local popup,scroll,body,host,current;local tips,labels={},{};local detailIcon,detailName,detailKind
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_BODY={4},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_2HWEAPON={16,17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18},INVTYPE_TABARD={19}}
local slotNames={[1]="Head",[2]="Neck",[3]="Shoulder",[4]="Shirt",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",[9]="Wrist",[10]="Hands",[11]="Finger 1",[12]="Finger 2",[13]="Trinket 1",[14]="Trinket 2",[15]="Back",[16]="Main hand",[17]="Off hand",[18]="Ranged",[19]="Tabard"}
local function call(fn,...)
 if type(fn)~="function"then return end
 local ok,a,b,c,d,e,f,g,h,i,j=pcall(fn,...);if ok then return a,b,c,d,e,f,g,h,i,j end
end
local function text(parent,size)
 local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal");f:SetFont("Fonts\\FRIZQT__.TTF",size,"");f:SetJustifyH("LEFT");f:SetWordWrap(true);WoWU_Theme.TextColor(f,.96,.84,.6);return f
end
function D.SetHost(f)host=f end
function D.IsShown()return popup and popup:IsShown()end
function D.Close()if popup then popup:Hide()end end
local function snapshot()
 if not GameTooltip or GameTooltip:NumLines()==0 then return end
 local _,link=call(GameTooltip.GetItem,GameTooltip);local _,spell=call(GameTooltip.GetSpell,GameTooltip)
 local result={link=link,spell=spell,lines={}}
 for i=1,GameTooltip:NumLines()do
  local l=_G["GameTooltipTextLeft"..i];local r=_G["GameTooltipTextRight"..i]
  if l then local a,b,c=l:GetTextColor();local x,y,z=1,1,1;if r then x,y,z=r:GetTextColor()end
   result.lines[#result.lines+1]={left=l:GetText(),right=r and r:IsShown()and r:GetText(),color={a,b,c},rightColor={x,y,z}}
  end
 end
 return result
end
if GameTooltip then
 local previous
 GameTooltip:HookScript("OnShow",function(self)
  if D.capturing then self:SetAlpha(0);return end
  if not host or not host:IsVisible()then return end
  local owner=self:GetOwner();local owned=false
  for i=1,50 do
   if not owner or (owner.IsForbidden and owner:IsForbidden())then break end
   if owner==host then owned=true;break end
   owner=owner.GetParent and owner:GetParent()
  end
  if not owned then return end
  if not previous then previous={scale=self:GetScale(),clamped=self:IsClampedToScreen()}end
  local scale=math.min(previous.scale,(host:GetWidth()-32)/math.max(1,self:GetWidth()),(host:GetHeight()-90)/math.max(1,self:GetHeight()))
  self:SetScale(scale);self:SetClampedToScreen(false);self:ClearAllPoints();self:SetPoint("TOPLEFT",host,"TOPLEFT",16,-55)
 end)
 GameTooltip:HookScript("OnHide",function(self)
  if previous then local old=previous;previous=nil;self:SetScale(old.scale);self:SetClampedToScreen(old.clamped)end
 end)
end

local function capture(fn,self,...)
 if not fn then return end
 GameTooltip:Hide();GameTooltip:ClearLines();local alpha=GameTooltip:GetAlpha();GameTooltip:SetAlpha(0);D.capturing=true
 local ok,err=pcall(fn,self,...);local result=snapshot();D.capturing=false;GameTooltip:Hide();GameTooltip:SetAlpha(alpha)
 if not ok then geterrorhandler()(err)end
 return result
end
local function stats(link)
 local t=link and call(C_Item and C_Item.GetItemStats or GetItemStats,link)
 return type(t)=="table"and t or {}
end
local shortStats={
 AGILITY="Agility",STRENGTH="Strength",STAMINA="Stamina",INTELLECT="Intellect",SPIRIT="Spirit",HEALTH="Health",MANA="Mana",ARMOR="Armor",RESISTANCE0_NAME="Armor",
 CRIT_RATING="Critical Strike",CRIT_MELEE_RATING="Critical Strike",CRIT_RANGED_RATING="Critical Strike",CRIT_SPELL_RATING="Critical Strike",
 HIT_RATING="Hit",HIT_MELEE_RATING="Hit",HIT_RANGED_RATING="Hit",HIT_SPELL_RATING="Hit",
 HASTE_RATING="Haste",HASTE_MELEE_RATING="Haste",HASTE_RANGED_RATING="Haste",HASTE_SPELL_RATING="Haste",
 MASTERY_RATING="Mastery",EXPERTISE_RATING="Expertise",RESILIENCE_RATING="Resilience",CR_RESILIENCE_RATING="Resilience",PVP_POWER="PvP Power",
 DAMAGE_PER_SECOND="Damage Per Second",DPS="Damage Per Second",ATTACK_POWER="Attack Power",RANGED_ATTACK_POWER="Ranged Attack Power",
 SPELL_POWER="Spell Power",SPELL_DAMAGE_DONE="Spell Damage",SPELL_HEALING_DONE="Healing",MANA_REGENERATION="Mana Regeneration",MANA_REGEN="Mana Regeneration",HEALTH_REGEN="Health Regeneration",
 DEFENSE_SKILL_RATING="Defense",DODGE_RATING="Dodge",PARRY_RATING="Parry",BLOCK_RATING="Block",BLOCK_VALUE="Block Value",ARMOR_PENETRATION_RATING="Armor Penetration",
 VERSATILITY="Versatility",VERSATILITY_RATING="Versatility",LIFESTEAL="Leech",SPEED="Speed",AVOIDANCE="Avoidance",BONUS_ARMOR="Bonus Armor",
 AGILITY_OR_INTELLECT="Agility or Intellect",STRENGTH_OR_AGILITY="Strength or Agility",STRENGTH_OR_INTELLECT="Strength or Intellect",AGILITY_OR_STRENGTH_OR_INTELLECT="Primary Stat"
}
local function statName(key)
 local token=key:gsub("^ITEM_MOD_",""):gsub("_SHORT$","")
 return shortStats[token]or token:gsub("_"," "):lower():gsub("(%a)([%w']*)",function(first,rest)return first:upper()..rest end)
end
local function delta(selected,equipped)
 local before={};for _,link in ipairs(equipped)do for k,v in pairs(stats(link))do if WoWUClient.Public(v)and type(v)=="number"then before[k]=(before[k]or 0)+v end end end
 local after=stats(selected);local keys,seen={},{}
 for k in pairs(before)do seen[k]=true;keys[#keys+1]=k end
 for k in pairs(after)do if not seen[k]then keys[#keys+1]=k end end;table.sort(keys)
 local out={}
 for _,k in ipairs(keys)do
  local a,b=after[k]or 0,before[k]or 0
  if WoWUClient.Public(a)and WoWUClient.Public(b)and type(a)=="number"and type(b)=="number"then
   local v=a-b;if math.abs(v)>.001 then
    local name=statName(k)
    local value=string.format("%+.2f",v):gsub("%.00$",""):gsub("(%..-)0$","%1")
    out[#out+1]=(v>0 and "|cff55ee77"or "|cffff7777")..value.." "..name.."|r"
   end
  end
 end
 return #out>0 and table.concat(out,"\n")or "No basic item-stat differences reported."
end
D.StatDifferences=delta
local function initialize()
 if popup or not host then return end
 popup=CreateFrame("Frame","WoWU_DetailsWindow",host,"BackdropTemplate");popup:SetFrameStrata("FULLSCREEN_DIALOG");popup:SetFrameLevel(host:GetFrameLevel()+500);popup:EnableMouse(true);WoWU_Theme.Backdrop(popup,{bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=17,insets={left=4,right=4,top=4,bottom=4}});WoWU_Theme.Color(popup,.10,.13,.15,.97);WoWU_Theme.Panel(popup);popup:Hide()
 detailIcon=popup:CreateTexture(nil,"ARTWORK");detailIcon:SetSize(52,52);detailIcon:SetPoint("TOPLEFT",18,-22)
 detailName=text(popup,20);detailName:SetPoint("TOPLEFT",detailIcon,"TOPRIGHT",12,-2);detailName:SetPoint("TOPRIGHT",-62,-24);detailName:SetHeight(50)
 detailKind=text(popup,13);detailKind:SetPoint("TOPLEFT",18,-86);detailKind:SetPoint("TOPRIGHT",-18,-86)
 local close=CreateFrame("Button",nil,popup,"UIPanelCloseButton");WoWU_Theme.CloseButton(close);close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",D.Close)
 scroll=CreateFrame("ScrollFrame",nil,popup,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",14,-115);scroll:SetPoint("BOTTOMRIGHT",-31,18)
 body=CreateFrame("Frame",nil,scroll);body:SetSize(700,1);scroll:SetScrollChild(body);if scroll.SetClipsChildren then scroll:SetClipsChildren(true)end;WoWU_EnableTouchScroll(scroll)
 table.insert(UISpecialFrames,"WoWU_DetailsWindow")
 host:HookScript("OnHide",D.Close)
end
local function label(index,value,x,y,width)
 local f=labels[index];if not f then f=text(body,17);labels[index]=f end
 f:ClearAllPoints();f:SetPoint("TOPLEFT",x,-y);f:SetWidth(width);f:SetText(value);f:Show();return f:GetStringHeight()+10
end
local function tooltip(index,source,x,y,width)
 local t=tips[index];if not t then
  t=CreateFrame("GameTooltip","WoWU_DetailsTooltip"..index,body,"GameTooltipTemplate");tips[index]=t
  if WoWUAuctionPrices and WoWUAuctionPrices.AttachTooltip then WoWUAuctionPrices.AttachTooltip(t)end
 end
 t:Hide();t:SetScale(1);t:SetOwner(body,"ANCHOR_NONE");t:SetClampedToScreen(false);t:ClearLines()
 local ok
 if source.link then ok=pcall(t.SetHyperlink,t,source.link)elseif source.spell and t.SetSpellByID then ok=pcall(t.SetSpellByID,t,source.spell)end
 if not ok or t:NumLines()==0 then
  t:ClearLines();for _,line in ipairs(source.lines or {})do
   if line.right and line.right~=""then t:AddDoubleLine(line.left or "",line.right,line.color[1],line.color[2],line.color[3],line.rightColor[1],line.rightColor[2],line.rightColor[3])
   else t:AddLine(line.left or "",line.color[1],line.color[2],line.color[3],true)end
  end
 end
 if t:NumLines()==0 then t:AddLine("Item data is loading. Select this entry again in a moment.",1,.85,.5,true)end
 t:Show();t:SetClampedToScreen(false);local scale=width/math.max(1,t:GetWidth());t:SetScale(scale);t:ClearAllPoints();t:SetPoint("TOPLEFT",body,"TOPLEFT",x/scale,-y/scale)
 return t:GetHeight()*scale+16
end
local function render()
 if not current or not popup or not popup:IsShown()then return end
 for _,f in pairs(tips)do f:Hide()end;for _,f in pairs(labels)do f:Hide()end
 local name,_,_,_,_,_,_,_,equip,icon=call(C_Item and C_Item.GetItemInfo or GetItemInfo,current.link)
 local choices=slots[equip]
 if not name and current.spell then
  local info=call(C_Spell and C_Spell.GetSpellInfo,current.spell)
  name=info and info.name;icon=info and info.iconID
 end
 detailIcon:SetTexture(icon or current.icon or 134400)
 detailName:SetText(name or (current.lines and current.lines[1]and current.lines[1].left)or "Details")
 detailKind:SetText(choices and "Item details and equipped comparison"or "Selected details")
 local width=math.max(100,scroll:GetWidth());body:SetWidth(width)
 local y=tooltip(1,current,0,0,width)
 if choices then
  local twoHand=equip=="INVTYPE_2HWEAPON";local links={}
  for i,slot in ipairs(choices)do
   local link=GetInventoryItemLink("player",slot);if link then links[#links+1]=link end
   y=y+label(2*i,"Currently equipped - "..(slotNames[slot]or slot)..(not link and " (empty)"or ""),0,y,width)
   if link then y=y+tooltip(i+1,{link=link},0,y,width)end
   if not twoHand then y=y+label(2*i+1,"Selected minus equipped:\n"..delta(current.link,link and {link}or {}),0,y,width)+20 end
  end
  if twoHand then y=y+label(8,"Selected minus main hand + off hand:\n"..delta(current.link,links),0,y,width)+20 end
  y=y+label(9,"Basic item stats only; effects, set bonuses and equip restrictions still need checking.",0,y,width)
 end
 if current.sections then
  local sections=type(current.sections)=='function'and call(current.sections)or current.sections
  for i,section in ipairs(type(sections)=='table'and sections or {})do
   y=y+label(20+i,(section.title and (section.title..'\n')or '')..(section.text or ''),0,y+10,width)+18
  end
 end
 body:SetHeight(math.max(y,scroll:GetHeight()))
end
function D.Show(data,owner)
 if not data or (not data.link and not data.spell and #(data.lines or {})==0)then return end
 initialize();if not popup then return end;current=data;GameTooltip:Hide()
 local page=WoWU_GetCurrentModuleFrame and WoWU_GetCurrentModuleFrame()or host
 if not page or not page:IsVisible()then page=host end
 local side="RIGHT";local x=owner and owner:GetCenter();local center=page:GetCenter()
 if x and center and x>=center then side="LEFT"end
 popup:SetSize(math.min(470,page:GetWidth()-28),math.max(200,page:GetHeight()-24));popup:ClearAllPoints();popup:SetPoint("TOP"..side,page,"TOP"..side,side=="RIGHT"and -12 or 12,-8)
 popup:Show();render();scroll:SetVerticalScroll(0)
end
function D.ShowLink(link,owner)D.Show({link=link},owner)end
local function directData(f)
 local e=f.data or f.entry or f.rewardData or {}
 if e.summary then
  return {icon=e.texture,lines={{left=e.summary,color={1,.82,.25}},{left=e.name or "",color={1,1,1}}}}
 end
 local link=e.link or e.itemLink or e.hyperlink or f.link
 if not link and e.itemKey and e.itemKey.itemID then link="item:"..e.itemKey.itemID end
 if not link and f.WoWUItemSlot then link=GetInventoryItemLink("player",f.WoWUItemSlot)end
 if not link and f.bag and f.slot then link=call(C_Container and C_Container.GetContainerItemLink or GetContainerItemLink,f.bag,f.slot)end
 if link then return {link=link,icon=e.icon or e.texture}end
end
function D.BindHover(f,inline)
 if not f then return end
 C_Timer.After(0,function()
  if bound[f]or (f.IsProtected and f:IsProtected())then return end
  local enter=f:GetScript("OnEnter");if not enter then return end
  bound[f]=true;local click=f:GetScript("OnClick")
  f:SetScript("OnEnter",function(self,...)capture(enter,self,...)end)
  f:SetScript("OnClick",function(self,button,...)
   local modifier=IsShiftKeyDown()or IsControlKeyDown()or IsAltKeyDown()
   local data=directData(self)or capture(enter,self)
   local alpha=GameTooltip:GetAlpha();GameTooltip:SetAlpha(0);D.capturing=true;local ok,err=true,nil;if click then ok,err=pcall(click,self,button,...)end;data=data or snapshot();D.capturing=false;GameTooltip:Hide();GameTooltip:SetAlpha(alpha)
   if not ok then geterrorhandler()(err);return end
   local already=type(inline)=="function"and inline(self)or inline==true
   local p=self:GetParent();local allowed=true
   while p do if p.WoWUGesture and not WoWU_TouchTapAllowed(p)then allowed=false;break end;p=p:GetParent()end
   if not already and not modifier and (button==nil or button=="LeftButton")and allowed and self:IsVisible()then D.Show(data,self)end
  end)
 end)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function()if D.IsShown()then render()end end)
