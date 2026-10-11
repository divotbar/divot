---
id: "0033"
title: "Split the clock into separate date and time items, each with its own toggle"
type: feature
status: inbox
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T00:39:24Z"
updated_at: "2026-10-11T00:39:24Z"
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
