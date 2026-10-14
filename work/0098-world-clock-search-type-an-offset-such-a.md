---
id: "0098"
title: "World clock search: type an offset such as +7 or -8 to find zones in that offset"
type: feature
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-search-type-an-offset-such-a
created_at: "2026-10-14T05:15:41Z"
updated_at: "2026-10-14T05:42:18Z"
---
## Problem
The Add timezone search only matches city or zone names. To add a zone by its offset, the user has to know the city name.

## Desired UX
Typing a signed offset in the search field, for example '+7' or '-8', lists the zones whose current UTC offset matches, so the user can pick their city in that offset. Accept whole hours and half/quarter hours such as '+5:30' or '+5.5'. Each result shows the zone's city name and its UTC offset (the offset column from #0097). Already-added zones keep their 'Already added' label.

## Acceptance criteria
- A query that matches the pattern +N, -N, +N:MM or +N.N lists matching zones (for example '+7' lists Jakarta, Bangkok and Ho Chi Minh City; '-8' lists Los Angeles, Vancouver and Tijuana).
- Name search still works when the query is not an offset.
- The offset is the zone's current offset, so DST shifts the match as expected.
- Tests cover a whole-hour, a negative, and a half-hour offset.
- docs/ and site/ pages are updated.

## Notes for AI
The current search lives in WorldClockPopover.swift (updateResults). Zone identifiers come from TimeZone.knownTimeZoneIdentifiers (443 zones on this Mac). Depends on #0097 for the offset display, so it should land after #0097.

## Shots
```json
[
{
"label": "World clock search by offset: a +7 query lists each zone at UTC+7 with its UTC offset",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "worldclock"
},
"glob": "*worldclock-offset-query*.png"
}
]
```

## Activity

- 2026-10-14T05:15:41Z · created · njachowski@gmail.com
- 2026-10-14T05:15:42Z · status inbox→ready
- 2026-10-14T05:30:26Z · status ready→active, branch
- 2026-10-14T05:37:38Z · body: section Shots
- 2026-10-14T05:41:39Z · status active→review
- 2026-10-14T05:42:14Z · note: shots: skipped — capture command for "Divot bar" produced no image files matching *worldclock-offset-query*.png 􁁛  Test "World clock popover — four zones with day labels, all themes × light/dark" passed after 34.422 seconds. 􁁛  Test "Volume popover — all themes × light/dark × larger text (16pt)" passed after 34.422 seconds. 􁁛  Test "World clock popover — add flow (typed 'los'), all themes × light/dark" passed after 34.422 seconds. 􁁛  Test "World clock popover — one zone, all themes × light/dark" passed after 34.422 seconds. 􁁛  Test rendersToast(config:) with 8 test cases passed after 34.422 seconds. 􁁛  Suite "Popover snapshots" passed after 34.422 seconds. 􁁛  Suite "Bar snapshots" passed after 34.422 seconds. 􁁛  Suite "Keep-awake toast snapshots" passed after 34.422 seconds. 􁁛  Test run with 29 tests in 4 suites passed after 34.427 seconds. Building for debugging... [0/10] Write swift-version--58304C5D6DBC2206.txt Build complete! (0.09s)
- 2026-10-14T05:42:18Z · note: review pass 1: needs some work
