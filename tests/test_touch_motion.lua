local tests={}
local function test(name,fn) tests[#tests+1]={name,fn} end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or .001),tostring(a)..' ~= '..tostring(b)) end
local time,pressed,x,y
local F={};F.__index=F
function F:SetScript(e,fn) self.scripts[e]=fn end
function F:HookScript(e,fn) local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;fn(...) end end
function F:Fire(e,...) if self.scripts[e] then self.scripts[e](self,...) end end
function F:RegisterEvent() end
function F:EnableMouse() end
function F:GetParent() return self.parent end
function F:GetLeft() return 0 end
function F:GetRight() return 200 end
function F:GetBottom() return 0 end
function F:GetTop() return 200 end
function F:GetEffectiveScale() return self.scale or 1 end
function F:GetHeight() return self.height or 200 end
function F:GetScrollChild() return self.child end
function F:GetVerticalScroll() return self.offset or 0 end
function F:SetVerticalScroll(v) self.offset=v;self.writes=(self.writes or 0)+1 end
function CreateFrame(kind,name,parent) return setmetatable({scripts={},parent=parent},F) end
local function setup(path)
    time=1;pressed=false;x=70;y=70
    function GetTime() return time end
    function GetCursorPosition() return x,y end
    function IsMouseButtonDown() return pressed end
    WoWUDB={locked=true};SlashCmdList={};GameTooltip=nil
    dofile('WoWU/TouchMotion.lua')
    dofile(path or 'WoWU/Core.lua')
    local s=CreateFrame('ScrollFrame');s.offset=500;s.child=CreateFrame('Frame');s.child.height=4200
    WoWU_EnableTouchScroll(s)
    return s,s.WoWUGesture,s.WoWUGesture.motion
end
local function tick(s,dt) dt=dt or 1/60;time=time+dt;s:Fire('OnUpdate',dt) end
local function begin(s) pressed=true;tick(s) end
local function settle(s,n) for i=1,n or 20 do tick(s) end end
local function ripple(path)
    local s=setup(path);begin(s)
    local deltas={};local last=s.offset
    for i=1,90 do
        y=70+math.floor(i/3)*6;tick(s)
        if i>30 then deltas[#deltas+1]=s.offset-last end
        last=s.offset
    end
    local mean=0;for _,v in ipairs(deltas) do mean=mean+v/#deltas end
    local variance=0;for _,v in ipairs(deltas) do variance=variance+(v-mean)^2/#deltas end
    return math.sqrt(variance),mean
end

test('batched 20 Hz input renders more evenly at 60 FPS than v0.14.9',function()
    local old,oldMean=ripple('tests/fixtures/touch-input-baseline.lua')
    local new,newMean=ripple('WoWU/Core.lua')
    assert(new<old*.6,'smoothing did not reduce step variation')
    near(newMean,oldMean,.1)
    print(string.format('MEASURE: rendered step deviation %.3f -> %.3f UI units (simulated)',old,new))
end)
test('normal steady input keeps its distance without reversing',function()
    local s,g=setup();begin(s);local previous=s.offset
    for i=1,60 do y=70+i*2;tick(s);assert(s.offset>=previous);previous=s.offset end
    settle(s);near(s.offset,620);assert(g.dragging)
end)
test('sub-threshold touch remains a tap and does not scroll',function()
    local s,g=setup();begin(s);y=78;tick(s);assert(WoWU_TouchTapAllowed(s));pressed=false;tick(s);settle(s);near(s.offset,500)
end)
test('swipe still blocks row activation before and after release',function()
    local s=setup();begin(s);y=110;assert(not WoWU_TouchTapAllowed(s));tick(s);pressed=false;tick(s);assert(not WoWU_TouchTapAllowed(s))
    begin(s);assert(WoWU_TouchTapAllowed(s))
end)
test('finger held still settles exactly and releases without a fling',function()
    local s,g,m=setup();begin(s);y=120;tick(s);settle(s);near(s.offset,550);near(m.velocity,0)
    pressed=false;tick(s);settle(s);near(s.offset,550)
end)
test('touching again stops both momentum and buffered movement',function()
    local s,g,m=setup();begin(s);y=120;tick(s);pressed=false;tick(s);tick(s);local at=s.offset
    begin(s);settle(s);near(s.offset,at);near(m.velocity,0)
end)
test('unlock cancels movement and cannot capture the same held press again',function()
    local s,g,m=setup();begin(s);y=120;tick(s);local at=s.offset;WoWUDB.locked=false;tick(s)
    WoWUDB.locked=true;y=150;tick(s);near(s.offset,at);assert(not g.down);assert(m.target==nil)
end)
test('hiding cancels buffered movement',function()
    local s,g,m=setup();begin(s);y=120;tick(s);local at=s.offset;s:Fire('OnHide');y=160;tick(s);near(s.offset,at);assert(m.target==nil)
end)
test('external scroll changes are respected during buffered motion',function()
    local s,g,m=setup();begin(s);y=120;tick(s);pressed=false;tick(s);s:SetVerticalScroll(50);settle(s);near(s.offset,50)
end)
test('scale converts pointer movement exactly once',function()
    local s=setup();s.scale=.5;x=30;y=30;begin(s);y=50;tick(s);settle(s);near(s.offset,540)
end)
test('both bounds clamp and reversal at an edge responds immediately',function()
    local s=setup();s.child.height=800;s.offset=590;begin(s);y=120;tick(s);settle(s);near(s.offset,600)
    y=100;tick(s);assert(s.offset<600);settle(s);near(s.offset,580)
    y=-1000;tick(s);settle(s);near(s.offset,0)
end)
test('content shrinking clamps without a delayed bounce',function()
    local s=setup();begin(s);y=120;tick(s);s.child.height=220;settle(s);near(s.offset,20)
end)
test('reward tooltip owned by dragged content is dismissed',function()
    local s=setup();local item=CreateFrame('Button',nil,s);local hides=0
    GameTooltip={GetOwner=function() return item end,Hide=function() hides=hides+1 end}
    begin(s);y=120;tick(s);assert(hides>0)
end)
test('unrelated tooltip is not dismissed',function()
    local s=setup();local item=CreateFrame('Button');local hides=0
    GameTooltip={GetOwner=function() return item end,Hide=function() hides=hides+1 end}
    begin(s);y=120;tick(s);assert(hides==0)
end)

local function sampledFlick(fps)
    local s,g,m=setup();m:Begin(0)
    local count=fps/20
    for i=1,fps/2 do
        time=1+i/fps
        m:Sample(math.floor((i+.001)/count)*6,1,4000)
        m:Step(1/fps,false,4000)
    end
    local velocity=m.velocity;m:Release()
    for i=1,fps do time=time+1/fps;m:Step(1/fps,true,4000) end
    return velocity,s.offset
end
test('sparse input yields consistent flick speed at 30, 60 and 120 FPS',function()
    -- 30 FPS cannot sample every 20 Hz arrival, so compare against the physical
    -- speed with a tolerance; 60/120 FPS receive the exact same sample times.
    local v30,p30=sampledFlick(30);local v60,p60=sampledFlick(60);local v120,p120=sampledFlick(120)
    near(v60,120,1);near(v120,v60,1);near(p120,p60,.5);near(v30,120,35);near(p30,p60,4)
end)
test('release in a gap between touch samples retains a measured flick',function()
    local s,g,m=setup();m:Begin(0)
    for i=1,6 do time=1+i*.05;m:Sample(i*6,1,4000);m:Step(.05,false,4000) end
    time=time+.025;m:Sample(36,1,4000);m:Release();assert(m.velocity>100 and m.velocity<130)
end)
test('a long stalled frame cannot fling the list across its entire range',function()
    local s,g,m=setup();m:Begin(0);time=time+.05;m:Sample(100,1,4000);m:Step(.016,false,4000)
    local at=s.offset;m:Release();m:Step(2,true,4000);assert(s.offset-at<200)
end)
test('idle lists stop writing scroll positions',function()
    local s,g,m=setup();begin(s);y=120;tick(s);settle(s);pressed=false;tick(s);settle(s)
    local writes=s.writes;settle(s,60);assert(s.writes==writes)
end)
test('touching outside the viewport stops old movement without capturing input',function()
    local s,g,m=setup();begin(s);y=120;tick(s);pressed=false;tick(s);tick(s);local at=s.offset
    x=300;pressed=true;tick(s);pressed=false;tick(s);settle(s);near(s.offset,at);assert(not g.down)
end)
for _,t in ipairs(tests) do local ok,err=pcall(t[2]);if not ok then error('FAIL: '..t[1]..'\n'..tostring(err)) end;print('PASS: '..t[1]) end
print(#tests..'/'..#tests..' motion tests passed')
