---
id: "0017"
title: Add a Divot settings window with theme and appearance pickers
type: feature
status: review
priority: p1
area: macos
depends_on: ["0006", "0011"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-divot-settings-window-with-theme-a
created_at: "2026-10-09T20:26:49Z"
updated_at: "2026-10-10T02:20:55Z"
---
## Problem

The maintainer wants to edit the Divot bar without hand-editing config: change the theme family (Gruvbox, Ayu, Dracula, Tokyo Night, and the native default) and the light/dark variant from a settings window. Persistence is handled by the versioned configuration task (0006); the palettes come from the theme task (0011).

## Desired UX

A Settings window (or menu-bar menu entry) with a theme family picker and a light/dark/system appearance picker. Choosing a value applies it live to the bar and persists it through the configuration store. The window opens from the Divot menu or a keyboard shortcut.

## Acceptance criteria

- Settings window opens from the app (menu entry at minimum) and shows the current family and appearance mode.
- Choosing each of the five families and each of light / dark / system applies immediately and survives relaunch.
- Changes go through the configuration store from 0006; no separate ad-hoc storage.
- Picker controls use the accessible native controls; no native `title` tooltips; overlays wrapped per AGENTS.md rules.
- Tests cover the view model: family/appearance selection maps to the persisted config and the palette applied.
- `repoos check` passes. A screenshot is evidence only; do not claim a human checked it.

## Notes for AI

Depends on 0006 (config, settings, appearance modes) and 0011 (theme families). Do not start until both are done. Keep the first version to the theme and appearance pickers; other settings can follow.

## Activity

- 2026-10-09T20:26:49Z · created · njachowski@gmail.com
- 2026-10-10T02:12:56Z · status inbox→ready
- 2026-10-10T02:18:09Z · status ready→active, branch
- 2026-10-10T02:20:31Z · note: Implementation note: the settings window with theme-family and System/Light/Dark pickers already shipped via 0006 (window + controller + view model) and 0011 (theme families/palette resolution), so this task adds the missing acceptance-criteria coverage: view-model tests that iterate all five families and all three modes, prove each selection maps to the persisted config and survives a reload, and prove a palette override changes the resolved palette the bar draws. No duplicate window was added.
- 2026-10-10T02:20:55Z · status active→review
- 2026-10-10T02:20:55Z · note: shots: skipped — the diff (2 changed paths) touches no [[preview.paths]] globs — no UI change to capture
