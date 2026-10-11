---
updated_at: "2026-10-11T13:14:15Z"
review_passes: 8
id: "0037"
title: Add a system light/dark toggle as a bar item
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-system-light-dark-toggle-as-a-bar-
created_at: "2026-10-11T00:41:48Z"
check_retry_count: 1
last_check_failure: "repoos check at 2026-10-11T13:13:43.330Z: repoos check failed: native-core — 􁁛 Test configureKeepsUnchangedProvidersRunning() passed after 2.277 seconds."
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
- Clicking the item toggles Divot's own bar theme between light and dark. It does not change the macOS system appearance.
- The click is a direct toggle, not a menu, and works with the mouse and VoiceOver through the same action.
- The current mode is shown on the item (sun or moon glyph) and updates when toggled.
- Tests cover the state mapping (light, dark), the click action, and the Settings persistence of the chosen mode.
- No macOS setting is changed. No AppleScript, System Events or private API is used.
- Verify on the packaged app; the maintainer confirms the look.
- repoos check passes.

## Notes for AI
Rescoped by the maintainer on 2026-10-11: the item only toggles Divot's own bar theme light/dark. There is no public macOS API to change the system appearance, so the "Full system" scope and its AppleScript path are removed. Keep the theme read and write behind a small provider so the view stays a display.


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
- 2026-10-11T12:25:11Z · status active→review
- 2026-10-11T12:25:11Z · note: shots: skipped — the diff (16 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T12:25:55Z · note: review pass 6: needs some work
- 2026-10-11T12:25:55Z · needs_input
- 2026-10-11T12:42:35Z · needs_input
- 2026-10-11T12:42:35Z · status review→active
- 2026-10-11T12:42:35Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T12:44:29Z · status active→review
- 2026-10-11T12:44:29Z · note: shots: skipped — the diff (17 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T12:45:13Z · note: review pass 7: needs some work
- 2026-10-11T12:45:14Z · needs_input
- 2026-10-11T13:08:53Z · body: section Acceptance criteria
- 2026-10-11T13:08:54Z · body: section Notes for AI
- 2026-10-11T13:08:54Z · needs_input
- 2026-10-11T13:08:54Z · status review→active
- 2026-10-11T13:08:54Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T13:13:17Z · status active→review
- 2026-10-11T13:13:17Z · note: shots: skipped — the diff (13 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:14:15Z · note: review pass 8: needs some work
- 2026-10-11T13:14:15Z · needs_input

