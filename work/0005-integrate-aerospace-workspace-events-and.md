---
id: "0005"
title: Integrate AeroSpace workspace events and actions
type: feature
status: ready
priority: p1
area: macos
story: Navigate the workspaces and apps I actually use
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T17:20:38Z"
---
## Problem

Workspace navigation must reflect the installed manager, with AeroSpace delivered first.

## Desired UX

Real workspace names, focus/occupied/empty state and optional deduplicated app icons on the left; current program beside them.

## Acceptance criteria

Capability detection, supported events/callbacks, async actions/timeouts, adapter lifecycle fixtures, app icon inventory, per-monitor mapping and overflow. No manager means honest unavailable state; no fake numbered workspaces. Customization can toggle app icons/details. No frame-rate subprocess queries.

## Notes for AI

AeroSpace first, shared interfaces for subsequent yabai. Native Spaces is a separate research task, not a delivery promise.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:14Z · story, body
- 2026-10-09T17:20:38Z · status inbox→ready
