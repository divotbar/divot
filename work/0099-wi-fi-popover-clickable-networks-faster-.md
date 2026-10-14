---
id: "0099"
title: "Wi-Fi popover: clickable networks, faster first paint, and a scanning state that is clearly in progress"
type: feature
status: inbox
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-14T07:17:58Z"
updated_at: "2026-10-14T07:17:58Z"
---
## Problem
The Wi-Fi popover has three UX problems, measured on this Mac:

1. Entries are not clickable, so the user cannot switch networks from the popover.
2. Opening the popover shows only 'Scanning for networks...' as static text for the whole scan. The first scan takes about 5.6 s here (later scans return in about 0.02 s, because the system has cached results), and the popover times out at 8 s. Nothing moves in that time, so the popover looks broken.
3. The popover never shows anything before the scan finishes, even though the list could start with what is already known.

## Desired UX
- Each network row is clickable. Clicking a saved or open network connects to it; a secured network that is not saved asks for its password in a Divot-styled dialog (never a plain text field in the bar), then connects. The current network stays marked.
- Show something immediately on open: the last completed scan (with 'Updated Xs ago') and the saved networks from the system, marked as 'not checked' until the scan confirms them in range. The scan then updates the list in place.
- While scanning, show a subtle animation (for example a pulsing signal icon or a shimmer row) rather than static text, so the user can see work is in progress. Keep the 8 s timeout, but show the cached list in the meantime.

## Acceptance criteria
- Clicking an in-range network connects to it; the popover shows 'Connecting...' and then the new current network, or an error message from macOS.
- A secured, unsaved network asks for its password through the dialog; the password is never written to Divot's config or logs.
- Opening the popover shows the last scan result or saved networks within 100 ms, and the list updates when the scan finishes.
- The scanning state animates; the static text is gone.
- Tests use a fake scanner and a fake connector; no test joins a real network or prompts for a password.
- docs/ and site/ pages describing the Wi-Fi item are updated.

## Measurements (this Mac, macOS 26.5.2)
- CWInterface.scanForNetworks, first call: 5.57 s, 11 networks.
- Second and third calls: 0.02 s, 26 networks.
- CWInterface.configuration().networkProfiles: 211 saved profiles, readable without a scan. These show saved networks, not which are in range.

## Notes for AI
The popover is macos/Sources/DivotAppKit/WifiPopover.swift; the scanner is WifiNetworkScanner.swift (CoreWLAN, 8 s timeout, one scan per open); the list shaping is macos/Sources/DivotCore/WifiNetworks.swift. Connecting needs a CoreWLAN associate call and a Location gate for network names, which the scanner already checks. Joining a network changes system state, so the connect path needs a fake in tests and a clear manual check by the maintainer. Screenshots from the maintainer are attached: 1 shows the list with the current network checked and lock icons; 2 shows the 'Scanning for networks...' state.

## Screenshots

![10](/api/tasks/0099/attachments/screenshot-1.png)
![11](/api/tasks/0099/attachments/screenshot-2.png)

## Activity

- 2026-10-14T07:17:58Z · created · njachowski@gmail.com
- 2026-10-14T07:17:58Z · screenshots
