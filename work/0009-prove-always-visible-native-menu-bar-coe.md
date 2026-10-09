---
last_close_out_gate_ms: 8462
last_close_out_gate_at: "2026-10-09T16:54:19.205Z"
id: "0009"
title: Prove always-visible native menu-bar coexistence on macOS 26
type: feature
status: review
priority: p1
area: macos
story: Divot stays visible when the native menu bar appears
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/prove-always-visible-native-menu-bar-coe
created_at: "2026-10-09T16:41:12Z"
updated_at: "2026-10-09T16:54:19Z"
review_passes: 1
---
## Problem

The defining behavior requires reliable observation of native menu-bar visibility and coordinated panel movement.

## Desired UX

Divot moves below a revealed native menu bar and returns to the top when it hides, remaining visible.

## Acceptance criteria

Create a focused prototype and evidence report for public API visibility detection, top/below positioning, rapid toggles, focus, menu interaction, and fullscreen/multi-display limits. Add state/geometry tests; explicitly separate physical human validation. No unbounded polling or silent hide fallback.

## Notes for AI

This is a feasibility gate before the full shell. Read the always-visible story; it supersedes the starter fullscreen-hide requirement. If public APIs cannot satisfy a scenario, report evidence and a concrete product decision. Do not expand private API scope.

## Activity

- 2026-10-09T16:41:12Z · created · njachowski@gmail.com
- 2026-10-09T16:41:15Z · status inbox→ready
- 2026-10-09T16:41:15Z · note: User-approved defining behavior needs early proof before app shell work.
- 2026-10-09T16:43:08Z · status ready→active, branch
- 2026-10-09T16:51:03Z · status active→review
- 2026-10-09T16:51:03Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T16:51:59Z · note: review pass 1: good to go
- 2026-10-09T16:54:19Z · close-out gate completed in 8s

