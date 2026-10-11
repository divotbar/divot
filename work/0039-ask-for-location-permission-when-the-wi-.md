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
created_at: "2026-10-11T11:54:34Z"
updated_at: "2026-10-11T12:03:16Z"
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

## Activity

- 2026-10-11T11:54:34Z · created · njachowski@gmail.com
- 2026-10-11T11:54:35Z · status inbox→ready
- 2026-10-11T11:54:35Z · status ready→active, branch
- 2026-10-11T12:03:16Z · status active→review
