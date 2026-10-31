-- Shared client identification. No Blizzard globals are replaced or patched.
if WoWUClient then return end
local version,build,date,interface=GetBuildInfo()
local forever=type(interface)=="number" and interface>=16000 and interface<17000
local retail=not forever and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID==WOW_PROJECT_MAINLINE
local classic=not forever and not retail and type(interface)=='number'and interface>=10000 and interface<100000
local major=type(interface)=='number'and math.floor(interface/10000)or 0
local classicNames={[1]='Classic Era / Anniversary',[2]='Burning Crusade Classic',[3]='Wrath Classic',[4]='Cataclysm Classic',[5]='Mists Classic'}
local C={isForever=forever,isRetail=not not retail,isClassic=not not classic,classicMajor=classic and major or nil,version=version,build=build,interface=interface}
WoWUClient=C
C.name=forever and "WoW Forever" or retail and "World of Warcraft Retail" or classic and (classicNames[major]or 'WoW Classic')or "Unsupported WoW client"
function C.Call(fn,...)
 if type(fn)~="function"then return end
 local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
 if ok then return a,b,c,d,e,f,g,h end
end
function C.Public(v)return not (issecretvalue and issecretvalue(v))end
function C.Number(v)return C.Public(v)and type(v)=="number"and v==v and v or nil end
function C.LastBag()
 return C.isRetail and Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or NUM_BAG_SLOTS or 4
end
function C.ModuleName(name)
 if C.classicMajor==5 and name=="Adventure Guide"then return "Dungeon Journal"end
 if C.classicMajor~=5 and name=="Dungeon Journal"then return "Adventure Guide"end
 return name
end
function C.ModuleAvailable(name)
 if name=="Dungeon Journal"then return C.classicMajor==5 end
 if name=="Legacy"then return C.isForever end
 if name=='Achievements'and C.isClassic then return major>=3 end
 if name=='Adventure Guide'and C.isClassic then return major>=4 end
 if (name=='Group Finder'or name=='Dungeon Finder')and C.isClassic then return major>=2 end
 if name=="Adventure Guide"or name=="Group Finder"or name=="Dungeon Finder"or name=="Housing Dashboard"or name=="Shop"then return C.isRetail end
 return true
end
function C.FilterModules(list)
 local result={};for _,name in ipairs(list)do name=C.ModuleName(name);if C.ModuleAvailable(name)then result[#result+1]=name end end
 return result
end
function C.Professions()
 local result={}
 for _,index in pairs({C.Call(GetProfessions)})do
  local name,icon,rank,maximum,_,_,skill=C.Call(GetProfessionInfo,index)
  if name then result[#result+1]={name=name,icon=icon,rank=rank or 0,max=maximum or 0,skillLine=skill}end
 end
 if C.isClassic and WoWUSpellBook and WoWUSpellBook.GetNumSpellBookSkillLines then
  local byName={};for _,d in ipairs(result)do byName[d.name]=d end
  local names={};local get=C_Spell and C_Spell.GetSpellName
  for id,skill in pairs({[2259]=171,[2018]=164,[7411]=333,[4036]=202,[2108]=165,[3908]=197,[2575]=186,[2366]=182,[8613]=393,[7620]=356,[2550]=185,[3273]=129,[78670]=794,[25229]=755,[45357]=773})do
   local n=get and get(id)or C.Call(GetSpellInfo,id);if n then names[n]=skill end
  end
  for line=1,C.Call(WoWUSpellBook.GetNumSpellBookSkillLines)or 0 do
   local tab=C.Call(WoWUSpellBook.GetSpellBookSkillLineInfo,line)
   if tab then for slot=(tab.itemIndexOffset or 0)+1,(tab.itemIndexOffset or 0)+(tab.numSpellBookItems or 0)do
    local s=C.Call(WoWUSpellBook.GetSpellBookItemInfo,slot,WoWUSpellBook.PlayerBank or 0)
    if s and names[s.name]then
     local d=byName[s.name];if not d then d={name=s.name,icon=s.iconID,rank=0,max=0,skillLine=names[s.name]};byName[s.name]=d;result[#result+1]=d end
     d.spellID=s.spellID
    end
   end end
  end
  for i=1,C.Call(GetNumSkillLines)or 0 do local n,h,_,rank,_,_,maximum=C.Call(GetSkillLineInfo,i);local d=byName[n];if d and not h then d.rank=rank or d.rank;d.max=maximum or d.max end end
 end
 return result
end
SLASH_WOWUCLIENT1="/wowuclient"
SlashCmdList.WOWUCLIENT=function()
 print("WoWU: "..C.name.." "..tostring(version).." ("..tostring(interface)..")")
 print(C.isRetail and "Retail native talents/crafting; live map data; reagent bag enabled."or C.isClassic and 'Classic native auction backend; realm-specific price scans. Retail-only modules are hidden.'or "Forever talents, Legacy and curated map databases.")
end
