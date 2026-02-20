## Project Overview

CDFlow is a World of Warcraft addon (Lua) that customizes WoW's built-in Cooldown Manager — icon styles, layouts, highlights, and text displays for cooldowns and buffs. Targets WoW Interface 12000+.

## Development

There is no build, lint, or test pipeline. This is a runtime-interpreted Lua addon loaded directly by the WoW client.

To test changes, copy the addon folder to `World of Warcraft\_retail_\Interface\AddOns\CDFlow` and reload the UI in-game with `/reload`. The in-game settings panel is opened with `/cdf`.

## Architecture

Modules loaded in order via `CDFlow.toc` (after `Libs/libs.xml`):

- `Locales.lua` — bilingual string table (EN/ZH), auto-detected via `GetLocale()`
- `Config.lua` — default config schema, `CDFlowDB` SavedVariables management, deep-copy/merge for settings migration
- `Style.lua` — icon sizing/cropping, border, font rendering, glow effects; caches icon regions for performance
- `Layout.lua` — multi-row layout engine for Essential/Utility viewers; single-row/column for Buff icons; handles tracked bars; consumes `ns.cdmSuppressedCooldownIDs` to hide monitor-bar skills from CDM
- `MonitorBars.lua` — stack/charge bars: CDM viewer scan (spellID→cooldownID), frame hooks for stack updates, secret-value detection, bar create/style/update; exposes `ns.cdmSuppressedCooldownIDs`; event handlers called by Core
- `Core.lua` — event orchestration, hooks into WoW's native cooldown viewers, debounced refresh; calls `MonitorBars` event hooks and `InitAllBars` on init
- `Settings.lua` — AceGUI-based settings panel with per-viewer tabs; embeds monitor-bar tab via `ns.BuildMonitorBarsTab`
- `MonitorBarsUI.lua` — monitor-bar settings UI: bar selector, catalog (spell list), per-bar options (type, spell, unit, specs, style); defines `ns.BuildMonitorBarsTab`

### Data Flow

Game events (e.g. `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED`) hit `Core.lua`, which calls a debounced `RequestRefreshAll()`. That fans out to `Layout:RefreshViewer()` → `Style:ApplyIcon()` / `Style:ApplyText()` / `Style:ShowHighlight()`.

Core also invokes `MonitorBars` event handlers (`OnCombatEnter`/`OnCombatLeave`, `OnChargeUpdate`, `OnCooldownUpdate`, `OnAuraUpdate`, `OnTargetChanged`) and `InitAllBars()` after PLAYER_ENTERING_WORLD.

Settings changes go through WoW's `CooldownViewerSettings.OnDataChanged` EventRegistry callback, caught by `Core.lua`, which triggers the same refresh path.

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

All settings persist in `CDFlowDB`. Per-viewer keys are `essential`, `utility`, and `bufs`. Each viewer has sub-tables: `stack`, `keybind`, `cooldownText`, `highlight`, and `buffGlow`. Global keys include `iconZoom`, `borderSize`, `suppressDebuffBorder`, and `trackedBarsGrowDir`.

`monitorBars`: `locked`, `nextID`, `bars[]`. Each bar: `id`, `enabled`, `barType` (stack/charge), `spellID`, `spellName`, `unit`, `maxStacks`/`maxCharges`, size/position, colors, border, font, `hideFromCDM`, `specs`, etc.
