---
id: "0099"
title: "Wi-Fi popover: clickable networks, faster first paint, and a scanning state that is clearly in progress"
type: feature
status: ready
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
model_override: opencode-go/muse-spark-1.3-contributor
created_at: "2026-10-14T07:17:58Z"
updated_at: "2026-10-14T07:39:46Z"
---
## Problem
The Wi-Fi popover has three UX problems, measured on this Mac:

1. Entries are not clickable, so the user cannot switch networks from the popover.
2. Opening the popover shows only 'Scanning for networks...' as static text for the whole scan. The first scan takes about 5.6 s here (later scans return in about 0.02 s, because the system has cached results), and the popover times out at 8 s. Nothing moves in that time, so the popover looks broken.
3. The popover never shows anything before the scan finishes, even though the list could start with what is already known.

## Desired UX
- Each network row is clickable. Clicking an in-range network connects to it; the popover shows 'Connecting...' and then the new current network, or the macOS error. A secured network that is not saved asks for its password in a Divot-styled dialog (never a plain text field in the bar), then connects. The current network stays marked.
- On open, if the last completed scan finished within the past 10 minutes, show that cached list immediately, with 'Updated Xs ago'. Run the live scan in the background at the same time and update the list in place when it finishes. Scan on every open, regardless of cache age.
- Previously joined networks are shown differently from in-range networks, so the user can see past networks at a glance. Use a clearly separate group or row style (for example a 'Previously joined' section or a muted row with a clock icon). Tell apart 'in range now' from 'joined before, not in range now'.
- Do NOT list all saved profiles. The system holds about 211 saved profiles on this Mac, which is too many for the list. Only show previously joined networks that Divot has connected to itself, capped to a short recent list, for example the last 5. Record each successful connect Divot makes, with its time, in Divot's own state.
- While scanning, show a subtle animation (for example a pulsing signal icon or a shimmer row) rather than static text.
- Scan timeout: 20 seconds (raised from 8), so a slow scan still finishes. The cached list stays visible until the scan completes or times out.

## Acceptance criteria
- Clicking an in-range network connects to it; the popover shows 'Connecting...' and then the new current network, or an error message from macOS.
- A secured, unsaved network asks for its password through a Divot-styled dialog; the password is never written to Divot's config or logs.
- If the last scan finished within 10 minutes, the popover shows that cached list at once, with 'Updated Xs ago'; a live scan always runs in the background on open and updates the list in place.
- Previously joined networks (only those Divot has connected to, capped to a short recent list) appear in a visibly separate group or style from in-range networks. Saved system profiles are not listed.
- The scan timeout is 20 seconds.
- The scanning state animates; the static text is gone.
- In-app timing is measured (popover open to first list shown, and to live list shown) and recorded in the task.
- Tests use a fake scanner and a fake connector; no test joins a real network or prompts for a password.
- docs/ and site/ pages describing the Wi-Fi item are updated.

## Measurements (this Mac, macOS 26.5.2)
- CWInterface.scanForNetworks, first call in a standalone process: 5.57 s, 11 networks.
- Second and third calls in the same standalone process: 0.02 s, 26 networks. This does NOT match the maintainer's experience in the app, where each open takes about 5-7 s. The engineer must measure in-app timing (popover open to list shown) before relying on any fast-path numbers.
- CWInterface.configuration().networkProfiles returns 211 saved profiles on this Mac. These are not a usable list (see Desired UX).

## Notes for AI
The popover is macos/Sources/DivotAppKit/WifiPopover.swift; the scanner is WifiNetworkScanner.swift (CoreWLAN, 8 s timeout, one scan per open); the list shaping is macos/Sources/DivotCore/WifiNetworks.swift. Connecting needs a CoreWLAN associate call and a Location gate for network names, which the scanner already checks. Joining a network changes system state, so the connect path needs a fake in tests and a clear manual check by the maintainer. Screenshots from the maintainer are attached: 1 shows the list with the current network checked and lock icons; 2 shows the 'Scanning for networks...' state.

## Screenshots

![10](/api/tasks/0099/attachments/screenshot-1.png)
![11](/api/tasks/0099/attachments/screenshot-2.png)

## Measurements
Merged into the section above.

## Activity

- 2026-10-14T07:17:58Z · created · njachowski@gmail.com
- 2026-10-14T07:17:58Z · screenshots
- 2026-10-14T07:28:55Z · body: section Desired UX
- 2026-10-14T07:28:55Z · body: section Measurements
- 2026-10-14T07:29:06Z · body: section Measurements (this Mac, macOS 26.5.2)
- 2026-10-14T07:29:06Z · body: section Measurements
- 2026-10-14T07:29:12Z · body: section Acceptance criteria
- 2026-10-14T07:39:42Z · model_override
- 2026-10-14T07:39:46Z · status inbox→ready
