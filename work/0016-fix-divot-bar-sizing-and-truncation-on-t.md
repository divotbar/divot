---
updated_at: "2026-10-09T21:10:23Z"
review_passes: 1
id: "0016"
title: Fix Divot bar sizing and truncation on the menu-bar row
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/fix-divot-bar-sizing-and-truncation-on-t
created_at: "2026-10-09T20:18:47Z"
---
## Problem

In the maintainer's screenshot, the Divot row is taller and wider than it should be relative to its content. Several labels are clipped with ellipses: the clock/date reads "10…" and "Sat, 10 Oct at 04:…", volume reads "Mut…", and the frontmost app reads "Ghos…". Content is not vertically centred in the bar height, and the workspace pills look oversized next to the a-bar row.

## Desired UX

Divot's row height, item padding and font sizes match a compact macOS menu-bar rhythm. Every shown label is fully visible at the default layout, and items are sized to their content with consistent spacing between left and right groups.

## Acceptance criteria

- Reproduce with a screenshot of the default layout (`repoos shot` or the preview) at this Mac's display width and record before/after.
- No ellipsis on default-width labels for clock/date, battery, network, volume, and frontmost app; add tests for the width/measurement logic in `DivotCore`.
- Default bar height and padding are documented; the value is set from one place (`BarGeometry` default height or the widget style), not per-widget.
- Left and right groups do not overlap the notch housing on notched displays.
- `repoos check` passes. Do not claim a human checked the appearance; record the screenshot as evidence only.

## Notes for AI

Depends conceptually on the placement fix in the sibling P0 task; coordinate on `BarPanels.swift` and `WidgetViews.swift` by keeping changes narrow so the two do not conflict.

## Activity

- 2026-10-09T20:18:47Z · created · njachowski@gmail.com
- 2026-10-09T20:21:59Z · note: PM: repoos shots cover web routes only, so they will not capture the native Divot bar. Verify sizing with DivotCore measurement tests; include a screenshot only if one can be captured, and do not claim it looks right without a human check.
- 2026-10-09T20:28:34Z · status inbox→ready
- 2026-10-09T20:28:35Z · status ready→active, branch
- 2026-10-09T21:09:36Z · status active→review
- 2026-10-09T21:09:36Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-09T21:10:23Z · note: review pass 1: good to go

