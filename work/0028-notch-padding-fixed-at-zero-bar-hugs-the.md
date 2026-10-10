---
id: "0028"
title: "Notch padding fixed at zero: bar hugs the notch with a 6pt colour extension"
type: bug
status: review
priority: p1
area: macos
depends_on: ["0025"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/notch-padding-fixed-at-zero-bar-hugs-the
cli_override: claude code
model_override: haiku
created_at: "2026-10-10T12:20:56Z"
updated_at: "2026-10-10T12:31:37Z"
---
## Problem

On the notched display the bar leaves a 1 to 2 pixel gap at the notch edge, so the background underneath shows through. The notch's rounded corners also don't blend with the bar. The maintainer wants the bar to hug the notch exactly, with no visible seepage.

## Desired UX

- The notch padding is always zero. There is no setting to change it, and the bar always hugs the notch.
- The bar colour extends about 6 points into the notch area so that the gap and the rounded corners are covered, and the join looks solid.
- No other colour shows through at the notch edge.

## Acceptance criteria

- Remove the notch padding option from configuration and Settings, and treat the notch gap as zero in `BarGeometry`. Migrate any saved value to the fixed behaviour, with a test.
- Extend the notch-side colour by 6 points so the rounded corners are covered. Add a test that the fill rectangle covers the housing edge plus the extension.
- Verify on the packaged app with a screen capture of the notch area, recorded as evidence. The maintainer confirms the look.
- `repoos check` passes.

## Notes for AI

Depends on #0025 (flat chrome), which changes the same bar drawing and corner handling. Do not start until #0025 is done. Keep the change in `BarGeometry` and the notch-side fill, not the widget views.

## Activity

- 2026-10-10T12:20:56Z · created · njachowski@gmail.com
- 2026-10-10T12:23:11Z · status inbox→ready
- 2026-10-10T12:23:24Z · cli_override, model_override
- 2026-10-10T12:23:26Z · model_override
- 2026-10-10T12:23:30Z · status ready→active, branch
- 2026-10-10T12:30:48Z · status active→review
- 2026-10-10T12:30:48Z · note: shots: skipped — the diff (18 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T12:31:37Z · note: review pass 1: needs some work
