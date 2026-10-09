---
updated_at: "2026-10-09T19:41:36Z"
review_passes: 6
id: "0005"
title: Integrate AeroSpace workspace events and actions
type: feature
status: review
priority: p1
area: macos
story: Navigate the workspaces and apps I actually use
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/integrate-aerospace-workspace-events-and
review_cli_override: cursor
review_model_override: composer-2.5
created_at: "2026-10-09T16:18:39Z"
close_out_repair_count: 1
last_check_failure: "repoos check at 2026-10-09T18:59:35.328Z: repoos check failed: ui verification failed (3 issue(s)): [route] Workspace guide: adapter reads AeroSpace and renders the left row: declared route /guide/workspaces#left-of-the-camera but the browser landed on /guide/workspaces (login or redirect?) (captured http://127.0.0.1:65493/guide/workspaces#left-of-the-camera) (http://127.0.0.1:65493/guide/workspaces#left-of-the-camera); [route] Workspace options: showDetails and maxAppIconsPerWorkspace: declared route /reference/configuration#widget-opt… (truncated)"
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

## Final focused review repair
Independent review at 2026-10-09T19:02:25Z found two remaining blockers. WorkspaceFeed.stop() must invalidate generation before cancellation/reset so a delayed snapshot cannot repopulate stopped state; add a deterministic delayed-completion-after-stop regression and stale callback protection. WorkspaceBarView must visibly distinguish nonfocused occupied, empty and unknown occupancy without relying only on tint, including when app icons are disabled; add a compact noncolor marker or shape cue and accessible descriptions with fixture coverage. Preserve the overflow width guarantee when adding the marker. Do not expand scope, fabricate native UI evidence, or change configured roles/agents/models. Run scoped checks and hand off for fresh review. Docs screenshots are now accepted and need no unrelated recapture.

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
- 2026-10-09T19:02:25Z · needs_input
- 2026-10-09T19:02:25Z · needs_input
- 2026-10-09T19:02:49Z · review_cli_override
- 2026-10-09T19:02:51Z · review_model_override
- 2026-10-09T19:02:52Z · body: section Final focused review repair
- 2026-10-09T19:02:54Z · status review→active
- 2026-10-09T19:07:29Z · status active→review
- 2026-10-09T19:07:29Z · note: shots: skipped — 3 handoff shots already captured for this exact plan (ace4c66) during finalization (#0734)
- 2026-10-09T19:08:23Z · note: review pass 5: good to go
- 2026-10-09T19:08:23Z · needs_input
- 2026-10-09T19:08:32Z · status review→active
- 2026-10-09T19:08:32Z · note: close-out repair: merge-conflict
- 2026-10-09T19:40:36Z · status active→review
- 2026-10-09T19:41:36Z · note: review pass 6: good to go

