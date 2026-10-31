local tests, passed = {}, 0
local frames, clockTime, pressed, cursorX, cursorY, focus, inCombat, enabled
local function eq(a,b,message) assert(a==b,(message or "values differ")..": "..tostring(a).." / "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." != "..tostring(b)) end
local function test(name, fn) tests[#tests+1]={name,fn} end
local Frame = {}
Frame.__index=Frame
function Frame:SetScript(event,fn) assert(not self.secure and not self.forbidden,"edited protected target");self.scripts[event]=fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HasScript(event)
    if event=="OnClick" or event=="OnDoubleClick" then return self.kind=="Button" end
    return true
end
function Frame:HookScript(event,fn)
    local old=self:GetScript(event)
    self:SetScript(event,function(...) if old then old(...) end;fn(...) end)
end
function Frame:Fire(event,...) local fn=self:GetScript(event);if fn then return fn(self,...) end end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent=parent end
function Frame:GetChildren()
    local children={};for _,f in ipairs(frames) do if f.parent==self then children[#children+1]=f end end
    return unpack(children)
end
function Frame:IsForbidden() return self.forbidden end
function Frame:IsProtected() return self.secure end
function Frame:IsObjectType(kind) return self.kind==kind end
function Frame:IsVisible() return not self.hidden and (not self.parent or self.parent:IsVisible()) end
function Frame:GetLeft() return 0 end
function Frame:GetRight() return 200 end
function Frame:GetBottom() return 0 end
function Frame:GetTop() return 200 end
function Frame:GetEffectiveScale() return self.scale or 1 end
function Frame:GetScrollChild() return self.content end
function Frame:GetVerticalScrollRange() return self.range end
function Frame:GetVerticalScroll() return self.offset end
function Frame:SetVerticalScroll(value)
    assert(not inCombat,"scroll mutation in combat")
    self.offset=value;self:Fire("OnVerticalScroll",value)
end
function CreateFrame(kind,name,parent)
    local f=setmetatable({kind=kind,parent=parent,scripts={}},Frame)
    frames[#frames+1]=f;return f
end
local function setup()
    frames={};clockTime=1;pressed=false;cursorX=70;cursorY=70;inCombat=false;enabled=true
    WoWUDB={locked=true}
    function WoWU_IsLocked() return WoWUDB.locked end
    function GetTime() return clockTime end
    function GetCursorPosition() return cursorX,cursorY end
    function IsMouseButtonDown(button) return button=="LeftButton" and pressed end
    function InCombatLockdown() return inCombat end
    function GetMouseFoci() return {focus} end
    function hooksecurefunc(target,key,fn)
        if type(target)=="string" then fn=key;key=target;target=_G end
        local original=target[key]
        target[key]=function(...) local result=original(...);fn(...);return result end
    end
    EQObjectiveTracker=nil;QuestMapFrame=nil;QuestScrollFrame=nil;QuestLogQuests_Update=nil
    dofile("WoWU/TouchMotion.lua")
    dofile("WoWU/ExternalTouch.lua")
    local s=CreateFrame("ScrollFrame");s.range=500;s.offset=100
    s.content=CreateFrame("Frame",nil,s)
    local row=CreateFrame("Button",nil,s.content)
    local calls={down=0,up=0,click=0,drag=0,stop=0,wheel=0,scroll=0,double=0}
    row:SetScript("OnMouseDown",function(_,button) calls.down=calls.down+1 end)
    row:SetScript("OnMouseUp",function(_,button,inside) calls.up=calls.up+1;calls.inside=inside;calls.button=button end)
    row:SetScript("OnClick",function() calls.click=calls.click+1 end)
    row:SetScript("OnDoubleClick",function() calls.double=calls.double+1 end)
    row:SetScript("OnDragStart",function() calls.drag=calls.drag+1 end)
    row:SetScript("OnDragStop",function() calls.stop=calls.stop+1 end)
    s:SetScript("OnMouseWheel",function() calls.wheel=calls.wheel+1 end)
    s:SetScript("OnVerticalScroll",function() calls.scroll=calls.scroll+1 end)
    focus=row
    local c=WoWU_AttachExternalTouchScroll(s,function() return enabled end)
    return s,row,c,calls
end
local function tick(c,dt) clockTime=clockTime+(dt or .016);c.driver:Fire("OnUpdate",dt or .016) end
-- Movement now has a destination plus a smoothed displayed position. Input/routing
-- tests check the destination; the motion suite verifies rendered trajectories.
local function destination(c) return c.motion.target or c.scroll:GetVerticalScroll() end
local function down(row) pressed=true;focus=row;row:Fire("OnMouseDown","LeftButton") end
local function up(row,c,updateFirst)
    pressed=false
    if updateFirst then tick(c) end
    row:Fire("OnMouseUp","LeftButton",true);row:Fire("OnClick","LeftButton")
end

test("tap calls original down/up/click exactly once with arguments",function()
    local s,r,c,n=setup();down(r);tick(c);up(r,c);eq(n.down,1);eq(n.up,1);eq(n.click,1);eq(n.inside,true);near(s.offset,100)
end)
test("sub-threshold movement stays a tap",function()
    local s,r,c,n=setup();down(r);cursorY=78;tick(c);up(r,c);eq(n.click,1);near(s.offset,100)
end)
test("swipe scrolls and suppresses release, click, double-click and EQ reorder",function()
    local s,r,c,n=setup();down(r);cursorY=110;tick(c);r:Fire("OnDragStart","LeftButton");up(r,c);r:Fire("OnDragStop");r:Fire("OnDoubleClick","LeftButton")
    near(destination(c),140);assert(s.offset>100 and s.offset<140);eq(n.up,0);eq(n.click,0);eq(n.down,0);eq(n.drag,0);eq(n.stop,0);eq(n.double,0);assert(n.scroll>0)
end)
test("fast swipe entirely between updates is detected on mouse release",function()
    local s,r,c,n=setup();down(r);cursorY=120;up(r,c);near(destination(c),150);eq(n.click,0);eq(n.up,0);tick(c);assert(s.offset>100)
end)
test("release update before OnClick still suppresses quest activation",function()
    local s,r,c,n=setup();down(r);cursorY=115;up(r,c,true);eq(n.click,0);near(destination(c),145)
end)
test("EQ frame row without OnClick or original OnMouseDown is guarded",function()
    local s,r,c,n=setup();local row=CreateFrame("Frame",nil,s.content)
    row:SetScript("OnMouseUp",function() n.up=n.up+1 end);c:Refresh();down(row);cursorY=105;up(row,c);eq(n.up,0)
    down(row);up(row,c);eq(n.up,1)
end)
test("next tap immediately after swipe works",function()
    local s,r,c,n=setup();down(r);cursorY=110;up(r,c);down(r);up(r,c);eq(n.click,1);eq(n.up,1)
end)
test("horizontal drag suppresses tap without vertical scrolling",function()
    local s,r,c,n=setup();down(r);cursorX=115;up(r,c);eq(n.click,0);near(s.offset,100)
end)
test("gesture threshold and distance respect UI scale",function()
    local s,r,c,n=setup();s.scale=.5;cursorX=30;cursorY=30;down(r);cursorY=35;tick(c);eq(c.dragging,false)
    cursorY=50;up(r,c);near(destination(c),140);eq(n.click,0)
end)
test("native range is authoritative and bounds are clamped",function()
    local s,r,c,n=setup();s.range=120;down(r);cursorY=150;tick(c);near(destination(c),120);assert(s.offset<=120);cursorY=-300;tick(c);near(destination(c),0);assert(s.offset>=0);up(r,c)
end)
test("non-scrollable list still cancels dragged row activation",function()
    local s,r,c,n=setup();s.offset=0;s.range=0;down(r);cursorY=120;up(r,c);eq(n.click,0);near(s.offset,0)
end)
test("flick momentum advances, decays and stops at range",function()
    local s,r,c,n=setup();down(r);cursorY=100;tick(c);up(r,c);local at=s.offset;tick(c);assert(s.offset>at)
    for i=1,120 do tick(c) end;assert(s.offset<=s.range);assert(math.abs(c.velocity)<=10)
end)
test("holding still before release prevents stale momentum",function()
    local s,r,c,n=setup();down(r);cursorY=110;tick(c);for i=1,15 do tick(c) end;up(r,c);local at=s.offset;eq(c.velocity,0);tick(c);near(s.offset,at)
end)
test("touching list interrupts momentum without moving or activating on down",function()
    local s,r,c,n=setup();down(r);cursorY=110;tick(c);up(r,c);tick(c);down(r);eq(c.velocity,0);eq(n.click,0)
end)
test("right-click and its original arguments survive a prior swipe",function()
    local s,r,c,n=setup();down(r);cursorY=110;up(r,c);r:Fire("OnMouseDown","RightButton");r:Fire("OnMouseUp","RightButton",true);r:Fire("OnClick","RightButton");eq(n.click,1);eq(n.button,"RightButton")
end)
test("unlocked original click and row drag handlers work without scrolling",function()
    local s,r,c,n=setup();WoWUDB.locked=false;down(r);cursorY=110;tick(c);r:Fire("OnDragStart","LeftButton");up(r,c);r:Fire("OnDragStop")
    eq(n.click,1);eq(n.drag,1);eq(n.stop,1);near(s.offset,100)
end)
test("disabled docking predicate restores original interaction",function()
    local s,r,c,n=setup();enabled=false;down(r);cursorY=110;tick(c);up(r,c);eq(n.click,1);near(s.offset,100)
end)
test("combat cancels motion without replaying a queued swipe",function()
    local s,r,c,n=setup();down(r);cursorY=100;tick(c);local at=s.offset;inCombat=true;cursorY=130;tick(c);up(r,c);near(s.offset,at);eq(n.click,0)
    inCombat=false;tick(c,.4);near(s.offset,at);down(r);up(r,c);eq(n.click,1)
end)
test("new combat taps retain native actions and install refuses combat",function()
    local s,r,c,n=setup();inCombat=true;down(r);cursorY=110;tick(c);up(r,c);eq(n.click,1);near(s.offset,100)
    eq(WoWU_AttachExternalTouchScroll(s,function() return true end),nil)
end)
test("hide cancels movement and a held press cannot recapture on show",function()
    local s,r,c,n=setup();down(r);cursorY=110;tick(c);local at=s.offset;s.hidden=true;c.driver:Fire("OnHide");s.hidden=false;c.driver:Fire("OnShow");cursorY=150;tick(c);near(s.offset,at);up(r,c);eq(n.click,0)
end)
test("map gesture crossing into list is not captured",function()
    local s,r,c,n=setup();local map=CreateFrame("Frame");focus=map;pressed=true;cursorX=400;tick(c)
    focus=r;cursorX=70;cursorY=160;tick(c);eq(c.down,nil);near(s.offset,100)
end)
test("overlapping popup is not mistaken for quest content",function()
    local s,r,c,n=setup();focus=CreateFrame("Button");pressed=true;tick(c);cursorY=150;tick(c);near(s.offset,100);eq(c.down,nil)
end)
test("background can start a swipe by pointer polling",function()
    local s,r,c,n=setup();focus=s;pressed=true;tick(c);cursorY=120;tick(c);pressed=false;tick(c);near(destination(c),150)
end)
test("scrollbar and search box are not wired or captured",function()
    local s,r,c,n=setup();local bar=CreateFrame("Slider",nil,s);local box=CreateFrame("EditBox",nil,s.content)
    c:Refresh();eq(bar:GetScript("OnMouseDown"),nil);eq(box:GetScript("OnMouseDown"),nil)
    focus=bar;pressed=true;tick(c);cursorY=120;tick(c);near(s.offset,100)
end)
test("secure item buttons and forbidden descendants remain untouched",function()
    local s,r,c,n=setup();local item=CreateFrame("Button",nil,s.content);item.secure=true
    local secret=CreateFrame("Frame",nil,s.content);secret.forbidden=true;c:Refresh()
    eq(item:GetScript("OnMouseDown"),nil);eq(secret:GetScript("OnMouseDown"),nil)
    focus=item;pressed=true;tick(c);cursorY=120;tick(c);near(s.offset,100)
end)
test("protected item above row in mouse focus list blocks background capture",function()
    local s,r,c,n=setup();local item=CreateFrame("Button",nil,s.content);item.secure=true
    GetMouseFoci=function() return {item,r} end;pressed=true;tick(c);cursorY=120;tick(c);near(s.offset,100)
end)
test("new pooled rows and replaced scripts get guarded",function()
    local s,r,c,n=setup();local fresh=CreateFrame("Button",nil,s.content);fresh:SetScript("OnClick",function() n.click=n.click+1 end)
    tick(c,.26);down(fresh);cursorY=115;up(fresh,c);eq(n.click,0)
    fresh:SetScript("OnClick",function() n.click=n.click+10 end);c:Refresh();down(fresh);up(fresh,c);eq(n.click,10)
end)
test("repeated attachment is idempotent and preserves wheel handler",function()
    local s,r,c,n=setup();local handler=r:GetScript("OnMouseDown");local wheel=s:GetScript("OnMouseWheel")
    for i=1,6 do eq(WoWU_AttachExternalTouchScroll(s,function() return enabled end),c) end
    eq(r:GetScript("OnMouseDown"),handler);eq(s:GetScript("OnMouseWheel"),wheel);down(r);up(r,c);eq(n.click,1)
end)
test("native title down/up visual offsets stay balanced on tap and swipe",function()
    local s,r,c,n=setup();local title=CreateFrame("Button",nil,s.content);local x=0
    title:SetScript("OnMouseDown",function() x=x+1 end);title:SetScript("OnMouseUp",function() x=x-1 end)
    title:SetScript("OnClick",function() n.click=n.click+1 end);c:Refresh();down(title);cursorY=120;up(title,c);eq(x,0);eq(n.click,0)
    down(title);up(title,c);eq(x,0);eq(n.click,1)
end)
test("EQ binding follows Render-created rows and click-through",function()
    local s,r,c,n=setup();local host=CreateFrame("Frame");local trackerFrame=CreateFrame("Frame",nil,host);s.parent=trackerFrame;trackerFrame.scroll=s
    local tracker={IsClickThrough=function() return false end}
    local fresh
    tracker.Render=function() fresh=CreateFrame("Frame",nil,s.content);fresh:SetScript("OnMouseUp",function() n.up=n.up+1 end) end
    EQObjectiveTracker={GetModule=function() return tracker end};WoWU_BindEQTouch(trackerFrame,host);tracker:Render()
    down(fresh);cursorY=120;up(fresh,c);eq(n.up,0)
    tracker.IsClickThrough=function() return true end;down(r);cursorY=160;up(r,c);eq(n.click,1)
end)
test("map binding touches only quest content and refreshes pooled rows synchronously",function()
    local s,r,c,n=setup();local host=CreateFrame("Frame");local map=CreateFrame("Frame",nil,host);local canvas=CreateFrame("Frame",nil,map)
    local pan=function() n.drag=n.drag+1 end;canvas:SetScript("OnDragStart",pan);map.ScrollContainer=canvas
    local qm=CreateFrame("Frame",nil,map);local qf=CreateFrame("Frame",nil,qm);s.parent=qf;qf.ScrollFrame=s;qm.QuestsFrame=qf;QuestMapFrame=qm
    local fresh;QuestLogQuests_Update=function() fresh=CreateFrame("Button",nil,s.content);fresh:SetScript("OnClick",function() n.click=n.click+1 end) end
    WoWU_BindMapQuestTouch(map,host,function() return enabled end);QuestLogQuests_Update()
    eq(canvas:GetScript("OnDragStart"),pan);eq(canvas:GetScript("OnMouseDown"),nil);canvas:Fire("OnDragStart");eq(n.drag,1)
    down(fresh);cursorY=120;up(fresh,c);eq(n.click,0)
    enabled=false;down(fresh);up(fresh,c);eq(n.click,1)
end)
test("old mouse-focus API works when GetMouseFoci is unavailable",function()
    local s,r,c,n=setup();GetMouseFoci=nil;GetMouseFocus=function() return focus end
    focus=s;pressed=true;tick(c);cursorY=120;tick(c);near(destination(c),150)
end)
test("another addon chaining the input scripts does not duplicate a press",function()
    local s,r,c,n=setup();local old=r:GetScript("OnMouseDown");local other=0
    r:SetScript("OnMouseDown",function(...) other=other+1;old(...) end);c:Refresh()
    down(r);up(r,c);eq(n.down,1);eq(n.up,1);eq(n.click,1);eq(other,1);eq(c.down,false)
end)
test("recycled row changes controller when moved between scroll lists",function()
    local s,r,c,n=setup();local second=CreateFrame("ScrollFrame");second.range=500;second.offset=0;second.content=CreateFrame("Frame",nil,second)
    local c2=WoWU_AttachExternalTouchScroll(second,function() return enabled end);r.parent=second.content;c2:Refresh()
    down(r);cursorY=120;up(r,c2);near(destination(c2),50);near(s.offset,100);eq(n.click,0)
end)
test("unlock during swipe cancels momentum and the next native tap works",function()
    local s,r,c,n=setup();down(r);cursorY=100;tick(c);local at=s.offset;WoWUDB.locked=false;cursorY=130;tick(c);up(r,c);eq(n.click,0);near(s.offset,at)
    down(r);up(r,c);eq(n.click,1);tick(c);near(s.offset,at)
end)
test("unsupported scroll API fails closed",function()
    setup();local f=CreateFrame("Frame");f.GetScrollChild=false;eq(WoWU_AttachExternalTouchScroll(f,function() return true end),nil)
end)
test("new press outside the list stops buffered motion without capturing it",function()
    local s,r,c,n=setup();down(r);cursorY=120;tick(c);up(r,c);tick(c);local at=s.offset
    focus=CreateFrame('Button');cursorX=300;pressed=true;tick(c);pressed=false;tick(c)
    for i=1,30 do tick(c) end
    near(s.offset,at);eq(c.down,false);eq(c.motion.target,nil)
end)

for _, t in ipairs(tests) do
    local ok,err=pcall(t[2])
    if not ok then error("FAIL: "..t[1].."\n"..tostring(err)) end
    passed=passed+1;print("PASS: "..t[1])
end
print(string.format("%d/%d regression tests passed",passed,#tests))
