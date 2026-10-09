---
id: "0017"
title: Add a Divot settings window with theme and appearance pickers
type: feature
status: inbox
priority: p1
area: macos
depends_on: ["0006", "0011"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T20:26:49Z"
updated_at: "2026-10-09T20:26:49Z"
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
