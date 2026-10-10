---
id: "0025"
title: "Flat bar chrome: square edges to the screen edges, no 3D, optional bottom shadow"
type: bug
status: active
priority: p1
area: macos
depends_on: ["0024"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/flat-bar-chrome-square-edges-to-the-scre
created_at: "2026-10-10T10:26:06Z"
updated_at: "2026-10-10T11:03:56Z"
review_rounds: 1
review_passes: 1
---
## Problem

The bar's background and item chips show rounded corners and a 3D bevel. The maintainer wants a flat colour that runs edge to edge with square corners and no bevel. A slight drop shadow along the bottom edge should be optional.

## Desired UX

- The bar background is one flat colour from the left screen edge to the right, with square corners and no highlight, bevel or gradient.
- The workspace chip and other item chips are flat too. Keep the focused-chip border as a flat stroke only.
- Settings has a "Bottom shadow" toggle, off by default. When on, a subtle shadow runs along the bottom edge only.

## Acceptance criteria

- Remove the rounded corners and bevel from the bar and chip drawing, using the theme's flat colour tokens.
- Add a `bottomShadow` configuration key (default false) persisted through the configuration store, with a toggle in the settings window.
- Test the config default and the round-trip. Verify on the packaged app with a screen capture recorded as evidence; the maintainer confirms the look.
- `repoos check` passes.

## Notes for AI

Depends on #0024, which changes the left group's leading item. Keep changes to the panel and chip drawing, not the workspace feed.

## Activity

- 2026-10-10T10:26:06Z · created · njachowski@gmail.com
- 2026-10-10T10:53:06Z · status inbox→ready
- 2026-10-10T10:53:08Z · status ready→active, branch
- 2026-10-10T11:03:15Z · status active→review
- 2026-10-10T11:03:15Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:03:56Z · note: review pass 1: needs some work
- 2026-10-10T11:03:56Z · status review→active
