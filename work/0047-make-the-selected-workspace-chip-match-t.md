---
id: "0047"
title: "Make the selected workspace chip match the other chips, and add a chip opacity setting (0 to 100)"
type: feature
status: active
priority: p2
area: macos
depends_on: ["0030"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/make-the-selected-workspace-chip-match-t
created_at: "2026-10-11T13:57:41Z"
updated_at: "2026-10-11T14:08:27Z"
review_rounds: 1
review_passes: 1
---
## Problem

The focused workspace is drawn with a different style from the other workspace chips: it has a highlighted border and background that don't match the rest. The maintainer wants the focused chip to use the same style as the others, with the focus shown in a subtler way. The chips also need an opacity control.

## Desired UX

- The focused workspace chip uses the same shape, padding and colours as the other chips. The focus is shown by the number's weight or by a small marker, not by a different chip style.
- Settings has a "Chip opacity" control from 0 to 100.
- At 0 the chips look as they do today. At 100 the chips match the bar colour, so they are invisible and only the workspace content shows.

## Acceptance criteria

- The focused workspace uses the same chip style as the others; the focus indicator is a subtle non-chip cue.
- Add a `chipOpacity` configuration key (0 to 100, default matching the current look), persisted through the configuration store, with a slider in Settings.
- Opacity 100 makes the chip background identical to the bar background; 0 keeps the current chip appearance. Test both ends and a midpoint.
- Values outside 0 to 100 are clamped, with a test.
- `repoos check` passes. The maintainer confirms the look.

## Notes for AI

Depends on #0030 (chips). Keep changes to the chip drawing and the focus cue, not the workspace feed.

## Activity

- 2026-10-11T13:57:41Z · created · njachowski@gmail.com
- 2026-10-11T13:58:16Z · status inbox→ready
- 2026-10-11T13:58:17Z · status ready→active, branch
- 2026-10-11T14:05:38Z · status active→review
- 2026-10-11T14:05:39Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T14:06:27Z · note: review pass 1: needs some work
- 2026-10-11T14:06:28Z · status review→active
- 2026-10-11T14:08:27Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
