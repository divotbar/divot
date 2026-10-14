---
id: "0097"
title: "World clock search: show UTC offset on the right of each result"
type: feature
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-search-show-utc-offset-on-th
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-14T05:11:50Z"
updated_at: "2026-10-14T05:30:58Z"
close_out_repair_count: 1
review_passes: 2
review_rounds: 1
---
## Problem
The Add timezone results show only the city name. It is hard to tell offsets apart when scanning the list.

## Desired UX
Each result row shows its current UTC offset, for example 'UTC+7' for Jakarta, right-aligned so the city names stay in one neat column. Already-added rows keep their 'Already added' label.

## Acceptance criteria
- Each result shows a right-aligned UTC offset (UTC+h or UTC+h:mm, with UTC+0 for zero), using the zone's current offset.
- City names stay left-aligned in one column, unaffected by offset width.
- Tests cover a positive, a negative and a zero offset.
- docs/ and site/ pages are updated.

## Notes for AI
Screenshots 3 and 4 from the maintainer are attached: 'Lon' and 'Sing' searches with London and Singapore missing. Both are already in the list, so they are hidden as already added; if this build predates #0096, the maintainer needs the packaged app rebuilt to see the labels. The search code is in WorldClockPopover.swift updateResults and WorldClock.friendlyName.

## Screenshots

![3](/api/tasks/0097/attachments/screenshot-1.png)
![4](/api/tasks/0097/attachments/screenshot-2.png)

## Shots
```json
[
{
"label": "World clock search results with right-aligned UTC offsets",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "worldclock"
},
"glob": "*worldclock*.png"
}
]
```

## Activity

- 2026-10-14T05:11:50Z · created · njachowski@gmail.com
- 2026-10-14T05:11:50Z · screenshots
- 2026-10-14T05:11:53Z · status inbox→ready
- 2026-10-14T05:11:54Z · cli_override, model_override
- 2026-10-14T05:11:54Z · status ready→active, branch
- 2026-10-14T05:16:42Z · body: section Shots
- 2026-10-14T05:19:00Z · status active→review
- 2026-10-14T05:19:41Z · note: review pass 1: needs some work
- 2026-10-14T05:19:42Z · status review→active
- 2026-10-14T05:21:27Z · message_queued at 2026-10-14T05:21:27.757Z
- 2026-10-14T05:22:44Z · status active→review
- 2026-10-14T05:22:44Z · note: shots: skipped — 24 handoff shots already captured for this exact plan (9d094f5b) during finalization (#0734)
- 2026-10-14T05:23:24Z · note: review pass 2: good to go
- 2026-10-14T05:24:00Z · status review→active
- 2026-10-14T05:24:00Z · note: close-out repair: merge-conflict
- 2026-10-14T05:24:00Z · message_delivered: 1 message(s)
- 2026-10-14T05:24:01Z · message_queued at 2026-10-14T05:24:01.200Z
- 2026-10-14T05:30:02Z · status active→review
- 2026-10-14T05:30:58Z · note: review pass 3: needs some work
