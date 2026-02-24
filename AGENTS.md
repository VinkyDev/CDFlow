## Project Overview

CDFlow is a World of Warcraft addon (Lua) that customizes WoW's built-in Cooldown Manager — icon styles, layouts, highlights, and text displays for cooldowns and buffs. Targets WoW Interface 12000+.

## Development

There is no build, lint, or test pipeline. This is a runtime-interpreted Lua addon loaded directly by the WoW client.

To test changes, copy the addon folder to `World of Warcraft\_retail_\Interface\AddOns\CDFlow` and reload the UI in-game with `/reload`. The in-game settings panel is opened with `/cdf`.

## WoW 12.0 API Restrictions

WoW 12.0 massively restricted addon APIs. Many combat-related return values are now "secret values" (`issecretvalue()` returns `true`) — addons cannot read raw numbers for buff stacks, spell charges, cooldown durations, etc. Legacy addons like WeakAuras can no longer function the traditional way.

Key new APIs: `C_CooldownViewer` for CDM data access, `DurationObject` for cooldown/charge durations (`C_Spell.GetSpellCooldownDuration` / `C_Spell.GetSpellChargeDuration`).

**Always use 12.0+ APIs. For combat data, refer to the MonitorBars secret-value pattern (see end of file).**

## Architecture

Modules loaded in order via `CDFlow.toc` (after `Libs/libs.xml`):

### Core/
- `Core/Defaults.lua` — default config schema + `DeepCopy` utility
- `Core/Serializer.lua` — Base64 encode/decode, Lua serialization, config import/export
- `Core/Migration.lua` — old data migration logic, exports `ns.MigrateOldData`
- `Core/Config.lua` — AceDB-3.0 initialization, `CDFlowDB` SavedVariables management

### Style/
- `Style/Icon.lua` — creates `ns.Style`; icon sizing/cropping, border, mask replacement; shared font resolver `ns.ResolveFontPath`
- `Style/Glow.lua` — skill activation highlight + buff glow effects via LibCustomGlow
- `Style/Keybind.lua` — keybind text display, action bar binding map, spell ID lookup
- `Style/Text.lua` — stack count font styling + cooldown countdown text styling

### Layout
- `Layout.lua` — multi-row layout engine for Essential/Utility viewers; single-row/column for Buff icons; tracked bars direction

### MonitorBars/
- `MonitorBars/Scanner.lua` — creates `ns.MonitorBars`; CDM viewer scan (spellID↔cooldownID mapping), spell catalog; exposes `ns.cdmSuppressedCooldownIDs`
- `MonitorBars/Bars.lua` — bar frame creation/styling, stack/charge/cooldown update logic, secret-value detection, OnUpdate loop, event handlers

### Init
- `Init.lua` — addon entry point, event orchestration, hooks into WoW's native cooldown viewers, debounced refresh; calls MonitorBars event hooks

### UI/
- `UI/Widgets.lua` — creates `ns.UI`; AceGUI widget factory functions, option list constants, font utilities
- `UI/GeneralTab.lua` — overview tab (module toggles, global settings, quick actions)
- `UI/ViewerTab.lua` — viewer tabs (Essential/Utility/Buffs); row size overrides; text overlay section builder
- `UI/HighlightTab.lua` — highlight effects tab (skill glow + buff glow config)
- `UI/ProfilesTab.lua` — profile management tab (create/switch/copy/delete/reset, LibDualSpec, import/export)
- `UI/MonitorBarsTab.lua` — monitor bar settings tab (bar selector, spell catalog, per-bar options)
- `UI/Settings.lua` — settings panel frame, tab routing, slash commands, Blizzard Settings registration

### Data Flow

Game events hit `Init.lua`, which calls a debounced `RequestRefreshAll()`. That fans out to `Layout:RefreshViewer()` → `Style:ApplyIcon()` / `Style:ApplyStack()` / `Style:ShowHighlight()`.

Init also invokes MonitorBars event handlers and `InitAllBars()` after PLAYER_ENTERING_WORLD.

Settings changes go through WoW's `CooldownViewerSettings.OnDataChanged` EventRegistry callback, caught by `Init.lua`, which triggers the same refresh path.

### Namespace Conventions

All files share state via `local _, ns = ...`:
- `ns.Style` — created by Style/Icon.lua, extended by other Style/ files
- `ns.Layout` — created by Layout.lua
- `ns.MonitorBars` — created by MonitorBars/Scanner.lua, extended by Bars.lua
- `ns.UI` — created by UI/Widgets.lua, consumed by tab files
- `ns.L` — created by Locales.lua
- `ns.defaults` / `ns.DeepCopy` — created by Core/Defaults.lua
- `ns.MigrateOldData` — created by Core/Migration.lua

### Viewers

Four native WoW viewers are hooked:
- `EssentialCooldownViewer` — core abilities
- `UtilityCooldownViewer` — utility abilities
- `BuffIconCooldownViewer` — buff icons
- `BuffBarCooldownViewer` — tracked status bars

### External Libraries (`Libs/`)

- `AceGUI-3.0` — settings panel UI widgets
- `LibSharedMedia-3.0` — font registry
- `LibCustomGlow-1.0` — glow/highlight effects
- `LibDBIcon-1.0` + `LibDataBroker-1.1` — minimap icon
- `LibStub`, `CallbackHandler-1.0` — library loading and event callbacks

### Config Shape

All settings persist in `CDFlowDB`. Per-viewer keys are `essential`, `utility`, and `buffs`. Each viewer has sub-tables: `stack`, `keybind`, `cooldownText`, `highlight`, and `buffGlow`. Global keys include `iconZoom`, `borderSize`, `suppressDebuffBorder`, and `trackedBarsGrowDir`.

`monitorBars`: `locked`, `nextID`, `bars[]`. Each bar: `id`, `enabled`, `barType` (stack/charge), `spellID`, `spellName`, `unit`, `maxStacks`/`maxCharges`, size/position, colors, border, font, `hideFromCDM`, `specs`, etc.

## Implementation Reference: MonitorBars Secret-Value Pattern

How MonitorBars works around 12.0 secret values to implement buff stack / spell charge / cooldown bars:

1. **CDM Scan** (`Scanner.lua`): Out of combat, scan CDM viewers via `C_CooldownViewer.GetCooldownViewerCategorySet()` and `GetCooldownViewerCooldownInfo()` to build `spellID → cooldownID → CDM frame` maps.

2. **CDM Frame Hooks** (`Bars.lua`): `hooksecurefunc` on CDM frame methods (`RefreshData`, `RefreshApplications`, `SetAuraInstanceInfo`) to get real-time updates during combat.

3. **Aura via CDM**: Read `cdmFrame.auraInstanceID` (may be secret), pass it to `C_UnitAuras.GetAuraDataByAuraInstanceID()` — secret values are valid references. Get `auraData.applications` (often secret too).

4. **Arc Detectors** (core trick): For secret numeric values, create hidden StatusBars with `SetMinMaxValues(i-1, i)` for each threshold i. Feed the secret value via `SetValue()`. The C++ engine compares internally. Read back via `GetStatusBarTexture():IsShown()` to determine the exact count.

5. **DurationObject**: Use `C_Spell.GetSpellCooldownDuration()` / `GetSpellChargeDuration()` returning DurationObject. Drive bars via `StatusBar:SetTimerDuration(durObj)`. Get remaining time via `DurationObject:GetRemainingDuration()` (handle with `pcall`+`tonumber`).

6. **Shadow Cooldown**: Create hidden `CooldownFrameTemplate`, feed DurationObject via `SetCooldownFromDurationObject()`, check `IsShown()` to detect active cooldown without reading secret start/duration.
