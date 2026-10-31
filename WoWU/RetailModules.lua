if not WoWUClient.isRetail then return end
local U=WoWUDungeonUI
function WoWU_OpenRetailShortcut(name)
 if not WoWUClient.isRetail then return false,"This module requires Retail."end
 if InCombatLockdown()then return false,"Open this window after combat."end
 if name=="Housing Dashboard"then
  local ok,reason=U.Load("Blizzard_HousingDashboard");if not ok then return false,reason end
  if not HousingDashboardFrame then return false,"Housing is not available on this client yet."end
  local opened,err=pcall(ShowUIPanel,HousingDashboardFrame);return opened,opened and "Housing Dashboard opened."or tostring(err)
 elseif name=="Shop"then
  if not ToggleStoreUI then local ok,reason=U.Load("Blizzard_StoreUI");if not ok then return false,reason end end
  if not ToggleStoreUI then return false,"The Shop is unavailable on this client."end
  local opened,err=pcall(ToggleStoreUI);return opened,opened and "Shop opened."or tostring(err)
 end
 return false,"Unknown Retail shortcut."
end
