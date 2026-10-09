---
updated_at: "2026-10-09T20:26:39Z"
review_passes: 1
id: "0015"
title: Stop Divot stacking under the a-bar on top of the notch
type: bug
status: review
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/stop-divot-stacking-under-the-a-bar-on-t
created_at: "2026-10-09T20:18:47Z"
---
## Problem

On the maintainer's MacBook Air (notched, camera housing), Divot renders as a second row below the third-party a-bar at the top of the screen instead of occupying the top band. The native macOS menu bar is not visibly revealed in that setup, but Divot still positions itself below a top inset.

Likely cause to verify: `MenuBarObservationAdapter` assumes a visible notch-free native bar uses a minimum inset when public APIs cannot see another app's bar in the top band. A third-party bar (a-bar, AeroSpace-managed) occupying that band is therefore read as a revealed native menu bar, so `BarPlacementResolver` returns `belowNativeBar`.

## Desired UX

Divot sits in the top band it owns on this Mac, with no stacked second row. When the native menu bar is genuinely revealed, Divot still moves below it (task 0009 behavior) and returns to the top when hidden.

## Acceptance criteria

- Determine and record the root cause with a test that reproduces the a-bar-occupied top band as a `ScreenGeometry`/`NativeMenuBarVisibility` input.
- Fix detection so an occupied top band from another bar does not produce a false `visible(inset:)`; keep `indeterminate` (and report the reason) when public signals cannot decide. No silent hide and no private APIs.
- Keep the 0009 below-bar behavior for a genuinely revealed native menu bar, covered by tests.
- Update `docs/` text on placement limits in the same change.
- `repoos check` passes.

## Notes for AI

Product reading taken by the PM: the user expects Divot in the top band, not beneath a-bar. If the correct answer requires a product decision (for example, a config option for "top band" vs "below any top bar"), record it as a question in the task rather than guessing. Do not change the a-bar configuration.

## Activity

- 2026-10-09T20:18:47Z · created · njachowski@gmail.com
- 2026-10-09T20:18:50Z · status inbox→ready
- 2026-10-09T20:18:50Z · status ready→active, branch
- 2026-10-09T20:21:58Z · note: PM: repoos shots cover web routes only, so they will not capture the native Divot bar (shots: skipped). Verify placement with geometry/state unit tests; screen capture from the terminal fails here until Screen Recording is granted, so do not depend on screencapture.
- 2026-10-09T20:25:47Z · status active→review
- 2026-10-09T20:25:48Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T20:26:39Z · note: review pass 1: good to go

