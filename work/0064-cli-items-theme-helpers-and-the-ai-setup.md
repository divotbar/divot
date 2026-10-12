---
last_close_out_gate_ms: 61750
last_close_out_gate_at: "2026-10-12T12:26:22.191Z"
id: "0064"
title: "CLI: items/theme helpers and the AI-setup docs snippet"
type: feature
status: review
priority: p2
area: [macos, docs]
depends_on: ["0062"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/cli-items-theme-helpers-and-the-ai-setup
created_at: "2026-10-12T11:39:01Z"
updated_at: "2026-10-12T12:26:22Z"
review_passes: 2
review_rounds: 1
---
## Problem
Reordering items and switching themes are the most common chat requests; users also need a copy-paste way to tell an agent how to drive Divot.

## Desired UX
- divot items list|add|remove|move, divot theme set <family> [--mode].
- Site docs page with a copy-pasteable 'set up Divot with your AI' snippet pointing at divot config schema --json and divot status --json.
- Public copy distinguishes implemented from planned behaviour.

## Acceptance criteria
- Helpers implemented via the config layer with tests; invalid items rejected.
- Docs page added; bun run check passes.

## Notes for AI
Builds on #0062; do not claim features that are not implemented.

## Shots
```json
[
{
"label": "New “Set up Divot with your AI” guide page",
"target": "default",
"route": "/guide/ai-setup",
"highlight": ".vp-doc"
}
]
```

## Activity

- 2026-10-12T11:39:01Z · created · njachowski@gmail.com
- 2026-10-12T12:13:18Z · status inbox→ready
- 2026-10-12T12:13:19Z · status ready→active, branch
- 2026-10-12T12:20:50Z · body: section Shots
- 2026-10-12T12:21:28Z · status active→review
- 2026-10-12T12:22:21Z · note: review pass 1: needs some work
- 2026-10-12T12:22:21Z · status review→active
- 2026-10-12T12:24:02Z · status active→review
- 2026-10-12T12:24:02Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (0fd230b) during finalization (#0734)
- 2026-10-12T12:24:02Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (0fd230b) during finalization (#0734)
- 2026-10-12T12:25:06Z · note: review pass 2: good to go
- 2026-10-12T12:26:22Z · close-out gate completed in 62s

