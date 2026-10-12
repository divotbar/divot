---
id: "0059"
title: Only the selected workspace gets the chip; match other chips' style and size
type: bug
status: inbox
needs_input: true
needs_input_reason: underspecified
needs_input_detail: "missing sections: Notes for AI"
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T09:13:35Z"
updated_at: "2026-10-12T09:13:38Z"
---
## Problem
The bar draws every workspace (1, 2, 3) as a chip all the time. Only the selected workspace should have the chip style; unselected workspaces are plain number + app icons. (Maintainer screenshot 2026-10-12: all three workspaces are blue chips; the right-side RepoOS Hub chip is visibly larger than the workspace chips.)

## Desired UX
- Unselected workspaces: no chip background, no border.
- Selected workspace: the same chip style as the right-side chips (shape, padding, colours, height, opacity), controlled by the chip setting.
- Chips off (default): selected workspace shows only a subtle cue, as in #0052.

## Acceptance criteria
- Unselected workspaces never draw a chip.
- Selected workspace chip matches right-side chip size and style, with a unit test on the metrics.
- Chip opacity setting still applies to all chips.
- Maintainer confirms by eye on the packaged app.

## Notes for AI
Look at the workspace chip drawing in macos/Sources/DivotAppKit (WidgetViews.swift) and BarMetrics. #0030, #0047 and #0052 touched this; the selected-only behaviour regressed or was never applied. Reuse the right-side chip metrics rather than new constants.

## Activity

- 2026-10-12T09:13:35Z · created · njachowski@gmail.com
- 2026-10-12T09:13:35Z · needs_input
- 2026-10-12T09:13:38Z · body: section Notes for AI
