---
id: "0074"
title: "Charging indicator must be a real green, independent of theme"
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/charging-indicator-must-be-a-real-green-
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T03:53:48Z"
updated_at: "2026-10-13T04:58:20Z"
review_passes: 3
review_rounds: 2
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

## Approach
- **Colour:** `ChargingIndicatorPalette.greenHex` (#248E3C) is one fixed green constant, never the theme accent. #0058 had used the accent, so Dracula and Tokyo Night showed a purple/blue bolt. A single value is deliberate: Apple's bright system green fails a light bar and a light-green dark variant fails a dark one, but #248E3C clears the 3:1 non-text floor against all four families' light and dark bar backgrounds. Measured in `PerformanceHarness.contrastChecks` (charging/background) and `DivotAppKitTests/ChargingIndicatorContrastTests.swift`.

- **Whole-icon tint (the chosen approach):** while charging the view tints the whole battery symbol and the bolt green, not just the bolt. A small bolt over the battery outline is not reliably legible and is lost against the optional chip fill, so the larger whole-symbol mark is what makes charging unmistakable, as the maintainer asked. The percentage label keeps the foreground colour; not charging draws no green and no bolt.

- **Chip caveat:** a chip's fill is the family `selected` state colour, which spans the luminance range, so no single green can hold a numeric ratio against every chip fill. The whole-symbol tint keeps a large green mark on the chip even where that ratio is low; the numeric audit covers the bar background, matching the existing per-role convention.

- **Charging vs error:** the icon prioritizes charging-green over error state, so if the battery item is both charging and in an error state, it draws green — charging is the more visually critical state and the label can convey error. Battery errors are rare and transient; charging state is what users need to distinguish at a glance.

## Activity

- 2026-10-13T03:53:48Z · created · njachowski@gmail.com
- 2026-10-13T03:53:51Z · status inbox→ready
- 2026-10-13T03:53:52Z · cli_override, model_override
- 2026-10-13T03:53:52Z · status ready→active, branch
- 2026-10-13T04:12:19Z · message_queued at 2026-10-13T04:12:19.167Z
- 2026-10-13T04:12:19Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T04:14:01Z · message_delivered: 1 message(s)
- 2026-10-13T04:18:41Z · body: section Approach
- 2026-10-13T04:36:46Z · message_queued at 2026-10-13T04:36:46.445Z
- 2026-10-13T04:46:51Z · cli_override, model_override
- 2026-10-13T04:46:52Z · message_delivered: 1 message(s)
- 2026-10-13T04:48:52Z · status active→review
- 2026-10-13T04:48:53Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T04:49:50Z · note: review pass 1: needs some work
- 2026-10-13T04:49:50Z · status review→active
- 2026-10-13T04:50:01Z · body: section Approach
- 2026-10-13T04:50:41Z · status active→review
- 2026-10-13T04:50:42Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T04:51:24Z · note: review pass 2: needs some work
- 2026-10-13T04:51:24Z · status review→active
- 2026-10-13T04:52:38Z · status active→review
- 2026-10-13T04:52:38Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T04:53:41Z · note: review pass 3: needs some work
- 2026-10-13T04:53:41Z · needs_input
- 2026-10-13T04:55:41Z · needs_input
- 2026-10-13T04:55:41Z · status review→active
- 2026-10-13T04:55:41Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T04:56:24Z · body: section Approach
- 2026-10-13T04:58:20Z · status active→review
- 2026-10-13T04:58:20Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
