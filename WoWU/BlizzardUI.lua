-- Native window shortcuts and independently saved Blizzard HUD visibility.
local keys={micro="hideBlizzardMicroMenu",bags="hideBlizzardBags",xp="hideBlizzardXP",tracker="hideBlizzardQuestTracker"}
local function combat() return InCombatLockdown and InCombatLockdown() end
local function usable(frame) return frame and not (frame.IsForbidden and frame:IsForbidden()) end
local launching,blocked=nil,{}
local shortcuts={}
-- Delegate hardware clicks to Blizzard's existing buttons. Never execute the
-- native window function from our insecure OnClick handler.
function WoWU_AttachNativeShortcut(tile,name,feedback)
    local action=CreateFrame("Button",nil,tile,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    action:SetAllPoints(tile)
    action:RegisterForClicks("AnyDown","AnyUp")
    action:SetAttribute("useOnKeyDown",false)
    action:SetAttribute("_onstate-combat",[[
        self:SetAttribute("type1",newstate=="peace" and "click" or nil)
    ]])
    if RegisterStateDriver then RegisterStateDriver(action,"combat","[combat] combat; peace") end
    local record={button=action,name=name,feedback=feedback}
    shortcuts[#shortcuts+1]=record
    action:SetScript("PreClick",function() launching=name end)
    action:SetScript("PostClick",function(_,_,down)
        launching=nil
        if down then return end
        if combat() then feedback("Open "..name.." after combat.")
        elseif blocked[name] then
            feedback("Blizzard blocked "..name..". Details saved; use /wowudebug.")
            action:SetAttribute("clickbutton1",nil)
        elseif not record.target then feedback("Blizzard's "..name.." button is unavailable on this client.")
        else feedback("") end
    end)
    local function refresh()
        if combat() then return end
        local target=name=="Collections" and CollectionsMicroButton or name=="Social" and (FriendsMicroButton or QuickJoinToastButton)
        if not usable(target) or blocked[name] then target=nil end
        if target and target.HasAccessConstraints and target:HasAccessConstraints() then target=nil end
        if target and target.HasAnyForbiddenAspects and Enum and Enum.ForbiddenAspect and target:HasAnyForbiddenAspects(Enum.ForbiddenAspect.ScriptedInput) then target=nil end
        record.target=target
        action:SetAttribute("clickbutton1",target)
        action:SetAttribute("type1","click")
    end
    record.refresh=refresh
    refresh()
    return action
end
local function nativeCall(fn,...)
    -- Do not wrap the native entry point in an addon-defined closure: that
    -- would carry our execution context into Blizzard's panel/load handlers.
    if type(securecallfunction)~="function" then return false end
    return pcall(securecallfunction,fn,...)
end
local function loadUI(name,shortcut)
    local loader=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loader then
        launching=shortcut
        local ok,result=nativeCall(loader,name)
        launching=nil
        return ok and result and not blocked[shortcut]
    end
end
function WoWU_OpenBlizzardWindow(name)
    if name=="Social" or name=="Collections" then
        return false,"Use the "..name.." tile's native button shortcut."
    end
    if launching then return false,"A Blizzard window is already opening." end
    if combat() then return false,"Open "..name.." after combat." end
    if blocked[name] then return false,name.." was blocked. Restart WoW before trying this shortcut again." end
    local fn,args,globalName
    if name=="Currencies" then
        if not TokenFrame then loadUI("Blizzard_TokenUI",name) end
        fn=ToggleCharacter;args={"TokenFrame"};globalName="ToggleCharacter"
        if not TokenFrame then return false,"Currencies are unavailable on this client." end
    elseif name=="Legacy" then
        local constants=Constants and Constants.LegacyConsts
        if constants and C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel then
            local ok,level=pcall(C_MajorFactions.GetCurrentRenownLevel,constants.LEGACY_REWARD_TRACK_FACTION_ID)
            if ok and level and level<=0 then return false,"Legacy is not unlocked yet." end
        end
        if not LegacySystemFrame then loadUI("Blizzard_LegacySystem",name) end
        if not LegacySystemFrame then return false,"Legacy is unavailable on this client." end
        fn=function()
            if not LegacySystemFrame:IsShown() then ToggleLegacySystemUI() end
            if LegacySystemFrame:IsShown() and LegacySystemFrame.SelectPage then LegacySystemFrame:SelectPage(3) end
        end
        args={}
    end
    if blocked[name] then return false,"Blizzard blocked "..name..". Restart WoW before trying again." end
    if type(fn)~="function" then return false,name.." is unavailable on this client." end
    if globalName and issecurevariable and not issecurevariable(globalName) then
        blocked[name]=true
        return false,name.." has been modified by an addon. Restart WoW before using this shortcut."
    end
    launching=name
    local ok
    if globalName then ok=nativeCall(fn,unpack(args)) else ok=pcall(fn,unpack(args)) end
    launching=nil
    if blocked[name] then return false,"Blizzard blocked "..name..". Restart WoW before trying again." end
    if not ok then return false,"The game could not open "..name..". Try again after /reload." end
    return true
end

local driver=CreateFrame("Frame")
local records=setmetatable({},{__mode="k"})
local hooked=setmetatable({},{__mode="k"})
local pending,applying=false,false
function WoWU_IsBlizzardUIShown(key)
    -- Unconfigured Blizzard HUD groups are hidden. Explicit saved choices survive upgrades.
    if not keys[key] then return true end
    return WoWUDB and WoWUDB[keys[key]]==false or false
end
local function queue() if not applying then pending=true end end
local function track(frame,xp)
    if not usable(frame) then return end
    if not hooked[frame] then
        hooked[frame]=true
        frame:HookScript("OnShow",queue)
        if hooksecurefunc then
            if xp then
                -- The same container may change from XP to reputation or honor.
                for _,method in ipairs({"ApplyPendingBarToShow","UpdateShownState"}) do
                    if type(frame[method])=="function" then hooksecurefunc(frame,method,queue) end
                end
            end
        end
    end
    if not records[frame] then records[frame]={} end
    return records[frame]
end
local function setGroup(frame,hide)
    local record=track(frame,false)
    if not record then return end
    if hide then
        if frame:IsShown() then record.hidden=true;frame:Hide() end
    elseif record.hidden then
        record.hidden=nil
        frame:Show()
    end
end
-- Keep the tracker running beneath a hidden parent. Repeated native Show()
-- calls then remain invisible, rather than flashing until our queued Hide().
-- Do not unregister quest events or replace Blizzard's visibility methods.
local trackerRecords=setmetatable({},{__mode="k"})
local setTracker
setTracker=function(frame,hide,refreshTracker)
    if not usable(frame) then return end
    if combat() then pending=true;return end
    local record=trackerRecords[frame]
    if not record then
        record={refreshTracker=refreshTracker};trackerRecords[frame]=record
        record.host=CreateFrame("Frame",nil,UIParent)
        record.host:SetAllPoints(UIParent);record.host:Hide()
        local function keepHidden()
            if record.changing or not record.hidden then return end
            if combat() then pending=true;return end
            setTracker(frame,true,record.refreshTracker)
        end
        frame:HookScript("OnShow",keepHidden)
        if hooksecurefunc then hooksecurefunc(frame,"SetParent",keepHidden) end
    end
    if record.changing then return end
    if hide then
        local parent=frame:GetParent()
        record.hidden=true
        if parent~=record.host then
            record.parent=parent
            -- Preserve the original coordinate space and inherited scale.
            record.host:SetParent(parent or UIParent)
            record.host:ClearAllPoints();record.host:SetAllPoints(parent or UIParent)
            record.changing=true
            local ok,err=pcall(frame.SetParent,frame,record.host)
            record.changing=false
            if not ok then error(err) end
        end
    elseif record.hidden then
        record.changing=true
        local ok,err=pcall(frame.SetParent,frame,record.parent or UIParent)
        record.changing=false
        if not ok then error(err) end
        record.hidden=nil;record.parent=nil
        -- Native updates own whether an empty/collapsed tracker is shown.
        if record.refreshTracker and type(frame.Update)=="function" then frame:Update() end
    end
end
local function setXP(container,hide)
    local record=track(container,true)
    if not record then return end
    local enum=StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum
    local isXP=enum and container.shownBarIndex==enum.Experience
    if hide and isXP then
        if container:IsShown() then record.hidden=true;container:Hide() end
    elseif record.hidden then
        record.hidden=nil
        -- Keep the native parent and let Blizzard decide whether this container
        -- should exist at this level, including reputation/honor replacements.
        if container.UpdateShownState then container:UpdateShownState() end
    end
end
function WoWU_ApplyBlizzardVisibility()
    if not WoWUDB then return end
    if combat() then pending=true;return end
    applying=true;pending=false
    local ok=pcall(function()
        setGroup(MicroMenuContainer or MicroMenu,not WoWU_IsBlizzardUIShown("micro"))
        setGroup(BagsBar,not WoWU_IsBlizzardUIShown("bags"))
        local companion=WoWUViewport and WoWUViewport.active
        setTracker(ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame,companion and not WoWU_IsBlizzardUIShown("tracker"),true)
        local hideBars=WoWUController and WoWUController.active and not WoWUController.ShowActionBars()
        local classic=WoWUClient and WoWUClient.isClassic
        if classic and companion and WoWUClassicLayout and WoWUClassicLayout.PrepareUtilities then WoWUClassicLayout.PrepareUtilities()end
        -- Preserve native special vehicle/override controls. These are not
        -- ordinary hotbars, and may contain encounter-specific controls.
        -- Classic exposes MainActionBar for the buttons AND MainMenuBar for
        -- the artwork/micro controls. Hiding just the first leaves the gryphons.
        for _,name in ipairs({"MainActionBar","MainMenuBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarLeft","MultiBarRight","MultiBar5","MultiBar6","MultiBar7"}) do
            setTracker(_G[name],hideBars,false)
        end
        for _,name in ipairs({'StanceBar','StanceBarFrame','PetActionBar','PetActionBarFrame'})do setTracker(_G[name],hideBars and not classic,false)end
        local manager=StatusTrackingBarManager
        for _,container in ipairs(manager and manager.barContainers or {}) do
            setXP(container,not WoWU_IsBlizzardUIShown("xp"))
        end
    end)
    applying=false
    return ok
end
function WoWU_SetBlizzardUIShown(key,shown)
    if not keys[key] or not WoWUDB then return false,"Settings are not ready. Try /reload." end
    WoWUDB[keys[key]]=not shown
    if combat() then pending=true;return true,"Saved. Visibility will update after combat." end
    if not WoWU_ApplyBlizzardVisibility() then return false,"Saved. The game could not update visibility yet; try /reload." end
    return true,""
end
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_REGEN_ENABLED"}) do driver:RegisterEvent(event) end
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do driver:RegisterEvent(event) end
driver:SetScript("OnEvent",function(_,event,addon,operation)
    if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
        if addon=="WoWU" or addon=="WoWU_Forever" then
            if launching then blocked[launching]=true end
            if WoWUDB then WoWUDB.lastShortcutError={window=launching or "Unknown",event=event,action=tostring(operation or "Unknown")} end
        end
        return
    end
    for _,record in ipairs(shortcuts) do record.refresh() end
    queue()
end)
SLASH_WOWUDEBUG1="/wowudebug"
SlashCmdList=SlashCmdList or {}
SlashCmdList.WOWUDEBUG=function()
    local e=WoWUDB and WoWUDB.lastShortcutError
    print(e and ("WoWU: "..e.window.." | "..e.event.." | "..e.action) or "WoWU: no blocked action recorded this session.")
end
local visibilityElapsed=0
driver:SetScript("OnUpdate",function(_,elapsed)
    if not pending or combat() then return end
    visibilityElapsed=visibilityElapsed+(elapsed or 0)
    if visibilityElapsed<.2 then return end
    visibilityElapsed=0;WoWU_ApplyBlizzardVisibility()
end)
