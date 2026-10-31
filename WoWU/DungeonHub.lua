-- Temporary dungeon presentation. Never writes the three Dashboard profiles.
-- Protected actions are prepared out of combat; spell changes during combat
-- run only in Blizzard's restricted SecureHandlerClickTemplate environment.
local D={role="DPS",active=false};WoWUDungeonHub=D
local C=WoWUClient
local units={"player","party1","party2","party3","party4"}
local function combat()return InCombatLockdown and InCombatLockdown()end
local function call(fn,...)return C.Call(fn,...)end
local function public(v)return C.Public(v)end
local function number(v)return C.Number(v)end
local function plain(v,fallback)return public(v)and type(v)=="string"and v or fallback end
local function yes(v)return public(v)and v==true end
local function settings()
 WoWUDB.dungeonHub=WoWUDB.dungeonHub or {activation="auto",characters={}}
 local s=WoWUDB.dungeonHub;s.characters=s.characters or {};return s
end
local function character()
 local s=settings();local key=UnitGUID("player")or "player"
 s.characters[key]=s.characters[key]or {};return s.characters[key]
end
function D.Get(key)
 if key=="role"then return (D.testing and D.testRole)or character().role or "AUTO"end
 if key=="spells"then return character().spells or ""end
 return settings()[key]
end
function D.Set(key,value)
 if combat()then return false,"Change Dungeon Hub settings after combat."end
 if key=="role"and D.testing then D.testRole=value
 elseif key=="role"then character().role=value
 elseif key=="spells"then character().spells=value
 else settings()[key]=value end
 if D.RefreshSpells then D.RefreshSpells()end
 if D.Evaluate then D.Evaluate(true)end
 return true,"Dungeon Hub preference saved."
end
local function role()
 local r=D.testing and D.testRole or character().role
 if r=="TANK"or r=="HEALER"or r=="DPS"then return r end
 r=call(UnitGroupRolesAssigned,"player")
 return r=="TANK"and "TANK"or r=="HEALER"and "HEALER"or "DPS"
end
local function text(p,value,size)
 local t=p:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size or 14,"");WoWU_Theme.TextColor(t,.95,.83,.57)
 t:SetJustifyH("LEFT");t:SetText(value or "");return t
end
local function panel(p,title)
 local f=CreateFrame("Frame",nil,p,"BackdropTemplate");WoWU_Theme.Panel(f)
 f.title=text(f,title,19);f.title:SetPoint("TOPLEFT",16,-14);return f
end
local function button(p,caption,width,fn,template)
 local b=CreateFrame("Button",nil,p,(template and template..","or "").."BackdropTemplate")
 -- BackdropTemplate also has an OnLoad. Explicitly initialise secure helper
 -- methods instead of relying on multiple-template OnLoad inheritance.
 if template=="SecureHandlerClickTemplate"then SecureHandler_OnLoad(b)end
 b:SetSize(width,36);WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)
 b.label=text(b,caption,14);b.label:SetPoint("CENTER");b.label:SetWidth(width-12)
 b.label:SetJustifyH("CENTER")
 if fn then b:SetScript("OnClick",fn)end
 return b
end
local function bar(p,r,g,b)
 local f=CreateFrame("StatusBar",nil,p);f:SetStatusBarTexture(WoWU_Theme.assets.statusbar)
 f:SetStatusBarColor(r,g,b);f:SetMinMaxValues(0,1);f:SetValue(0)
 local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.035,.04,.045,.95)
 return f
end
local function place(f,x,y,w,h)
 f:ClearAllPoints();f:SetPoint("TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local heals={
 PALADIN={635,19750,20473,85673,633,4987,1152,7328},
 PRIEST={2061,2060,2050,2064,17,139,596,32546,527,528,2006},
 DRUID={5185,8936,774,18562,48438,33763,2782,88423,2908,20484,50769},
 SHAMAN={331,8004,1064,61295,77472,73685,974,51886,77130,2008},
 MONK={116670,115151,124682,116849,191837,115175,115450,115178},
 EVOKER={361469,355936,364343,366155,360823,374251,361227},
}
local tools={
 WARRIOR={355,871,12975,2565,6552,23920},PALADIN={62124,498,642,1022,31850,96231},
 DRUID={6795,22812,22842,61336,106839},DEATHKNIGHT={56222,48792,55233,48707,47528},
 DEMONHUNTER={185245,187827,203720,198589,183752},MONK={115546,115203,122278,119582,116705},
 PRIEST={33206,47788,19236,15487},SHAMAN={108271,57994,8143},ROGUE={1766,5277,31224,1966},
 MAGE={2139,45438,1953},WARLOCK={104773,108416,19647},HUNTER={147362,186265,109304},
 EVOKER={351338,363916,374348},
}
local function spellInfo(id)
 if C_Spell and C_Spell.GetSpellInfo then
  local s=call(C_Spell.GetSpellInfo,id);if s then return s.name,s.iconID,s.spellID or id end
 end
 local name,_,icon=call(GetSpellInfo,id);return name,icon,id
end
-- Resolve spellbook ranks by localized name so a learned higher rank is used.
local function knownSpells()
 local result={};local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
 if WoWUSpellBook and WoWUSpellBook.GetNumSpellBookSkillLines then
  for line=1,(call(WoWUSpellBook.GetNumSpellBookSkillLines)or 0)do
   local info=call(WoWUSpellBook.GetSpellBookSkillLineInfo,line)
   if info then for slot=(info.itemIndexOffset or 0)+1,(info.itemIndexOffset or 0)+(info.numSpellBookItems or 0)do
    local s=call(WoWUSpellBook.GetSpellBookItemInfo,slot,bank)
    if s and s.spellID and not s.isPassive then
     local name,icon,id=spellInfo(s.spellID);if name then result[name]={name=name,icon=icon,id=id}end
    end
   end end
  end
 elseif GetNumSpellTabs then
  for tab=1,GetNumSpellTabs()do
   local _,_,offset,count=GetSpellTabInfo(tab)
   for slot=offset+1,offset+count do
    local _,id=GetSpellBookItemInfo(slot,"spell")
    if id then local name,icon=spellInfo(id);if name then result[name]={name=name,icon=icon,id=id}end end
   end
  end
 end
 return result
end
local function resolve(ids,known)
 local out,seen={},{}
 for _,id in ipairs(ids or {})do
  local name,icon=spellInfo(id)
  local s=name and known[name]
  if not s and name and (yes(call(IsPlayerSpell,id))or yes(call(IsSpellKnown,id)))then s={name=name,icon=icon,id=id}end
  if s and not seen[s.name]then out[#out+1]=s;seen[s.name]=true end
 end
 return out
end
local function cooldown(id)
 local start,duration
 if C_Spell and C_Spell.GetSpellCooldown then
  local s=call(C_Spell.GetSpellCooldown,id)
  if s then start,duration=number(s.startTime),number(s.duration)end
 elseif GetSpellCooldown then start,duration=GetSpellCooldown(id);start,duration=number(start),number(duration)end
 if not start or not duration then return "Cooldown hidden"end
 local left=math.max(0,start+duration-GetTime())
 return left>0 and string.format("%.0fs",math.ceil(left))or "Ready"
end
local function setValue(b,value,max)
 -- Pass secret numbers directly to supported display setters; never compare or
 -- calculate with them. These are visual bars, not protected action decisions.
 if public(value)and value==nil then value=0 end
 if public(max)and max==nil then max=1 end
 local n=number(max);if n and n<=0 then max=1 end
 b:SetMinMaxValues(0,max);b:SetValue(value)
end
local function safeFormat(label,format,...)
 local ok=pcall(label.SetFormattedText,label,format,...)
 if not ok then label:SetText("Unavailable")end
end
function D.Build(parent)
 local root=CreateFrame("Frame",nil,parent);D.root=root
 local title=text(root,"Dungeon Hub",23);title:SetPoint("TOPLEFT",12,-8)
 local status=text(root,"",12);status:SetPoint("TOPLEFT",12,-40);status:SetPoint("RIGHT",-12,0)
 local compendium=button(root,"Compendium",140,function()if WoWUCompendium then WoWUCompendium.Open(true)end end)
 compendium:SetHeight(27);compendium:SetPoint("TOPLEFT",12,-35)
 status:ClearAllPoints();status:SetPoint("TOPLEFT",163,-40);status:SetPoint("RIGHT",-12,0)
 local returnButton=button(root,"Normal Dashboard",170,function()D.testing=false;D.testRole=nil;D.suppressed=true;D.manual=false;D.Activate(false)end)
 returnButton:SetPoint("TOPRIGHT",-8,-4)
 local roleButtons={}
 for i,r in ipairs({"TANK","HEALER","DPS"})do
  local b=button(root,r=="DPS"and "DPS"or r:sub(1,1)..r:sub(2):lower(),85,function()D.Set("role",r)end)
  b:SetPoint("RIGHT",returnButton,"LEFT",-10-(3-i)*92,0);roleButtons[r]=b
 end
 local party=panel(root,"Party")
 local spells=panel(root,"Select a spell")
 local meter=panel(root,"Current encounter")
 local threat=panel(root,"Threat & enemy casts")
 local utilities=panel(root,"Defensives & interrupts")
 local spellHint=text(spells,"Select once, then tap a party member to cast. Right-click a party member to target.",12)
 spellHint:SetPoint("TOPLEFT",16,-43);spellHint:SetPoint("RIGHT",-16,0)
 local activeSpell=text(spells,"",14);activeSpell:SetPoint("BOTTOMLEFT",16,14);activeSpell:SetPoint("RIGHT",-16,0)
 local partyHint=text(party,"",12);partyHint:SetPoint("BOTTOMLEFT",16,10);partyHint:SetPoint("RIGHT",-16,0)
 local controller=CreateFrame("Frame",nil,root,"SecureHandlerBaseTemplate")
 local members,selectors,actions={},{},{}
 for i,u in ipairs(units)do
  local b=CreateFrame("Button",nil,party,"SecureActionButtonTemplate,BackdropTemplate")
  WoWU_Theme.Panel(b,"inset");b:RegisterForClicks("AnyDown","AnyUp")
  b:SetAttribute("unit",u);b:SetAttribute("type1","target");b:SetAttribute("type2","target")
  b:SetAttribute("checkselfcast",false);b:SetAttribute("checkfocuscast",false);b:SetAttribute("checkmouseovercast",false)
  b.unit=u;b.name=text(b,"",16);b.name:SetPoint("TOPLEFT",12,-9);b.name:SetPoint("RIGHT",-12,0)
  b.health=bar(b,.18,.62,.26);b.health:SetPoint("TOPLEFT",12,-33);b.health:SetPoint("TOPRIGHT",-12,-33);b.health:SetHeight(22)
  b.healthText=text(b.health,"",13);b.healthText:SetPoint("CENTER");b.healthText:SetTextColor(1,1,1)
  b.power=bar(b,.15,.4,.9);b.power:SetPoint("TOPLEFT",b.health,"BOTTOMLEFT",0,-3);b.power:SetPoint("TOPRIGHT",b.health,"BOTTOMRIGHT",0,-3);b.power:SetHeight(7)
  b.detail=text(b,"",11);b.detail:SetPoint("TOPLEFT",12,-69);b.detail:SetPoint("RIGHT",-12,0)
  b.auras={}
  for j=1,4 do
   local icon=b:CreateTexture(nil,"OVERLAY");icon:SetSize(20,20);icon:SetPoint("BOTTOMRIGHT",-12-(j-1)*23,7)
   b.auras[j]=icon
  end
  members[i]=b
 end
 for i=1,12 do
  local b=button(spells,"",150,nil,"SecureHandlerClickTemplate")
  b:RegisterForClicks("LeftButtonUp");SecureHandlerSetFrameRef(b,"selection",controller)
  for j,member in ipairs(members)do SecureHandlerSetFrameRef(b,"member"..j,member)end
  b:SetAttribute("_onclick",[[
   local spell=self:GetAttribute("chosenSpell")
   if spell then
    self:GetFrameRef("selection"):SetAttribute("selected",spell)
    for i=1,5 do
     local member=self:GetFrameRef("member"..i)
     member:SetAttribute("type1","spell")
     member:SetAttribute("spell1",spell)
    end
   end
  ]])
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(28,28);b.icon:SetPoint("LEFT",8,0)
  b.label:ClearAllPoints();b.label:SetPoint("LEFT",b.icon,"RIGHT",7,0);b.label:SetPoint("RIGHT",-7,0)
  b.label:SetFont("Fonts\\FRIZQT__.TTF",12,"")
  selectors[i]=b
 end
 for i=1,6 do
  local b=button(utilities,"",120,nil,"SecureActionButtonTemplate")
  b:RegisterForClicks("AnyDown","AnyUp")
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(28,28);b.icon:SetPoint("TOP",0,-7)
  b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",5,-39);b.label:SetPoint("TOPRIGHT",-5,-39)
  b.label:SetFont("Fonts\\FRIZQT__.TTF",11,"")
  b.cooldown=text(b,"",12);b.cooldown:SetPoint("BOTTOM",0,7)
  actions[i]=b
 end
 local toolHint=text(utilities,"Tap to cast. Offensive abilities use your current target.",11)
 toolHint:SetPoint("BOTTOMLEFT",12,10);toolHint:SetPoint("RIGHT",-12,0)
 local enemyRows={}
 for i=1,5 do
  local t=text(threat,"",13);t:SetPoint("TOPLEFT",15,-44-(i-1)*41);t:SetPoint("RIGHT",-15,0);t:SetHeight(38)
  enemyRows[i]=t
 end
 local threatHint=text(threat,"Current target and visible nameplates only.",11)
 threatHint:SetPoint("BOTTOMLEFT",14,10);threatHint:SetPoint("RIGHT",-14,0)
 local meterMode="DamageDone"
 local metrics={{"DamageDone","Damage"},{"Interrupts","Interrupts"},{"DamageTaken","Taken"},{"Deaths","Deaths"}}
 for i,entry in ipairs(metrics)do
  local b=button(meter,entry[2],87,function()meterMode=entry[1]end)
  b:SetPoint("TOPLEFT",14+(i-1)*93,-44)
 end
 local meterRows={}
 for i=1,5 do
  local row=bar(meter,.35,.49,.73);row:SetHeight(52)
  row.name=text(row,"",15);row.name:SetPoint("TOPLEFT",9,-6);row.name:SetTextColor(1,1,1)
  row.value=text(row,"",13);row.value:SetPoint("BOTTOMLEFT",9,7);row.value:SetTextColor(1,1,1)
  meterRows[i]=row
 end
 local meterHint=text(meter,"Waiting for combat data.",12)
 meterHint:SetPoint("BOTTOMLEFT",16,14);meterHint:SetPoint("RIGHT",-16,0)
 function D.RefreshSpells()
  if combat()then D.spellsPending=true;return end
  D.spellsPending=false
  local _,class=UnitClass("player");local known=knownSpells()
  local ids={};for token in string.gmatch(character().spells or "","%d+")do ids[#ids+1]=tonumber(token)end
  if #ids==0 then ids=heals[class]or {}end
  local list=resolve(ids,known);local old=controller:GetAttribute("selected");local chosen
  for _,s in ipairs(list)do if s.name==old then chosen=s.name end end
  chosen=chosen or (list[1]and list[1].name)
  controller:SetAttribute("selected",chosen)
  for i,b in ipairs(selectors)do
   local s=list[i];b.spell=s;b:SetAttribute("chosenSpell",s and s.name)
   b.label:SetText(s and s.name or "");b.icon:SetTexture(s and s.icon);b:SetShown(s~=nil)
  end
  for _,b in ipairs(members)do
   b:SetAttribute("type1",D.role=="HEALER"and chosen and "spell"or "target")
   b:SetAttribute("spell1",D.role=="HEALER"and chosen or nil)
  end
  spellHint:SetText(#list>0 and "Select once, then tap party members to cast. Right-click to target."or "No supported healing spells learned. Configure spell IDs in Settings > Dungeon Hub.")
  local available=resolve(tools[class],known)
  for i,b in ipairs(actions)do
   local s=available[i];b.spell=s;b:SetAttribute("type",s and "spell");b:SetAttribute("spell",s and s.name)
   b.label:SetText(s and s.name or "");b.icon:SetTexture(s and s.icon);b:SetShown(s~=nil)
  end
  toolHint:SetText(#available==0 and "No supported defensive or interrupt spells learned yet."or "Tap to cast. Offensive abilities use your current target.")
 end
 function D.Resize(_,w,h)
  if combat()then return end
  local tank=D.role=="TANK";local healer=D.role=="HEALER"
  local left=w*.57;local right=w-left-12;local content=h-68
  party:SetShown(healer or not tank);spells:SetShown(healer);meter:SetShown(not healer and not tank)
  threat:SetShown(tank);utilities:SetShown(not healer)
  if healer then
   place(party,0,65,left,content);place(spells,left+12,65,right,content)
  elseif tank then
   party:Show();place(party,0,65,w*.55,content*.54)
   place(threat,0,65+content*.54+8,w*.55,content*.46-8)
   place(utilities,w*.585,h*.64,w*.415,h*.36-3)
  else
   place(meter,0,65,left,content)
   place(party,left+12,65,right,content*.62)
   place(utilities,left+12,65+content*.62+8,right,content*.38-8)
  end
  local rowH=math.max(38,(party:GetHeight()-72)/5)
  for i,b in ipairs(members)do
   place(b,12,42+(i-1)*(rowH+2),party:GetWidth()-24,rowH)
   local large=rowH>=91
   b.health:ClearAllPoints();b.health:SetPoint("TOPLEFT",12,large and -33 or -23);b.health:SetPoint("TOPRIGHT",-12,large and -33 or -23);b.health:SetHeight(large and 22 or 14)
   b.name:SetFont("Fonts\\FRIZQT__.TTF",large and 16 or 12,"")
   b.name:ClearAllPoints();b.name:SetPoint("TOPLEFT",12,-7);b.name:SetPoint("RIGHT",-12,0)
   b.detail:SetShown(large)
   for _,icon in ipairs(b.auras)do icon:SetAlpha(large and 1 or 0)end
  end
  local sh=math.max(34,math.min(74,(spells:GetHeight()-138)/6))
  for i,b in ipairs(selectors)do place(b,14+((i-1)%2)*(right-28)/2,94+math.floor((i-1)/2)*(sh+3),(right-34)/2,sh)end
  local aw=(utilities:GetWidth()-32)/3;local ah=math.max(66,(utilities:GetHeight()-64)/2)
  for i,b in ipairs(actions)do place(b,12+((i-1)%3)*(aw+3),39+math.floor((i-1)/3)*ah,aw,ah-4)end
  for i,row in ipairs(meterRows)do place(row,14,94+(i-1)*65,left-28,54)end
  local th=math.max(20,(threat:GetHeight()-73)/5)
  for i,t in ipairs(enemyRows)do t:ClearAllPoints();t:SetPoint("TOPLEFT",15,-42-(i-1)*th);t:SetPoint("RIGHT",-15,0);t:SetHeight(th)end
  for r,b in pairs(roleButtons)do WoWU_Theme.Tab(b,r==D.role)end
  D.RefreshSpells()
 end
 local function updateParty()
  local dead=0;local restricted=false
  for _,b in ipairs(members)do
   local u=b.unit;local exists=yes(call(UnitExists,u))
   b:SetAlpha(exists and 1 or .35)
   if not exists then
    b.name:SetText("Empty party slot");setValue(b.health,0,1);setValue(b.power,0,1);b.healthText:SetText("");b.detail:SetText("")
    for _,icon in ipairs(b.auras)do icon:SetTexture(nil)end
   else
    local name=call(UnitName,u);local r=plain(call(UnitGroupRolesAssigned,u),"NONE")
    local mana=number(call(UnitPower,u,0));local manaMax=number(call(UnitPowerMax,u,0))
    local manaLabel=r=="HEALER"and mana and manaMax and manaMax>0 and ("  |  Mana "..math.floor(100*mana/manaMax).."%")or ""
    if public(name)then b.name:SetText((name or u)..(r~="NONE"and "  |  "..r or "")..manaLabel)else b.name:SetText(name)end
    local hp,max=call(UnitHealth,u),call(UnitHealthMax,u)
    setValue(b.health,hp,max)
    local n,m=number(hp),number(max)
    local isDead=yes(call(UnitIsDeadOrGhost,u));local connected=call(UnitIsConnected,u)
    if isDead then dead=dead+1;b.healthText:SetText("Dead")
    elseif public(connected)and connected==false then b.healthText:SetText("Offline")
    elseif n and m and m>0 then b.healthText:SetText(string.format("%d%%  |  %d / %d",math.floor(n/m*100+.5),n,m))
    else safeFormat(b.healthText,"%s / %s",hp,max);restricted=true end
    local power,pmax=call(UnitPower,u),call(UnitPowerMax,u);setValue(b.power,power,pmax)
    local incoming=number(call(UnitGetIncomingHeals,u));local details={}
    if mana and manaMax and manaMax>0 then details[#details+1]="Mana "..math.floor(100*mana/manaMax).."%"end
    if incoming and incoming>0 then details[#details+1]="Incoming +"..incoming end
    local found=0;local types={}
    for i=1,16 do
     local a
     if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then a=call(C_UnitAuras.GetAuraDataByIndex,u,i,"HARMFUL")
     elseif UnitDebuff then local name,icon,_,dtype=call(UnitDebuff,u,i);if name then a={icon=icon,dispelName=dtype}end end
     if not a then break end
     if found<4 then found=found+1;b.auras[found]:SetTexture(a.icon)end
     local dtype=plain(a.dispelName,nil);if dtype then types[dtype]=true end
    end
    for j=found+1,4 do b.auras[j]:SetTexture(nil)end
    local dispelType=false
    for _,kind in ipairs({"Magic","Curse","Disease","Poison"})do if types[kind]then details[#details+1]=kind;dispelType=true end end
    WoWU_Theme.Border(b,dispelType and 1 or .7,dispelType and .35 or .6,dispelType and .2 or .4,1)
    b.detail:SetText(table.concat(details,"  |  "))
    b.health:SetStatusBarColor(isDead and .35 or .18,isDead and .35 or .62,.26)
   end
  end
  partyHint:SetText((D.role=="HEALER"and "Tap to cast selected spell"or "Tap to target").."  |  "..dead.." dead"..(restricted and "  |  Some values restricted"or ""))
 end
 local function updateThreat()
  local observed={"target"}
  for i=1,40 do observed[#observed+1]="nameplate"..i end
  local seen,lines={},{};local hidden=false
  for _,u in ipairs(observed)do
   if yes(call(UnitExists,u))and yes(call(UnitCanAttack,"player",u))then
    local guid=call(UnitGUID,u)
    if public(guid)and guid and not seen[guid]then
     seen[guid]=true
     local enemy=plain(call(UnitName,u),"Enemy");local target=u.."target"
     local victim=plain(call(UnitName,target),nil);local partyTarget=yes(call(UnitInParty,target))or yes(call(UnitIsUnit,target,"player"))
     local victimRole=plain(call(UnitGroupRolesAssigned,target),"NONE")
     local offTank=partyTarget and not yes(call(UnitIsUnit,target,"player"))and victimRole~="TANK"
     local isTanking,_,pct=call(UnitDetailedThreatSituation,"player",u);pct=number(pct)
     local cast=plain(call(UnitCastingInfo,u),nil)or plain(call(UnitChannelInfo,u),nil)
     local line=enemy..(victim and " > "..victim or " | target unavailable")
     if cast then line=line.."\nCasting: "..cast elseif pct then line=line..string.format("  |  %.0f%% threat",pct)end
     lines[#lines+1]={text=line,priority=offTank and 1 or cast and 2 or 3,red=offTank}
     if not public(isTanking)then hidden=true end
    else hidden=true end
   end
  end
  table.sort(lines,function(a,b)return a.priority<b.priority end)
  for i,t in ipairs(enemyRows)do
   local line=lines[i];t:SetText(line and line.text or (i==1 and "No observed hostile targets."or ""))
   WoWU_Theme.TextColor(t,1,line and line.red and .3 or .83,line and line.red and .2 or .55)
  end
  threatHint:SetText(hidden and "Some enemy information is restricted by this client."or "Current target + visible nameplates. Red: targeting a non-tank.")
 end
 local function updateMeter()
  local api=C_DamageMeter;local session
  if api and api.GetCombatSessionFromType and Enum and Enum.DamageMeterType and Enum.DamageMeterSessionType then
   session=call(api.GetCombatSessionFromType,Enum.DamageMeterSessionType.Current,Enum.DamageMeterType[meterMode])
  end
  if not session or not session.combatSources then
   for _,row in ipairs(meterRows)do row:Hide()end
   meterHint:SetText("Client combat meter unavailable. Enable Blizzard's Damage Meter if your client offers it.");return
  end
  local sources=session.combatSources;local restricted=false;local personalIndex
  for i,s in ipairs(sources)do if yes(s.isLocalPlayer)then personalIndex=i end end
  -- Preserve the client-provided ranking, including while values are secret.
  for i,row in ipairs(meterRows)do
   local index=i==5 and personalIndex and personalIndex>5 and personalIndex or i
   local s=sources[index];row:SetShown(s~=nil)
   if s then
    setValue(row,s.totalAmount,session.maxAmount)
    safeFormat(row.name,"%d. %s",index,s.name)
    local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[s.classFilename]
    if color then row:SetStatusBarColor(color.r,color.g,color.b)end
    local amount,total=number(s.totalAmount),number(session.totalAmount)
    if amount and total and total>0 then
     local rate=number(s.amountPerSecond)or 0
     row.value:SetText(meterMode=="DamageDone"and string.format("%.0f damage  |  %.0f DPS  |  %.1f%%",amount,rate,100*amount/total)or string.format("%.0f  |  %.1f%%",amount,100*amount/total))
    elseif meterMode=="DamageDone"then safeFormat(row.value,"%s damage  |  %s DPS",s.totalAmount,s.amountPerSecond);restricted=true
    else safeFormat(row.value,"%s",s.totalAmount);restricted=true end
   end
  end
  meterHint:SetText(#sources==0 and "No combat recorded yet."or (restricted and "Live client values | percentage breakdown available after combat."or "Blizzard's current / latest combat session. Pets follow the client's attribution."))
 end
 local elapsed=0
 root:SetScript("OnUpdate",function(_,dt)
  elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
  local name=call(GetInstanceInfo);title:SetText(plain(name,"Dungeon").." | "..(D.role=="DPS"and "DPS"or D.role:sub(1,1)..D.role:sub(2):lower()))
  title:SetWidth(math.max(150,root:GetWidth()-480))
  status:SetText((D.testing and "TEST MODE | Real spells and party data | "or "")..(combat()and "Combat | role and layout changes resume afterwards."or "Temporary Dungeon Hub | your saved Dashboard layouts are unchanged."))
  updateParty()
  if D.role=="TANK"then updateThreat()elseif D.role=="DPS"then updateMeter()end
  local selected=controller:GetAttribute("selected")
  activeSpell:SetText(selected and "Active: "..selected or "Select a healing spell")
  for _,b in ipairs(selectors)do
   if b.spell then WoWU_Theme.Tab(b,b.spell.name==selected)end
  end
  for _,b in ipairs(actions)do if b.spell then b.cooldown:SetText(cooldown(b.spell.id))end end
 end)
 D.RefreshSpells()
 return root
end
function D.Activate(enabled)
 if enabled and D.failed then print("WoWU: Dungeon Hub could not load. Use /wowudungeonerror for details.");return false end
 if combat()then D.pending=enabled;print("WoWU: Dungeon Hub changes will apply after combat.");return false end
 local L=WoWUDashboardLayout
 if not L.SetOverride then return false end
 D.active=enabled;D.pending=nil;D.role=role()
 local layout
 if enabled then
  layout={widgets={dungeon={x=0,y=0,w=24,h=20}}}
  if D.role=="TANK"then layout.widgets.minimap={x=14,y=2,w=10,h=10}end
 end
 L.SetOverride(layout)
 return true
end
function D.Open()
 if D.failed then return false,"Dungeon Hub could not load. Use /wowudungeonerror for details."end
 if combat()then return false,"Open the Dungeon Hub after combat."end
 local inside,kind=IsInInstance()
 if not inside or kind~="party"then return false,"The Dungeon Hub is available inside a five-player dungeon."end
 D.suppressed=false;D.manual=true;D.Activate(true)
 if WoWU_ShowPage then WoWU_ShowPage("Dashboard")end
 return true,"Dungeon Hub opened."
end
function D.Initialize(parent)
 if D.failed then return end
 local offer=CreateFrame("Frame",nil,parent,"BackdropTemplate");offer:SetSize(570,100)
 offer:SetPoint("TOP",0,-56);offer:SetFrameStrata("DIALOG");WoWU_Theme.Panel(offer);offer:Hide()
 local label=text(offer,"Dungeon detected. Open your Dungeon Hub?",17);label:SetPoint("TOP",0,-14)
 local open=button(offer,"Open Dungeon Hub",215,function()D.suppressed=false;offer:Hide();D.Activate(true)end)
 open:SetPoint("BOTTOMLEFT",16,14)
 local later=button(offer,"Not this visit",180,function()D.suppressed=true;offer:Hide()end);later:SetPoint("BOTTOMRIGHT",-16,14)
 function D.Evaluate(force)
  if D.testing then
   offer:Hide()
   if force or not D.active or D.role~=role()then D.Activate(true)end
   return
  end
  local inside,kind=IsInInstance();local dungeon=inside and kind=="party"
  if not dungeon then
   D.suppressed=false;D.offered=false;D.manual=false;offer:Hide()
   if D.active or D.pending then D.Activate(false)end
   return
  end
  local mode=settings().activation or "auto"
  if mode=="off"and not D.manual then offer:Hide();if D.active then D.Activate(false)end;return end
  if D.suppressed then return end
  if mode=="auto"or D.active or D.manual then
   offer:Hide();if force or not D.active or D.role~=role()then D.Activate(true)end
  elseif not D.offered and not combat()then D.offered=true;offer:Show()end
 end
 local ev=CreateFrame("Frame")
 for _,e in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","PLAYER_SPECIALIZATION_CHANGED"})do pcall(ev.RegisterEvent,ev,e)end
 ev:SetScript("OnEvent",function(_,event)
  if event=="SPELLS_CHANGED"then if D.RefreshSpells then D.RefreshSpells()end;return end
  if event=="PLAYER_REGEN_ENABLED"then
   if D.pending~=nil then D.Activate(D.pending)end
   if D.spellsPending and D.RefreshSpells then D.RefreshSpells()end
  end
  D.Evaluate()
 end)
 parent:HookScript("OnShow",function()D.Evaluate()end)
 SLASH_WOWUDUNGEON1="/wowudungeon"
 SlashCmdList.WOWUDUNGEON=function(arg)
  if combat()then print("WoWU: change Dungeon Hub mode after combat.");return end
  arg=string.lower(arg or "")
  if arg=="off"then D.testing=false;D.testRole=nil;D.suppressed=true;D.manual=false;D.Activate(false)
  else local ok,message=D.Open();if not ok then print("WoWU: "..message)end end
 end
 D.Evaluate()
end

-- The optional Hub must not abort Core's construction of every other module.
-- Retain the actual error instead of silently treating a partial build as ready.
function D.BuildSafely(parent)
 local ok,result=pcall(D.Build,parent)
 if ok then return result end
 D.failed=tostring(result)
 WoWUDB.dungeonHubLastError=D.failed
 D.RefreshSpells=nil;D.Resize=nil
 for _,child in ipairs({parent:GetChildren()})do
  child:Hide();child:SetScript("OnUpdate",nil)
 end
 local placeholder=CreateFrame("Frame",nil,parent)
 print("WoWU: Dungeon Hub could not load; the normal interface remains available. /wowudungeonerror shows the error.")
 return placeholder
end
SLASH_WOWUDUNGEONERROR1="/wowudungeonerror"
SlashCmdList.WOWUDUNGEONERROR=function()
 print("WoWU Dungeon Hub: "..(D.failed or "No startup error in this session."))
end
SLASH_WOWUDUNGEONTEST1="/wowudungeontest"
SlashCmdList.WOWUDUNGEONTEST=function(arg)
 if combat()then print("WoWU: toggle Dungeon Hub testing after combat.");return end
 if D.failed then print("WoWU: Dungeon Hub could not load. Use /wowudungeonerror for details.");return end
 if not D.Evaluate then print("WoWU: Dungeon Hub is not ready yet.");return end
 arg=string.lower(arg or ""):match("^%s*(.-)%s*$")
 if arg~=""and arg~="on"and arg~="off"and arg~="tank"and arg~="healer"and arg~="dps"then
  print("WoWU: /wowudungeontest [on | off | tank | healer | dps]");return
 end
 local enabled=arg==""and not D.testing or arg~=""and arg~="off"
 if not enabled then
  D.testing=false;D.testRole=nil;D.manual=false;D.suppressed=true;D.Activate(false)
  print("WoWU: Dungeon Hub test mode OFF. Normal Dashboard restored.");return
 end
 D.testing=true;D.suppressed=false
 if arg=="tank"or arg=="healer"or arg=="dps"then D.testRole=arg:upper()end
 D.Activate(true)
 if WoWU_MainFrame then WoWU_MainFrame:Show()end
 if WoWU_ShowPage then WoWU_ShowPage("Dashboard")end
 print("WoWU: Dungeon Hub test mode ON. Uses real spells and party members; group up to populate party slots. /wowudungeontest toggles it off.")
end
