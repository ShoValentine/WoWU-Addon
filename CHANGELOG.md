# Changelog

## Initial repository snapshot - WoWU 0.13.4 / Compass 0.4.5

This is the first addon-only source snapshot. There is no previous addon-repository commit to compare against.

Recent local development includes:

- Restored the independent player-following map as **Mini World Map**.
- Added **Main screen / WoWU** placement for the native minimap and its controls.
- Hide native minimap widgets from the dashboard picker while they are on the main screen.
- Release their grid space for other widgets; restore them without overlapping user placements, or keep them parked until room is available.
- Reorganised Settings with grouped categories and larger touch targets.
- Fixed corrupted punctuation and unsupported decorative characters in addon display text.
- Default **Lock WoWU window** to enabled for fresh settings, while respecting existing saved choices.

The snapshot also includes the existing addon modules, controller and companion-mode support, navigation data, assets, licences and isolated regression tests. The experimental native-minimap helper and Windows Assistant are not included.
