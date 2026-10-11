---
id: "0038"
title: Optional bar items reserve empty space when their extra content is off
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-bar-items-reserve-empty-space-w
created_at: "2026-10-11T11:54:01Z"
updated_at: "2026-10-11T11:58:22Z"
---
## Problem

The network item keeps an empty gap after the Wi-Fi icon even when "Show Wi-Fi network name" is off. The gap is reserved for the name. The volume item is affected the same way: with its percentage and muted label off, space is still reserved. Items should size to what is shown.

## Desired UX

- When the optional content is off, the item is only as wide as its icon, with normal item spacing and no reserved gap.
- Turning the content on widens the item to fit, and turning it off collapses it again, live.

## Acceptance criteria

- The network item's width is computed from what it actually shows. The Wi-Fi name adds width only when enabled and available; when the name is unavailable, no gap remains.
- The volume item does the same for the percentage and muted label.
- The bar re-lays out live when a toggle changes, without a relaunch.
- Tests cover the width with each combination of toggles, and the unavailable-name case.
- `repoos check` passes. The maintainer confirms the look.

## Notes for AI

Fix in the item width calculation and layout, not in the readings. Keep changes to item sizing so this does not conflict with the time/date split in #0033.

## Activity

- 2026-10-11T11:54:01Z · created · njachowski@gmail.com
- 2026-10-11T11:54:04Z · status inbox→ready
- 2026-10-11T11:54:05Z · status ready→active, branch
- 2026-10-11T11:57:35Z · status active→review
- 2026-10-11T11:57:36Z · note: shots: skipped — the diff (3 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T11:58:22Z · note: review pass 1: good to go
