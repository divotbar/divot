---
id: "0021"
title: "Divot placement: top edge when the native menu bar is hidden, below only while it is revealed; bar height 32pt"
type: bug
status: review
needs_input: true
needs_input_reason: dev-error
needs_input_detail: the agent process exited with an error — open the task to see the full output
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/divot-placement-top-edge-when-the-native
created_at: "2026-10-10T05:23:24Z"
updated_at: "2026-10-10T07:28:39Z"
review_rounds: 1
review_passes: 1
dev_error_count: 1
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

## Verification
Automated (task branch, this run):

- `swift build --package-path macos` and `swift test --package-path macos`: build clean, 355 tests pass, including the new probe/detection/height/transition tests.
- `REPOOS_CHECK_CHANGED=main repoos check`: all steps pass (native-core tests, native-app, package-app, smoke-app-bundle including "default bar layout through the packaged app").
- `scripts/package-app.sh --no-archive`: packaged Release `dist/Divot.app` from this branch.

Root cause of "below the notch band": AppKit's default `constrainFrameRect(_:to:)` clamps a window frame below the menu-bar band (`visibleFrame.maxY`) even while the native bar is hidden. On the built-in notched display that parked the top-edge bar at y=33 from the top instead of y=0. The nonactivating panels now override `constrainFrameRect` so a top-edge placement may occupy the camera-housing band; the panel level stays `mainMenu - 1`, so native menus still draw above Divot.

Window-server observation (CGWindowListCopyWindowInfo, not a screenshot):

- This branch's packaged build, two panels: `(x:0, y:0, w:753, h:30)` and `(x:958, y:0, w:752, h:30)` — the top edge.
- The build from `main` still running on the machine: same panels at `y:33`.
- `h:30` here is the local config file's `layout.height: 30`; the code default is now 32. Window-list geometry is objective; it does not judge appearance.

Screen capture: `screencapture -x -R0,0,1710,80` succeeded and shows the branch build's bar on the top edge above the older build's below-band row (both apps were running). The capture was an inspection aid; the screenshot binary is not committed.

Signal that reported "visible" while auto-hidden: `kAXHiddenAttribute`. It stays `false` because an auto-hidden bar is slid above the screen rather than AX-hidden, so the old `!hidden` heuristic claimed visible. `SystemMenuBarProbe` now derives visibility from the bar's own frame — on-screen when `position.y >= 0`, off-screen when negative — and the app constructs `AXSystemMenuBarProbe(validated: true)` so a notched display resolves `.hidden` (top edge) while hidden and `.visible(inset:)` while revealed.

Human-only (NOT supplied here; do not treat as verified):

- The live Accessibility sample on the maintainer's machine was not observable from this agent process (`AXIsProcessTrusted()` is false here; the Accessibility grant belongs to `dist/Divot.app`). The agent verified the probe's on-screen rule and the detector/coordinator transitions by test, not by a live AX read.
- Visual confirmation of the top strip on the maintainer's setup. The appearance is the maintainer's to confirm; no claim is made that it looks right.
- Auto-hidden vs revealed transition with Accessibility granted to the packaged app.

## Activity

- 2026-10-10T05:23:24Z · created · njachowski@gmail.com
- 2026-10-10T05:23:26Z · status inbox→ready
- 2026-10-10T05:23:27Z · status ready→active, branch
- 2026-10-10T06:03:05Z · body: section Verification
- 2026-10-10T06:06:04Z · status active→review
- 2026-10-10T06:06:04Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T06:06:43Z · note: review pass 1: needs some work
- 2026-10-10T06:06:43Z · status review→active
- 2026-10-10T07:07:02Z · agent exited with an error (opencode) · the agent process exited with an error — open the task to see the full output
- 2026-10-10T07:28:39Z · status active→review
