local fixture=dofile('tests/fake_frames.lua')
local function upvalue(fn,key,replacement)
 for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end
  if name==key then if replacement~=nil then debug.setupvalue(fn,i,replacement)end;return value,i end
 end
 error('Missing upvalue '..key)
end
local before=#fixture.frames
assert(loadfile('WoWU/Core.lua'))('WoWU')
local owner=fixture.frames[before+1]
local initialize=upvalue(owner:GetScript('OnEvent'),'initialize')
-- Isolate saved-default initialization from unrelated UI construction.
upvalue(initialize,'build',function()end)
local _,initializedIndex=upvalue(initialize,'initialized')
local checks=0
for _,case in ipairs({{label='fresh settings',saved={},expected=true},{label='existing unset preference',saved={scale=.9},expected=true},{label='explicit unlock preference',saved={locked=false},expected=false},{label='explicit lock preference',saved={locked=true},expected=true}})do
 WoWUDB=case.saved;debug.setupvalue(initialize,initializedIndex,false)
 owner:Fire('OnEvent','ADDON_LOADED','WoWU')
 assert(WoWUDB.locked==case.expected and WoWU_IsLocked()==case.expected,case.label)
 checks=checks+1;print('PASS '..case.label)
end
WoWU_SetLocked(false);assert(not WoWU_IsLocked());checks=checks+1
WoWU_SetLocked(true);assert(WoWU_IsLocked());checks=checks+1
print('PASS user can still unlock and relock the window')
return checks
