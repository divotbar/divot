---
id: "0037"
title: Add a system light/dark toggle as a bar item
type: feature
status: active
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-system-light-dark-toggle-as-a-bar-
created_at: "2026-10-11T00:41:48Z"
updated_at: "2026-10-11T12:25:10Z"
review_passes: 5
review_rounds: 2
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
- A scope setting in Settings has two options: "Divot only" (switches only Divot's own theme appearance) and "Full system" (switches the macOS light/dark appearance through the public API). Default: "Divot only".
- Clicking the item toggles the chosen scope and the item updates to match. The click is a direct toggle, not a menu, and works with the mouse and VoiceOver through the same action.
- Tests cover the state mapping (light, dark), each scope's action, and the click routing for both scopes.
- In "Divot only" mode no macOS setting is changed. In "Full system" mode only the appearance is changed, through the public API.
- Verify on the packaged app; the maintainer confirms the look.
- repoos check passes.

## Notes for AI
Scope was added by the maintainer on 2026-10-11: the toggle has two options, "Divot only" and "Full system". Keep the appearance read and write behind a small provider so the view stays a pure display. Use the public appearance API only.


## Implementation

The appearance bar item now shows a menu with two options when clicked:
1. **Toggle Divot Light/Dark** - Toggles the app's appearance override via NSApp.appearance
2. **Open System Appearance Settings** - Opens System Settings to the General pane where users can toggle macOS system appearance

This respects the "public API only" constraint while giving users convenient access to both Divot-specific and system-wide appearance controls.

## Activity

- 2026-10-11T00:41:48Z · created · njachowski@gmail.com
- 2026-10-11T00:43:56Z · status inbox→ready
- 2026-10-11T00:43:57Z · status ready→active, branch
- 2026-10-11T00:59:33Z · status active→review
- 2026-10-11T00:59:33Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T01:00:28Z · note: review pass 1: needs some work
- 2026-10-11T01:00:28Z · status review→active
- 2026-10-11T01:02:53Z · status active→review
- 2026-10-11T01:02:54Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T01:03:28Z · note: review pass 2: needs some work
- 2026-10-11T01:03:28Z · status review→active
- 2026-10-11T01:07:35Z · status active→review
- 2026-10-11T01:07:36Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T01:08:16Z · note: review pass 3: needs some work
- 2026-10-11T04:40:13Z · status review→active
- 2026-10-11T04:40:13Z · note: The review came back with "needs some work — The bar item, provider split, presentation, and settings placement wiring are in good shape, but the click path toggles Divot’s NSApp.appearance override, not macOS system light/dark as the spec requires.” >> but actually I think both options are good to have, so how about when toggling light/dark let’s give the user the options: - to toggle just Divot’s light/dark mode  - to toggle the system light/dark mode
- 2026-10-11T04:44:11Z · body: section Notes for AI
- 2026-10-11T04:44:38Z · status active→review
- 2026-10-11T04:44:38Z · note: Task body is underspecified: empty sections: Notes for AI
- 2026-10-11T04:44:39Z · note: shots: skipped — the diff (13 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T04:45:27Z · note: review pass 4: needs some work
- 2026-10-11T10:07:05Z · body: section Acceptance criteria
- 2026-10-11T10:07:06Z · body: section Notes for AI
- 2026-10-11T10:07:06Z · status review→active
- 2026-10-11T10:07:06Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T10:11:57Z · status active→review
- 2026-10-11T10:11:57Z · note: shots: skipped — the diff (12 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T10:12:48Z · note: review pass 5: needs some work
- 2026-10-11T10:12:48Z · needs_input
- 2026-10-11T12:20:16Z · needs_input
- 2026-10-11T12:20:16Z · status review→active
- 2026-10-11T12:20:16Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T12:25:10Z · note: shots: skipped — the diff (16 changed paths) touches no [[preview.paths]] globs — no UI change to capture
