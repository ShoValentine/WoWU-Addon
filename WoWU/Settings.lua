-- Extra settings share the More page, with an optional companion API bridge.
local function label(parent,caption,size,x,y,width)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    text:SetFont("Fonts\\FRIZQT__.TTF",size,"");WoWU_Theme.TextColor(text,.94,.82,.57)
    text:SetJustifyH("LEFT");text:SetPoint("TOPLEFT",x,y);text:SetText(caption)
    if width then text:SetWidth(width);text:SetWordWrap(true) end
    return text
end

local function touchSlider(slider)
 slider:SetHitRectInsets(0,0,-12,-12)
 slider:SetThumbTexture(WoWU_Theme.assets.thumb)
 local thumb=slider:GetThumbTexture();if thumb then thumb:SetSize(40,44)end
end

function WoWU_CreateScaleControl(parent,name,caption,x,y,minimum,maximum,get,set,status)
    local title=label(parent,caption,18,x,y)
    local slider=CreateFrame("Slider",name.."Slider",parent,"OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL");slider:SetSize(430,36);slider:SetPoint("TOPLEFT",x,y-40)
    slider:SetHitRectInsets(0,0,-12,-12)
    slider:SetMinMaxValues(minimum,maximum);slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetThumbTexture(WoWU_Theme.assets.thumb)
    local thumb=slider:GetThumbTexture();if thumb then thumb:SetSize(40,44) end
    for _,suffix in ipairs({"Low","High","Text"}) do local text=_G[name.."Slider"..suffix];if text then text:SetText("") end end
    local input=CreateFrame("EditBox",name.."Input",parent,"InputBoxTemplate")
    input:SetSize(84,44);input:SetPoint("TOPLEFT",x+460,y-34)
    input:SetAutoFocus(false);input:SetFont("Fonts\\FRIZQT__.TTF",18,"");input:SetMaxLetters(5);input:SetJustifyH("CENTER")
    label(parent,"%",18,x+552,y-45)
    local syncing=false
    local function refresh()
        local value=get()
        syncing=true
        slider:SetValue(math.floor((value or 1)*100+.5))
        input:SetText(value and tostring(math.floor(value*100+.5)) or "")
        if slider.SetEnabled then slider:SetEnabled(value~=nil) end
        if input.SetEnabled then input:SetEnabled(value~=nil) end
        title:SetAlpha(value and 1 or .5)
        syncing=false
    end
    local function commit(value)
        if syncing then return end
        value=tonumber(value)
        if not value or value~=value or value<minimum or value>maximum then
            status:SetText("Enter a value from "..minimum.." to "..maximum.."%.")
            refresh();return
        end
        local ok,message=set(value/100)
        status:SetText(message or (ok and "" or "Setting unavailable."));refresh()
    end
    slider:SetScript("OnValueChanged",function(_,value)
        if syncing then return end
        input:SetText(tostring(math.floor(value+.5)))
        -- Applying WoWU scale during a held drag moves the slider under the finger.
        if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton") then commit(value) end
    end)
    slider:HookScript("OnMouseUp",function() commit(slider:GetValue()) end)
    input:SetScript("OnEnterPressed",function(self) commit(self:GetText());self:ClearFocus() end)
    input:SetScript("OnEscapePressed",function(self) self:ClearFocus();refresh() end)
    input:SetScript("OnEditFocusLost",function() refresh() end)
    return {Refresh=refresh,slider=slider,input=input,Commit=commit}
end

-- Shared saved presentation preferences. Existing gameplay options keep their own storage.
local defaults={availableWorld=true,dashboardXP=true,dashboardXPText=true,dashboardZone=true,dashboardHints=true,
 dashboardMoney=true,dashboardBags=true,dashboardDurability=true,popups=true,
 keyboardWidth=1,keyboardHeight=2/3,keyboardLetters=1,keyboardDrag=true,bagIconScale=1,minimapLocation="wowu"}
function WoWU_GetPreference(key)
 local prefs=WoWUDB and WoWUDB.preferences
 if prefs and prefs[key]~=nil then return prefs[key]end
 return defaults[key]
end
function WoWU_SetPreference(key,value)
 WoWUDB.preferences=WoWUDB.preferences or {};WoWUDB.preferences[key]=value
 if WoWU_RefreshDashboard then WoWU_RefreshDashboard()end
end
function WoWU_GetMinimapLocation()
 return WoWU_GetPreference("minimapLocation")=="main"and "main"or "wowu"
end
function WoWU_SetMinimapLocation(value)
 if value~="main"and value~="wowu"then return false,"Choose Main screen or WoWU."end
 if InCombatLockdown and InCombatLockdown()then return false,"Move the minimap after combat."end
 WoWU_SetPreference("minimapLocation",value)
 if WoWU_DashboardEnter then WoWU_DashboardEnter()end
 if WoWUDashboardLayout and WoWUDashboardLayout.Apply then WoWUDashboardLayout.Apply()end
 if value=="wowu"and WoWUDashboardLayout and WoWUDashboardLayout.minimapPlacementNotice then return true,WoWUDashboardLayout.minimapPlacementNotice end
 return true,value=="main"and "Minimap restored to your main screen. Mini World Map remains available in WoWU."or "Minimap moved to WoWU. Its saved widget positions are preserved."
end
function WoWU_BuildExtraSettings(detail,settingsFrames)
 local root=CreateFrame("Frame",nil,detail);root:SetPoint("TOPLEFT",18,-88);root:SetPoint("BOTTOMRIGHT",-18,18)
 settingsFrames[#settingsFrames+1]=root
 local nav=CreateFrame("Frame",nil,root,"BackdropTemplate");nav:SetPoint("TOPLEFT");nav:SetPoint("BOTTOMLEFT");nav:SetWidth(248);WoWU_Theme.Panel(nav,"inset",false)
 local area=CreateFrame("Frame",nil,root,"BackdropTemplate");area:SetPoint("TOPLEFT",nav,"TOPRIGHT",14,0);area:SetPoint("BOTTOMRIGHT");WoWU_Theme.Panel(area,"inset",false)
 local status=label(area,"",16,20,-1,760);status:ClearAllPoints();status:SetPoint("BOTTOMLEFT",20,12);status:SetPoint("BOTTOMRIGHT",-20,12);status:SetHeight(48)
 local sc=CreateFrame("ScrollFrame",nil,area,"UIPanelScrollFrameTemplate");sc:SetPoint("TOPLEFT",12,-12);sc:SetPoint("BOTTOMRIGHT",-32,70)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(sc)end
 local pages,buttons={},{};local selected="Companion Display";local serial=0
 local function button(parent,caption,x,y,w,fn,navButton)
  local b=CreateFrame("Button",nil,parent,navButton and "BackdropTemplate"or "UIPanelButtonTemplate,BackdropTemplate")
  b:SetPoint("TOPLEFT",x,y);b:SetSize(w,52)
  b.label=label(b,caption,17,0,0);b.label:ClearAllPoints();b.label:SetPoint("CENTER");b.label:SetWidth(w-20);b.label:SetWordWrap(true)
  if navButton then WoWU_Theme.Tab(b,false);WoWU_Theme.Button(b)end
  b:SetScript("OnClick",function(...)
   if not navButton and WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(sc)then return end
   return fn(...)
  end);return b
 end
 local function page(name,description)
  local p=CreateFrame("Frame",nil,sc);p:SetSize(790,1);p:Hide();p.y=12;p.refresh={};pages[name]=p
  label(p,name,23,12,-p.y);p.y=p.y+36
  label(p,description,16,12,-p.y,740);p.y=p.y+math.max(60,math.ceil(#description/82)*19+22)
  return p
 end
 local function check(p,caption,description,get,set)
  local y=p.y;local b=CreateFrame("CheckButton",nil,p,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",10,-y);b:SetSize(52,52)
  local heading=label(p,caption,19,72,-y-4,660)
  local headingHeight=math.max(24,heading.GetStringHeight and heading:GetStringHeight()or 24)
  local hint=label(p,description,15,72,-y-headingHeight-8,660)
  local hintHeight=math.max(20,hint.GetStringHeight and hint:GetStringHeight()or math.ceil(#description/80)*18)
  local height=math.max(82,headingHeight+hintHeight+32)
  b:SetHitRectInsets(0,-660,0,-math.max(0,height-58))
  local function refresh()local value=get();b:SetEnabled(value~=nil);b:SetChecked(value==true);b:SetAlpha(value==nil and .4 or 1)end
  b:SetScript("OnClick",function(self)if WoWU_TouchTapAllowed and not WoWU_TouchTapAllowed(sc)then refresh();return end;local _,message=set(self:GetChecked()==true);status:SetText(message or "Saved.");refresh()end)
  p.refresh[#p.refresh+1]=refresh;p.y=y+height
 end
 local function pref(p,key,caption,description)check(p,caption,description,function()return WoWU_GetPreference(key)end,function(v)WoWU_SetPreference(key,v);return true end)end
 local function slider(p,caption,minimum,maximum,get,set)
  serial=serial+1;local control=WoWU_CreateScaleControl(p,"WoWUCustomSetting"..serial,caption,16,-p.y,minimum,maximum,get,set,status)
  p.refresh[#p.refresh+1]=control.Refresh;p.y=p.y+120
 end
 local function action(p,caption,fn)
  button(p,caption,16,-p.y,520,function()local _,message=fn();status:SetText(message or "Done.")end);p.y=p.y+72
 end
 local bags=page("Bags","Choose the size of the inventory icons. The bag grid automatically fits as many columns as the available space allows.")
 slider(bags,"Bag icon size",60,160,function()return WoWU_GetPreference("bagIconScale")end,function(value)
  value=tonumber(value)
  if not value or value~=value then return false,"Enter an icon size from 60 to 160%." end
  value=math.max(.6,math.min(1.6,value))
  WoWU_SetPreference("bagIconScale",value)
  if WoWU_RefreshBags then WoWU_RefreshBags()end
  return true,"Bag icon size saved."
 end)
 action(bags,"Restore default icon size",function()
  WoWU_SetPreference("bagIconScale",1)
  if WoWU_RefreshBags then WoWU_RefreshBags()end
  for _,fn in ipairs(bags.refresh)do fn()end
  return true,"Default bag icon size restored."
 end)
 local companion=page("Companion Display","Adjust gameplay UI sizing on a spanned display. WoWU stays at 1280 x 800. Changes apply outside combat while the companion viewport is active.")
 action(companion,"Enable Gamepad Mode",WoWUCompanionBridge.PromptEnable)
 action(companion,"Disable Gamepad Mode",WoWUCompanionBridge.PromptDisable)
 check(companion,"Hide Gamepad Mode button","Use /wowu on and /wowu off instead of the floating button.",function()return WoWUDB.hideGamepadToggle==true end,function(value)
  WoWUDB.hideGamepadToggle=value;WoWUCompanionBridge.RefreshButton();return true
 end)
 check(companion,"Automatic gameplay UI scale","Compensate for the extra display height using your original UI scale.",function()WoWUViewport.GetUIScale();return WoWUDB.companionUIScale==nil end,function(enabled)
  if enabled then return WoWUViewport.SetUIScale(nil) end
  return WoWUViewport.SetUIScale(math.max(.2,math.min(1,WoWUViewport.GetUIScale())))
 end)
 slider(companion,"Gameplay UI scale (20-100%)",20,100,function()return WoWUViewport.GetUIScale()end,WoWUViewport.SetUIScale)
 action(companion,"Reset to automatic scaling",function()return WoWUViewport.SetUIScale(nil)end)
 label(companion,"Moving the slider selects a custom scale. This is separate from WoWU scale and can go below Blizzard's 65% limit. Your original gameplay UI scale is restored when the viewport closes. Scaling does not reposition individual UI elements.",14,16,-companion.y,710)
 companion.y=companion.y+100
 local controller=page("Controller","Forever-style controller controls with independent WoWU assignments. Your keyboard bindings and native hotbar contents are preserved. Forever continues using its own native controller system.")
 check(controller,"Enable controls with companion mode","Retail: activate WoWU's controller preset when the companion viewport opens, then restore the previous controller settings when it closes.",function()if WoWUClient.isForever then return nil end;return WoWUController.IsAutomatic()end,WoWUController.SetAutomatic)
 check(controller,"Show Blizzard action bars with controller","Keep the normal action bars visible alongside the controller HUD. Off by default; bars return when the overlay closes.",WoWUController.ShowActionBars,WoWUController.SetShowActionBars)
 check(controller,"Hold to Cast","Repeat eligible assigned spells while holding their controller button; release to stop repeating. Requires native client support and the spell on an existing action bar (hidden bars work). No hotbar changes. Macros/items do not repeat. Change outside combat.",WoWUController.HoldToCast,WoWUController.SetHoldToCast)
 check(controller,"Compact Layout","Show one eight-button pair plus LB/RB. Hold LT, RT or both to change its layer. Assignments are preserved. Change this outside combat.",WoWUControllerLayout.IsCompact,WoWUControllerLayout.SetCompact)
 action(controller,"Enter / leave controller edit mode",WoWUControllerLayout.ToggleEdit)
 check(controller,"Move eight-button cluster pairs","On: move a D-pad and face-button pair together. Off: move individual four-button diamonds. Positions and scales are saved in either mode.",WoWUControllerLayout.MovePairs,WoWUControllerLayout.SetMovePairs)
 slider(controller,"Overall controller HUD scale",50,150,WoWUControllerLayout.GetScale,WoWUControllerLayout.SetScale)
 slider(controller,"Selected cluster / pair scale",50,180,WoWUControllerLayout.SelectedScale,WoWUControllerLayout.SetSelectedScale)
 action(controller,"Reset controller positions & scales",WoWUControllerLayout.Reset)
 controller=page("Controller Help","Assignment help and advanced controls. Your existing bindings and hotbar contents are preserved.")
 label(controller,"Assign from the Spellbook or Bags: select an active spell or item, press + Pad, then hold the desired trigger and press a face button or D-pad direction. The popup shows the chosen ability and icon. Existing assignments on that pad slot are replaced; native hotbars are untouched.",16,16,-controller.y,710)
 controller.y=controller.y+100
 action(controller,"Advanced slot editor",WoWUController.OpenSetup)
 action(controller,"Restore Y to Inspect",WoWUController.RestoreInspectDefault)
 action(controller,"Enable controls without companion",function()return WoWUController.Start(true)end)
 action(controller,"Release controller controls",WoWUController.Disable)
 label(controller,"Four layers: no trigger, left trigger, right trigger, and both triggers. Each has a D-pad diamond and a face-button diamond. Assignments are saved separately for each character and specialization. Select a slot, then choose from learned spells, existing hotbar actions, or macros. The Hotbars list copies actions without moving them.\n\nDefaults: A jumps, B goes Back / cancels targeting / clears your target, X attacks, Y opens a controller-navigable target menu outside combat (native context menu in combat). Tap LB to target a friendly interaction NPC in front of you, or cycle friendly targets; hold LB and use D-pad to cycle your party/raid (including yourself). Tap RB to cycle enemies; hold RB and use X/Y for previous/next enemy. A keeps the chosen target; B clears it. Release the shoulder to return to normal controls. Trigger spell layers stay available while targeting. Left stick moves, right stick controls the camera. Stick clicks toggle auto-run and interact; Start opens the game menu. Hold View/Back + D-pad Up/Down to zoom the camera; View/Back + Y toggles the mouse cursor, with A/X for left/right click. B remains Back. Native windows no longer automatically enable joystick mouse mode. Ground-targeted spells start a dedicated aiming session: the right stick moves the cursor, A places the spell and B cancels. A and B temporarily emulate native left/right mouse clicks. The cursor starts at the gameplay screen center; camera controls return once the ring closes and the click is released. NPC choices use D-pad, A to choose and B to leave. Vehicle actions temporarily replace the controller slots; right-stick click exits the vehicle.\n\nUse /wowupad setup, on, off or status. Use /wowupad edit or Settings to move and scale clusters outside combat. Changes to assignments and controller mode wait until combat ends. ConsolePort must be disabled to use this preset.",16,16,-controller.y,710)
 controller.y=controller.y+740
 local clientPage=page("Game Version",WoWUClient.name.." - "..tostring(WoWUClient.version).." (interface "..tostring(WoWUClient.interface)..")")
 label(clientPage,WoWUClient.isRetail and "Retail: native talent editing and crafting; reagent bag support. Legacy and Forever map databases are disabled. Map markers use live client data and your observations." or WoWUClient.isClassic and "Classic: version-specific talents, professions, quest tracking and map data. Features follow the capabilities of this client."or "Forever: custom talent trees, Legacy, and curated quest/service locations are enabled.",16,16,-clientPage.y,740);clientPage.y=clientPage.y+140
 local appearance=page("Appearance","Choose a background and frame style independently. Save your choices, then Apply & Reload to refresh every module.")
 local function themeValue(key,fallback)return WoWUDB.preferences and WoWUDB.preferences[key]or fallback end
 local function chooseTheme(key,value)
  WoWUDB.preferences=WoWUDB.preferences or {};WoWUDB.preferences[key]=value
  for _,fn in ipairs(appearance.refresh)do fn()end
  return true,"Theme saved. Use Apply & Reload when ready."
 end
 local themeMenus={}
 local function themeDropdown(caption,key,fallback,choices)
  label(appearance,caption,18,16,-appearance.y,700);appearance.y=appearance.y+29
  local b=button(appearance,"",16,-appearance.y,430,function()end)
  local menu=CreateFrame("Frame",nil,appearance,"BackdropTemplate");menu:SetFrameLevel(b:GetFrameLevel()+20)
  menu:SetPoint("TOPLEFT",b,"BOTTOMLEFT",0,-2);menu:SetSize(430,#choices*54+12);WoWU_Theme.Panel(menu);menu:Hide()
  for i,choice in ipairs(choices)do
   local value,title=choice[1],choice[2]
   button(menu,title,7,-6-(i-1)*54,416,function()chooseTheme(key,value);menu:Hide();status:SetText("Theme saved. Use Apply & Reload when ready.")end):SetHeight(50)
  end
  themeMenus[#themeMenus+1]=menu
  b:SetScript("OnClick",function()local open=not menu:IsShown();for _,m in ipairs(themeMenus)do m:Hide()end;menu:SetShown(open)end)
  appearance:HookScript("OnHide",function()menu:Hide()end)
  appearance.refresh[#appearance.refresh+1]=function()
   local current=themeValue(key,fallback)
   for _,choice in ipairs(choices)do if choice[1]==current then b.label:SetText(choice[2].."  v");return end end
   b.label:SetText(choices[1][2].."  v")
  end
  appearance.y=appearance.y+80
 end
 themeDropdown("Background","surfaceTheme","stone",{
  {"stone","Dark stone"},{"parchment","Light parchment"},{"collections","Collections leather"},
  {"marble","Marble"},{"dialog","Blizzard dark leather"},{"plain","Plain charcoal"}})
 themeDropdown("Frame style","frameTheme","gold",{
  {"gold","Gilded gold"},{"silver","Gilded silver"},{"dialog","Blizzard dialog"},{"tooltip","Simple tooltip"}})
 action(appearance,"Apply & Reload",function()
  if InCombatLockdown()then return false,"Apply the theme after combat."end
  ReloadUI();return true
 end)
 appearance.y=math.max(appearance.y,470)
 local p=page("Window & Touch","Position, interface size and touch interaction.")
 check(p,"Lock WoWU window","Lock to swipe-scroll lists. Unlock to move the main window.",function()return WoWU_IsLocked()end,function(v)WoWU_SetLocked(v);return true end)
 slider(p,"WoWU scale",30,150,function()return WoWUDB.scale or .85 end,WoWU_SetScale)
 action(p,"Reset docked map position",function()return WoWU_ResetMapPosition()end)
 p=page("Dashboard","Choose the information shown on your home screen.")
 action(p,"Edit current Dashboard layout",function()
  if InCombatLockdown()then return false,"Edit the Dashboard after combat."end
  WoWU_ShowPage("Dashboard");WoWUDashboardLayout.Edit();return true
 end)
 do
  local y=p.y
  local caption=label(p,"Quick Access buttons (current Dashboard layout)",17,16,-y,700)
  label(p,"1-20 slots. Extra pins are preserved when you lower the limit.",12,16,-y-26,700)
  local control=CreateFrame("Slider","WoWUQuickAccessCapacity",p,"OptionsSliderTemplate")
  control:SetPoint("TOPLEFT",20,-y-62);control:SetSize(440,36)
  touchSlider(control);control:SetMinMaxValues(1,20);control:SetValueStep(1)
  if control.SetObeyStepOnDrag then control:SetObeyStepOnDrag(true)end
  for _,suffix in ipairs({"Text","Low","High"})do
   if _G["WoWUQuickAccessCapacity"..suffix]then _G["WoWUQuickAccessCapacity"..suffix]:SetText("")end
  end
  local input=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
  input:SetPoint("LEFT",control,"RIGHT",30,0);input:SetSize(80,44);input:SetAutoFocus(false);input:SetFont("Fonts\\FRIZQT__.TTF",18,"");input:SetMaxLetters(2)
  local syncing=false
  local function refreshCapacity()
   syncing=true
   local value=WoWUDashboardLayout.QuickLimit()
   control:SetValue(value);input:SetText(tostring(value))
   caption:SetText("Quick Access buttons - "..WoWUDashboardLayout.Profile().name)
   syncing=false
  end
  local function commit(value)
   local _,message=WoWUDashboardLayout.SetQuickLimit(value)
   status:SetText(message or "Saved.");refreshCapacity()
  end
  control:SetScript("OnValueChanged",function(_,value)
   if syncing then return end
   input:SetText(tostring(math.floor(value+.5)))
   if not IsMouseButtonDown("LeftButton")then commit(value)end
  end)
  control:HookScript("OnMouseUp",function()commit(control:GetValue())end)
  input:SetScript("OnEnterPressed",function(self)commit(self:GetText());self:ClearFocus()end)
  input:SetScript("OnEscapePressed",function(self)self:ClearFocus();refreshCapacity()end)
  p.refresh[#p.refresh+1]=refreshCapacity;p.y=y+112
 end
 pref(p,"dashboardXP","Show experience bar","Hide the bar without moving the surrounding panels.")
 pref(p,"dashboardXPText","Show experience numbers","Display level, percentage and current / maximum XP.")
 pref(p,"dashboardZone","Show zone name","Display your current zone inside the minimap.")
 pref(p,"dashboardHints","Show Quick Access hint","Display the reminder about pinning items and spells.")
 pref(p,"dashboardMoney","Show money","Include your gold, silver and copper in the footer.")
 pref(p,"dashboardBags","Show free bag space","Include remaining bag capacity in the footer.")
 pref(p,"dashboardDurability","Show durability","Include average equipment condition in the footer.")
 p=page("Minimap","Choose where the original game minimap lives during Gamepad Mode. Mini World Map is a separate player-following map and stays available in either location.")
 label(p,"Original minimap location",21,16,-p.y,710);p.y=p.y+40
 local locations={{"main","Main screen"},{"wowu","WoWU"}}
 for i,entry in ipairs(locations)do
  local value,caption=entry[1],entry[2]
  local b=button(p,caption,16+(i-1)*340,-p.y,324,function()
   local _,message=WoWU_SetMinimapLocation(value);status:SetText(message)
   for _,refresh in ipairs(pages.Minimap.refresh)do refresh()end
  end)
  b:SetHeight(60)
  p.refresh[#p.refresh+1]=function()b.label:SetText(caption..(WoWU_GetMinimapLocation()==value and " (selected)"or ""))end
 end
 p.y=p.y+84
 label(p,"Main screen restores the minimap, clock, tracking and attached controls to their original game positions. The Minimap and Minimap Controls widgets are hidden from the dashboard and widget picker.\n\nWoWU returns them to their saved dashboard positions. Layout data is kept when switching locations. Change this setting outside combat.",16,16,-p.y,710)
 p.y=p.y+160
 action(p,"Add or arrange Mini World Map",function()
  if InCombatLockdown()then return false,"Edit the dashboard after combat."end
  WoWU_ShowPage("Dashboard");WoWUDashboardLayout.Edit();return true,"Choose Add Widget, then Mini World Map."
 end)
 p=page("Keyboard","Size changes apply next time you open the keyboard. The Social log uses the remaining space.")
 slider(p,"Keyboard width",60,100,function()return WoWU_GetPreference("keyboardWidth")end,function(v)WoWU_SetPreference("keyboardWidth",v);return true end)
 slider(p,"Keyboard height",55,66,function()return math.min(.66,WoWU_GetPreference("keyboardHeight"))end,function(v)WoWU_SetPreference("keyboardHeight",v);return true end)
 slider(p,"Key lettering size",75,140,function()return WoWU_GetPreference("keyboardLetters")end,function(v)WoWU_SetPreference("keyboardLetters",v);return true end)
 pref(p,"keyboardDrag","Allow Dashboard keyboard dragging","Move it by its title bar. The Social keyboard stays docked.")
 p=page("Notifications","Urgent game requests remain until answered or expired. Other banners last eight seconds; the Adventure Log keeps your latest 100 notifications.")
 pref(p,"popups","Show Dashboard notification popup","Disable the popup while keeping the Adventurer hub available.")
 for _,e in ipairs({{"upgrades","Possible equipment upgrades"},{"trainer","Trainer reminders"},{"rares","Rare creature detections"},{"supplies","Bag space and durability"},{"mail","New mail notifications"},{"talents","Unspent talent points"},{"requests","Invites, queues, summons and ready checks"},{"auctions","Auction updates"},{"crafting","Crafting completion"},{"fishing","Fishing lure expiration"},{"calendar","Calendar event reminders"},{"sounds","Notification sounds (off by default)"},{"quietCombat","Quiet ordinary banners and sounds during combat"}})do
  local key=e[1];if key~="trainer"or not WoWUClient.isRetail then check(p,e[2],"Uses the same preference as the Adventurer hub.",function()return WoWUAdventure.GetOption(key)end,function(v)WoWUAdventure.SetOption(key,v);return true end)end
 end
 p=page("Navigation Trails","Direct guidance to your destination. Corpse navigation always takes priority while dead.")
 for _,e in ipairs({{"enabled","Enable ant trails"},{"worldmap","Trails on the world map"},{"minimap","Trails on the minimap"},{"backToMap","Show Back to Map shortcut"}})do
  local key=e[1];check(p,e[2],"Updates the existing navigation trail preference.",function()return WoWUNavigation.GetTrailSetting(key)end,function(v)WoWUNavigation.SetTrailSetting(key,v);return true end)
 end
 slider(p,"Trail opacity",20,100,function()return WoWUNavigation.GetTrailSetting("opacity")end,function(v)WoWUNavigation.SetTrailSetting("opacity",v);return true end)
 slider(p,"Trail dot size (100% = 5)",40,240,function()return WoWUNavigation.GetTrailSetting("size")/5 end,function(v)WoWUNavigation.SetTrailSetting("size",v*5);return true end)
 slider(p,"Trail spacing (100% = 20)",50,200,function()return WoWUNavigation.GetTrailSetting("spacing")/20 end,function(v)WoWUNavigation.SetTrailSetting("spacing",v*20);return true end)
 slider(p,"Trail speed (0% = still)",0,200,function()return WoWUNavigation.GetTrailSetting("speed")/40 end,function(v)WoWUNavigation.SetTrailSetting("speed",v*40);return true end)
 p=page("Map Markers","Shared filters for service and exploration locations. These also affect the locations offered to the compass.")
 pref(p,"availableWorld","Available quests (!) on world map","Show available quest offers supplied by your client as WoWU world-map markers.")
 check(p,"Available quests (!) on compass","Independent of the world-map toggle; compass visibility and distance limits still apply.",function()return WoWUCompassAPI and WoWUCompassAPI.Get("poiOffers")end,function(v)if WoWUCompassAPI then return WoWUCompassAPI.Set("poiOffers",v)end;return false,"Enable WoWU Compass, then /reload."end)

 for _,e in ipairs({{"inns","Inns"},{"mail","Mailboxes"},{"trainers","Trainers"},{"repairs","Repair services"},{"flights","Flight masters"},{"otherServices","Banks, vendors and other services"},{"bookmarks","Bookmarks"},{"rares","Rare locations"},{"treasures","Treasure locations"},{"pois","Other points of interest"}})do
  local key=e[1];check(p,e[2],"Show available locations from the existing map data.",function()return WoWUExplorer.IsEnabled(key)end,function(v)WoWUExplorer.SetEnabled(key,v);return true end)
 end
 p=page("Compass","Requires the WoWU Compass companion addon. Unavailable controls are dimmed.")
 local function cg(k)return WoWUCompassAPI and WoWUCompassAPI.Get(k)end
 local function cs(k,v)if WoWUCompassAPI then return WoWUCompassAPI.Set(k,v)end;return false,"Enable WoWU Compass, then /reload."end
 for _,e in ipairs({{"enabled","Show compass"},{"locked","Lock compass position"},{"showDistance","Show destination distance"},{"showNames","Show marker names"},{"navigationOnly","Navigation target only"},{"groupMarkers","Group overlapping markers"},{"fadeDistant","Fade distant markers"},{"showDestination","Show navigation destination"},{"showPOIs","Show point-of-interest icons"},{"poiQuests","Quest objectives"},{"poiOffers","Available quests (!)"},{"poiTurnins","Quest turn-ins"},{"poiInns","Inns"},{"poiMail","Mailboxes"},{"poiTrainers","Trainers"},{"poiRepairs","Repair services"},{"poiFlights","Flight masters"},{"poiRares","Rare locations"},{"poiBookmarks","Bookmarks"},{"poiOther","Other locations"}})do
  if e[1]=="poiQuests"then p=page("Compass Markers","Choose which locations appear on the compass. Map marker filters are managed separately.")end
  local key=e[1];check(p,e[2],"Applies to the compass on your main screen.",function()return cg(key)end,function(v)return cs(key,v)end)
 end
 p=pages["Compass"]
 slider(p,"Compass scale",50,200,function()return cg("scale")end,function(v)return cs("scale",v)end)
 local function compassNumber(key,caption,minimum,maximum,step)
  serial=serial+1;local name="WoWUCompassNumber"..serial;local y=p.y
  label(p,caption,18,16,-y)
  local control=CreateFrame("Slider",name,p,"OptionsSliderTemplate");control:SetPoint("TOPLEFT",16,-y-38);control:SetSize(430,36);touchSlider(control);control:SetMinMaxValues(minimum,maximum);control:SetValueStep(step)
  if control.SetObeyStepOnDrag then control:SetObeyStepOnDrag(true)end
  for _,suffix in ipairs({"Low","High","Text"})do if _G[name..suffix]then _G[name..suffix]:SetText("")end end
  local input=CreateFrame("EditBox",nil,p,"InputBoxTemplate");input:SetPoint("TOPLEFT",482,-y-32);input:SetSize(100,44);input:SetAutoFocus(false);input:SetFont("Fonts\\FRIZQT__.TTF",18,"");input:SetMaxLetters(5);input:SetJustifyH("CENTER")
  local syncing=false
  local function refresh()
   local v=cg(key);syncing=true;control:SetEnabled(v~=nil);input:SetEnabled(v~=nil);control:SetValue(v or minimum);input:SetText(v and tostring(math.floor(v+.5))or "");syncing=false
  end
  local function commit(v)
   v=tonumber(v);if not v or v~=v or v<minimum or v>maximum then status:SetText("Enter a value from "..minimum.." to "..maximum..".");refresh();return end
   local _,message=cs(key,v);status:SetText(message or "Saved.");refresh()
  end
  control:SetScript("OnValueChanged",function(_,v)if syncing then return end;input:SetText(tostring(math.floor(v+.5)));if not IsMouseButtonDown("LeftButton")then commit(v)end end)
  control:HookScript("OnMouseUp",function()commit(control:GetValue())end)
  input:SetScript("OnEnterPressed",function(self)commit(self:GetText());self:ClearFocus()end)
  input:SetScript("OnEscapePressed",function(self)self:ClearFocus();refresh()end)
  input:SetScript("OnEditFocusLost",refresh)
  p.refresh[#p.refresh+1]=refresh;p.y=p.y+120
 end
 compassNumber("iconSize","Marker size (UI pixels)",16,36,1)
 compassNumber("poiRange","POI visibility distance (yards)",100,5000,100)
 compassNumber("width","Compass width (UI pixels)",320,900,20)
 slider(p,"Compass opacity",20,100,function()return cg("opacity")end,function(v)return cs("opacity",v)end)

 p=page("Blizzard UI","Tick to hide Blizzard controls. Hidden by default; combat changes apply when combat ends.")
 for _,e in ipairs({{"micro","Hide Blizzard micro menu"},{"bags","Hide Blizzard bag buttons"},{"xp","Hide Blizzard experience bar"},{"tracker","Hide Blizzard Quest Tracker"}})do
  local key=e[1];check(p,key=="tracker"and "Hide Blizzard Quest Tracker in Gamepad Mode"or e[2],key=="tracker"and "The tracker returns when Gamepad Mode is off."or "Independent of the WoWU controls.",function()return not WoWU_IsBlizzardUIShown(key)end,function(v)return WoWU_SetBlizzardUIShown(key,not v)end)
 end
 p=page("Top Tabs","Drag a tab onto another slot to reorder it. Drag a module from below onto a slot to add it. You can also tap a module, then tap its destination.")
 local tabPage=p
 local choices=WoWUClient.FilterModules({"Bags","Character","Quests","Map","Spells","Professions","Achievements","Social","Talents","Legacy","Settings","Adventure","Collections","Adventure Guide","Dungeon Finder","Housing Dashboard","Shop"})
 local slots,library={},{};local picked,gesture;local refreshTabs
 local ghost=CreateFrame("Frame",nil,root,"BackdropTemplate");ghost:SetSize(170,46);ghost:SetFrameStrata("TOOLTIP");ghost:EnableMouse(false);WoWU_Theme.Panel(ghost,"inset",false)
 local ghostText=label(ghost,"",16,10,-14,150);ghost:Hide()
 local function hit(f,x,y)
  if not f:IsVisible()then return false end
  local scale=f:GetEffectiveScale();x=x/scale;y=y/scale
  return f:GetLeft()and x>=f:GetLeft()and x<=f:GetRight()and y>=f:GetBottom()and y<=f:GetTop()
 end
 local function cancel()
  gesture=nil;ghost:Hide();sc.WoWUSuspendTouch=nil
 end
 local function assign(name,destination)
  if InCombatLockdown()then status:SetText("Change top tabs after combat.");return end
  WoWU_RefreshTopTabs()
  local list=WoWUDB.topTabs;local source
  for i,v in ipairs(list)do if v==name then source=i;break end end
  if source then table.remove(list,source);table.insert(list,destination,name)else list[destination]=name end
  picked=nil;WoWU_RefreshTopTabs();refreshTabs();status:SetText("Top tabs saved.")
 end
 local function wire(b,getName,destination)
  b:SetScript("OnMouseDown",function(self,mouse)
   if mouse~="LeftButton"then return end
   if InCombatLockdown()then status:SetText("Change top tabs after combat.");return end
   local x,y=GetCursorPosition();gesture={name=getName(),x=x,y=y,destination=destination};sc.WoWUSuspendTouch=true
   if sc.WoWUGesture then sc.WoWUGesture.motion:Stop();sc.WoWUGesture.down=false end
  end)
  b:SetScript("OnClick",nil)
 end
 label(p,"YOUR TOP BAR",14,16,-p.y);p.y=p.y+28
 local start=p.y
 local fixed=button(p,"Dashboard",12,-start,104,function()end);fixed:SetHeight(62);fixed:Disable();fixed.label:SetFont("Fonts\\FRIZQT__.TTF",14,"")
 label(p,"Fixed",12,44,-start-59)
 for i=1,5 do
  local slot=i;local card=button(p,"",12+i*108,-start,104,function()end);card:SetHeight(62);card.label:SetFont("Fonts\\FRIZQT__.TTF",14,"");slots[i]=card
  wire(card,function()return WoWUDB.topTabs[slot]end,slot)
  label(p,tostring(i+1),12,57+i*108,-start-59)
 end
 fixed=button(p,"More",12+6*108,-start,104,function()end);fixed:SetHeight(62);fixed:Disable();fixed.label:SetFont("Fonts\\FRIZQT__.TTF",14,"");label(p,"Fixed",12,44+6*108,-start-59)
 p.y=start+102;label(p,"AVAILABLE MODULES",14,16,-p.y);p.y=p.y+28
 for i,name in ipairs(choices)do
  local card=button(p,name,16+((i-1)%4)*188,-p.y-math.floor((i-1)/4)*58,178,function()end);card:SetHeight(48);library[name]=card
  wire(card,function()return name end)
 end
 p.y=p.y+math.ceil(#choices/4)*58+14
 refreshTabs=function()
  WoWU_RefreshTopTabs()
  for i,card in ipairs(slots)do card.label:SetText(WoWUDB.topTabs[i]);WoWU_Theme.Tab(card,picked==WoWUDB.topTabs[i])end
  for name,card in pairs(library)do
   local active=false;for _,v in ipairs(WoWUDB.topTabs)do if v==name then active=true end end
   WoWU_Theme.Tab(card,picked==name);card:SetAlpha(active and .65 or 1)
  end
 end
 p.refresh[#p.refresh+1]=refreshTabs
 p:SetScript("OnUpdate",function()
  if not gesture then return end
  if InCombatLockdown()then cancel();refreshTabs();return end
  local x,y=GetCursorPosition();local scale=root:GetEffectiveScale()
  if (x-gesture.x)^2+(y-gesture.y)^2>(9*scale)^2 then gesture.dragging=true end
  local destination
  if hit(sc,x,y)then for i,card in ipairs(slots)do if hit(card,x,y)then destination=i;break end end end
  if gesture.dragging then
   ghost:ClearAllPoints();ghost:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/ghost:GetEffectiveScale()+12,y/ghost:GetEffectiveScale()+18);ghostText:SetText(gesture.name);ghost:Show()
   for i,card in ipairs(slots)do WoWU_Theme.Tab(card,i==destination)end
  end
  if not IsMouseButtonDown("LeftButton")then
   local g=gesture;cancel()
   if g.dragging then
    if destination then assign(g.name,destination)else refreshTabs();status:SetText("Drop onto one of the five middle slots. No changes made.")end
   elseif g.destination and picked then assign(picked,g.destination)
   else picked=g.name;refreshTabs();status:SetText(picked.." selected. Tap a middle slot to place it.")end
  end
 end)
 p:HookScript("OnHide",function()cancel();picked=nil end)
 action(p,"Restore default top tabs",function()if InCombatLockdown()then return false,"Change tabs after combat."end;cancel();picked=nil;WoWUDB.topTabs=nil;refreshTabs();return true,"Default top tabs restored."end)
 p=page("Quality of Life","Optional conveniences. Automatic looting, selling and repairs start disabled. Junk protection is always respected by WoWU.")
 local qol=WoWUQoL
 for _,entry in ipairs({
  {"fastLoot","Faster auto-loot","Uses your normal auto-loot setting and modifier key. Keeps confirmations and blocked loot visible."},
  {"floatingLoot","Floating loot text","Brief pickup text beside your character on the main screen. Independent of faster looting."},
  {"autoSell","Auto-sell grey junk","Sells eligible, unprotected grey items at merchants. Protect items in Bags before enabling."},
  {"autoRepair","Auto-repair","Repair at suitable merchants using personal funds unless guild repairs are enabled below."},
  {"guildRepair","Prefer guild repair funds","Uses permitted guild funds when sufficient; falls back to personal funds."},
  {"openMail","Mailbox Open All button","Adds a large Open All / Stop control beside the mailbox. Skips COD and GM mail; never deletes messages."},
  {"bagWarning","Inventory full warning","Uses the existing Dashboard popup. Tap it to open Bags. Specialised bag slots are treated separately."},
  {"camera","Extended camera distance","Changes the permitted zoom limit only; zoom out normally. Disabling restores the previous value if unchanged elsewhere."}
 })do
  local key=entry[1]
  check(p,entry[2],entry[3],function()return qol.Get(key)end,function(v)return qol.Set(key,v)end)
 end
 local function numberSetting(key,caption,minimum,maximum,step)
  local y=p.y
  label(p,caption,17,16,-y,700)
  serial=serial+1;local name="WoWUQoLNumber"..serial
  local control=CreateFrame("Slider",name,p,"OptionsSliderTemplate")
  control:SetPoint("TOPLEFT",20,-y-40);control:SetSize(440,36);touchSlider(control);control:SetMinMaxValues(minimum,maximum);control:SetValueStep(step)
  if control.SetObeyStepOnDrag then control:SetObeyStepOnDrag(true)end
  for _,suffix in ipairs({"Text","Low","High"})do if _G[name..suffix]then _G[name..suffix]:SetText("")end end
  local input=CreateFrame("EditBox",nil,p,"InputBoxTemplate");input:SetPoint("LEFT",control,"RIGHT",30,0);input:SetSize(100,44);input:SetAutoFocus(false);input:SetFont("Fonts\\FRIZQT__.TTF",18,"");input:SetMaxLetters(8)
  local syncing=false
  local function refresh()
   syncing=true;local value=qol.Get(key);control:SetValue(value);input:SetText(tostring(value));syncing=false
  end
  local function commit(value)
   value=tonumber(value)
   if not value then status:SetText("Enter a number.");refresh();return end
   value=math.floor(value/step+.5)*step;value=tonumber(string.format("%.2f",value))
   local _,message=qol.Set(key,value);status:SetText(message or "Saved.");refresh()
  end
  control:SetScript("OnValueChanged",function(_,value)
   if syncing then return end
   input:SetText(string.format(step<1 and "%.1f"or "%.0f",value))
   if not IsMouseButtonDown("LeftButton")then commit(value)end
  end)
  control:HookScript("OnMouseUp",function()commit(control:GetValue())end)
  input:SetScript("OnEnterPressed",function(self)commit(self:GetText());self:ClearFocus()end)
  input:SetScript("OnEscapePressed",function(self)self:ClearFocus();refresh()end)
  p.refresh[#p.refresh+1]=refresh;p.y=y+90
 end
 numberSetting("cameraFactor","Camera zoom limit multiplier (client limits apply)",1,2.6,.1)
 numberSetting("lootDuration","Floating loot duration (seconds)",1,10,.1)
 numberSetting("lootScale","Floating loot text size multiplier",.7,1.6,.1)
 numberSetting("lootX","Floating loot horizontal offset (right is positive)",-800,800,10)
 numberSetting("lootY","Floating loot vertical offset (up is positive)",-500,500,10)
 label(p,"Junk Protection: select an item in Bags, then tap Protect Item. A shield marks protected items. Remove Protection reverses it. Protection covers every copy of that item and only governs WoWU's automatic selling.",14,16,-p.y,730)
 p.y=p.y+90
 p=page("Dungeon Hub","A temporary Dashboard for five-player dungeons. Your three saved layouts are preserved. Role and layout changes wait until combat ends.")
 local dungeon=WoWUDungeonHub
 label(p,"On entering a dungeon",18,16,-p.y);p.y=p.y+32
 local modes={{"auto","Automatically open"},{"ask","Ask me first"},{"off","Disabled"}}
 for i,entry in ipairs(modes)do
  local b=button(p,entry[2],16+(i-1)*228,-p.y,218,function()
   local _,message=dungeon.Set("activation",entry[1]);status:SetText(message)
   for _,refresh in ipairs(pages["Dungeon Hub"].refresh)do refresh()end
  end)
  p.refresh[#p.refresh+1]=function()WoWU_Theme.Tab(b,(dungeon.Get("activation")or "auto")==entry[1])end
 end
 p.y=p.y+62;label(p,"Preferred role for this character",18,16,-p.y);p.y=p.y+32
 for i,entry in ipairs({{"AUTO","Use group role"},{"TANK","Tank"},{"HEALER","Healer"},{"DPS","DPS"}})do
  local b=button(p,entry[2],16+(i-1)*171,-p.y,161,function()
   local _,message=dungeon.Set("role",entry[1]);status:SetText(message)
   for _,refresh in ipairs(pages["Dungeon Hub"].refresh)do refresh()end
  end)
  p.refresh[#p.refresh+1]=function()WoWU_Theme.Tab(b,dungeon.Get("role")==entry[1])end
 end
 p.y=p.y+62
 label(p,"Healer spell palette (optional)",18,16,-p.y);p.y=p.y+30
 label(p,"Leave blank for your class defaults, including healing, cleansing and resurrection spells. To customise, enter up to 12 learned spell IDs separated by commas. The selected spell remains active until you choose another.",13,16,-p.y,710);p.y=p.y+64
 local spellInput=CreateFrame("EditBox",nil,p,"InputBoxTemplate");spellInput:SetSize(480,44);spellInput:SetPoint("TOPLEFT",22,-p.y);spellInput:SetAutoFocus(false);spellInput:SetFont("Fonts\\FRIZQT__.TTF",18,"");spellInput:SetMaxLetters(160)
 local function saveSpells()
  local value=spellInput:GetText();local count=0
  for _ in value:gmatch("%d+")do count=count+1 end
  if value:find("[^%d,%s]")or count>12 then status:SetText("Use up to 12 numeric spell IDs, separated by commas.");return end
  local _,message=dungeon.Set("spells",value);status:SetText(message);spellInput:ClearFocus()
 end
 button(p,"Save spells",520,-p.y,165,saveSpells)
 spellInput:SetScript("OnEnterPressed",saveSpells);spellInput:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
 p.refresh[#p.refresh+1]=function()if not spellInput:HasFocus()then spellInput:SetText(dungeon.Get("spells"))end end
 p.y=p.y+64
 label(p,"Healer: select a spell once, then tap party members to cast it. Selection uses Blizzard's secure click handlers, including in combat. Right-click targets a member.\n\nTank: the minimap, party health, observed enemies and defensive controls. Threat coverage is limited to your target and visible nameplates.\n\nDPS: the client's current combat session, with damage, interrupts, damage taken and deaths. Live values use the native meter; unavailable or restricted information is never guessed.\n\nNormal Dashboard returns to your layout for the rest of the visit. Use /wowudungeon to reopen the Hub in a dungeon.",14,16,-p.y,710)
 p.y=p.y+260
 action(p,"Open Dungeon Hub",dungeon.Open)
 local groups={
  {"GAMEPAD & DISPLAY",{"Companion Display","Controller","Controller Help","Minimap"}},
  {"INTERFACE",{"Dashboard","Appearance","Window & Touch","Top Tabs","Bags","Keyboard","Blizzard UI"}},
  {"MAP & NAVIGATION",{"Map Markers","Navigation Trails","Compass","Compass Markers"}},
  {"ACTIVITIES & ALERTS",{"Dungeon Hub","Notifications","Quality of Life"}},
  {"ABOUT",{"Game Version"}},
 }
 local function show(name)
  selected=name;for _,page in pairs(pages)do page:Hide()end
  local page=pages[name];page:SetHeight(page.y+20);page:SetWidth(math.max(790,sc:GetWidth()));sc:SetScrollChild(page);page:Show();sc:SetVerticalScroll(0)
  for _,fn in ipairs(page.refresh)do fn()end
  for k,b in pairs(buttons)do WoWU_Theme.Tab(b,k==name)end;status:SetText("")
 end
 local navScroll=CreateFrame("ScrollFrame",nil,nav,"UIPanelScrollFrameTemplate")
 navScroll:SetPoint("TOPLEFT",7,-8);navScroll:SetPoint("BOTTOMRIGHT",-27,8)
 local navBody=CreateFrame("Frame",nil,navScroll);navBody:SetWidth(208);navScroll:SetScrollChild(navBody)
 if WoWU_EnableTouchScroll then WoWU_EnableTouchScroll(navScroll)end
 local navY=4
 for _,group in ipairs(groups)do
  label(navBody,group[1],13,6,-navY,200);navY=navY+28
  for _,name in ipairs(group[2])do
   buttons[name]=button(navBody,name,3,-navY,205,function()if not WoWU_TouchTapAllowed or WoWU_TouchTapAllowed(navScroll)then show(name)end end,true)
   navY=navY+58
  end
  navY=navY+18
 end
 navBody:SetHeight(navY)
 root:SetScript("OnShow",function()show(selected)end);root:Hide()
end
