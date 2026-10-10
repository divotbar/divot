---
id: "0026"
title: Optional occupied and empty workspace dots in Settings
type: feature
status: done
priority: p1
area: macos
depends_on: ["0024"]
merged_commit: 6ec6ae8231c4b184b2328a6dc68e31ef0273d83c
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-occupied-and-empty-workspace-do
created_at: "2026-10-10T10:26:07Z"
updated_at: "2026-10-10T10:36:47Z"
last_close_out_gate_ms: 38278
last_close_out_gate_at: "2026-10-10T10:36:45.057Z"
review_passes: 1
---
## Problem

The workspace row shows a green filled dot for occupied workspaces and a hollow ring for empty ones. The maintainer wants each marker to be optional, controlled from Settings.

## Desired UX

- Settings has two toggles: "Show the occupied dot" and "Show the empty dot", both on by default to keep today's look.
- Turning a dot off hides that marker only. The focused highlight and the workspace names still show, so a workspace stays identifiable.

## Acceptance criteria

- Add `showOccupiedDot` and `showEmptyDot` configuration keys (default true), persisted through the configuration store, with toggles in the settings window.
- The bar hides the matching marker live, without a relaunch.
- Tests cover the defaults and the rendering of each marker on and off.
- `repoos check` passes. A screen capture is evidence; the maintainer confirms the look.

## Notes for AI

Depends on #0024. Keep the marker drawing in the workspace bar view; do not change the workspace feed or the chip background, which the flat-chrome task changes.

## Activity

- 2026-10-10T10:26:07Z · created · njachowski@gmail.com
- 2026-10-10T10:26:32Z · status inbox→ready
- 2026-10-10T10:26:33Z · status ready→active, branch
- 2026-10-10T10:32:43Z · status active→review
- 2026-10-10T10:32:43Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T10:33:14Z · note: review pass 1: good to go
- 2026-10-10T10:36:45Z · close-out gate completed in 38s
- 2026-10-10T10:36:47Z · status review→done, release:success
