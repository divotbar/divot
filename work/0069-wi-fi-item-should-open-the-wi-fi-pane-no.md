---
id: "0069"
title: "Wi-Fi item should open the Wi-Fi pane, not the generic Network pane"
type: bug
status: done
priority: p2
area: macos
merged_commit: 69484cb5571078b2f7f178417af6b6ebd1f4620f
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/wi-fi-item-should-open-the-wi-fi-pane-no
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-12T18:51:44Z"
updated_at: "2026-10-12T18:57:15Z"
last_close_out_gate_ms: 54607
last_close_out_gate_at: "2026-10-12T18:57:13.262Z"
review_passes: 1
---
## Problem
Clicking the Wi-Fi item opens System Settings > Network. WidgetSettingsPane.network (macos/Sources/DivotCore/WidgetActions.swift) builds x-apple.systempreferences:com.apple.preference.network, which was only a design-time candidate (see its doc comment) and lands on the generic Network page.

## Desired UX
- Clicking the Wi-Fi item opens System Settings > Wi-Fi directly.

## Acceptance criteria
- The network item opens the Wi-Fi pane via the macOS 13+ extension id (believed: x-apple.systempreferences:com.apple.wifi-settings-extension). The engineer must confirm the id against Apple documentation or a known-good source and say which in the task; do not guess.
- Fall back to the old Network pane URL if the new one cannot be opened.
- Unit test for the URL; docs updated if the click behaviour is documented.
- Maintainer confirms by clicking it on the packaged app (macOS 26): this needs a human check.

## Notes for AI
Only the network item's URL changes. Keep the sound/battery panes as they are.

## Verification
**Wi-Fi extension id** — confirmed against a known-good local source, not guessed: the identifier `com.apple.wifi-settings-extension` is the `CFBundleIdentifier` of `/System/Library/ExtensionKit/Extensions/Wi-Fi.appex` on this machine (macOS 26.5.2, build 25F84), read via `/usr/libexec/PlistBuddy`. The deep link is `x-apple.systempreferences:com.apple.wifi-settings-extension`.

**Implementation** — `WidgetSettingsPane.network.url` now returns that link; `WidgetSettingsPane.network.fallbackURL` returns the legacy `x-apple.systempreferences:com.apple.preference.network`. `DivotAppDelegate.perform(_:)` opens the primary link and, only when it returns `false`, opens the fallback. Sound/battery/date panes are unchanged.

**Tests** — `swift test` includes `networkPaneOpensTheWifiSettingsExtension` (exact URL) and `networkPaneFallsBackToTheLegacyNetworkPane` (fallback present only for network).

**Still human-only** — the maintainer must click the Wi-Fi item on the packaged app (macOS 26) to confirm the pane actually opens; no click was observed in this run.

## Activity

- 2026-10-12T18:51:44Z · created · njachowski@gmail.com
- 2026-10-12T18:51:47Z · status inbox→ready
- 2026-10-12T18:51:48Z · status ready→active, branch
- 2026-10-12T18:51:49Z · cli_override, model_override
- 2026-10-12T18:53:03Z · body: section Verification
- 2026-10-12T18:54:33Z · status active→review
- 2026-10-12T18:54:33Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T18:55:04Z · note: review pass 1: good to go
- 2026-10-12T18:57:13Z · close-out gate completed in 55s
- 2026-10-12T18:57:15Z · status review→done, release:success
