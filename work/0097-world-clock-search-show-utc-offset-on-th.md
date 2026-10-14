---
id: "0097"
title: "World clock search: show UTC offset on the right of each result"
type: feature
status: inbox
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-14T05:11:50Z"
updated_at: "2026-10-14T05:11:50Z"
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

## Activity

- 2026-10-14T05:11:50Z · created · njachowski@gmail.com
- 2026-10-14T05:11:50Z · screenshots
