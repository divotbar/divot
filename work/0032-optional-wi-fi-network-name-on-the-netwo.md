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
updated_at: "2026-10-11T04:40:37Z"
close_out_repair_count: 2
review_passes: 3
review_rounds: 1
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
- 2026-10-11T00:52:19Z · status active→review
- 2026-10-11T00:52:19Z · note: shots: skipped — the diff (9 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:53:00Z · note: review pass 1: needs some work
- 2026-10-11T00:53:00Z · status review→active
- 2026-10-11T00:59:06Z · status active→review
- 2026-10-11T00:59:06Z · note: shots: skipped — the diff (14 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:59:55Z · note: review pass 2: good to go
- 2026-10-11T01:11:27Z · status review→active
- 2026-10-11T01:11:27Z · note: close-out repair: merge-conflict
- 2026-10-11T01:14:52Z · status active→review
- 2026-10-11T01:14:52Z · note: shots: skipped — the diff (14 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T01:15:32Z · note: review pass 3: good to go
- 2026-10-11T04:37:46Z · status review→active
- 2026-10-11T04:37:46Z · note: close-out repair: merge-conflict
- 2026-10-11T04:40:37Z · status active→review
