---
id: "0012"
title: "Add the second workspace adapter: yabai"
type: feature
status: active
priority: p2
area: [macos, docs]
story: Navigate the workspaces and apps I actually use
depends_on: ["0005"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-the-second-workspace-adapter-yabai
created_at: "2026-10-09T16:41:13Z"
updated_at: "2026-10-09T20:33:16Z"
---
## Problem

AeroSpace-only workspaces exclude people using yabai.

## Desired UX

A shared capability model supports yabai as the second integration, with real labels, focused/occupied states and optional app icons.

## Acceptance criteria

Fixture tests for yabai query/events and actions, async timeouts/cancellation, capability/manager selection, per-display mapping and no fake support. Record any dependency on special system privileges explicitly; do not require private APIs in Divot without an approved decision.

## Notes for AI

Second integration milestone; AeroSpace first. No blocker to an AeroSpace-first release. Update setup/troubleshooting docs.

## Activity

- 2026-10-09T16:41:13Z · created · njachowski@gmail.com
- 2026-10-09T17:20:41Z · status inbox→ready
- 2026-10-09T20:33:16Z · status ready→active, branch
