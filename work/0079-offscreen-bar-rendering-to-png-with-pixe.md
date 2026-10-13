---
id: "0079"
title: Offscreen bar rendering to PNG with pixel assertions (follow-up to popover snapshots)
type: chore
status: review
priority: p3
area: macos
depends_on: ["0078"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/offscreen-bar-rendering-to-png-with-pixe
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T07:01:36Z"
updated_at: "2026-10-13T07:52:44Z"
review_rounds: 2
review_passes: 2
last_check_failure: "repoos check at 2026-10-13T07:42:06.739Z: repoos check failed: ◆ Check plan"
---
## Problem
#0078 renders the popovers offscreen. The bar itself (workspaces, front app and right-side chips) has no offscreen render, so bar layout, spacing, chip style and the charging colour have no visual evidence.

## Desired UX
- Reuse the #0078 helper to render the bar view offscreen to PNG for every theme family in light and dark at the default and one larger text size, with chips on and off, into the same gitignored directory. Never commit PNGs.

## Acceptance criteria
- Pixel assertions without stored goldens: item order and gaps match BarMetrics, the 17px right inset, chip opacity applied, charging indicator is the fixed green while charging, text contrast meets the audit.
- If part of the bar cannot be rendered offscreen, state exactly what and why.
- docs updated; swift test --package-path macos passes.

## Notes for AI
Build on the helper and docs/popover-snapshot-testing.md from #0078.

## Activity

- 2026-10-13T07:01:36Z · created · njachowski@gmail.com
- 2026-10-13T07:22:36Z · status inbox→ready
- 2026-10-13T07:22:37Z · cli_override, model_override
- 2026-10-13T07:22:38Z · status ready→active, branch
- 2026-10-13T07:42:50Z · status active→review
- 2026-10-13T07:42:50Z · note: shots: skipped — the diff (3 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T07:43:59Z · note: review pass 1: needs some work
- 2026-10-13T07:44:00Z · status review→active
- 2026-10-13T07:47:13Z · status active→review
- 2026-10-13T07:47:13Z · note: shots: skipped — the diff (3 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T07:48:20Z · note: review pass 2: needs some work
- 2026-10-13T07:48:20Z · status review→active
- 2026-10-13T07:49:26Z · message_queued at 2026-10-13T07:49:26.837Z
- 2026-10-13T07:51:31Z · status active→review
- 2026-10-13T07:51:31Z · note: shots: skipped — the diff (4 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T07:52:44Z · note: review pass 3: needs some work
