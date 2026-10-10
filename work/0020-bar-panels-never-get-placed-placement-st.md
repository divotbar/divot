---
last_close_out_gate_ms: 40335
last_close_out_gate_at: "2026-10-10T04:23:46.387Z"
id: "0020"
title: "Bar panels never get placed: placement stays undecided on the notched display even with Accessibility granted"
type: bug
status: review
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/bar-panels-never-get-placed-placement-st
created_at: "2026-10-10T04:02:13Z"
updated_at: "2026-10-10T04:23:46Z"
review_passes: 2
review_rounds: 1
---
## Problem

The packaged app `dist/Divot.app` (bundle `local.divot.preview`) runs with Accessibility granted and no permission warning in its log. Its bar is still not visible on the maintainer's notched MacBook Air. Only two 1x1 windows exist, at x=0, y=-1, layer 23. The panels are created in `BarPanels` but never get a frame, because `BarPanels.apply` returns early when `update.placement` is nil (`macos/Sources/DivotAppKit/BarPanels.swift`, around line 103). So the placement resolver is still returning nil.

A second, separate symptom in the same log: `workspaces: No supported window manager found`, even though AeroSpace is running and `aerospace list-workspaces --all` works from a shell.

## Desired UX

With Accessibility granted, the bar appears at the top band of the built-in notched display and fills the left and right panels with content. Workspace pills populate when AeroSpace is running.

## Acceptance criteria

- Reproduce with a unit test: a notched `ScreenGeometry` plus an Accessibility-granted observation must yield a non-nil placement. Find which input keeps the resolver returning nil.
- Fix it so the panels get a frame, and add a test that a placement is always produced when permission is granted, with no silent hide (AGENTS.md).
- Find why the AeroSpace capability probe reports no supported window manager when the same CLI works from a shell (PATH inside the launched app, or probe timing). Add a test for the probe result.
- Verify on the packaged app with `scripts/smoke-app-bundle.sh` and a screen capture, and record the capture as evidence. A human must confirm the appearance; do not claim it looks right without that.
- `repoos check` passes.

## Notes for AI

The maintainer confirmed Accessibility is on for `dist/Divot.app` and the log has no permission warning. The bar process started from the Dev page is a different ad-hoc-signed binary; do not rely on it for verification. Keep the change inside `DivotCore` placement logic and the probe, not the widget views, so it does not conflict with other active work.

## Verification
Automated (task branch, this run):
- `scripts/smoke-app-bundle.sh`: PASS (packaged Release bundle, bundled `--report`/`--widgets`).
- Packaged `dist/Divot.app` launched via `open` with stderr captured: the workspace capability probe now reports `available (workspaces, windows, events, callbacks, monitors)` with a 3-workspace snapshot, and the false `No supported window manager found` line is gone.
- Window-server observation (CGWindowListCopyWindowInfo, not a screenshot): two on-screen Divot panels at `(x:0, y:33, w:753, h:24)` and `(x:958, y:33, w:752, h:24)` — the built-in notched top band, split around the camera housing.

Human-only (NOT supplied here):
- No screen capture was produced: `screencapture` failed with "could not create image from display" (Screen Recording permission is not granted to the agent process). A person must capture the bar and confirm its appearance; no visual claim is made.

## Activity

- 2026-10-10T04:02:13Z · created · njachowski@gmail.com
- 2026-10-10T04:02:14Z · status inbox→ready
- 2026-10-10T04:02:17Z · status ready→active, branch
- 2026-10-10T04:15:46Z · status active→review
- 2026-10-10T04:15:46Z · note: shots: skipped — the diff (6 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T04:16:33Z · note: review pass 1: needs some work
- 2026-10-10T04:16:33Z · status review→active
- 2026-10-10T04:17:49Z · body: section Verification
- 2026-10-10T04:18:58Z · status active→review
- 2026-10-10T04:18:59Z · note: shots: skipped — the diff (6 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-10T04:19:53Z · note: review pass 2: good to go
- 2026-10-10T04:23:46Z · close-out gate completed in 40s

