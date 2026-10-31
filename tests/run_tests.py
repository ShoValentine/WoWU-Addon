from pathlib import Path
import json,sys,os
root=Path(__file__).resolve().parents[1]
os.chdir(root)
from lupa.lua51 import LuaRuntime
out=root/'outputs'/'project-review';out.mkdir(parents=True,exist_ok=True)
results=[]
def record(name,fn):
 log=[]
 try:
  count=fn(log);status='passed'
 except Exception as exc:
  count=0;status='failed';log.append(str(exc))
 results.append(dict(name=name,status=status,checks=count,log=log))
 print(name+': '+status+' ('+str(count)+' checks)')
 if status=='failed':print(log[-1])
def compile_all(log):
 lua=LuaRuntime(unpack_returned_tuples=True)
 compile=lua.eval('function(s,n)local f,e=loadstring(s,n);return f~=nil,e end')
 count=0
 for folder in ('WoWU','WoWU_Compass'):
  for p in sorted((root/folder).glob('*.lua')):
   ok,error=compile(p.read_text(encoding='utf-8-sig'),str(p));assert ok,error;count+=1
 log.append('Compiled every current Lua file with the actual Lua 5.1 compiler; no addon was run for this check.')
 return count
def compatibility(log):
 profiles=[('Retail',120105,1,True,False,None),('Forever',16001,99,False,True,None),('Era',11509,2,False,False,1),('TBC',20506,5,False,False,2),('Wrath',30403,11,False,False,3),('Cata',40402,14,False,False,4),('Mists',50504,19,False,False,5)]
 count=0
 for name,interface,project,retail,forever,major in profiles:
  lua=LuaRuntime(unpack_returned_tuples=True);g=lua.globals();g.GetBuildInfo=lambda:('fixture','1','today',interface);g.WOW_PROJECT_MAINLINE=1;g.WOW_PROJECT_ID=project;g.SlashCmdList=lua.table()
  lua.execute((root/'WoWU/Compatibility.lua').read_text(encoding='utf-8'))
  c=g.WoWUClient
  assert bool(c.isRetail)==retail and bool(c.isForever)==forever and c.classicMajor==major,name;count+=1
  assert bool(c.ModuleAvailable('Legacy'))==forever,name;count+=1
  assert bool(c.ModuleAvailable('Housing Dashboard'))==retail,name;count+=1
  assert bool(c.ModuleAvailable('Shop'))==retail,name;count+=1
  assert c.ModuleName('Adventure Guide')==('Dungeon Journal'if major==5 else 'Adventure Guide'),name;count+=1
  assert c.ModuleAvailable('Adventure'),name+' cannot open its own notification history';count+=1
  log.append(name+': identity, Legacy, Housing, Shop, journal naming and notification-history access passed')
 return count
def minimap(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 return lua.execute((root/'tests/test_current_minimap.lua').read_text(encoding='utf-8'))
def controller(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 return lua.execute((root/'tests/test_current_controller.lua').read_text(encoding='utf-8'))

def companion_map(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 return lua.execute((root/'tests/test_companion_map.lua').read_text(encoding='utf-8'))
def settings_dashboard(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 return lua.execute((root/'tests/test_settings_dashboard.lua').read_text(encoding='utf-8'))

def text_encoding(log):
 count=0
 for folder in ('WoWU','WoWU_Compass'):
  for p in (root/folder).rglob('*'):
   if p.is_file()and p.suffix.lower()in ('.lua','.xml','.toc','.txt'):
    text=p.read_text(encoding='utf-8-sig')
    for signature in ('\u00e2\u20ac','\u00c3\u00a9','\u00c2 ','\ufffd'):
     assert signature not in text,str(p)+' contains corrupt display text'
    count+=1
 log.append('All addon source, metadata and text documents decoded as UTF-8; known mojibake/replacement sequences absent.')
 return count

def window_defaults(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 return lua.execute((root/'tests/test_window_defaults.lua').read_text(encoding='utf-8'))

def touch(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 # Current Core themes its scrollbars; the legacy gesture fixture predates that.
 # This no-op only supplies presentation, leaving all gesture assertions intact.
 lua.execute('WoWU_Theme={Scrollbar=function()end}')
 lua.execute((root/'tests/test_touch_motion.lua').read_text(encoding='utf-8'))
 return sum(line.startswith('PASS:')for line in log)
def external_touch(log):
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().print=lambda *args:log.append(' '.join(map(str,args)))
 source=(root/'tests/test_external_touch.lua').read_text(encoding='utf-8')
 source=source[:source.index('for _, t in ipairs(tests) do')]
 # EQ integration was intentionally removed when WoWU gained its own tracker.
 # Execute every remaining original assertion against current source.
 source+='''
 local passed=0
 for _,t in ipairs(tests)do
  if t[1]:find('EQ')then print('SKIP obsolete removed EQ integration: '..t[1])
  else local ok,err=pcall(t[2]);assert(ok,t[1]..': '..tostring(err));passed=passed+1;print('PASS: '..t[1])end
 end
 return passed
 '''
 return lua.execute(source)
record('Lua 5.1 compiler',compile_all)
record('Addon text encoding',text_encoding)
record('Seven-client feature gates',compatibility)
record('Current minimap lifecycle',minimap)
record('Mini World Map',companion_map)
record('Settings and dashboard availability',settings_dashboard)
record('Locked window default and existing preferences',window_defaults)
record('Current controller state and held-cast release',controller)
record('Current swipe/momentum regression (presentation shim)',touch)
record('Current external-touch regression (removed EQ cases excluded)',external_touch)
(out/'current-regression-tests.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('Current checks: '+str(sum(r['checks']for r in results))+' passed; '+str(sum(r['status']=='failed'for r in results))+' failed suites')
sys.exit(any(r['status']=='failed'for r in results))
