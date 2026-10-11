---
id: "0039"
title: "Ask for Location permission when the Wi-Fi name is turned on, and show an error when it is denied"
type: feature
status: review
priority: p1
area: macos
depends_on: ["0032"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/ask-for-location-permission-when-the-wi-
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-11T11:54:34Z"
updated_at: "2026-10-11T12:29:00Z"
review_passes: 4
review_rounds: 2
last_check_failure: "repoos check at 2026-10-11T12:08:42.383Z: repoos check failed: native-core — 􁁛 Test configureStopsRemovedProvidersAndStartsNewOnes() passed after 2.170 seconds."
---
## Problem

macOS hides the Wi-Fi network name from apps without Location Services permission. Divot never asks for that permission, so when "Show Wi-Fi network name" is on, the name silently stays hidden with no error. The maintainer expects Divot to ask, or to say clearly why the name is missing.

## Desired UX

- Turning on "Show Wi-Fi network name" asks for Location permission once, with a clear reason in the request text.
- If permission is granted, the name appears.
- If permission is denied or restricted, the Settings row shows a plain message ("Location permission is needed to show the Wi-Fi name") with a button that opens the Location Services pane in System Settings. The bar shows the icon only.
- No prompts appear unless the user has turned the toggle on.

## Acceptance criteria

- Add the location usage description to the app's Info.plist, and request authorization through CoreLocation only when the toggle is turned on.
- Track the authorization status and show the granted, denied and not-determined states in the Settings row.
- The bar reads the Wi-Fi name only while authorization is granted, and re-reads when the status changes.
- The denied state links to the Location Services pane. Open it through the public URL scheme; do not change any system setting.
- Tests cover each authorization state and the Settings message for each.
- Note in the task that the request needs the packaged app (dist/Divot.app) with its Info.plist; `swift run` may not show the prompt.
- `repoos check` passes. The maintainer confirms the prompt and the messages.

## Notes for AI
Depends on #0032, which added the Wi-Fi name. Keep the authorization logic in its own type behind the network reading, not in the view.

The location permission prompt only appears when the packaged app (dist/Divot.app) with its Info.plist is used. Running with `swift run` may not show the prompt because the runtime-generated bundle does not include the NSLocationWhenInUseUsageDescription key.

## Activity

- 2026-10-11T11:54:34Z · created · njachowski@gmail.com
- 2026-10-11T11:54:35Z · status inbox→ready
- 2026-10-11T11:54:35Z · status ready→active, branch
- 2026-10-11T12:02:43Z · body: section Notes for AI
- 2026-10-11T12:03:16Z · status active→review
- 2026-10-11T12:03:16Z · note: shots: skipped — the diff (10 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T12:03:54Z · note: review pass 1: needs some work
- 2026-10-11T12:03:54Z · status review→active
- 2026-10-11T12:09:22Z · status active→review
- 2026-10-11T12:09:22Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-11T12:09:57Z · note: review pass 2: needs some work
- 2026-10-11T12:09:57Z · status review→active
- 2026-10-11T12:12:39Z · status active→review
- 2026-10-11T12:12:40Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-11T12:13:32Z · note: review pass 3: needs some work
- 2026-10-11T12:13:32Z · needs_input
- 2026-10-11T12:20:16Z · needs_input
- 2026-10-11T12:20:16Z · status review→active
- 2026-10-11T12:20:16Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T12:21:42Z · status active→review
- 2026-10-11T12:21:43Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-11T12:22:40Z · note: review pass 4: needs some work
- 2026-10-11T12:22:40Z · needs_input
- 2026-10-11T12:24:30Z · cli_override, model_override
- 2026-10-11T12:24:30Z · needs_input
- 2026-10-11T12:24:30Z · status review→active
- 2026-10-11T12:24:30Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T12:29:00Z · status active→review
