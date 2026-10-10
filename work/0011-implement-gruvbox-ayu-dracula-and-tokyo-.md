---
id: "0011"
title: "Implement Gruvbox, Ayu, Dracula and Tokyo Night theme families"
type: feature
status: review
priority: p1
area: [macos, docs]
story: Choose a hacker theme in light or dark
depends_on: ["0006"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/implement-gruvbox-ayu-dracula-and-tokyo-
created_at: "2026-10-09T16:41:12Z"
updated_at: "2026-10-10T00:49:58Z"
---
## Problem

Theme families and paired light/dark variants are central product requirements.

## Desired UX

The four requested hacker families plus a native default apply across all product surfaces; family survives appearance changes.

## Acceptance criteria

Semantic tokens, live persisted switching, verified upstream palette attribution, honest light adaptations, contrast/state fixtures, accessible settings and config overrides. Opaque and native materials respect system preferences. Switching only invalidates appearance caches.

## Notes for AI

Depends on shared settings/config and provider views. Do not label unofficial light adaptations official. Update public theme guides with delivered state.

## Shots
```json
[
{
"label": "Theme guide: delivered families, attribution, contrast, materials",
"target": "website",
"route": "/guide/themes",
"highlight": "main h2 + table"
}
]
```

## Activity

- 2026-10-09T16:41:12Z · created · njachowski@gmail.com
- 2026-10-09T17:20:39Z · status inbox→ready
- 2026-10-09T23:51:00Z · status ready→active, branch
- 2026-10-10T00:41:59Z · body: section Shots
- 2026-10-10T00:49:54Z · status active→review
- 2026-10-10T00:49:58Z · note: highlight main h2 + table matched nothing on /guide/themes
