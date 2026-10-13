---
updated_at: "2026-10-13T14:40:23Z"
review_passes: 3
id: "0085"
title: "World clock popover on the time chip: your timezones with day label and hour difference"
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-popover-on-the-time-chip-you
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T13:29:11Z"
review_rounds: 2
last_check_failure: "repoos check at 2026-10-13T13:40:12.423Z: repoos check failed: native-core — 􁁛 Test configureReplacesAProviderWhoseActivationChanged() passed after 8.044 seconds."
---
## Problem
Clicking the time chip only opens a System Settings pane. The date chip now opens a useful calendar (#0077); the time chip needs something equally useful. The maintainer lives in Jakarta and often needs the time in California (and others).

## Desired UX
- Clicking the TIME chip (the date chip keeps the calendar) opens a popover in the same style as the Wi-Fi, Volume, Appearance and Calendar popovers (shared solid, left-aligned, theme-based panel; outside-click and Escape dismissal).
- Top: the local time and date with the UTC offset and the timezone name.
- Below: the user's added timezones, one per row, left-aligned: city/zone name, its current time, a day label only when the day differs from local (Yesterday / Tomorrow), and the hour difference from local (for example '14 h behind'; show half-hour offsets correctly, e.g. India).
- 'Add timezone...' row with a search field (city or IANA identifier such as America/Los_Angeles, using TimeZone.knownTimeZoneIdentifiers); each added row has a remove control. Keyboard accessible and VoiceOver labelled.
- The time format follows the existing time-format settings (#0035, 12 or 24 hour, seconds option).
- Last row: 'Open Date & Time Settings...'.
- The saved list lives in the config (for example widgets.clock.timezones, an ordered array of IANA identifiers, default empty) and appears in the config CLI schema (divot config schema) and the Settings window; invalid identifiers are rejected with a clear error and ignored on load without breaking the config.

## Acceptance criteria
- Pure logic in DivotCore behind an injectable clock/TimeZone seam, unit tested: offset and day-label computation across the date line, daylight saving transitions, half-hour and 45-minute offsets, ordering, duplicates removed, invalid identifiers dropped, time format variants.
- Public Foundation APIs only; no network, no location permission, no timer polling beyond the existing clock tick (refresh while the popover is open uses the existing minute/second tick).
- Colours and alignment come from theme tokens and the shared popover component and pass the existing contrast audit for every family (including Alpine) in light and dark.
- Config key added to the schema, parser, store, Settings UI control (add/remove list) and docs; the config CLI reads and writes it.
- VERIFY WITH SHOTS: declare ## Shots with target 'Divot bar'; extend the offscreen snapshot set so the popover renders with zero, two and four added timezones including one with a day label; LOOK at the captured images and describe what each shows. Say honestly what offscreen shots do not prove.
- docs/ and site/ pages (widgets guide, configuration reference, themes if applicable) updated; the item stays optional per existing settings; swift test --package-path macos passes.
- The maintainer verifies by eye on the packaged app; do not claim visual sign-off.

## Screenshots
Maintainer screenshot 2026-10-13 20:26: the current bar with the time chip (20:26), date chip and the bolt-only green charging battery. The time chip is the click target for this task.

![Bar with time chip](/api/tasks/0085/attachments/screenshot-1.png)

## Notes for AI
Reuse the shared popover component and the time-format helpers; follow the patterns of #0070-#0077 and #0083. Do not use sunrise/sunset or any location API. The time-converter scrubber and day/night marking are a separate follow-up task.

## Activity

- 2026-10-13T13:29:11Z · created · njachowski@gmail.com
- 2026-10-13T13:29:21Z · body: section Screenshots
- 2026-10-13T13:29:22Z · status inbox→ready
- 2026-10-13T13:29:23Z · cli_override, model_override
- 2026-10-13T13:29:23Z · status ready→active, branch
- 2026-10-13T13:49:17Z · message_queued at 2026-10-13T13:49:17.753Z
- 2026-10-13T13:49:17Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T14:26:00Z · message_delivered: 1 message(s)
- 2026-10-13T14:30:04Z · status active→review
- 2026-10-13T14:31:50Z · note: review pass 1: needs some work
- 2026-10-13T14:31:51Z · status review→active
- 2026-10-13T14:34:49Z · status active→review
- 2026-10-13T14:34:55Z · note: shots: skipped — 24 handoff shots already captured for this exact plan (53aba6b) during finalization (#0734)
- 2026-10-13T14:36:07Z · note: review pass 2: needs some work
- 2026-10-13T14:36:07Z · status review→active
- 2026-10-13T14:37:34Z · message_queued at 2026-10-13T14:37:34.961Z
- 2026-10-13T14:38:51Z · status active→review
- 2026-10-13T14:38:56Z · note: shots: skipped — 24 handoff shots already captured for this exact plan (14b941e) during finalization (#0734)
- 2026-10-13T14:40:23Z · note: review pass 3: needs some work
- 2026-10-13T14:40:23Z · needs_input

