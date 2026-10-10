---
id: "0027"
title: Bar item reorder arrows point left and right
type: bug
status: inbox
priority: p2
area: macos
depends_on: ["0024"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-10T10:26:07Z"
updated_at: "2026-10-10T10:26:07Z"
---
## Problem

In Settings > Bar items, the reorder buttons are up and down arrows. Within a bar side the items read left to right, so the arrows should be left and right.

## Desired UX

- Each item row in "Bar items" shows a left arrow and a right arrow to move the item earlier or later on its side.
- The arrow is disabled at the first and last position, as the up and down arrows are today.

## Acceptance criteria

- Replace the up and down reorder icons with left and right arrows in the settings view, keeping the disabled states at the ends.
- Moving an item left or right keeps the configuration order and the bar's order in sync, with a test for the first and last positions.
- `repoos check` passes. A screen capture is evidence; the maintainer confirms the look.

## Notes for AI

Depends on #0024. Only the reorder controls change; do not alter the left/right side toggles or the enable switches.

## Activity

- 2026-10-10T10:26:07Z · created · njachowski@gmail.com
