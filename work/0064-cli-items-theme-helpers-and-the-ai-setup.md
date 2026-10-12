---
id: "0064"
title: "CLI: items/theme helpers and the AI-setup docs snippet"
type: feature
status: inbox
priority: p2
area: [macos, docs]
depends_on: ["0062"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T11:39:01Z"
updated_at: "2026-10-12T11:39:01Z"
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

## Activity

- 2026-10-12T11:39:01Z · created · njachowski@gmail.com
