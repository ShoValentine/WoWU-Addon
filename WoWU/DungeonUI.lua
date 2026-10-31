-- Shared visual toolkit for the integrated Retail and Mists dungeon modules.
if not (WoWUClient.isRetail or WoWUClient.classicMajor==5)then return end
local U={};WoWUDungeonUI=U
if WoWUClient.isRetail then WoWURetailUI=U else WoWUMistsUI=U end
function U.Call(fn,...)
 if type(fn)~="function"then return end
 local function pack(...)return {n=select("#",...),...}end
 local result=pack(pcall(fn,...))
 if result[1]then return unpack(result,2,result.n)end
end
function U.Text(parent,size)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(t,.96,.83,.57);t:SetJustifyH("LEFT");return t
end
function U.Button(parent,width,caption,handler)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetSize(width,36)
 b.label=U.Text(b,13);b.label:SetPoint("CENTER");b.label:SetText(caption)
 WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b);b:SetScript("OnClick",handler);return b
end
function U.Panel(parent)
 local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");WoWU_Theme.Panel(f);return f
end
function U.Scroll(parent)
 local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
 local body=CreateFrame("Frame",nil,scroll);body:SetSize(400,1);scroll:SetScrollChild(body)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(scroll)end
 scroll:SetScript("OnSizeChanged",function()body:SetWidth(math.max(1,scroll:GetWidth()))end)
 return scroll,body
end
function U.List(parent)
 local scroll,body=U.Scroll(parent);local rows={}
 function scroll:SetData(data,onClick,selected)
  local width=math.max(100,self:GetWidth());local height=self.rowHeight or 58;local stride=height+4;body:SetWidth(width)
  for i,d in ipairs(data)do
   local b=rows[i]
   if not b then
    b=CreateFrame("Button",nil,body,"BackdropTemplate");rows[i]=b;WoWU_Theme.Panel(b);WoWU_Theme.Button(b)
    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(34,34);b.icon:SetPoint("LEFT",8,0)
    b.title=U.Text(b,14);b.title:SetPoint("TOPRIGHT",-10,-10);b.title:SetHeight(20)
    b.level=U.Text(b,12);b.level:SetPoint("TOPRIGHT",-10,-10);b.level:SetJustifyH("RIGHT")
    b.sub=U.Text(b,11);b.sub:SetPoint("BOTTOMRIGHT",-10,7);b.sub:SetHeight(17)
    b:SetScript("OnClick",function(self)if not WoWU_TouchTapAllowed or WoWU_TouchTapAllowed(scroll)then
     for _,row in ipairs(rows)do WoWU_Theme.Border(row,row==self and 1 or .65,row==self and .85 or .55,.3,1)end
     if self.action then self.action(self.data)end
    end end)
    b:SetScript("OnEnter",function(self)if self.data.link then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.data.link);GameTooltip:Show()end end)
    b:SetScript("OnLeave",function()GameTooltip:Hide()end);WoWUDetails.BindHover(b,false)
   end
   b:SetSize(width,height);b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(i-1)*stride)
   b.data=d;b.action=onClick;b.icon:SetTexture(d.icon);b.icon:SetShown(d.icon~=nil)
   b.icon:SetSize(d.largeIcon and 56 or d.art and 94 or 34,d.largeIcon and 56 or d.art and 66 or 34);b.icon:SetTexCoord(0,1,0,1)
   if d.art then b.icon:SetTexCoord(.1,.9,.08,.85)end
   b.level:SetText(d.levelText or "");b.level:SetShown(d.levelText~=nil)
   local x=d.icon and (d.largeIcon and 78 or d.art and 112 or 50)or 10
   b.title:SetFont("Fonts\\FRIZQT__.TTF",d.queue and 22 or d.journal and 20 or 14,"");b.title:SetHeight(d.journal and 48 or d.queue and 34 or 20);b.title:SetWordWrap(d.journal==true)
   b.level:SetFont("Fonts\\FRIZQT__.TTF",d.queue and 16 or 12,"")
   b.sub:SetFont("Fonts\\FRIZQT__.TTF",d.queue and 15 or d.journal and 14 or 11,"")
   b.title:ClearAllPoints();b.title:SetPoint("TOPLEFT",d.queue and 18 or x,d.queue and -13 or -8);b.title:SetPoint("TOPRIGHT",d.levelText and -116 or -10,d.queue and -13 or -8)
   b.sub:ClearAllPoints();b.sub:SetPoint("BOTTOMLEFT",d.queue and 18 or x,d.queue and 12 or 7);b.sub:SetPoint("BOTTOMRIGHT",-10,d.queue and 12 or 7)
   b.title:SetText((d.titleColor or "")..(d.name or "")..(d.titleColor and "|r"or ""));b.sub:SetText(d.sub or "");WoWU_Theme.Border(b,d.id==selected and 1 or .65,d.id==selected and .85 or .55,.3,1);b:Show()
  end
  for i=#data+1,#rows do rows[i]:Hide()end
  body:SetHeight(math.max(1,#data*stride));self:SetVerticalScroll(math.min(self:GetVerticalScroll(),math.max(0,body:GetHeight()-self:GetHeight())))
 end
 return scroll,body
end
function U.Menu(parent,width,caption)
 local b=U.Button(parent,width,caption)
 local popup=U.Panel(b);popup:SetFrameStrata("DIALOG");popup:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2);popup:SetWidth(math.max(width,330));popup:Hide()
 local list=U.List(popup);list:SetPoint("TOPLEFT",6,-6);list:SetPoint("BOTTOMRIGHT",-27,46)
 local page,render=1
 local prev=U.Button(popup,115,"Previous",function()page=page-1;render()end);prev:SetPoint("BOTTOMLEFT",6,5)
 local nextPage=U.Button(popup,115,"Next",function()page=page+1;render()end);nextPage:SetPoint("BOTTOMRIGHT",-6,5)
 b.options={}
 function b:SetOptions(options,value)
  self.options=options or {};self.value=value
  for _,d in ipairs(self.options)do if d.id==value then self.label:SetText(d.name);break end end
 end
 function b:SetOpenUp(value)
  popup:ClearAllPoints()
  if value then popup:SetPoint("BOTTOMLEFT",b,"TOPLEFT",0,2)else popup:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2)end
 end
 function b:Close()popup:Hide()end
 render=function()
  local pages=math.max(1,math.ceil(#b.options/4));page=math.max(1,math.min(page,pages))
  local visible={};for i=(page-1)*4+1,math.min(page*4,#b.options)do visible[#visible+1]=b.options[i]end
  popup:SetHeight(math.max(1,#visible)*62+52)
  list:SetData(visible,function(d)b.value=d.id;b.label:SetText(d.name);popup:Hide();if b.OnSelect then b.OnSelect(d.id,d)end end,b.value)
  prev:SetEnabled(page>1);nextPage:SetEnabled(page<pages);list:SetVerticalScroll(0)
 end
 b:SetScript("OnClick",function()
  if popup:IsShown()then popup:Hide();return end
  page=1;for i,d in ipairs(b.options)do if d.id==b.value then page=math.ceil(i/4);break end end
  render();popup:Show()
 end)
 b:HookScript("OnHide",function()popup:Hide()end)
 return b
end
function U.Message(parent)
 local t=U.Text(parent,13);t:SetPoint("BOTTOMLEFT",18,14);t:SetPoint("BOTTOMRIGHT",-18,14);return t
end
function U.Load(name)
 if InCombatLockdown()then return false,"Open this window after combat."end
 local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
 if loaded and loaded(name)then return true end
 local ok,reason=U.Call(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,name)
 if ok then return true end
 return false,"This client could not load "..name..(reason and " ("..tostring(reason)..")"or "").."."
end

function U.RedButton(parent,width,caption,handler)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width,50);b:SetText(caption);b.label=b:GetFontString();b.label:SetFont("Fonts\\FRIZQT__.TTF",17,"");b:SetScript("OnClick",handler);return b
end
