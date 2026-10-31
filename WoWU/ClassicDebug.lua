-- On-demand read-only diagnostics; never changes game layouts or navigation.
SLASH_WOWUCLASSICDEBUG1='/wowuclassicdebug'
SlashCmdList.WOWUCLASSICDEBUG=function()
 local C,N,Q=WoWUClient,WoWUNavigation,WoWUQuestLog
 if not C or not C.isClassic then print('WoWU: this diagnostic is for Classic.');return end
 local map=C.Call(C_Map and C_Map.GetBestMapForUnit,'player')
 local w,h=N.MapWorldSize(map);local r=N.MinimapRadius()
 print('WoWU Classic: '..C.name..'; map '..tostring(map)..'; size '..tostring(w)..' x '..tostring(h)..'; minimap radius '..tostring(r))
 local entries=C.Call(Q.GetTrackedEntries)or {}
 print('Quest log entries: '..tostring(C.Call(Q.GetNumQuestLogEntries))..'; WoWU tracked quests: '..#entries)
 local target,reason=N.Destination()
 print('Compass: '..(target and(target.name or 'Destination')..' ('..math.floor(target.distance)..' yd)'or reason or 'No active destination'))
 local ok,points=pcall(WoWUExplorer.Points,map)
 print('Service/map points: '..(ok and #points or tostring(points)))
 if WoWUDB and WoWUDB.classicTrackerError then print('Tracker error: '..WoWUDB.classicTrackerError)end
 if WoWUDB and WoWUDB.mistsQuestMapError then print('Mists quest map: '..WoWUDB.mistsQuestMapError)end
 if WoWUDB and WoWUDB.mistsQuestBlobError then print('Mists quest area: '..WoWUDB.mistsQuestBlobError)end
 print('Classic automatic UI positioning: disabled; saved layouts are untouched.')
end
