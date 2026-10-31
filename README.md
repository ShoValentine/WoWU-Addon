<p align="center">
  <img src="https://raw.githubusercontent.com/ShoValentine/WoWU-Gamepad-Assistant/main/docs/assets/wowu-logo.png" alt="WoWU" width="600">
</p>

# Your adventure. Two screens. One WoWU.

Keep Azeroth on your main screen and put the interface at your fingertips. WoWU brings bags, quests, maps, spells and more to a touch-friendly companion screen, alongside controller controls and a customisable dashboard.

Built for players using a Steam Deck, Legion Go, ROG Ally, tablet or phone as a second screen through [Moonlight](https://moonlight-stream.org/). The game runs on your Windows PC; use the [WoWU Gamepad Assistant](https://github.com/ShoValentine/WoWU-Gamepad-Assistant) to manage the companion display and connection.

![WoWU in use on a handheld](https://raw.githubusercontent.com/ShoValentine/WoWU-Gamepad-Assistant/main/docs/screenshots/setup.jpg)

## In this repository

- **WoWU 0.13.4** - the addon, its modules, controller interface and dashboard.
- **WoWU Compass 0.4.5** - navigation on your gameplay screen.
- Source, required assets, third-party notices, tests and development instructions.

This is the addon repository. The Windows Assistant and installer are maintained separately.

## Highlights

- Move and resize dashboard widgets, with a separate Mini World Map.
- Choose whether the original minimap lives on your main screen or in WoWU.
- Browse inventory and compare equipment with readable item details.
- Use touch-friendly spellbooks, quests, professions, collections and NPC interactions.
- Assign controller actions independently of your usual hotbars.

## Client support

One addon uses client checks for Retail, Forever, Classic Era, TBC, Wrath, Cataclysm and Mists Classic. Features vary with each client's APIs. Not every feature is available or live-tested on every version.

## Install

Copy `WoWU` and `WoWU_Compass` into your client's `Interface/AddOns` folder. Use the [Assistant](https://github.com/ShoValentine/WoWU-Gamepad-Assistant/releases) for companion display setup and [Moonlight](https://moonlight-stream.org/) on the receiving device.

See [the changelog](CHANGELOG.md) for the current update.

## Development

Install Python and the test dependency, then run:

```sh
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
```

The test runner uses Lua 5.1 to compile source and run isolated frame/API simulations. These checks do not replace in-game testing.

Development stays local. The owner reviews and explicitly approves each repository update before it is committed or pushed. See [AGENTS.md](AGENTS.md).

## Licence and notices

Project code is licensed under [GPL-2.0](LICENSE). Bundled third-party code, data and artwork retain their own terms. Read the notices in the addon folders; the GPL does not relicense Blizzard artwork or trademarks.
