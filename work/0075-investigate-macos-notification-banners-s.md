---
id: "0075"
title: "Investigate: macOS notification banners sit under the Divot bar"
type: bug
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/investigate-macos-notification-banners-s
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T05:46:47Z"
updated_at: "2026-10-13T05:54:51Z"
---
## Problem
Maintainer screenshot 2026-10-13: a Chrome/Google Calendar notification banner appears at the top right with its top edge tucked under the Divot bar (its title row is partly covered). The native menu bar is hidden, and macOS places banners just below the menu bar area, which Divot now occupies.

## Goal
Find out why, and whether Divot can avoid hiding banner content. This is an investigation first: report findings, then implement a fix only if a public, reliable one exists.

## Questions to answer (record answers in the task)
- What window level, collection behaviour and ignoresMouseEvents does the Divot panel use today (BarPanels.swift), and what are the levels of the notification banner window (check with CGWindowListCopyWindowInfo for the Notification Center process while a banner shows)?
- Is the banner positioned using the menu bar height macOS believes is present (hidden native bar means it starts at the very top), so Divot necessarily overlaps it? Does the overlap also occur when the native menu bar is revealed?
- Can the panel be ordered below banners (a lower window level) without losing its place above normal app windows and fullscreen behaviour decided in #0009/#0023?
- Is there any public API to offset or reserve space for notification banners (expected: no)? Say what you tried.

## Acceptance criteria
- A short written finding with evidence (window levels, screenshots only if you can capture them, otherwise describe) added to docs/evidence/ and linked from the task.
- If a safe fix exists (for example a level that keeps Divot above app windows but below banners, or other public behaviour), implement it behind a tested seam, with unit tests for the level selection, and update docs/ and site/ pages that describe window behaviour.
- If no fix is possible, document the limitation in docs/troubleshooting and the site troubleshooting page with the honest reason, and propose options (for example an optional setting) as a follow-up in the task, not implemented.
- No private APIs, no event taps beyond what Divot already uses, no polling loop.
- The maintainer verifies by eye on the packaged app with a real notification; do not claim visual sign-off.

## Notes for AI
Related decisions: bar placement is the top edge when the native menu bar is hidden (#0021/#0023); Divot hugs the notch (#0028). Do not break those.

## Activity

- 2026-10-13T05:46:47Z · created · njachowski@gmail.com
- 2026-10-13T05:46:53Z · status inbox→ready
- 2026-10-13T05:46:54Z · cli_override, model_override
- 2026-10-13T05:46:55Z · status ready→active, branch
- 2026-10-13T05:54:51Z · status active→review
