---
id: "0052"
title: "Selected workspace chip style, app icon size setting, and chip opacity for all chips"
type: feature
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/selected-workspace-chip-style-app-icon-s
created_at: "2026-10-12T06:59:51Z"
updated_at: "2026-10-12T06:59:53Z"
---
## Problem

Three things on the bar need changing, from the maintainer's screenshots:

1. The selected workspace on the left still has a bordered box that the other workspaces and the right-side chips don't have. It should use the same chip style as the right-side items.
2. The app icons on the left are small. They should be about the same size as the Claude icon on the right, and the maintainer wants a size setting in Settings.
3. The chip opacity setting only applies to the workspace chips. It should apply to all chips (the left and right items).

## Desired UX

- The selected workspace uses the same chip as the other items; the focus shows as a subtle cue, not a box.
- Settings has an "App icon size" control, default matching the right-side app icon size (the Claude icon).
- The "Chip opacity" setting applies to every chip on the bar, not only the workspace chips. The help text is updated to say so.

## Acceptance criteria

- The selected workspace uses the same chip shape, padding and colours as the right-side items.
- Add an `appIconSize` configuration key (default matching the right-side icon size), persisted through the configuration store, with a slider in Settings.
- The left-side app icons use `appIconSize`; the default equals the right-side app icon size, verified in the packaged app.
- `chipOpacity` applies to every chip on the bar. Update the Settings help text.
- Tests cover the selected chip style, the icon size default and range, and opacity applied to both sides.
- repoos check passes. The maintainer confirms the look.

## Notes for AI

This supersedes the selected-chip part of #0047, which is marked done but still shows the old box. Keep changes to chip drawing, icon sizing and the opacity scope.

## Activity

- 2026-10-12T06:59:51Z · created · njachowski@gmail.com
- 2026-10-12T06:59:52Z · status inbox→ready
- 2026-10-12T06:59:53Z · status ready→active, branch
