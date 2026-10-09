---
id: "0006"
title: "Implement versioned configuration, settings, and appearance modes"
type: feature
status: inbox
priority: p1
area: macos
story: Make either side of the bar my own
depends_on: ["0004", "0005"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T16:41:14Z"
---
## Problem

The original workspaces-left/status-right schema is too narrow for core customization.

## Desired UX

Validated model and settings customize either side: add/remove/reorder/move widgets, detail levels, workspace app icons, explicit theme family and System/Light/Dark variants. Defaults remain beautiful without user input.

## Acceptance criteria

Versioned left/right item groups and per-widget options; atomic reload/writes; last-good state on error; migration fixtures for starter examples; disabled providers stop. Persist mode and family separately; native keyboard-accessible settings and login item controls. Documents and checker reflect the actual model.

## Notes for AI

SwiftUI is permitted for settings only. Theme families implemented in the separate theme task. Scripts/marketplace are not needed to deliver built-in customization.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:14Z · story, body
