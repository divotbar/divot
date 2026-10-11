---
id: "0030"
title: "Optional chips style for bar items, enabled in Settings"
type: feature
status: inbox
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T00:39:23Z"
updated_at: "2026-10-11T00:39:23Z"
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
