---
id: "0100"
title: "Calendar popover: move the previous and next month arrows beside the month and year"
type: feature
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/calendar-popover-move-the-previous-and-n
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-14T08:39:43Z"
updated_at: "2026-10-14T08:52:41Z"
review_rounds: 1
review_passes: 1
---
## Problem
In the date calendar popover, the previous and next month arrows sit at the top right of the header, away from the month name. They read as separate controls and are easy to miss.

## Desired UX
Put the arrows on either side of the month and year, in the header row, in this order: previous arrow, month and year, next arrow, for example ( < October 2026 > ). The month and year stay centred between the two arrows.

## Acceptance criteria
- The previous arrow is immediately left of the month and year, and the next arrow immediately right of it, in one row.
- Both arrows still change the month, with mouse and keyboard, and keep their accessibility labels.
- The Today link, the day grid and the focus behaviour on open are unchanged. Do not change the initial keyboard focus.
- Tests cover the header order and that the arrows change the month.
- docs/ page describing the date popover is updated if it describes the arrow layout.

## Notes for AI
The calendar popover is macos/Sources/DivotAppKit/CalendarPopover.swift; the header row and arrow buttons are built in the controller near the headerRow and headerLabel setup. The maintainer's screenshot (12) is attached and shows the current layout. Do not change the Today row or the initial focus on the first day button.

## Screenshots

![12](/api/tasks/0100/attachments/screenshot-1.png)

## Shots
```json
[
{
"label": "Calendar popover header: previous and next chevrons beside the centred month and year",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "calendar"
},
"glob": "*calendar*.png"
}
]
```

## Activity

- 2026-10-14T08:39:43Z · created · njachowski@gmail.com
- 2026-10-14T08:39:43Z · screenshots
- 2026-10-14T08:39:47Z · status inbox→ready
- 2026-10-14T08:39:57Z · cli_override, model_override
- 2026-10-14T08:39:57Z · status ready→active, branch
- 2026-10-14T08:48:52Z · body: section Shots
- 2026-10-14T08:51:30Z · status active→review
- 2026-10-14T08:52:40Z · note: review pass 1: needs some work
- 2026-10-14T08:52:41Z · status review→active
