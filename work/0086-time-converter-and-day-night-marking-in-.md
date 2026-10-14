---
id: "0086"
title: Time converter and day/night marking in the world clock popover
type: feature
status: review
priority: p3
area: macos
depends_on: ["0085"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/time-converter-and-day-night-marking-in-
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T13:29:21Z"
updated_at: "2026-10-14T04:32:15Z"
review_rounds: 1
review_passes: 1
---
## Problem
#0085 shows the current time in the user's chosen timezones. The next question people ask is 'what is 9 am my time over there', and whether it is a sensible hour to call.

## Desired UX
- In the world clock popover, a time scrubber (or a typed time field) lets the user pick any time of day on any date (default: now). While scrubbing, every row shows the equivalent local time in its timezone and its day label; a 'Now' control resets.
- Each row shows a small sun or moon marker, or dims outside 09:00-18:00 local, so working hours are visible at a glance; the working-hours range is fixed (09-18) in the first version.
- Left-aligned, solid theme-based panel, keyboard accessible (arrow keys adjust the scrubber in 15-minute steps) and VoiceOver labelled.

## Acceptance criteria
- Conversion and day/night logic in DivotCore behind the injectable clock/TimeZone seam, unit tested: conversions across the date line and DST changes, 15-minute stepping, day labels, marker thresholds at the boundaries.
- Public Foundation APIs only, no network or location permission, no extra timers.
- Contrast audit passes for the new elements in every family and mode; layout assertions via the offscreen snapshot helpers.
- VERIFY WITH SHOTS using the Divot bar target: capture the popover at now and at a scrubbed time with a day-boundary row; describe what each image shows.
- docs/ and site/ updated; the maintainer verifies by eye on the packaged app.

## Notes for AI
Builds on #0085; reuse its list model and popover layout. Do not add sunrise/sunset computation (needs location).

## Shots
```json
[
{
"label": "World clock popover at now: sun/moon working-hours markers and the scrubber at the current minute",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "worldclock"
},
"glob": "*worldclock*default-defaults.png"
},
{
"label": "World clock popover scrubbed to 22:00 UTC: a day-boundary row (Kiritimati/Tokyo Tomorrow), a mix of sun and moon markers, and the enabled Now control",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "worldclock"
},
"glob": "*worldclock*scrubbed.png"
}
]
```

## Activity

- 2026-10-13T13:29:21Z · created · njachowski@gmail.com
- 2026-10-13T19:09:06Z · status inbox→ready
- 2026-10-14T03:55:12Z · cli_override, model_override
- 2026-10-14T03:55:12Z · status ready→active, branch
- 2026-10-14T04:12:47Z · body: section Shots
- 2026-10-14T04:20:17Z · status active→review
- 2026-10-14T04:21:20Z · note: review pass 1: needs some work
- 2026-10-14T04:21:20Z · message_queued at 2026-10-14T04:21:20.849Z
- 2026-10-14T04:21:20Z · status review→active
- 2026-10-14T04:24:25Z · message_delivered: 1 message(s)
- 2026-10-14T04:32:15Z · status active→review
