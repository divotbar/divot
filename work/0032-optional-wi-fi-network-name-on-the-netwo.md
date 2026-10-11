---
id: "0032"
title: Optional Wi-Fi network name on the network item in Settings
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-wi-fi-network-name-on-the-netwo
created_at: "2026-10-11T00:39:24Z"
updated_at: "2026-10-11T00:52:18Z"
---
## Problem

The network item shows a Wi-Fi icon but not the network name. The maintainer wants the name shown when it's wanted.

## Desired UX

- Settings has a "Show Wi-Fi network name" toggle, off by default.
- When on, the network item shows the current Wi-Fi network name beside the icon.
- When the name is unavailable, the item shows the icon only, without an error.

## Acceptance criteria

- Add a `showWifiName` configuration key (default false), persisted through the configuration store, with a toggle in the settings window.
- Read the current network name using a public API. Do not shell out to private tools. Handle permission or unavailable states quietly.
- Tests cover the default, the label with and without a name, and the unavailable state.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep the network reading in its own provider, not in the view.

## Activity

- 2026-10-11T00:39:24Z · created · njachowski@gmail.com
- 2026-10-11T00:43:53Z · status inbox→ready
- 2026-10-11T00:43:54Z · status ready→active, branch
- 2026-10-11T00:52:18Z · status active→review
