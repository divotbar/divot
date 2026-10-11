---
id: "0048"
title: Date and time items show a placeholder ellipsis on main instead of the date and time
type: bug
status: inbox
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T14:25:56Z"
updated_at: "2026-10-11T14:25:56Z"
---
## Problem

On current main, the Date and Time bar items show the three-dot placeholder ("…", the noData case in Widgets.swift) instead of the date and time. The bar was restarted from main and still shows it. The DateProvider and TimeProvider are not emitting snapshots. This started after the date-only change (#0046) and the time-format work (#0034) landed.

## Desired UX

- The Date item shows the date only, for example "Sun 11 Oct".
- The Time item shows the time in the chosen format.
- No placeholder ellipsis appears for either item when the system clock is available.

## Acceptance criteria

- Find where DateProvider and TimeProvider stopped emitting snapshots, and fix it.
- Add a test that each provider emits a snapshot on start and on a clock tick, and that neither emits noData.
- Verify on the packaged app that the date and time show text; record the observed text in the task.
- repoos check passes.

## Notes for AI

Relevant code: macos/Sources/DivotAppKit/DefaultWidgetProviders.swift and WidgetProviders.swift, and the noData case in macos/Sources/DivotCore/Widgets.swift. Keep the fix to the providers and their wiring.

## Activity

- 2026-10-11T14:25:56Z · created · njachowski@gmail.com
