-- Retail talent routing and optional native loadout/PvP editor shortcut.
if not WoWUClient.isRetail then return end
local C=WoWUClient
function WoWU_OpenRetailTalents()
 if InCombatLockdown()then return false,"Open talents after combat."end
 local loader=C_AddOns and C_AddOns.LoadAddOn
 if not PlayerSpellsFrame then C.Call(loader,"Blizzard_PlayerSpells")end
 if not PlayerSpellsUtil or not PlayerSpellsUtil.OpenToClassTalentsTab then return false,"Talent window is not available yet."end
 local ok=pcall(PlayerSpellsUtil.OpenToClassTalentsTab)
 return ok,ok and ""or "The game could not open talents. Use the native talent button."
end
function WoWU_BuildTalents(panel)
 return WoWU_BuildRetailTalents(panel)
end
