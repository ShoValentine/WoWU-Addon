-- Companion viewport shared by Forever, Retail and Classic; connected sessions resume after loading.
-- Windows topology, window resizing, streaming and IPC are deliberately separate.
WoWUViewport={active=false}
local V=WoWUViewport
local saved,deadline,pendingRestore
local applyingScale=false
local function say(message) print("WoWU viewport: "..message) end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function snapshot(frame)
    local s={points={},scale=frame:GetScale(),shown=frame:IsShown()}
    for i=1,frame:GetNumPoints() do s.points[i]={frame:GetPoint(i)} end
    return s
end
local function restore(frame,s)
    frame:ClearAllPoints();frame:SetScale(s.scale)
    for _,p in ipairs(s.points) do frame:SetPoint(unpack(p)) end
end
function V.GetGameplayRect()
    if not V.active then return end
    local pw,ph=GetPhysicalScreenSize()
    local ux,uy=UIParent:GetWidth()/pw,UIParent:GetHeight()/ph
    return {left=0,bottom=800*uy,right=V.width*ux,top=(V.height+800)*uy}
end
-- Change the frame scale directly: the native uiScale CVar clamps low values.
local function migrateScaleDefault()
    if WoWUDB and not WoWUDB.companionAutoScaleRestored then
        WoWUDB.companionUIScale=nil
        WoWUDB.companionAutoScaleRestored=true
    end
end
function V.GetUIScale()
    migrateScaleDefault()
    if WoWUDB and WoWUDB.companionUIScale then return WoWUDB.companionUIScale end
    if saved then return saved.uiScale*V.height/(V.height+800) end
    return UIParent:GetScale()
end
function V.ApplyLayout()
    local actualW,actualH=GetPhysicalScreenSize()
    local ux,uy=UIParent:GetWidth()/actualW,UIParent:GetHeight()/actualH
        -- Physical pixels -> UIParent units -> receiving frame offset units.
        -- EffectiveScale alone omits the render-to-canvas conversion.
        local factor=UIParent:GetEffectiveScale()/WorldFrame:GetEffectiveScale()
        WorldFrame:ClearAllPoints()
        WorldFrame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,800*uy*factor)
        WorldFrame:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",V.width*ux*factor,(V.height+800)*uy*factor)
        local f=WoWU_MainFrame
        f:StopMovingOrSizing();f:SetScale(ux);f:ClearAllPoints()
        local ff=UIParent:GetEffectiveScale()/f:GetEffectiveScale()
        f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",V.x*ux*ff,0);f:Show()
end
function V.ApplyUIScale()
    applyingScale=true
    local ok,err=pcall(function()
        UIParent:SetScale(V.GetUIScale())
        V.ApplyLayout()
    end)
    applyingScale=false
    if not ok then error(err) end
end
function V.SetUIScale(value)
    migrateScaleDefault()
    if combat() then return false,"Change gameplay UI scale outside combat." end
    if value~=nil and (type(value)~="number" or value~=value or value<.2 or value>1) then
        return false,"Choose a scale between 20 and 100%."
    end
    local previous=WoWUDB.companionUIScale
    WoWUDB.companionUIScale=value
    if V.active then
        local ok,err=pcall(V.ApplyUIScale)
        if not ok then
            WoWUDB.companionUIScale=previous
            V.Restore()
            return false,"Could not apply gameplay scale: "..tostring(err)
        end
    end
    return true,V.active and "Gameplay scale applied." or "Saved for the next companion viewport session."
end
function V.Restore()
    if not saved then
        if WoWU_RestoreNativeMinimap and not (WoWUDB and (WoWUDB.companionSession or WoWUDB.companionBridgeTransition)) then WoWU_RestoreNativeMinimap() end
        return true,"Viewport is already off."
    end
    if combat() then pendingRestore=true;return false,"Restoration queued until combat ends." end
    local ok,err=pcall(function()
        if WoWUHUDDebug and not WoWUHUDDebug.Restore() then error("HUD positions could not be restored") end
        applyingScale=true
        UIParent:SetScale(saved.uiScale)
        applyingScale=false
        restore(WorldFrame,saved.world)
        restore(WoWU_MainFrame,saved.dashboard)
        WoWU_MainFrame:SetShown(saved.dashboard.shown)
    end)
    applyingScale=false
    if not ok then return false,"Could not restore: "..tostring(err)..". Use /reload outside combat." end
    V.active=false;V.reapplyPending=nil;saved=nil;deadline=nil;pendingRestore=nil
    if WoWU_RestoreNativeMinimap and not (WoWUDB and (WoWUDB.companionSession or WoWUDB.companionBridgeTransition)) then WoWU_RestoreNativeMinimap() end
    if WoWU_ApplyBlizzardVisibility then WoWU_ApplyBlizzardVisibility() end
    local layoutOK,layoutError=true,nil
    if WoWUCompanionLayouts then layoutOK,layoutError=pcall(WoWUCompanionLayouts.Restore) end
    if WoWUDB then WoWUDB.viewportPreviewDirty=nil end
    if not layoutOK then return false,"Viewport restored; layout recovery pending: "..tostring(layoutError) end
    return true,"Original viewport, WoWU placement and previous UI layout restored."
end
function V.Start(width,height,x)
    if combat() then return false,"Start the preview outside combat." end
    if not WoWUClient or not (WoWUClient.isForever or WoWUClient.isRetail or WoWUClient.isClassic) then return false,"Companion viewport requires Forever, Retail or Classic." end
    if not WoWU_MainFrame then return false,"Wait for WoWU to finish loading." end
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("Offhand") then return false,"Disable Offhand and reload before this proof of concept." end
    if V.active then return false,"Use /wowuviewport off before changing the preview geometry." end
    width,height=tonumber(width),tonumber(height)
    if not width or not height or width<1280 or height<600 or width>16384 or height>8192 or width%1~=0 or height%1~=0 then
        return false,"Use /wowuviewport preview GAMEPLAY_WIDTH GAMEPLAY_HEIGHT [VIRTUAL_LEFT]. Dimensions are physical pixels."
    end
    x=tonumber(x) or math.floor((width-1280)/2)
    if x<0 or x+1280>width or x%1~=0 then return false,"The 1280-pixel virtual display must fit beneath the gameplay display." end
    local actualW,actualH=GetPhysicalScreenSize()
    if math.abs(actualW-width)>2 or math.abs(actualH-height-800)>2 then
        return false,string.format("Current render area is %.0f x %.0f; expected %d x %d. Keep the existing Windows span; this addon cannot resize it.",actualW,actualH,width,height+800)
    end
    local ux,uy=UIParent:GetWidth()/actualW,UIParent:GetHeight()/actualH
    if ux<=0 or uy<=0 or math.abs(ux/uy-1)>.02 then
        return false,"UI canvas does not match the render aspect ratio. Reload, then send /wowuviewport status."
    end
    saved={world=snapshot(WorldFrame),dashboard=snapshot(WoWU_MainFrame),uiScale=UIParent:GetScale()}
    V.width,V.height,V.x=width,height,x
    local ok,err=pcall(function()
        V.ApplyUIScale()
    end)
    if not ok then V.Restore();return false,"Preview could not start: "..tostring(err) end
    V.active=true
    -- Acquire the minimap even when the saved WoWU page is Bags/More/etc.
    -- Its hidden Dashboard parent keeps it off the gameplay display.
    if WoWU_DashboardEnter then WoWU_DashboardEnter() end
    if WoWU_ApplyBlizzardVisibility then WoWU_ApplyBlizzardVisibility() end
    local layoutOK,layoutError=pcall(function() if WoWUCompanionLayouts then WoWUCompanionLayouts.Start() end end)
    if not layoutOK then say("Viewport active; layout conversion needs attention: "..tostring(layoutError)) end
    deadline=GetTime()+30
    WoWUDB.viewportPreviewDirty=true
    return true,"Preview active for 30 seconds. /wowuviewport keep retains it this session; /wowuviewport off restores immediately."
end
function V.Keep()
    if V.active and not pendingRestore then deadline=nil;return true end
    return false
end
SLASH_WOWUVIEWPORT1="/wowuviewport"
SlashCmdList.WOWUVIEWPORT=function(input)
    local command,w,h,x=input:match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    if command=="preview" then local _,message=V.Start(w,h,x~="" and x or nil);say(message)
    elseif command=="keep" then
        if V.active and not pendingRestore then deadline=nil;say("Kept for this session only. Reloading or logging out restores the viewport.") else say("No active preview to keep.") end
    elseif command=="off" then WoWUDB.companionSession=nil;WoWUDB.companionResumeSuppressed=true;local _,message=V.Restore();say(message)
    elseif command=="status" then
        local w,h=GetPhysicalScreenSize();say(string.format("%s; render area %.0f x %.0f; UI scale %.3f.",V.active and "Active" or "Off",w,h,UIParent:GetEffectiveScale()))
        if WoWUCompanionBridge and WoWUCompanionBridge.GetStatus then say(WoWUCompanionBridge.GetStatus()) end
        if WoWUCompanionLayouts and WoWUCompanionLayouts.GetStatus then say(WoWUCompanionLayouts.GetStatus()) end
        say(string.format("UI canvas %.1f x %.1f; world %.1f x %.1f (scale %.3f); WoWU scale %.3f.",UIParent:GetWidth(),UIParent:GetHeight(),WorldFrame:GetWidth(),WorldFrame:GetHeight(),WorldFrame:GetEffectiveScale(),WoWU_MainFrame and WoWU_MainFrame:GetScale() or 0))
    else say("/wowuviewport preview WIDTH HEIGHT [VIRTUAL_LEFT], keep, off, status. Uses an existing vertical span with a 1280 x 800 lower display.") end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_REGEN_ENABLED","PLAYER_LOGOUT","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED","CINEMATIC_START","PLAY_MOVIE","PLAYER_ENTERING_WORLD"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event)
    if applyingScale then return end
    -- UIParent scale notifications can arrive after SetScale returns.
    if event=="UI_SCALE_CHANGED" and V.active and math.abs(UIParent:GetScale()-V.GetUIScale())<.0001 then return end
    if event=="UI_SCALE_CHANGED"and V.active and WoWUDB and WoWUDB.companionSession then V.reapplyPending=true;return end
    if event=="DISPLAY_SIZE_CHANGED" and V.active then
        local w,h=GetPhysicalScreenSize()
        if math.abs(w-V.width)<=2 and math.abs(h-V.height-800)<=2 then return end
    end
    -- Zoning is not an instruction to leave companion mode. The bridge
    -- rechecks anchors once the world/loading screen has settled.
    if event=="PLAYER_ENTERING_WORLD"and V.active then return end
    if event=="PLAYER_ENTERING_WORLD"and WoWUDB and WoWUDB.companionSession then return end
    if event=="PLAYER_ENTERING_WORLD" and not V.active and WoWUDB and WoWUDB.viewportPreviewDirty and not combat() then
        -- A previous interrupted preview must never auto-activate on login.
        WorldFrame:ClearAllPoints();WorldFrame:SetAllPoints(UIParent);WoWUDB.viewportPreviewDirty=nil
        say("Recovered the full-window viewport after an interrupted preview.")
    elseif event=="PLAYER_REGEN_ENABLED" then
        if pendingRestore then local _,message=V.Restore();say(message) end
    elseif saved then
        local _,message=V.Restore()
        if event~="PLAYER_LOGOUT" then say(message) end
    end
end)
events:SetScript("OnUpdate",function()
    if deadline and GetTime()>=deadline then deadline=nil;local _,message=V.Restore();say(message) end
end)
