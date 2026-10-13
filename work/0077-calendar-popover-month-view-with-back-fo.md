---
id: "0077"
title: "Calendar popover: month view with back/forward and today highlighted, opened from the date chip"
type: feature
status: ready
priority: p2
area: macos
depends_on: ["0076"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T05:58:05Z"
updated_at: "2026-10-13T06:25:23Z"
---
## Problem
Clicking the date item currently only opens a System Settings pane. The maintainer wants a calendar popup, as in the macOS menu bar clock, to glance at other days and months.

## Desired UX
- Clicking the date chip opens a popover anchored to the chip, in the same style and using the same shared popover component as the Wi-Fi, Volume and Appearance popovers (solid theme-based background, left-aligned, #0076).
- The popover shows a whole month grid: the month and year as a heading, weekday header row, and the days laid out in weeks, with trailing and leading days of adjacent months shown dimmed.
- Back and forward buttons (chevrons) move one month at a time; a 'Today' control jumps back to the current month. The first weekday and weekday names follow the user's locale and system calendar settings; do not hard-code Monday or Sunday.
- Today's date is clearly highlighted with the theme accent (readable contrast against the solid background).
- Opening the popover always starts on the current month. It rolls over correctly at midnight and across year ends.
- Last row: 'Open Date & Time Settings...' opens the Date & Time pane, matching the other popovers' footer rows.
- The time chip keeps its current behaviour.

## Acceptance criteria
- Month and week layout logic lives in DivotCore behind a pure, injectable Calendar/Date seam and is unit tested: month lengths including February and leap years, week start in several locales/first-weekday values, month navigation across year boundaries, today detection, and leading/trailing day padding to full weeks.
- Public Foundation Calendar/DateFormatter APIs only. No EventKit and no calendar permission: showing events or reminders is out of scope. No timer polling: refresh the 'today' highlight when the popover opens and on the existing day-change/clock notifications if they exist.
- Colours and alignment come from theme tokens and the shared popover component, and pass the existing contrast audit for every theme family in light and dark (heading, weekday labels, day numbers, dimmed days, today highlight, links).
- Keyboard accessible and VoiceOver friendly: arrow keys move between days or months as practical, buttons have accessibility labels ('Previous month', 'Next month', 'Today'), and today is announced.
- Outside-click, Escape and click-again-to-close behaviour matches the other popovers.
- The click behaviour change is documented in docs/ and the matching site/ pages (widgets guide, configuration reference if the click action is described there); the item stays optional per existing settings.
- The maintainer checks the final look by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
Start after #0076 lands so the shared popover component and its styling are stable. Look at the existing clock/date widgets and how #0070/#0071/#0072 built their popovers and fake-backed tests.

## Activity

- 2026-10-13T05:58:05Z · created · njachowski@gmail.com
- 2026-10-13T06:25:22Z · status inbox→ready
- 2026-10-13T06:25:23Z · cli_override, model_override
