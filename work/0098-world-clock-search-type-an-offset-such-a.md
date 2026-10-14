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
updated_at: "2026-10-14T05:41:38Z"
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

## Activity

- 2026-10-14T05:15:41Z · created · njachowski@gmail.com
- 2026-10-14T05:15:42Z · status inbox→ready
- 2026-10-14T05:30:26Z · status ready→active, branch
- 2026-10-14T05:41:38Z · status active→review
