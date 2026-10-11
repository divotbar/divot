---
id: "0035"
title: Let the user choose the time format in Settings (24-hour or AM/PM)
type: feature
status: review
priority: p2
area: macos
depends_on: ["0033"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/let-the-user-choose-the-time-format-in-s
created_at: "2026-10-11T00:41:47Z"
updated_at: "2026-10-11T13:19:07Z"
---
## Problem

The time item uses a fixed format. The maintainer wants to choose between 24-hour and AM/PM.

## Desired UX

- Settings has a time format choice: "24-hour" or "AM/PM", plus a custom pattern option.
- The format applies live and persists through the configuration store.
- An invalid custom pattern falls back to the default with a visible note.

## Acceptance criteria

- Add a `timeFormat` configuration key, default to the current format, persisted through the configuration store, with a settings control.
- Validate custom patterns; fall back to the default on error.
- Tests cover both presets, a valid custom pattern and an invalid one.
- `repoos check` passes.

## Notes for AI

Depends on #0033, the date/time split. Keep this to the time item's formatting, separate from the date format in #0034.

## Activity

- 2026-10-11T00:41:47Z · created · njachowski@gmail.com
- 2026-10-11T13:08:14Z · status inbox→ready
- 2026-10-11T13:08:15Z · status ready→active, branch
- 2026-10-11T13:18:26Z · status active→review
- 2026-10-11T13:18:26Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:19:07Z · note: review pass 1: needs some work
