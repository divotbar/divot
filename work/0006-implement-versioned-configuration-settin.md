---
id: "0006"
title: "Implement versioned configuration, settings, and appearance modes"
type: feature
status: inbox
priority: p1
area: macos
depends_on: ["0004", "0005"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T16:18:39Z"
---
## Problem

Proposed JSON examples need a native parser and user settings.

## Desired UX

One validated model, atomic hot reload, preserved last-good snapshot, System/Light/Dark overrides, native settings and login-item control.

## Acceptance criteria

Contract tests using examples; reject unknown fields; invalid reload preserved; persisted appearance across launches; cache invalidation scoped; all surfaces accessible in both modes.

## Notes for AI

Read docs/configuration.md and appearance release gate. SwiftUI permitted for settings only. Add schema/reference changes together.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
