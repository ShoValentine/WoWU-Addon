dofile('tests/fake_frames.lua')
local source=assert(io.open('WoWU/Controller.lua','rb')):read('*a')
local function snippet(pattern)local body=assert(source:match(pattern),'Snippet not found');return assert(loadstring('return function(self,control,newstate,down) '..body..' end'))()end
local context=snippet('local contextSnippet=%[%[(.-)%]%]')
local layout=snippet('root:SetAttribute%("_refreshlayout",%[%[(.-)%]%]%)')
local pre=snippet('SecureHandlerWrapScript%(b,"PreClick",root,%[%[(.-)%]%]%)')
local post=snippet('SecureHandlerWrapScript%(b,"PostClick",root,%[%[(.-)%]%]%)')
local F=getmetatable(UIParent)
function F:GetFrameRef(name)return self.refs[name]end
function F:ClearBindings()self.bindings={}end
function F:SetBindingClick(_,key,name,button)self.bindings[key]={name,button}end
function F:SetBinding(_,key,command)self.bindings[key]={command}end
function F:SetBindingSpell(_,key,name)self.bindings[key]={name}end
function F:EnableMouse(v)self.mouse=v end
function F:RunAttribute(name)
 if name=='_refreshlayout'then layout(self)
 elseif name=='_refreshbindings'then context(self,nil,self:GetAttribute('state-context')or '0')
 else error(name)end
end
local root=CreateFrame('Frame','ControllerFixture',UIParent);root.refs={};root.bindings={}
local keys={'PADDLEFT','PADDUP','PADDRIGHT','PADDDOWN','PAD3','PAD4','PAD2','PAD1'}
local prefixes={'','SHIFT-','CTRL-','CTRL-SHIFT-'}
root:SetAttribute('key-count',32);root:SetAttribute('pad-active',true);root:SetAttribute('pad-compact',true);root:SetAttribute('pad-hold-enabled',true)
for i=1,8 do root:SetAttribute('target-key'..i,keys[i])end
for i=1,4 do root.refs['group'..i]=CreateFrame('Frame',nil,root)end
for i=1,32 do
 local b=CreateFrame('Button','PadFixture'..i,root.refs['group'..math.ceil(i/8)]);root.refs['slot'..i]=b
 b:SetAttribute('pad-kind','macro');b:SetAttribute('pad-base-macrotext','/cast Spell'..i);b:SetAttribute('pad-physical-key',keys[(i-1)%8+1])
 root:SetAttribute('key'..i,prefixes[math.ceil(i/8)]..keys[(i-1)%8+1])
end
for layer=1,4 do
 root:SetAttribute('state-padlayer',tostring(layer));layout(root)
 local shown,mouse=0,0
 for i=1,4 do if root.refs['group'..i]:GetAlpha()==1 then shown=shown+1;assert(i==layer)end end
 for i=1,32 do local b=root.refs['slot'..i];assert(b:IsShown());if b.mouse then mouse=mouse+1;assert(math.ceil(i/8)==layer)end end
 assert(shown==1 and mouse==8)
end
print('PASS all four compact layers show exactly one group with eight mouse targets; secure action frames remain shown')
root:SetAttribute('pad-editing',true);layout(root);assert(root.refs.group1:GetAlpha()==1 and root.refs.group4:GetAlpha()==0)
root:SetAttribute('pad-editing',false);root:SetAttribute('pad-compact',false);layout(root)
for i=1,32 do assert(root.refs['slot'..i].mouse)end
print('PASS compact editing exposes base pair; expanded mode restores all mouse targets')
local b=root.refs.slot16;b:SetAttribute('pad-repeat-action',45)
context(root,nil,'0');assert(b:GetAttribute('type')=='action'and b:GetAttribute('action')==45 and b:GetAttribute('typerelease')=='actionrelease')
assert(root.refs.slot15:GetAttribute('type')=='macro'and not root.refs.slot15:GetAttribute('pressAndHoldAction'))
pre(b,root,nil,true)
assert(b:GetAttribute('pad-cast-held'))
for i=1,4 do assert(root.bindings[prefixes[i]..'PAD1'][1]==b:GetName())end
print('PASS matching spell uses native action/release; nonmatching macro remains single-press; held input latches all trigger variants')
root:SetAttribute('state-context','2');context(root,nil,'2')
assert(b:GetAttribute('action')==45)
-- Verify the release attributes before running the actual wrapped PostClick.
local released=b:GetAttribute('typerelease')=='actionrelease'and b:GetAttribute('action')
post(b,root,nil,false)
assert(released==45 and not b:GetAttribute('pad-cast-held')and not root:GetAttribute('cast-held-PAD1'))
assert(b:GetAttribute('action')==16 and root.bindings.PAD1[1]~=b:GetName())
print('PASS context/trigger changes preserve original action until release, then restore current context bindings')
root:SetAttribute('state-context','0');root:SetAttribute('pad-fishing',true);root:SetAttribute('pad-fishing-spell','Fishing')
root.refs.slot8:SetAttribute('pad-repeat-action',46);context(root,nil,'0')
assert(root.refs.slot8:GetAttribute('type')=='spell'and not root.refs.slot8:GetAttribute('pressAndHoldAction')and root.refs.slot8:GetAttribute('typerelease')==nil)
print('PASS fishing controls do not inherit repeat-action release attributes')
-- Exercise public option and restoration helpers with an in-memory CVar store.
local vars={ActionButtonUseKeyHeldSpell='0'}
function GetCVar(k)return vars[k]end
function SetCVar(k,v)vars[k]=tostring(v)end
function ReleaseAction()error('No native action should be invoked by settings')end
function GetBuildInfo()return 'fixture','1','today',120105 end
WOW_PROJECT_MAINLINE=1;WOW_PROJECT_ID=1
dofile('WoWU/Compatibility.lua');dofile('WoWU/Controller.lua')
local P=WoWUController;assert(P.SupportsHoldToCast()and not P.HoldToCast())
assert(P.SetHoldToCast(true));assert(P.HoldToCast()and vars.ActionButtonUseKeyHeldSpell=='0')
local function upvalue(fn,name)for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end;error(name)end
local preference=upvalue(P.SetHoldToCast,'applyHoldPreference');preference()
assert(vars.ActionButtonUseKeyHeldSpell=='1'and WoWUDB.controllerRecovery.ActionButtonUseKeyHeldSpell=='0')
assert(P.SetHoldToCast(false));preference();assert(vars.ActionButtonUseKeyHeldSpell=='0')
vars.ActionButtonUseKeyHeldSpell=nil;assert(not P.SetHoldToCast(true)and not P.HoldToCast())
combat=true;assert(not P.SetHoldToCast(false));combat=false
print('PASS hold preference defaults off, changes only when activated, restores native value and rejects unsupported/combat changes')
return 14
