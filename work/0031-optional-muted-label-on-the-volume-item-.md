---
id: "0031"
title: Optional %/muted label on the volume item in Settings
type: feature
status: done
priority: p2
area: macos
depends_on: ["0028"]
merged_commit: cadee4d181c74d2bc8544641b06993b675d41d59
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-muted-label-on-the-volume-item-
created_at: "2026-10-11T00:39:23Z"
updated_at: "2026-10-11T01:11:23Z"
last_close_out_gate_ms: 46110
last_close_out_gate_at: "2026-10-11T01:11:20.971Z"
review_passes: 2
review_rounds: 1
---
## Problem

The volume item always shows a percentage and a muted label. The maintainer wants each to be optional.

## Desired UX

- Settings has two toggles for the volume item: "Show percentage" and "Show muted state", both on by default to keep today's look.
- With both off, the item shows only the volume icon.

## Acceptance criteria

- Add `showVolumePercent` and `showVolumeMuted` configuration keys (default true), persisted through the configuration store, with toggles in the settings window.
- The volume item hides the matching text live, without a relaunch.
- Tests cover the defaults and the label output for each combination.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep changes to the volume widget's label, not the volume reading.

## Activity

- 2026-10-11T00:39:23Z · created · njachowski@gmail.com
- 2026-10-11T00:43:52Z · status inbox→ready
- 2026-10-11T00:43:52Z · status ready→active, branch
- 2026-10-11T00:50:16Z · status active→review
- 2026-10-11T00:50:17Z · note: shots: skipped — the diff (8 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:51:15Z · note: review pass 1: needs some work
- 2026-10-11T00:51:16Z · status review→active
- 2026-10-11T00:55:11Z · status active→review
- 2026-10-11T00:55:12Z · note: shots: skipped — the diff (10 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:56:04Z · note: review pass 2: good to go
- 2026-10-11T01:11:20Z · close-out gate completed in 46s
- 2026-10-11T01:11:23Z · status review→done, release:success
