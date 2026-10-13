---
id: "0074"
title: "Charging indicator must be a real green, independent of theme"
type: bug
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/charging-indicator-must-be-a-real-green-
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T03:53:48Z"
updated_at: "2026-10-13T04:13:54Z"
---
## Problem
#0058 drew the charging bolt in 'the theme's accent set'. On themes whose accent is not green (maintainer screenshot 2026-10-13, Dracula: the bolt is purple/blue) charging is not obvious. The maintainer wants it unmistakable.

## Desired UX
- While charging, the battery item shows an unmistakable GREEN: the bolt in a fixed system-style green (not the theme accent), and if the bolt alone is not clearly visible against the chip on every theme, tint the whole battery symbol green while charging.
- Not charging: no green, no bolt, unchanged.
- Readable on all theme families in light and dark, and on chip and non-chip backgrounds.

## Acceptance criteria
- The charging colour is one named constant (a fixed green) not taken from the theme accent; the contrast audit (ContrastAudit) is extended or used to verify it against each theme's bar/chip background in light and dark, with the whole-icon tint chosen where the bolt alone fails the threshold; state which approach and why in the task.
- Tests cover charging and not-charging states, that the colour is green regardless of theme family, and the contrast result for each family.
- docs/ and site/ pages describing the charging indicator are updated.
- The maintainer confirms by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
Look at the badge tint code around WidgetViews.swift (the #0058 bolt) and BarTheme. Keep the #0057 icon sizing.

## Activity

- 2026-10-13T03:53:48Z · created · njachowski@gmail.com
- 2026-10-13T03:53:51Z · status inbox→ready
- 2026-10-13T03:53:52Z · cli_override, model_override
- 2026-10-13T03:53:52Z · status ready→active, branch
- 2026-10-13T04:12:19Z · message_queued at 2026-10-13T04:12:19.167Z
- 2026-10-13T04:12:19Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
