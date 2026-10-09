---
last_close_out_gate_ms: 23133
last_close_out_gate_at: "2026-10-09T23:50:16.553Z"
id: "0006"
title: "Implement versioned configuration, settings, and appearance modes"
type: feature
status: review
priority: p1
area: macos
story: Make either side of the bar my own
depends_on: ["0004", "0005"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/implement-versioned-configuration-settin
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T23:50:16Z"
review_passes: 2
review_rounds: 1
---
## Problem

The original workspaces-left/status-right schema is too narrow for core customization.

## Desired UX

Validated model and settings customize either side: add/remove/reorder/move widgets, detail levels, workspace app icons, explicit theme family and System/Light/Dark variants. Defaults remain beautiful without user input.

## Acceptance criteria

Versioned left/right item groups and per-widget options; atomic reload/writes; last-good state on error; migration fixtures for starter examples; disabled providers stop. Persist mode and family separately; native keyboard-accessible settings and login item controls. Documents and checker reflect the actual model.

## Notes for AI

SwiftUI is permitted for settings only. Theme families implemented in the separate theme task. Scripts/marketplace are not needed to deliver built-in customization.

## Shots
```json
[
{
"label": "Configuration reference: implemented model and v1 migration",
"target": "website",
"route": "/reference/configuration",
"highlight": "#migration-from-version-1"
}
]
```

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:14Z · story, body
- 2026-10-09T17:20:39Z · status inbox→ready
- 2026-10-09T20:33:26Z · status ready→active, branch
- 2026-10-09T21:21:44Z · body: section Shots
- 2026-10-09T21:22:15Z · status active→review
- 2026-10-09T21:23:11Z · note: review pass 1: needs some work
- 2026-10-09T21:23:11Z · status review→active
- 2026-10-09T21:27:00Z · status active→review
- 2026-10-09T21:27:00Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (9a7758b) during finalization (#0734)
- 2026-10-09T21:27:00Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (9a7758b) during finalization (#0734)
- 2026-10-09T21:27:49Z · note: review pass 2: good to go
- 2026-10-09T23:50:16Z · close-out gate completed in 23s

