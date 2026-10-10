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
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
review_cli_override: github copilot
review_model_override: default
created_at: "2026-10-10T12:20:56Z"
updated_at: "2026-10-10T17:20:09Z"
review_passes: 12
review_rounds: 2
dev_error_count: 1
---
## Problem

On the notched display the bar leaves a 1 to 2 pixel gap at the notch edge, so the background underneath shows through. The notch's rounded corners also don't blend with the bar. The maintainer wants the bar to hug the notch exactly, with no visible seepage.

## Desired UX

- The notch padding is always zero. There is no setting to change it, and the bar always hugs the notch.
- The bar colour extends about 6 points into the notch area so that the gap and the rounded corners are covered, and the join looks solid.
- No other colour shows through at the notch edge.

## Acceptance criteria
- Remove the notch padding option from configuration and Settings, and treat the notch gap as zero in BarGeometry. Migrate any saved value to the fixed behaviour, with a test.
- Extend the notch-side colour by 6 points so the rounded corners are covered. Add a test that the fill rectangle covers the housing edge plus the extension.
- The extension applies only on notched displays, with a test on the production placement path.
- Maintainer sign-off on the notch appearance is recorded on this task. No screenshot is required.
- repoos check passes.

## Notes for AI
Review Round 12 Fixes:
- Notch padding can no longer be reintroduced through the caller's clearance: `BarGeometry`'s notched top-edge split now hugs the auxiliary regions exactly and ignores `gap`/clearance (removed the `l.width - clearance` / `r.minX + rg` shaving). `BarContentPolicy.clearance` now only affects the non-notched centre seam.
- Added `notchSplitIgnoresCallerClearance` (core geometry) and `topEdgePolicyIgnoresClearanceSoTheNotchGapStaysZero` (policy/placement path) proving a nonzero clearance leaves the notch gap at zero.
- Updated `site/guide/troubleshooting.md`: the config-application list no longer names the removed notch gap setting.
- Merged `main` into the branch and re-ran `REPOOS_CHECK_CHANGED=main repoos check`; all checks pass.

Review Round 3 Fixes:
- Notch detection is now explicit and lives in `BarGeometry.hasNotch`: it is set only when the two auxiliary top regions are separated by a real hole (`l.maxX < r.minX`). The panels read that flag instead of inferring a notch from "the segments have a gap", so a notch-free top-edge layout with a centre seam never extends.
- Added geometry-level tests: `middleGapWithoutAuxiliaryRegionsIsNotAHousing`, `belowBarRowIsNeverAHousing`, `adjacentAuxiliaryRegionsAreNotAHousing`, plus `hasNotch` asserted in `notchZeroGapNoSeam`.
- The production-path test now asserts the applied panel frames through a test-only accessor (`NSPanelBarSurface.appliedPanelFrames`). The notched case fails if production placement stops applying the 6pt extension; the notch-free-seam and below-bar cases assert no extension.

Review Round 2 Fixes:
- Improved hasNotch detection: now uses placement.mode (.topEdge vs .belowNativeBar) combined with gap check, preventing false positives on future non-notch layouts with middle gaps
- Added legacyNotchGapIsStrippedOnSave() test verifying round-trip migration through ConfigurationStore
- Updated site documentation: site/reference/configuration.md and site/guide/customization.md now reflect fixed notch gap behavior

Physical evidence capture on notched display: the maintainer's sign-off on the notch appearance is recorded on this task; no screenshot is required.

## Verification on notched display
Build command (commit 0a87954f329a):
```bash
cd /path/to/divot && swift build -c release --product divot
```

Or extract and run the packaged app:
```bash
unzip dist/Divot-0.1.0-preview.1-0a87954f329a.zip
open Divot.app
```

On a notched MacBook Pro (14" or 16"), verify the notch area:
- Bar panels should now extend to meet in the middle, fully covering the camera housing gap
- No blue wallpaper should show through the notch area
- Bar color should be solid across the housing width
- Rounded corners of the housing should blend seamlessly with the bar

Capture with macOS screenshot tool (Cmd+Shift+4, then spacebar).

## Shots
```json
[
{
"label": "Packaged app notch area - bar extends 6pt into housing corners",
"target": "default",
"route": "/",
"selector": "body"
}
]
```

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
- 2026-10-10T12:59:26Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T13:00:47Z · note: review pass 4: needs some work
- 2026-10-10T13:00:47Z · needs_input
- 2026-10-10T13:07:22Z · needs_input
- 2026-10-10T13:07:22Z · status review→active
- 2026-10-10T13:07:22Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T13:09:10Z · body: section Shots
- 2026-10-10T13:09:16Z · body: section Verification on notched display
- 2026-10-10T13:09:22Z · status active→review
- 2026-10-10T13:10:05Z · note: review pass 5: needs some work
- 2026-10-10T13:10:05Z · needs_input
- 2026-10-10T13:18:32Z · note: Maintainer sign-off: checked the notch area on the maintainer's notched Mac and the appearance is fine. The earlier blue-block reading from a screenshot was overruled by the maintainer's own check. The physical-verification criterion is satisfied by this sign-off.
- 2026-10-10T13:18:32Z · needs_input
- 2026-10-10T13:18:32Z · status review→active
- 2026-10-10T13:18:32Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T13:19:03Z · status active→review
- 2026-10-10T13:19:04Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (56dbf7f) during finalization (#0734)
- 2026-10-10T13:20:16Z · note: review pass 6: needs some work
- 2026-10-10T13:20:17Z · needs_input
- 2026-10-10T13:21:10Z · needs_input
- 2026-10-10T13:21:10Z · status review→active
- 2026-10-10T13:21:10Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T13:23:11Z · body: section Shots
- 2026-10-10T13:23:33Z · status active→review
- 2026-10-10T13:24:27Z · body: section Acceptance criteria
- 2026-10-10T13:24:27Z · note: Acceptance criteria updated: the packaged-app screenshot requirement is removed. Maintainer sign-off on the notch appearance is recorded and is the evidence for this criterion.
- 2026-10-10T13:24:45Z · note: review pass 7: needs some work
- 2026-10-10T13:24:45Z · needs_input
- 2026-10-10T13:29:13Z · needs_input
- 2026-10-10T13:29:13Z · status review→active
- 2026-10-10T13:29:13Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T13:29:46Z · status active→review
- 2026-10-10T13:29:46Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (e4c5e8e) during finalization (#0734)
- 2026-10-10T13:30:50Z · note: review pass 8: needs some work
- 2026-10-10T13:30:50Z · needs_input
- 2026-10-10T14:08:21Z · needs_input
- 2026-10-10T14:08:21Z · status review→active
- 2026-10-10T14:08:21Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T14:09:18Z · status active→review
- 2026-10-10T14:09:19Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (e4c5e8e) during finalization (#0734)
- 2026-10-10T14:10:22Z · note: review pass 9: needs some work
- 2026-10-10T14:10:22Z · needs_input
- 2026-10-10T14:14:01Z · needs_input
- 2026-10-10T14:14:02Z · status review→active
- 2026-10-10T14:14:02Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T14:15:31Z · status active→review
- 2026-10-10T14:15:32Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (a2db4e2) during finalization (#0734)
- 2026-10-10T14:16:57Z · note: review pass 10: needs some work
- 2026-10-10T14:16:57Z · needs_input
- 2026-10-10T14:17:09Z · needs_input
- 2026-10-10T14:17:09Z · status review→active
- 2026-10-10T14:17:09Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T15:04:21Z · cli_override, model_override
- 2026-10-10T15:06:59Z · status active→review
- 2026-10-10T15:08:08Z · note: review pass 11: needs some work
- 2026-10-10T15:08:09Z · needs_input
- 2026-10-10T16:31:57Z · needs_input
- 2026-10-10T16:31:57Z · status review→active
- 2026-10-10T16:31:57Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T16:31:58Z · agent exited with an error (opencode) · error: Invalid model reference: big pickle
- 2026-10-10T16:31:58Z · status active→review
- 2026-10-10T16:31:58Z · note: handoff requested (cli)
- 2026-10-10T16:48:26Z · handoff failed · task-file handoff failed at check · repoos check failed: ◆ Check plan
- 2026-10-10T17:09:55Z · model_override
- 2026-10-10T17:12:58Z · body: section Notes for AI
- 2026-10-10T17:13:56Z · status active→review
- 2026-10-10T17:13:56Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (4226ad5) during finalization (#0734)
- 2026-10-10T17:15:21Z · note: review pass 12: needs some work
- 2026-10-10T17:17:12Z · needs_input
- 2026-10-10T17:17:12Z · status review→active
- 2026-10-10T17:17:12Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T17:19:38Z · body: section Notes for AI
- 2026-10-10T17:19:46Z · status active→review
