---
id: "0049"
title: Battery item does not show the charging state on the bar
type: bug
status: ready
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T15:53:55Z"
updated_at: "2026-10-11T15:53:55Z"
---
## Problem

The battery item shows only the level. The maintainer is charging the Mac, and the bar shows no charging indicator. The reader (SystemBatteryReading) and the presentation (WidgetPresentation, batterySymbol) both handle `isCharging` and would use a bolt symbol, so the state is lost somewhere between them and the bar.

## Desired UX

- While the Mac is charging, the battery item shows a charging indicator (a bolt), and it goes back to the plain battery when charging stops.
- The charging state updates live when the power source changes.

## Acceptance criteria

- Trace the charging state from SystemBatteryReading through the provider to the bar view, and fix the point where it is dropped.
- Add a test that a snapshot with isCharging true produces the bolt symbol on the bar item, and one with it false produces the plain symbol.
- Verify on the packaged app while charging; record the observed symbol in the task.
- repoos check passes.

## Notes for AI

Relevant code: macos/Sources/DivotAppKit/SystemBatteryReading.swift, macos/Sources/DivotCore/WidgetPresentation.swift (batterySymbol), and the bar's symbol rendering in WidgetViews.swift.

## Activity

- 2026-10-11T15:53:55Z · created · njachowski@gmail.com
- 2026-10-11T15:53:55Z · status inbox→ready
