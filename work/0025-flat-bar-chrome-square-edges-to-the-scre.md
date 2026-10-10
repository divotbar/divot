---
id: "0025"
title: "Flat bar chrome: square edges to the screen edges, no 3D, optional bottom shadow"
type: bug
status: active
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
depends_on: ["0024"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/flat-bar-chrome-square-edges-to-the-scre
cli_override: cursor
model_override: composer-2.5
review_cli_override: claude code
review_model_override: haiku
created_at: "2026-10-10T10:26:06Z"
updated_at: "2026-10-10T11:30:01Z"
review_passes: 3
review_rounds: 2
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

## Verification
Automated (task branch, this run):

- `REPOOS_CHECK_CHANGED=main repoos check`: all steps pass (site, native-core, native-app, native-app-bundle, justfile). `swift test --package-path macos` runs **412 tests**, including the `bottomShadow` default and explicit parse, the wrong-type error, the canonical JSON round-trip, store persist/omit, settings-model toggle and persist, `rendersSameBar`, the flat bar/chip drawing assertions, and the panel-container and panel-frame shadow math.
- `bun run check`: the config schema tests (including the new `bottomShadow` accept/reject cases), the example fixtures, and the website build pass.
- Packaged bundle: `scripts/package-app.sh` plus `scripts/smoke-app-bundle.sh` PASS (structure, ad-hoc signature, launch, `--report`, default bar layout, archive and checksum). This does not render the bar.

Implementation notes:

- Flat chrome: `BarContentView` fills the solid `background` token edge to edge with `cornerRadius = 0` and no default border; the `NSVisualEffectView` material path is removed. Workspace chips are square with a flat `accent` focused stroke.
- `bottomShadow` (default `false`) is a root key: parsed, serialized, checked by `scripts/config-schema.ts`, and surfaced as a Settings toggle. Toggling it changes `rendersSameBar`, so the bar rebuilds and the shadow applies live (a brief panel rebuild, not an in-place shadow resize).
- The shadow is a `BarPanelContainer` `CAGradientLayer` strip inside a panel enlarged 6 pt downward, so it runs along the bottom edge only. Each display's left and right panel gets its own strip, so the camera-housing gap stays clear. The gradient is a fixed neutral dark tint (black at 20% alpha), not a theme token, because a drop shadow is conventionally dark regardless of the bar's theme.

Review round 3:

- `appearance.material` no longer changes the bar fill (the flat chrome always draws the solid `background` token). The Settings Material picker now carries a caption saying so, and the public configuration reference states it, as the review suggested. This is an intentional consequence of the flat spec, not a defect.

Human-only (NOT supplied here; do not treat as verified):

- The acceptance screen capture of the packaged app (flat bar, and the bottom shadow off and on) was not produced from this agent process. This shell has no running bar on the maintainer's display, and screen capture requires the human's Screen Recording grant. A person must run `dist/Divot.app`, capture both shadow states, and confirm the look before close-out. This is not waived by this run, and no run here claims the appearance is correct.


## Activity

- 2026-10-10T10:26:06Z · created · njachowski@gmail.com
- 2026-10-10T10:53:06Z · status inbox→ready
- 2026-10-10T10:53:08Z · status ready→active, branch
- 2026-10-10T11:03:15Z · status active→review
- 2026-10-10T11:03:15Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:03:56Z · note: review pass 1: needs some work
- 2026-10-10T11:03:56Z · status review→active
- 2026-10-10T11:04:24Z · body: section Verification
- 2026-10-10T11:05:24Z · status active→review
- 2026-10-10T11:05:24Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:06:04Z · note: review pass 2: needs some work
- 2026-10-10T11:06:04Z · status review→active
- 2026-10-10T11:06:47Z · body: section Verification
- 2026-10-10T11:07:08Z · status active→review
- 2026-10-10T11:07:09Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:07:46Z · note: review pass 3: needs some work
- 2026-10-10T11:07:46Z · needs_input
- 2026-10-10T11:29:47Z · cli_override, model_override
- 2026-10-10T11:29:48Z · model_override
- 2026-10-10T11:29:55Z · review_cli_override, review_model_override
- 2026-10-10T11:29:56Z · review_model_override
- 2026-10-10T11:30:01Z · status review→active
