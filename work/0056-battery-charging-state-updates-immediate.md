---
id: "0056"
title: Battery charging state updates immediately when plugging and unplugging
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/battery-charging-state-updates-immediate
created_at: "2026-10-12T08:36:23Z"
updated_at: "2026-10-12T08:40:32Z"
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

## Activity

- 2026-10-12T08:36:23Z · created · njachowski@gmail.com
- 2026-10-12T08:36:29Z · status inbox→ready
- 2026-10-12T08:36:30Z · status ready→active, branch
- 2026-10-12T08:40:32Z · status active→review
