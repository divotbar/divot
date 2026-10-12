---
id: "0056"
title: Battery charging state updates immediately when plugging and unplugging
type: bug
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/battery-charging-state-updates-immediate
created_at: "2026-10-12T08:36:23Z"
updated_at: "2026-10-12T08:39:42Z"
---
## Problem

The battery's charging bolt appears late after plugging in, sometimes minutes later, and disappears right away when unplugged. The native menu bar updates at once. The reader (SystemBatteryReading) is event-driven through IOPSNotificationCreateRunLoopSource, with no polling, so the delay is likely a power-source notification that updates the charge level without updating the charging flag. The cause is unconfirmed.

## Desired UX

- Plugging in shows the charging bolt within about a second, the same as the native battery.
- Unplugging removes it at once.

## Acceptance criteria

- Confirm the cause by logging each power-source notification with its isCharging and isPluggedIn values during a plug-in and an unplug on the packaged app. Record the log in the task.
- Fix it so the charging state is read on every power-source notification, not just the level, and the bar re-renders on any change to the state.
- If notifications can lag, add a bounded check of the power-source state that runs only on a short fixed interval, documented in the task.
- Test a plug-in and an unplug transition with a fake power source.
- repoos check passes.

## Notes for AI

Relevant code: SystemBatteryReading.swift (notification callback and the isCharging read) and the provider's update path. Keep the change to the battery reading and its update path.

## Fix and evidence
### Cause

The reader already reads the whole `BatterySnapshot` (including `Is Charging`)
on every `IOPSNotificationCreateRunLoopSource` callback, but one read at
notification time is not enough: IOKit can deliver the power-source
notification before the charging flag flips. On plug-in the first read can see
`isPluggedIn = true, isCharging = false`, and no second notification is
guaranteed when charging actually begins, so the bolt is missed until the next
percentage change (minutes later). On unplug the flag is already false at
notification time, which is why it disappears at once. This is the inferred
cause; the hardware log below is still required to confirm it.

### Fix

- `DivotCore.BatteryRecheckWindow` is a pure, unit-tested value type for a
bounded follow-up window: each notification arms up to `maxAttempts` (4)
re-checks on a fixed `interval` (1s), and the window closes on its own
(`close()`/exhaustion). It is not continuous polling.
- `PowerSourceRunLoopObserver` (SystemBatteryReading.swift) fires the handler
immediately on every power-source notification, then runs a repeating run-loop
`Timer` on the same dedicated background run loop while the window is active.
Each tick re-reads the full snapshot, so a charging flag that flips a moment
after the notification is observed within about a second. The timer is
invalidated when the window closes or the observer stops.
- `IOKitBatteryReading.read()` logs each read at debug level with
`charging=` and `plugged=` so a person can confirm the notification timing on
hardware.
- The provider's update path is unchanged: it re-reads `reading.snapshot()` and
emits on every handler call, so the bar re-renders whenever the state changes.

### Tests

- `DivotCoreTests.BatteryRecheckTests` covers the bounded window: attempts are
limited, a new notification restarts it, it can be disabled/closed, and a
non-positive interval is clamped.
- `WidgetProviderTests.batteryProviderFollowsFakePowerSourcePlugInAndUnplug`
drives a fake power source through unplugged → plugged (flag lags, then flips)
→ unplugged and asserts each emission, so a plug/unplug transition is covered
without real hardware.
- `REPOOS_CHECK_CHANGED=main repoos check` passes.

### Still needed from a human (not observed in this run)

The acceptance criterion to log a real plug-in and unplug on the packaged app
has not been performed: it needs a Mac with an internal battery and a person to
plug/unplug while streaming

  log stream --predicate 'subsystem == "com.divot.Divot" && category == "battery"'

The captured `charging=`/`plugged=` lines must be recorded here by a human. Do
not treat this section as that evidence.


## Activity

- 2026-10-12T08:36:23Z · created · njachowski@gmail.com
- 2026-10-12T08:36:29Z · status inbox→ready
- 2026-10-12T08:36:30Z · status ready→active, branch
- 2026-10-12T08:39:42Z · body: section Fix and evidence
