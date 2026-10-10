---
id: "0012"
title: "Add the second workspace adapter: yabai"
type: feature
status: review
priority: p2
area: [macos, docs]
story: Navigate the workspaces and apps I actually use
depends_on: ["0005"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-the-second-workspace-adapter-yabai
created_at: "2026-10-09T16:41:13Z"
updated_at: "2026-10-10T00:38:27Z"
review_passes: 2
close_out_repair_count: 1
---
## Problem

AeroSpace-only workspaces exclude people using yabai.

## Desired UX

A shared capability model supports yabai as the second integration, with real labels, focused/occupied states and optional app icons.

## Acceptance criteria

Fixture tests for yabai query/events and actions, async timeouts/cancellation, capability/manager selection, per-display mapping and no fake support. Record any dependency on special system privileges explicitly; do not require private APIs in Divot without an approved decision.

## Notes for AI

Second integration milestone; AeroSpace first. No blocker to an AeroSpace-first release. Update setup/troubleshooting docs.

## Shots
```json
[
{
"label": "Troubleshooting: yabai detection, adapter override, and no scripting addition",
"target": "website",
"route": "/guide/troubleshooting",
"highlight": "#yabai-isn-t-detected-or-shows-the-wrong-workspaces"
},
{
"label": "Configuration: workspaces adapter accepts aerospace or yabai",
"target": "website",
"route": "/reference/configuration",
"highlight": "#widget-options"
}
]
```

## Activity

- 2026-10-09T16:41:13Z · created · njachowski@gmail.com
- 2026-10-09T17:20:41Z · status inbox→ready
- 2026-10-09T20:33:16Z · status ready→active, branch
- 2026-10-09T21:11:27Z · body: section Shots
- 2026-10-09T21:13:24Z · status active→review
- 2026-10-09T21:14:30Z · note: review pass 1: good to go
- 2026-10-09T23:50:23Z · status review→active
- 2026-10-09T23:50:23Z · note: close-out repair: merge-conflict
- 2026-10-09T23:57:54Z · status active→review
- 2026-10-09T23:58:46Z · note: review pass 2: good to go
- 2026-10-10T00:09:24Z · status review→active
- 2026-10-10T00:09:24Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-10T00:37:40Z · status active→review
- 2026-10-10T00:38:27Z · note: review pass 3: good to go
