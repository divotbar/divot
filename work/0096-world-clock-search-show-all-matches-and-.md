---
id: "0096"
title: "World clock search: show all matches, and cap the results at 90% of screen height with scrolling"
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-search-show-all-matches-and-
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-14T04:37:00Z"
updated_at: "2026-10-14T04:52:28Z"
review_rounds: 1
review_passes: 1
---
## Problem
In the world clock popover, the Add timezone search has two problems.

1. Zones already in the list (for example Singapore, which is a default) are hidden from the results. That is intended, but it is not explained in the UI, so it looks like the zone is missing. Show already-added matches as disabled or marked 'Already added', or at least say so.
2. When a search returns many results, the list is capped at 8 rows (TimezoneSearchResultsController, maximumVisibleRows = 8) and the popover does not grow. A broad or empty query overflows the popover.

## Desired UX
When there are many results, the popover grows up to 90% of the screen height and the results scroll beyond that, the same way the Wi-Fi network list does (macos/Sources/DivotAppKit/WifiPopover.swift, from #0095).

## Acceptance criteria
- Singapore (or any default already in the list) is either shown as 'Already added' or the UI states why it is hidden.
- A search with many results grows the popover to at most 90% of the screen height, then scrolls.
- Tests cover the live panel path, not only the content view size.
- docs/ and site/ pages are updated.

## Notes for AI
Screenshots from the maintainer are attached. The first (screenshot 1) shows 'sin' with Singapore already added. The second (screenshot 2) shows an empty query overflowing the popover.

## Screenshots

![1](/api/tasks/0096/attachments/screenshot-1.png)
![2](/api/tasks/0096/attachments/screenshot-2.png)

## Shots
```json
[
{
"label": "World clock search: many results capped at 90% of the screen height and scrolling",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "many-results"
},
"glob": "*many-results*.png"
},
{
"label": "World clock search: an already-added zone marked Already added",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "already-added"
},
"glob": "*already-added*.png"
}
]
```

## Activity

- 2026-10-14T04:37:00Z · created · njachowski@gmail.com
- 2026-10-14T04:37:00Z · screenshots
- 2026-10-14T04:37:07Z · cli_override, model_override
- 2026-10-14T04:37:11Z · status inbox→ready
- 2026-10-14T04:37:12Z · status ready→active, branch
- 2026-10-14T04:46:14Z · body: section Shots
- 2026-10-14T04:48:38Z · status active→review
- 2026-10-14T04:49:19Z · note: review pass 1: needs some work
- 2026-10-14T04:49:19Z · status review→active
- 2026-10-14T04:50:45Z · message_queued at 2026-10-14T04:50:45.863Z
- 2026-10-14T04:52:28Z · status active→review
- 2026-10-14T04:52:28Z · note: shots: skipped — 4 handoff shots already captured for this exact plan (63b066b9) during finalization (#0734)
