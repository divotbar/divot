---
close_out_repair_count: 1
id: "0036"
title: Toggle the battery percentage on or off in Settings
type: feature
status: active
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/toggle-the-battery-percentage-on-or-off-
created_at: "2026-10-11T00:41:47Z"
updated_at: "2026-10-11T01:11:28Z"
review_passes: 2
review_rounds: 1
---
## Problem

The battery item always shows the percentage. The maintainer wants it optional.

## Desired UX

- Settings has a "Show battery percentage" toggle, on by default to keep today's look.
- With it off, the battery item shows the icon only.

## Acceptance criteria

- Add a `showBatteryPercent` configuration key (default true), persisted through the configuration store, with a toggle in the settings window.
- The battery item hides the percentage live, without a relaunch.
- Tests cover the default and the label with and without the percentage.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep changes to the battery widget's label, not the battery reading.

## Activity

- 2026-10-11T00:41:47Z · created · njachowski@gmail.com
- 2026-10-11T00:43:54Z · status inbox→ready
- 2026-10-11T00:43:55Z · status ready→active, branch
- 2026-10-11T00:50:23Z · status active→review
- 2026-10-11T00:50:23Z · note: shots: skipped — the diff (9 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:51:06Z · note: review pass 1: needs some work
- 2026-10-11T00:51:06Z · status review→active
- 2026-10-11T00:56:03Z · status active→review
- 2026-10-11T00:56:03Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:56:38Z · note: review pass 2: good to go
- 2026-10-11T01:11:28Z · status review→active
- 2026-10-11T01:11:28Z · note: close-out repair: merge-conflict

