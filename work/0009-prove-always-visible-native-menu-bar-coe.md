---
id: "0009"
title: Prove always-visible native menu-bar coexistence on macOS 26
type: feature
status: inbox
priority: p1
area: macos
story: Divot stays visible when the native menu bar appears
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:41:12Z"
updated_at: "2026-10-09T16:41:12Z"
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
