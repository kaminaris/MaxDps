# Copilot Instructions for MaxDps

## Build, Test, and Lint Commands
- This repository is a World of Warcraft addon written in Lua. It does **not** use standard build, test, or lint commands. To test changes, copy the addon folder into your WoW `_retail_` or `_classic_` AddOns directory and reload the UI in-game (`/reload`).
- There are no automated tests; all testing is manual in-game.

## High-Level Architecture
- **Core.lua** initializes the addon using Ace3 libraries and sets up the main MaxDps object.
- **Modules/** contains feature modules (e.g., Window, Profiler, Custom, SpellIDToolTip) that extend MaxDps via Ace3's module system.
- **MaxDps_<Class>/** folders (e.g., MaxDps_Priest) contain class-specific logic and specializations, each with their own rotation logic (e.g., Shadow.lua, Holy.lua, Discipline.lua).
- **SpellData.lua, spell_durations.lua, Cooldowns.lua** provide spell and cooldown data, with logic to support multiple WoW versions (Retail, Classic, etc.).
- **Buttons.lua** manages action bar overlays and spell highlighting for supported action bar addons.
- **Libs/** contains embedded libraries (e.g., ForAllIndentsAndPurposes for indentation support).

## Key Conventions
- All modules are registered using Ace3's `:NewModule` pattern.
- Class and specialization logic is separated by folder and file (e.g., `MaxDps_Priest/Specialization/Shadow.lua`).
- WoW version detection is handled via `WOW_PROJECT_ID` and expansion constants in most core/data files.
- Action bar support is abstracted via LibActionButton and compatible libraries; new bars can be supported by extending the LABs table in Buttons.lua.
- Debug and tooltip features are toggled via the `MaxDpsOptions.global.debugMode` flag.

---

If you need to add new class support, create a new `MaxDps_<Class>` folder and follow the structure in `MaxDps_Priest`.

If you want to add new action bar support, extend the LABs table in `Buttons.lua`.

---

No MCP servers are relevant for this project type.
