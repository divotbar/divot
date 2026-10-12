---
id: "0070"
title: "Wi-Fi popover: list nearby networks and the current one (read-only spike)"
type: feature
status: inbox
priority: p2
area: macos
depends_on: ["0069"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T18:53:13Z"
updated_at: "2026-10-12T18:53:13Z"
---
## Problem
Clicking the Wi-Fi item only opens a System Settings pane. The maintainer wants a popup/dropdown of the available Wi-Fi networks.

## Desired UX
- Clicking the Wi-Fi item opens a popover or menu anchored to the item, listing nearby networks (SSID, signal strength, lock icon for secured), with the current network marked.
- The last row is 'Open Wi-Fi Settings...' which opens the Wi-Fi pane (the fix from #0069).
- Read-only in this task: no joining networks, no password entry.
- Without Location permission, show a short message with a button to open the Location Services pane, instead of an empty list.

## Acceptance criteria
- Uses public CoreWLAN API only (CWWiFiClient / CWInterface.scanForNetworks), no private APIs, no permanent render loop: scan on open, not on a timer, off the main actor, with a timeout and an empty/error state.
- Scan logic sits behind a protocol seam so it is unit tested with fakes (sorting by signal, dedupe by SSID, current-network marking, permission-denied state).
- Dev builds (no Info.plist) show the permission/unavailable state cleanly.
- docs and site pages that describe the Wi-Fi item click are updated; the item stays optional per existing settings.
- In the task, record what CoreWLAN returned for hidden SSIDs and without permission; do not invent behaviour. Whether joining known networks is possible is a finding to write down, not to build.
- The maintainer verifies on the packaged app (Location granted) that real networks appear; say so as a human step.

## Notes for AI
Depends on #0069 for the Settings pane URL. Joining networks and password entry are explicitly out of scope; follow-up tasks will decide based on your findings.

## Activity

- 2026-10-12T18:53:13Z · created · njachowski@gmail.com
