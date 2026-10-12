---
id: "0055"
title: Align workspace numbers and app icons vertically at every icon size
type: bug
status: inbox
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T08:31:59Z"
updated_at: "2026-10-12T08:31:59Z"
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
