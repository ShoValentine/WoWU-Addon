-- A Dashboard view of Retail's native combat meter; no duplicate combat log collector.
function WoWU_BuildDamageMeter(parent)
 local f=CreateFrame('Frame',nil,parent,'BackdropTemplate');WoWU_Theme.Panel(f)
 local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',14,-13);title:SetText('Damage Meter')
 local hint=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');hint:SetPoint('BOTTOMLEFT',12,10);hint:SetPoint('BOTTOMRIGHT',-12,10);hint:SetJustifyH('LEFT');hint:SetWordWrap(true);hint:SetHeight(32)
 local mode='DamageDone';local sessionType='Current';local rows={}
 local function button(caption,x,fn)
  local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(94,28);b:SetPoint('TOPLEFT',x,-40);b:SetText(caption);b:SetScript('OnClick',fn);return b
 end
 local modeButton;modeButton=button('Damage',12,function()mode=mode=='DamageDone'and 'HealingDone'or 'DamageDone';modeButton:SetText(mode=='DamageDone'and 'Damage'or 'Healing')end)
 local period;period=button('Current',112,function()sessionType=sessionType=='Current'and 'Overall'or 'Current';period:SetText(sessionType=='Current'and 'Current'or 'Overall')end)
 for i=1,8 do
  local r=CreateFrame('StatusBar',nil,f);r:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');r:SetStatusBarColor(.55,.35,.12);r:SetHeight(31)
  r:SetPoint('TOPLEFT',12,-78-(i-1)*36);r:SetPoint('RIGHT',-12,0)
  r.name=r:CreateFontString(nil,'OVERLAY','GameFontNormal');r.name:SetPoint('LEFT',5,0);r.name:SetWidth(150);r.name:SetJustifyH('LEFT')
  r.value=r:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');r.value:SetPoint('RIGHT',-5,0);rows[i]=r
 end
 local function format(t,pattern,...)
  if not pcall(t.SetFormattedText,t,pattern,...)then t:SetText('--')end
 end
 local function update()
  local api=C_DamageMeter;local types=Enum and Enum.DamageMeterType;local periods=Enum and Enum.DamageMeterSessionType
  local session
  if api and api.GetCombatSessionFromType and types and periods and periods[sessionType]then
   local ok,result=pcall(api.GetCombatSessionFromType,periods[sessionType],types[mode]);if ok then session=result end
  end
  local sources=session and session.combatSources or {}
  local maxRows=math.max(0,math.min(8,math.floor((f:GetHeight()-126)/36)))
  for i,r in ipairs(rows)do
   local s=sources[i];r:SetShown(s~=nil and i<=maxRows)
   if s and i<=maxRows then
    -- Client values may be secret: pass directly to display methods, without comparison or sorting.
    pcall(r.SetMinMaxValues,r,0,session.maxAmount);pcall(r.SetValue,r,s.totalAmount)
    format(r.name,'%d. %s',i,s.name);format(r.value,'%s  |  %s/s',s.totalAmount,s.amountPerSecond)
    r.name:SetWidth(math.max(60,(f:GetWidth()-30)*.48))
    local class=s.classFilename
    if not(issecretvalue and issecretvalue(class))then local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class];if c then r:SetStatusBarColor(c.r,c.g,c.b)end end
   end
  end
  hint:SetText(not api and 'The native combat meter is unavailable on this client.'or #sources==0 and 'No combat recorded yet.'or 'Native ranking and pet attribution.')
 end
 local elapsed=0;f:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>.5 then elapsed=0;update()end end)
 f:SetScript('OnShow',update);return f
end
