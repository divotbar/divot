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
updated_at: "2026-10-14T04:33:10Z"
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

## Evidence
Shots re-captured on the final HEAD, the merge of `main` (commit `07f68749`). The `Divot bar` target ran with `DIVOT_SNAPSHOT_ONLY=worldclock` under the reduced `DIVOT_SNAPSHOT_SET=shots`, so each state is captured in Native and Gruvbox, light and dark (the `-2` filenames).

**At now — `worldclock-popover-{native,gruvbox}-{light,dark}-default-defaults-2.png`**
- Header reads the current local time and zone (captured `11:29 UTC+7` / `Jakarta`); the scrubber thumb sits at the current minute with its `11:29` label, and the **Now** control is greyed out because the converter is un-scrubbed.
- Rows convert at that instant: San Francisco `21:29 (14 h behind) Yesterday` with a moon, London `05:29 (6 h behind)` with a moon, Singapore `12:29 (1 h ahead)` with a sun. The sun/moon marker shows each zone's fixed 09:00–18:00 local working window at a glance.
- Native and Gruvbox differ only in palette (Native neutral grey; Gruvbox warm sepia light / warm brown dark); layout and content are identical.

**Scrubbed — `worldclock-popover-{native,gruvbox}-{light,dark}-default-scrubbed-2.png`**
- The scrubber is moved to `22:00 UTC+0` (`GMT`): the thumb sits near the right end and the **Now** control is enabled.
- Every row shows the converted instant with a day boundary in one view: Kiritimati `12:00 (14 h ahead) Tomorrow` (sun), Midway `11:00 (11 h behind)` (sun), Tokyo `07:00 (9 h ahead) Tomorrow` (moon), San Francisco `14:00 (8 h behind)` (sun) — a mix of sun and moon markers plus Tomorrow labels.
- Same palette difference across Native and Gruvbox, light and dark.

The offscreen pixel assertions also ran on every render (opaque palette fill, leading-edge alignment, text contrast ≥ 4, no clipping), and the marker tint clears the 3:1 non-text floor in every family and mode.

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
- 2026-10-14T04:31:01Z · body: section Evidence
- 2026-10-14T04:32:16Z · status active→review
- 2026-10-14T04:32:16Z · note: shots: skipped — 8 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-14T04:33:10Z · note: review pass 2: needs some work
