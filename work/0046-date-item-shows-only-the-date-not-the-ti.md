---
id: "0046"
title: "Date item shows only the date, not the time"
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/date-item-shows-only-the-date-not-the-ti
created_at: "2026-10-11T13:26:29Z"
updated_at: "2026-10-11T14:02:53Z"
---
## Problem

After the clock was split into Date and Time items (#0033), the Date item still shows the time, e.g. "Sun, 11 Oct at 20:24". The date should show only the date.

## Desired UX

- The Date item shows only the date. The default looks like "Sun 11 Oct" (no comma, no time).
- The Time item keeps showing only the time.

## Acceptance criteria

- The Date item's default output contains no time and no comma.
- Tests cover the default date output and confirm the time is absent.
- `repoos check` passes.

## Notes for AI

The format options (weekday, year, presets) are in #0034. Keep this change to the Date item's default output.

## Activity

- 2026-10-11T13:26:29Z · created · njachowski@gmail.com
- 2026-10-11T13:58:14Z · status inbox→ready
- 2026-10-11T13:58:15Z · status ready→active, branch
- 2026-10-11T14:02:15Z · status active→review
- 2026-10-11T14:02:16Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T14:02:53Z · note: review pass 1: needs some work
