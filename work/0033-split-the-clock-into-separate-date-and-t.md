---
id: "0033"
title: "Split the clock into separate date and time items, each with its own toggle"
type: feature
status: active
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/split-the-clock-into-separate-date-and-t
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-11T00:39:24Z"
updated_at: "2026-10-11T12:36:18Z"
review_rounds: 1
review_passes: 1
last_check_failure: "repoos check at 2026-10-11T00:55:08.295Z: repoos check failed: native-core — 􁁛 Test configureStopsRemovedProvidersAndStartsNewOnes() passed after 2.845 seconds."
---
## Problem

The clock item combines the date and the time. The maintainer wants them as two separate items, each with its own toggle in Settings.

## Desired UX

- The clock becomes two items, "Date" and "Time", that can be placed and toggled independently in the bar items list.
- Settings has a toggle for each, on by default for the time and off for the date to keep today's look as close as possible.

## Acceptance criteria

- Add `date` and `time` items to the bar item configuration, replacing the combined clock, with a migration that keeps the existing clock placement.
- Each item has an enable toggle and a side toggle in the bar items list.
- Tests cover the migration and the layout of both items.
- `repoos check` passes.

## Notes for AI

Depends on #0028. The date format is a separate task, so this one renders the default format only.

## Activity

- 2026-10-11T00:39:24Z · created · njachowski@gmail.com
- 2026-10-11T00:43:49Z · status inbox→ready
- 2026-10-11T00:43:49Z · status ready→active, branch
- 2026-10-11T00:59:05Z · handoff failed · check failed after 2 automatic retries · repoos check failed: native-core — 􁁛  Test pipelineStartsProvidersOffTheMainThread() passed after 2.403 seconds.
- 2026-10-11T01:04:17Z · watchdog: escalated to needs_input · check-failed-after-retries · check failed after 2 automatic retries · repoos check failed: native-core — 􁁛  Test pipelineStartsProvidersOffTheMainThread() passed after 2.403 seconds. · next step: resume the session manually from the task's worktree and check for uncommitted work
- 2026-10-11T12:20:12Z · cli_override, model_override
- 2026-10-11T12:20:13Z · needs_input
- 2026-10-11T12:27:45Z · status active→review
- 2026-10-11T12:27:45Z · note: shots: skipped — the diff (27 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T12:28:50Z · note: review pass 1: needs some work
- 2026-10-11T12:28:50Z · status review→active
- 2026-10-11T12:36:18Z · note: shots: skipped — the diff (30 changed paths) touches no [[preview.paths]] globs — no UI change to capture
