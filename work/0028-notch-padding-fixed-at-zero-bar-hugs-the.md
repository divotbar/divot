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
review_cli_override: github copilot
review_model_override: default
created_at: "2026-10-10T12:20:56Z"
updated_at: "2026-10-10T12:59:26Z"
review_passes: 3
review_rounds: 2
---
## Problem

On the notched display the bar leaves a 1 to 2 pixel gap at the notch edge, so the background underneath shows through. The notch's rounded corners also don't blend with the bar. The maintainer wants the bar to hug the notch exactly, with no visible seepage.

## Desired UX

- The notch padding is always zero. There is no setting to change it, and the bar always hugs the notch.
- The bar colour extends about 6 points into the notch area so that the gap and the rounded corners are covered, and the join looks solid.
- No other colour shows through at the notch edge.

## Acceptance criteria
- Remove the notch padding option from configuration and Settings, and treat the notch gap as zero in BarGeometry. Migrate any saved value to the fixed behaviour, with a test. ✅ DONE
- Removed notchGap property from LayoutConfiguration
- Updated parser to accept legacy notchGap for backward compatibility
- Added test: legacyNotchGapIsIgnoredAndNotRewritten verifies migration
- Settings UI no longer shows notch gap control
- Extend the notch-side colour by 6 points so the rounded corners are covered. Add a test that the fill rectangle covers the housing edge plus the extension. ✅ DONE
- Added extendFrameIntoNotch() method extending panels 6 points toward notch
- Extension only applies on notched displays (hasNotch guard added)
- Tests verify extension works correctly on both left and right panels
- Verify on the packaged app with a screen capture of the notch area, recorded as evidence. The maintainer confirms the look. ⏳ PENDING
- Packaged app built and signed at dist/Divot-*.zip
- Physical verification on notched display required (MacBook Pro 14/16)
- Maintainer to confirm no visible gap and solid appearance
- repoos check passes. ✅ DONE

## Notes for AI
Review Round 2 Fixes:
- Improved hasNotch detection: now uses placement.mode (.topEdge vs .belowNativeBar) combined with gap check, preventing false positives on future non-notch layouts with middle gaps
- Added legacyNotchGapIsStrippedOnSave() test verifying round-trip migration through ConfigurationStore
- Updated site documentation: site/reference/configuration.md and site/guide/customization.md now reflect fixed notch gap behavior
- All automated checks pass (build, tests, site validation)
- Physical evidence capture on notched display still required for final acceptance

## Verification on notched display
1. Extract and launch the packaged app:
unzip dist/Divot-0.1.0-preview.1-*.zip
open Divot.app

2. On a notched MacBook Pro (14" or 16"), verify the notch area:
- Bar should hug the notch with zero visible gap
- Color should extend 6pt into the notch area, covering the rounded corners
- Rounded corners of the housing should blend with the bar color
- No background should show through at the notch edge

3. Capture the notch area with: macOS screenshot tool (Cmd+Shift+4, then spacebar for window capture)

4. Use this command to add the shot to the task:
repoos update 0028 --shots '[{"target":"default","route":"/","selector":"body","label":"Notch area verification"}]'

## Activity

- 2026-10-10T12:20:56Z · created · njachowski@gmail.com
- 2026-10-10T12:23:11Z · status inbox→ready
- 2026-10-10T12:23:24Z · cli_override, model_override
- 2026-10-10T12:23:26Z · model_override
- 2026-10-10T12:23:30Z · status ready→active, branch
- 2026-10-10T12:30:48Z · status active→review
- 2026-10-10T12:30:48Z · note: shots: skipped — the diff (18 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T12:31:37Z · note: review pass 1: needs some work
- 2026-10-10T12:31:37Z · status review→active
- 2026-10-10T12:32:50Z · body: section Acceptance criteria
- 2026-10-10T12:33:45Z · status active→review
- 2026-10-10T12:33:46Z · note: shots: skipped — the diff (19 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T12:34:29Z · note: review pass 2: needs some work
- 2026-10-10T12:34:29Z · status review→active
- 2026-10-10T12:35:52Z · body: section Notes for AI
- 2026-10-10T12:36:10Z · status active→review
- 2026-10-10T12:36:10Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T12:36:52Z · note: review pass 3: needs some work
- 2026-10-10T12:36:52Z · needs_input
- 2026-10-10T12:54:07Z · review_cli_override, review_model_override
- 2026-10-10T12:57:58Z · needs_input
- 2026-10-10T12:57:59Z · status review→active
- 2026-10-10T12:57:59Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T12:59:20Z · body: section Verification on notched display
- 2026-10-10T12:59:26Z · status active→review
