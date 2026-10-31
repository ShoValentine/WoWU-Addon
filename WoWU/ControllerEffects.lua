-- Cosmetic feedback only: never changes bindings, casts spells or infers procs.
WoWUControllerEffects={}
local E=WoWUControllerEffects
local entries,procs,indices={},{},{}
local media="Interface\\AddOns\\WoWU\\Media\\Controller\\"
local function public(v)return not(issecretvalue and issecretvalue(v))end
local function call(fn,...)
 if type(fn)=="function"then local ok,v=pcall(fn,...);if ok and public(v)then return v end end
end
function E.Attach(button,round,key,layer)
 local glow=button:CreateTexture(nil,"OVERLAY",nil,5);glow:SetAllPoints()
 glow:SetTexture(media..(round and "circle"or "square").."-highlight.tga");glow:SetBlendMode("ADD");glow:SetVertexColor(1,.82,.35);glow:Hide()
 local entry={button=button,round=round,key=key,layer=layer,glow=glow,dashes={}}
 if layer then
  for i=1,8 do
   local t=button:CreateTexture(nil,"OVERLAY",nil,6);t:SetTexture("Interface\\Buttons\\WHITE8X8");t:SetVertexColor(1,.82,.08);t:SetBlendMode("ADD");t:Hide();entry.dashes[i]=t
  end
 end
 button.wowuEffects=entry;entries[#entries+1]=entry
end
function E.SetSpell(button,id)
 local entry=button.wowuEffects;if not entry then return end
 entry.spell=public(id)and type(id)=="number"and id>0 and id or nil
end
local function overlay(id)
 if not id then return false end
 local value=call(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed or IsSpellOverlayed,id)
 if type(value)=="boolean"then return value end
 return procs[id]==true
end
local function refreshProc(entry)
 local id=entry.spell
 entry.proc=overlay(id)
 -- Native overlays may use the override spell rather than the assigned base ID.
 if id and not entry.proc then
  local override=call(C_Spell and C_Spell.GetOverrideSpell or FindSpellOverrideByID,id)
  if type(override)=="number"and override>0 and override~=id then entry.proc=overlay(override)end
 end
end
local timer,phase=0,0
function E.Tick(dt,active,editing)
 timer=timer+dt;if timer<1/30 then return end;phase=(phase+timer*.65)%1;timer=0
 local layer=(IsControlKeyDown()and 2 or 0)+(IsShiftKeyDown()and 1 or 0)+1
 local state=active and call(C_GamePad and C_GamePad.GetDeviceMappedState,call(C_GamePad and C_GamePad.GetActiveDeviceID))
 local overrides=WoWUControllerShoulders and WoWUControllerShoulders.VisualMode()
 for _,entry in ipairs(entries)do
  local button=entry.button
  local pressed=false
  if state and state.buttons and not editing and (not entry.layer or entry.layer==layer)then
   local index=indices[entry.key]
   if index==nil then index=call(C_GamePad and C_GamePad.ButtonBindingToIndex,entry.key);if type(index)=="number"then indices[entry.key]=index end end
   if type(index)=="number"and index>=0 then
    local value=state.buttons[state.buttons[0]~=nil and index or index+1]
    pressed=public(value)and value==true
   end
  end
  entry.glow:SetShown(active and pressed)
  if active then refreshProc(entry)end
  local proc=active and not editing and entry.proc
  if entry.layer==1 and (overrides or WoWUController and WoWUController.fishing)then proc=false end
  for i,t in ipairs(entry.dashes)do
   t:SetShown(proc)
   if proc then
    local pos=(phase+(i-1)/8)%1;local x,y,w,h
    local radius=button:GetWidth()/2+1
    if entry.round then
     local angle=pos*math.pi*2;x,y=math.cos(angle)*radius,math.sin(angle)*radius;w,h=5,2
     if t.SetRotation then t:SetRotation(angle+math.pi/2)end
    else
     local edge=pos*4;local side=math.floor(edge);local f=edge-side
     if side==0 then x,y=-radius+f*2*radius,radius
     elseif side==1 then x,y=radius,radius-f*2*radius
     elseif side==2 then x,y=radius-f*2*radius,-radius
     else x,y=-radius,-radius+f*2*radius end
     w,h=side%2==0 and 6 or 2,side%2==0 and 2 or 6
    end
    t:SetSize(w,h);t:ClearAllPoints();t:SetPoint("CENTER",button,"CENTER",x,y)
   end
  end
 end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"SPELL_ACTIVATION_OVERLAY_GLOW_SHOW","SPELL_ACTIVATION_OVERLAY_GLOW_HIDE","PLAYER_ENTERING_WORLD"})do pcall(events.RegisterEvent,events,event)end
events:SetScript("OnEvent",function(_,event,id)
 if event=="PLAYER_ENTERING_WORLD"then procs={};return end
 if not public(id)or type(id)~="number"then return end
 procs[id]=event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"or nil
end)
