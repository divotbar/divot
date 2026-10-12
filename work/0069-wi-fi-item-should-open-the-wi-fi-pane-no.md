---
id: "0069"
title: "Wi-Fi item should open the Wi-Fi pane, not the generic Network pane"
type: bug
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/wi-fi-item-should-open-the-wi-fi-pane-no
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-12T18:51:44Z"
updated_at: "2026-10-12T18:51:49Z"
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

## Activity

- 2026-10-12T18:51:44Z · created · njachowski@gmail.com
- 2026-10-12T18:51:47Z · status inbox→ready
- 2026-10-12T18:51:48Z · status ready→active, branch
- 2026-10-12T18:51:49Z · cli_override, model_override
