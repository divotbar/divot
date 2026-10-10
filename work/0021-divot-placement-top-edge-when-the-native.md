---
id: "0021"
title: "Divot placement: top edge when the native menu bar is hidden, below only while it is revealed; bar height 32pt"
type: bug
status: active
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/divot-placement-top-edge-when-the-native
created_at: "2026-10-10T05:23:24Z"
updated_at: "2026-10-10T05:23:27Z"
---
## Problem

The packaged bar now shows, but it sits below the notch band instead of at the top of the screen. The maintainer's native menu bar is set to auto-hide (`_HIHideMenuBar` = 1), so it is hidden almost all the time and only slides down when the cursor reaches the top edge. Divot should therefore be at the top edge, and move below only while the native bar is revealed, then slide back up when it hides.

The screen-level detection is probably reporting a visible native bar even when it is hidden. The current placement used y=33 for both panels, which matches the reserved menu-bar inset, not a hidden bar. `MenuBarObservationAdapter` falls back to a 24pt "nominal" bar when the reported top band is small, and `DivotCore` decides placement from that. Confirm which signal says "visible" when the bar is hidden and fix it.

The bar is also too short. The maintainer expects the row to match the notch height, which is 64px on a 2x display, so 32pt. The current default in `BarMetrics.default.height` is 24pt.

Two status-glyph readings to keep (no change needed): a filled dot means the workspace is occupied (has windows), a hollow ring means empty, and the highlighted chip is the focused workspace. The green colour on the occupied dot is the theme's occupied colour.

## Desired UX

- Native menu bar hidden (auto-hide, the default): Divot sits at the very top edge, spanning the width, with the notch gap handled by the existing top-edge split.
- Cursor reveals the native bar: the native bar slides down and Divot slides below it.
- Native bar hides again: Divot slides back to the top edge.
- Default row height 32pt, so it matches the notch height.

## Acceptance criteria

- Find and document the probe signal that reports "visible" while the native bar is auto-hidden; add a test that a hidden bar with a notched screen yields `hidden`, and a revealed bar yields `visible(inset:)`.
- Default `BarMetrics.default.height` set to 32 and documented; `layout.height` config still overrides it. Update the test that pins the old default.
- Placement follows the reveal/hide state in both directions, with a test for the transition.
- Verify with `scripts/package-app.sh` and a screen capture of the top strip, recorded as evidence. The maintainer confirms appearance; do not claim it looks right without that.
- `repoos check` passes.

## Notes for AI

The maintainer's current setup: AeroSpace running, native menu bar auto-hide on, Accessibility granted to `dist/Divot.app`. Do not change the AeroSpace or a-bar configuration. Keep the change in the placement and probe code, not the widget views.

## Activity

- 2026-10-10T05:23:24Z · created · njachowski@gmail.com
- 2026-10-10T05:23:26Z · status inbox→ready
- 2026-10-10T05:23:27Z · status ready→active, branch
