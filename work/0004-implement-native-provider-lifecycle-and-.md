---
id: "0004"
title: "Implement native provider lifecycle and clock, power, front-app widgets"
type: feature
status: inbox
priority: p1
area: macos
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T16:18:39Z"
---
## Problem

The bar has no real status providers yet.

## Desired UX

Native notifications, immutable snapshots, bounded off-main work; minute clock, battery, front-app.

## Acceptance criteria

Lifecycle/cancellation tests; stale snapshots ignored; provider failure leaves others responsive; no main-thread I/O; disabled providers release observers.

## Notes for AI

Depends on the panel shell. Use docs/performance.md; no shell polling for built-ins.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
