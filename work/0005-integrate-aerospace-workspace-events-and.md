---
id: "0005"
title: Integrate AeroSpace workspace events and actions
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
story: Navigate the workspaces and apps I actually use
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/integrate-aerospace-workspace-events-and
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T19:02:25Z"
last_check_failure: "repoos check at 2026-10-09T18:59:35.328Z: repoos check failed: ui verification failed (3 issue(s)): [route] Workspace guide: adapter reads AeroSpace and renders the left row: declared route /guide/workspaces#left-of-the-camera but the browser landed on /guide/workspaces (login or redirect?) (captured http://127.0.0.1:65493/guide/workspaces#left-of-the-camera) (http://127.0.0.1:65493/guide/workspaces#left-of-the-camera); [route] Workspace options: showDetails and maxAppIconsPerWorkspace: declared route /reference/configuration#widget-opt… (truncated)"
review_passes: 3
review_rounds: 2
---
## Problem

Workspace navigation must reflect the installed manager, with AeroSpace delivered first.

## Desired UX

Real workspace names, focus/occupied/empty state and optional deduplicated app icons on the left; current program beside them.

## Acceptance criteria

Capability detection, supported events/callbacks, async actions/timeouts, adapter lifecycle fixtures, app icon inventory, per-monitor mapping and overflow. No manager means honest unavailable state; no fake numbered workspaces. Customization can toggle app icons/details. No frame-rate subprocess queries.

## Notes for AI

AeroSpace first, shared interfaces for subsequent yabai. Native Spaces is a separate research task, not a delivery promise.

## Shots
```json
[
{
"label": "Workspace guide: adapter reads AeroSpace and renders the left row",
"target": "website",
"route": "/guide/workspaces",
"highlight": "#left-of-the-camera"
},
{
"label": "Workspace options: showDetails and maxAppIconsPerWorkspace",
"target": "website",
"route": "/reference/configuration",
"highlight": "#widget-options"
},
{
"label": "Troubleshooting: AeroSpace detection and unavailable state",
"target": "website",
"route": "/guide/troubleshooting",
"highlight": "#aerospace-isn-t-installed"
}
]
```

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:14Z · story, body
- 2026-10-09T17:20:38Z · status inbox→ready
- 2026-10-09T18:02:48Z · status ready→active, branch
- 2026-10-09T18:14:13Z · status active→review
- 2026-10-09T18:14:13Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T18:15:42Z · note: review pass 1: needs some work
- 2026-10-09T18:15:42Z · status review→active
- 2026-10-09T18:33:45Z · status active→review
- 2026-10-09T18:33:45Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T18:35:57Z · note: review pass 2: needs some work
- 2026-10-09T18:35:57Z · status review→active
- 2026-10-09T18:46:04Z · body: section Shots
- 2026-10-09T18:47:16Z · status active→review
- 2026-10-09T18:47:16Z · note: shots: skipped — 3 handoff shots already captured for this exact plan (a0a7368) during finalization (#0734)
- 2026-10-09T18:47:17Z · note: shots: skipped — 3 handoff shots already captured for this exact plan (a0a7368) during finalization (#0734)
- 2026-10-09T18:49:43Z · note: review pass 3: needs some work
- 2026-10-09T18:49:44Z · needs_input
- 2026-10-09T18:51:01Z · status review→active
- 2026-10-09T18:57:33Z · body: section Shots
- 2026-10-09T18:59:32Z · note: ui verification failed (3 issue(s)): [route] Workspace guide: adapter reads AeroSpace and renders the left row: declared route /guide/workspaces#left-of-the-camera but the browser landed on /guide/workspaces (login or redirect?) (captured http://127.0.0.1:65493/guide/workspaces#left-of-the-camera) (http://127.0.0.1:65493/guide/workspaces#left-of-the-camera); [route] Workspace options: showDetails and maxAppIconsPerWorkspace: declared route /reference/configuration#widget-options but the browser
- 2026-10-09T19:00:01Z · body: section Shots
- 2026-10-09T19:00:41Z · status active→review
- 2026-10-09T19:02:25Z · note: review pass 4: needs some work
