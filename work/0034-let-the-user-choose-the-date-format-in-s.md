---
id: "0034"
title: Let the user choose the date format in Settings
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028", "0033"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/let-the-user-choose-the-date-format-in-s
created_at: "2026-10-11T00:39:28Z"
updated_at: "2026-10-11T14:23:35Z"
review_passes: 5
review_rounds: 2
---
## Problem

The date uses a fixed format. The maintainer wants to choose it.

## Desired UX

- Settings has a date format field with a short list of presets (for example "Sat, 10 Oct" and "10/10/2026") and a custom pattern option.
- An invalid custom pattern falls back to the default with a visible note, not a crash.
- The format applies live and persists through the configuration store.

## Acceptance criteria
- Settings has a date format section for the Date item with these options, each a toggle or choice: show the weekday (on by default), show the year (off by default), day-first or month-first order, and a separator (none by default).
- The default output is "Sun 11 Oct" (no comma, no time).
- A custom pattern option is available for advanced users; an invalid pattern falls back to the default with a visible note, not a crash.
- The format applies live and persists through the configuration store.
- Tests cover the default output, each option on and off, a valid custom pattern, and an invalid one.
- repoos check passes.


## Notes for AI

Depends on #0033, the date/time split, which must land first.

## Activity

- 2026-10-11T00:39:28Z · created · njachowski@gmail.com
- 2026-10-11T13:08:13Z · status inbox→ready
- 2026-10-11T13:08:13Z · status ready→active, branch
- 2026-10-11T13:14:33Z · status active→review
- 2026-10-11T13:14:33Z · note: shots: skipped — the diff (9 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:15:12Z · note: review pass 1: needs some work
- 2026-10-11T13:15:12Z · status review→active
- 2026-10-11T13:17:55Z · status active→review
- 2026-10-11T13:17:55Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:18:51Z · note: review pass 2: needs some work
- 2026-10-11T13:18:51Z · status review→active
- 2026-10-11T13:22:50Z · status active→review
- 2026-10-11T13:22:50Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:23:56Z · note: review pass 3: needs some work
- 2026-10-11T13:23:56Z · needs_input
- 2026-10-11T13:26:33Z · body: section Acceptance criteria
- 2026-10-11T13:26:33Z · needs_input
- 2026-10-11T13:26:34Z · status review→active
- 2026-10-11T13:26:34Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T13:30:55Z · status active→review
- 2026-10-11T13:30:55Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:31:35Z · note: review pass 4: needs some work
- 2026-10-11T13:31:35Z · needs_input
- 2026-10-11T13:58:25Z · needs_input
- 2026-10-11T13:58:25Z · status review→active
- 2026-10-11T13:58:25Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T14:01:32Z · status active→review
- 2026-10-11T14:01:32Z · note: shots: skipped — the diff (11 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T14:02:32Z · note: review pass 5: needs some work
- 2026-10-11T14:02:33Z · needs_input
- 2026-10-11T14:17:47Z · needs_input
- 2026-10-11T14:17:47Z · status review→active
- 2026-10-11T14:17:47Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T14:23:34Z · status active→review
- 2026-10-11T14:23:35Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
