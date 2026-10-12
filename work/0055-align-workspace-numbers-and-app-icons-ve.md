---
id: "0055"
title: Align workspace numbers and app icons vertically at every icon size
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/align-workspace-numbers-and-app-icons-ve
created_at: "2026-10-12T08:31:59Z"
updated_at: "2026-10-12T08:38:22Z"
review_rounds: 1
review_passes: 1
---
## Problem

When the app icon size changes, the workspace numbers and the app icons drift out of line. In the maintainer's screenshots they only line up at the smallest icon size (12). At larger sizes the icons sit lower or higher than the numbers, and the row looks uneven.

## Desired UX

- At every app icon size, the workspace numbers and the app icons share one vertical centre line.
- The row height grows with the icon size without shifting either element off that line.

## Acceptance criteria

- Lay out each workspace group so the number and the icons are centred on the same vertical line, using the row's height and the icon's size, not fixed offsets.
- Tests cover the vertical centre of the number and the icons at the smallest, default and largest icon sizes, and assert they match within half a point.
- Verify on the packaged app at three icon sizes; record the observed alignment in the task. The maintainer confirms the look.
- repoos check passes.

## Notes for AI

This is layout alignment only. Do not change the icon size setting, the spacing rules or the chip style, which are in #0052 and #0054.

## Activity

- 2026-10-12T08:31:59Z · created · njachowski@gmail.com
- 2026-10-12T08:32:00Z · status inbox→ready
- 2026-10-12T08:32:01Z · status ready→active, branch
- 2026-10-12T08:35:25Z · status active→review
- 2026-10-12T08:35:25Z · note: shots: skipped — the diff (3 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T08:36:13Z · note: review pass 1: needs some work
- 2026-10-12T08:36:13Z · status review→active
- 2026-10-12T08:37:23Z · status active→review
- 2026-10-12T08:37:23Z · note: shots: skipped — the diff (3 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T08:38:22Z · note: review pass 2: good to go
