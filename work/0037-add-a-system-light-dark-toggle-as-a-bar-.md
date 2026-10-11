---
updated_at: "2026-10-11T01:00:28Z"
review_passes: 1
id: "0037"
title: Add a system light/dark toggle as a bar item
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-system-light-dark-toggle-as-a-bar-
created_at: "2026-10-11T00:41:48Z"
handoff_signal_retry_count: 1
---
## Problem

The maintainer wants a bar item that switches the macOS system appearance between light and dark, from the bar.

## Desired UX

- A new bar item, "Appearance", that shows the current mode (a sun or moon glyph) and toggles system light/dark on click.
- The item can be placed on either side and enabled or disabled in the bar items list, like the other items.
- The item uses the public appearance API; no private settings are touched.

## Acceptance criteria

- Add an `appearance` bar item with an enable toggle and side placement, consistent with the other items.
- Clicking the item switches the system appearance through the public API and the item updates to match.
- Tests cover the state mapping (light, dark) and the click action routing.
- The toggle does not change any other system setting. Verify on the packaged app; the maintainer confirms the look.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep the appearance read and write behind a small provider so the view stays a pure display.

## Activity

- 2026-10-11T00:41:48Z · created · njachowski@gmail.com
- 2026-10-11T00:43:56Z · status inbox→ready
- 2026-10-11T00:43:57Z · status ready→active, branch
- 2026-10-11T00:59:33Z · status active→review
- 2026-10-11T00:59:33Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T01:00:28Z · note: review pass 1: needs some work

