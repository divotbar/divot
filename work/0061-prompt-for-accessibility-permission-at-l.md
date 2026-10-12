---
id: "0061"
title: Prompt for Accessibility permission at launch when missing
type: feature
status: inbox
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T11:38:56Z"
updated_at: "2026-10-12T11:38:56Z"
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
