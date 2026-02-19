## Project Overview

CDFlow is a World of Warcraft addon (Lua) that customizes WoW's built-in Cooldown Manager — icon styles, layouts, highlights, and text displays for cooldowns and buffs. Targets WoW Interface 12000+.

## Development

There is no build, lint, or test pipeline. This is a runtime-interpreted Lua addon loaded directly by the WoW client.

To test changes, copy the addon folder to `World of Warcraft\_retail_\Interface\AddOns\CDFlow` and reload the UI in-game with `/reload`. The in-game settings panel is opened with `/cdf`.

## Architecture

Six modules loaded in order via `CDFlow.toc`:

- `Locales.lua` — bilingual string table (EN/ZH), auto-detected via `GetLocale()`
- `Config.lua` — default config schema, `CDFlowDB` SavedVariables management, deep-copy/merge for settings migration
- `Style.lua` — icon sizing/cropping, border, font rendering, glow effects; caches icon regions for performance
- `Layout.lua` — multi-row layout engine for Essential/Utility viewers; single-row/column for Buff icons; handles tracked bars
- `Settings.lua` — AceGUI-based settings panel with per-viewer tabs
- `Core.lua` — event orchestration, hooks into WoW's native cooldown viewers, debounced refresh system

### Data Flow

Game events (e.g. `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED`) hit `Core.lua`, which calls a debounced `RequestRefreshAll()`. That fans out to `Layout:RefreshViewer()` → `Style:ApplyIcon()` / `Style:ApplyText()` / `Style:ShowHighlight()`.

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
