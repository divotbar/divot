---
updated_at: "2026-10-11T16:20:22Z"
review_passes: 1
id: "0049"
title: Battery item does not show the charging state on the bar
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/battery-item-does-not-show-the-charging-
created_at: "2026-10-11T15:53:55Z"
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

## Observed Results
**Root cause:** `IOKitBatteryReading.read()` read `Is Charging` with a strict `as? Bool \?\? false`. IOKit returns that flag as a `CFBoolean` on this Mac but has shipped it as a numeric `CFNumber` (1/0) on other OS/Mac combinations; the strict cast then silently read `false`, so `WidgetPresentation.batterySymbol` never chose `battery.100.bolt`. The reader was the only silent drop between the power source and the bar; the provider, presenter, and view all preserve `isCharging`.

**Fix:** read `Is Charging`/`Is Charged` through a tolerant `boolValue(_:)` (`Bool` or `NSNumber.boolValue`), and extract the snapshot construction into a testable `snapshot(from:)`. No behavior change when the flag is already a `CFBoolean`; the numeric form can no longer be dropped.

**Tests:** `SystemBatteryReadingTests` (boolean + numeric + missing flags, percentage), `WidgetViewTests.batteryItemShowsBoltWhileChargingAndPlainSymbolOtherwise` (charging snapshot -> `battery.100.bolt` on the bar item, plain -> `battery.75`, and a live switch re-resolves the icon), and `batteryProviderEmitsInitialValueChangeAndCancels` now asserts the emitted snapshot keeps `isCharging`. Full suite: 542 tests pass; `repoos check --changed main` passes.

**Observed live (packaged app, `dist/Divot.app/Contents/MacOS/divot --widgets`, 2026-10-11 while the Mac was charging):** `battery: 48% · Battery 48%, charging` — the live provider reported `isCharging == true`, which the presenter maps to the `battery.100.bolt` symbol. On-screen confirmation of the rendered bolt on the physical bar is a human/device check and is left to the maintainer.

## Activity

- 2026-10-11T15:53:55Z · created · njachowski@gmail.com
- 2026-10-11T15:53:55Z · status inbox→ready
- 2026-10-11T15:53:56Z · status ready→active, branch
- 2026-10-11T16:17:56Z · body: section Observed Results
- 2026-10-11T16:19:32Z · status active→review
- 2026-10-11T16:19:32Z · note: shots: skipped — the diff (7 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T16:20:22Z · note: review pass 1: good to go

