---
id: "0013"
title: Investigate native macOS Spaces adapter feasibility
type: feature
status: done
hold: true
priority: p2
area: [macos, docs]
story: Navigate the workspaces and apps I actually use
merged_commit: 6c94d24513418f87fb74a82f70409bba22e867b8
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/investigate-native-macos-spaces-adapter-
created_at: "2026-10-09T16:41:13Z"
updated_at: "2026-10-09T23:50:46Z"
last_close_out_gate_ms: 22527
last_close_out_gate_at: "2026-10-09T23:50:44.070Z"
review_passes: 1
---
## Problem

The user asked whether native Spaces can be adopted, but public API support has not been established.

## Desired UX

A concrete capability report distinguishes achievable public-API behavior from unavailable native workspace operations.

## Acceptance criteria

Primary-source/API research and a limited prototype, evidence for listing/switching Spaces/app mapping and multi-display behavior. Recommend supported scope with limitations; no claim of full native adapter without proof.

## Notes for AI

This is research, not a committed first-release adapter. Do not block AeroSpace or yabai or add private APIs merely to claim parity.

## Activity

- 2026-10-09T16:41:13Z · created · njachowski@gmail.com
- 2026-10-09T20:33:25Z · status inbox→ready
- 2026-10-09T20:33:26Z · status ready→active, branch
- 2026-10-09T21:08:45Z · status active→review
- 2026-10-09T21:08:45Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T21:09:16Z · note: review pass 1: good to go
- 2026-10-09T23:50:44Z · close-out gate completed in 23s
- 2026-10-09T23:50:46Z · status review→done, release:success
