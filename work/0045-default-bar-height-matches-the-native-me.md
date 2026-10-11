---
id: "0045"
title: Default bar height matches the native menu bar height on each display
type: bug
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/default-bar-height-matches-the-native-me
created_at: "2026-10-11T13:13:19Z"
updated_at: "2026-10-11T13:23:30Z"
---
## Problem

Divot's default row height is 32pt. On the maintainer's notched MacBook Air the native menu bar is 33pt tall (the screen's top safe-area inset, `safeAreaInsets.top` = 33, with the menu band equal to frame.maxY minus visibleFrame.maxY = 33). The Divot row sits 1pt (2px at 2x) shorter, which the maintainer can see.

## Desired UX

- With no user override, Divot's row height equals the native menu bar height on the display it sits on.
- On notched displays that is the safe-area top (33pt here). On notch-free displays it is the native menu bar height reported by AppKit (24pt).
- A `layout.height` value in configuration still overrides it.

## Acceptance criteria

- Compute the default row height per display from the native menu bar band, not a constant. Keep `BarMetrics.default.height` only as a fallback when the band is unknown.
- A configured `layout.height` still wins when set.
- Tests cover: notched display returns the safe-area top, notch-free display returns the fallback, and an explicit configured height overrides both.
- Verify on the packaged app that the Divot row matches the native bar height on the notched display; record the measured values in the task. The maintainer confirms the look.
- `repoos check` passes.

## Notes for AI

Measured on 2026-10-11: NSScreen.main safeAreaInsets.top = 33, frame.maxY - visibleFrame.maxY = 33, NSStatusBar.system.thickness = 22 (status item height, not the menu bar height; do not use it). Change only the height default and its resolution, not the padding or item layout.

## Activity

- 2026-10-11T13:13:19Z · created · njachowski@gmail.com
- 2026-10-11T13:13:20Z · status inbox→ready
- 2026-10-11T13:13:21Z · status ready→active, branch
- 2026-10-11T13:23:30Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
