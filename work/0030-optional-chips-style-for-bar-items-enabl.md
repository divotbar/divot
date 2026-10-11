---
id: "0030"
title: "Optional chips style for bar items, enabled in Settings"
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-chips-style-for-bar-items-enabl
created_at: "2026-10-11T00:39:23Z"
updated_at: "2026-10-11T00:51:05Z"
---
## Problem

Bar items blend together. The maintainer wants a "chips" option that draws each item as its own rounded or flat chip so the items read as distinct.

## Desired UX

- Settings has a "Chips" toggle for bar items, off by default.
- When on, each item sits in its own chip with the same padding and theme colours. Spacing between chips follows the existing item spacing.
- Turning it off restores the current look.

## Acceptance criteria

- Add a `chipStyle` configuration key (default false), persisted through the configuration store, with a toggle in the settings window.
- Chip drawing uses theme tokens; no hard-coded colours.
- Tests cover the default and that the chip style changes the item layout padding.
- `repoos check` passes. A screen capture is evidence; the maintainer confirms the look.

## Notes for AI

Depends on #0028 so the notch-side geometry is settled first. Keep changes to item drawing, not the notch geometry.

## Activity

- 2026-10-11T00:39:23Z · created · njachowski@gmail.com
- 2026-10-11T00:43:50Z · status inbox→ready
- 2026-10-11T00:43:51Z · status ready→active, branch
- 2026-10-11T00:49:59Z · status active→review
- 2026-10-11T00:50:00Z · note: shots: skipped — the diff (10 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T00:51:05Z · note: review pass 1: good to go
