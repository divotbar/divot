---
id: "0061"
title: Prompt for Accessibility permission at launch when missing
type: feature
status: done
priority: p2
area: macos
merged_commit: ea1ed5f6f4b1283614b7ff0cf3319cb43f8e892e
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/prompt-for-accessibility-permission-at-l
created_at: "2026-10-12T11:38:56Z"
updated_at: "2026-10-12T11:50:24Z"
last_close_out_gate_ms: 56588
last_close_out_gate_at: "2026-10-12T11:50:20.409Z"
review_passes: 1
---
## Problem
Divot only checks AXIsProcessTrusted() and prints a stderr line (DivotAppDelegate.swift, SystemMenuBarProbe.swift:134), so users are never prompted and notched-display menu-bar detection stays indeterminate.

## Desired UX
- On launch, if Accessibility is not granted, call AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt once per launch.
- Do not prompt when already trusted; never prompt in a loop.
- When running unbundled (swift run / dev page), print a one-line stderr hint that the grant attaches to the host terminal/app and that dist/Divot.app is where it lasts.

## Acceptance criteria
- Prompt requested at most once per launch and only when untrusted, behind a testable seam.
- Unit test for the decision logic; docs updated.
- Human verifies the dialog on the packaged app.

## Notes for AI
No private APIs, no polling. Keep the existing stderr message.

## Activity

- 2026-10-12T11:38:56Z · created · njachowski@gmail.com
- 2026-10-12T11:39:02Z · status inbox→ready
- 2026-10-12T11:39:03Z · status ready→active, branch
- 2026-10-12T11:45:52Z · status active→review
- 2026-10-12T11:45:52Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T11:46:30Z · note: review pass 1: good to go
- 2026-10-12T11:50:20Z · close-out gate completed in 57s
- 2026-10-12T11:50:24Z · status review→done, release:success
