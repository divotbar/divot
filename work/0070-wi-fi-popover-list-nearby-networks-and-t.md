---
id: "0070"
title: "Wi-Fi popover: list nearby networks and the current one (read-only spike)"
type: feature
status: review
priority: p2
area: macos
depends_on: ["0069"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/wi-fi-popover-list-nearby-networks-and-t
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-12T18:53:13Z"
updated_at: "2026-10-12T19:15:21Z"
handoff_signal_retry_count: 1
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

## Verification
**Implementing pieces** — `DivotCore.WifiNetworks` (pure dedupe/mark/sort and the `WifiScanState` mapping), the `WifiNetworkScanning` seam and `WifiScanModel`, `DivotAppKit.CoreWLANNetworkScanner` (public CoreWLAN only, own serial queue, 8s timeout race, permission gate), `WifiPopover.swift` (AppKit `NSPopover`, read-only, last row opens the Wi-Fi pane via the #0069 link), and the network-item interception in `BarContentView`. The `locationServices` pane was added to `WidgetSettingsPane` for the permission message button.

**Tests** — `swift test --package-path macos`: 660 tests pass. `WifiNetworksTests` covers dedupe keeping the strongest duplicate, a signal tie keeping the secure entry, dropping blank/hidden SSIDs, marking and pinning the current network, signal-descending sort, the dBm-to-bars bands, every response mapping to its honest state, and the scan model through a fake scanner seam. The Location Services deep link is pinned.

**CoreWLAN observations (findings, not device validation)** — a local probe on the authoring machine (macOS 26.5, a non-bundled command-line process, `CLLocationManager.authorizationStatus == .notDetermined`) returned `CWInterface.ssid() == nil` while `scanForNetworks(withSSID: nil)` still returned 19 named results. That is one observation; it does not establish whether TCC attributed the scan to a parent process that holds Location. It does show the environment produces the intended dev-build path: with no authorization the scanner gate returns `.permissionDenied`, so the popover shows the permission message instead of an empty list.

**Hidden SSIDs** — CoreWLAN reports a hidden network with a `nil`/empty `ssid`; the scanner drops those and `WifiNetworks` drops a blank name again. No hidden AP appeared in the local probe, so this path is asserted by unit tests only, not observed against a real hidden network.

**Joining known networks (a finding to record, not build)** — the public CoreWLAN header exposes `CWInterface.associate(to:password:)` (macOS 10.7+) and `associate(toEnterpriseNetwork:identity:username:password:)`, so the API surface exists; whether it works for an unsandboxed app without extra entitlements is unverified. Credential prompting, keychain use, and failure UX are a follow-up decision. This task ships read-only.

**Human step** — the maintainer must verify on the packaged app with Location granted that the network item opens the popover and real nearby networks appear with the current one marked; and with Location denied, that the permission message and its Location Services button appear. No click or on-screen popover was observed in this run.

## Activity

- 2026-10-12T18:53:13Z · created · njachowski@gmail.com
- 2026-10-12T18:57:18Z · status inbox→ready
- 2026-10-12T18:57:19Z · status ready→active, branch
- 2026-10-12T18:57:19Z · cli_override, model_override
- 2026-10-12T19:13:09Z · body: section Verification
- 2026-10-12T19:14:35Z · status active→review
- 2026-10-12T19:14:35Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T19:15:21Z · note: review pass 1: good to go
