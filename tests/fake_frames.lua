-- In-memory frame model for regression tests. No Windows/WoW APIs are called.
local F={};F.__index=F
local frames={}
function F:SetParent(p)self.parent=p end
function F:GetParent()return self.parent end
function F:GetName()return self.name end
function F:GetChildren()local out={};for _,f in ipairs(frames)do if f.parent==self then out[#out+1]=f end end;return unpack(out)end
function F:GetRegions()return unpack(self.regions or {})end
function F:SetSize(w,h)self.w=w;self.h=h end
function F:GetWidth()return self.w or 32 end
function F:GetHeight()return self.h or 32 end
function F:SetWidth(w)self.w=w end
function F:SetHeight(h)self.h=h end
function F:SetScale(v)self.scale=v end
function F:GetScale()return self.scale or 1 end
function F:GetEffectiveScale()return self:GetScale()*(self.parent and self.parent:GetEffectiveScale()or 1)end
function F:SetAlpha(v)self.alpha=v end
function F:GetAlpha()return self.alpha or 1 end
function F:SetFrameStrata(v)self.strata=v end
function F:GetFrameStrata()return self.strata or 'MEDIUM'end
function F:SetFrameLevel(v)self.level=v end
function F:GetFrameLevel()return self.level or 1 end
function F:SetPoint(...)self.points[#self.points+1]={...}end
function F:GetPoint(i)return unpack(self.points[i or 1]or {})end
function F:GetNumPoints()return #self.points end
function F:ClearAllPoints()self.points={}end
function F:SetAllPoints(p)self:ClearAllPoints();self:SetPoint('TOPLEFT',p);self:SetPoint('BOTTOMRIGHT',p)end
function F:GetCenter()return 500,500 end
function F:IsShown()return self.shown~=false end
function F:IsVisible()return self:IsShown()and(not self.parent or self.parent:IsVisible())end
function F:Show()self.shown=true end
function F:Hide()self.shown=false end
function F:SetShown(v)self.shown=not not v end
function F:IsProtected()return false end
function F:IsForbidden()return false end
function F:IsObjectType(t)return self.kind==t end
function F:SetScript(e,fn)self.scripts[e]=fn end
function F:GetScript(e)return self.scripts[e]end
function F:HookScript(e,fn)local old=self.scripts[e];self.scripts[e]=function(...)if old then old(...)end;return fn(...)end end
function F:RegisterEvent(e)self.events[e]=true end
function F:Fire(e,...)if self.scripts[e]then return self.scripts[e](self,...)end end
function F:SetAttribute(k,v)self.attrs[k]=v end
function F:GetAttribute(k)return self.attrs[k]end
function F:SetMaskTexture(v)self.mask=v end
function F:GetMaskTexture()return self.mask end
function F:SetHitRectInsets(...)self.insets={...}end
function F:GetHitRectInsets()return unpack(self.insets or {0,0,0,0})end
function F:SetScrollChild(c)self.child=c end
function F:SetVerticalScroll(v)self.scroll=v end
function F:SetText(v)self.text=v end
function F:SetChecked(v)self.checked=v end
function F:GetChecked()return self.checked end
function F:CreateFontString()return CreateFrame('FontString',nil,self)end
function F:CreateTexture()return CreateFrame('Texture',nil,self)end
for _,name in ipairs({'EnableMouse','EnableMouseWheel','RegisterForClicks','SetFont','SetJustifyH','SetWordWrap','SetBlendMode','SetTexture','SetColorTexture','SetTexCoord','SetVertexColor','SetBackdrop','SetBackdropColor','SetBackdropBorderColor'})do F[name]=function()end end
function CreateFrame(kind,name,parent)
 local f=setmetatable({kind=kind,name=name,parent=parent,points={},scripts={},events={},attrs={}},F)
 frames[#frames+1]=f;if name then _G[name]=f end;return f
end
UIParent=CreateFrame('Frame','UIParent');UIParent:SetSize(2560,2240)
local now=100
function GetTime()return now end
function time()return 1793260000 end
function InCombatLockdown()return combat==true end
function RegisterStateDriver()end
function hooksecurefunc()end -- hooks are inspected separately; no native hooks here.
SlashCmdList={};WoWUDB={};C_Timer={After=function(_,fn)fn()end}
WoWU_Theme=setmetatable({},{__index=function()return function()end end})
return {F=F,frames=frames}
