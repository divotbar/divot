---
id: "0092"
title: "Banner probe v2: print every newly appearing window with its real layer, and measure Divot's actual window"
type: bug
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/banner-probe-v2-print-every-newly-appear
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T16:56:56Z"
updated_at: "2026-10-13T18:49:54Z"
review_passes: 3
last_check_failure: "repoos check at 2026-10-13T18:41:26.243Z: repoos check failed: native-core — 􁁛 Suite \"Windowless presentation\" passed after 10.578 seconds."
review_rounds: 2
handoff_signal_retry_count: 1
---
## Problem
#0089 fixed the layer key but main's divot-notification-banner-probe --watch (DivotNotificationBannerProbe/main.swift, watchForNotificationWindows) still only reports windows whose owner name contains the exact, case-sensitive text 'NotificationCenter'. The maintainer ran it twice (2026-10-13 23:28 and 23:53) with real system overlays on screen (the Control Center panel was opened during the second run) and it printed only 'No NotificationCenter windows observed'. It also prints 'Divot panel layer for comparison: 23', computed from NSWindow.Level.mainMenu.rawValue - 1, not measured from Divot's real panel. The maintainer's Mac currently has Do Not Disturb on, so test notifications never appear; the Control Center panel is the reliable reference overlay.

## Desired UX
- --watch [seconds] polls CGWindowListCopyWindowInfo twice a second and prints EVERY window that newly appears or whose bounds/layer change between polls, whatever its owner: timestamp, owner name, owner PID, window name, layer, CG bounds and AppKit-flipped bounds (clearly labelled), alpha and whether it is on screen.
- It flags NotificationCenter banners (owner contains NotificationCenter or Notification Center, case-insensitive, or the process whose bundle id is com.apple.notificationcenterui) and ControlCenter windows (com.apple.controlcenter) explicitly so they are easy to find in the output.
- Divot's real layer is MEASURED: find the Divot bar panel windows in the same list (owner Divot, bounds at the top edge) and print their actual layer and bounds next to every new window, plus a one-line comparison ('Control Center panel layer 101 is above Divot panel layer 24', and so on).
- A final summary lists the highest-layer windows seen and says plainly when nothing new appeared.

## Acceptance criteria
- Pure functions for owner matching and for diffing two window lists, unit tested with sample dictionaries (new window, bounds change, layer change, banner owner variants, ControlCenter owner, windows without a name).
- The watch loop uses the shared parsing (kCGWindowLayer, bounds dictionary parsing) and prints the Divot panel's measured layer, or says that no Divot window was found.
- Update docs/evidence/0075-notification-banner-overlap.md and docs/troubleshooting.md with the exact command and the Control Center reference method, and note that Focus/Do Not Disturb suppresses banners.
- No private APIs. swift build, swift test --package-path macos and repoos check --changed main pass.
- Do not claim banner measurements: the maintainer runs the probe (task #0080).

## Notes for AI
Related: #0075, #0080, #0089. Do not kill processes by name.

## Activity

- 2026-10-13T16:56:56Z · created · njachowski@gmail.com
- 2026-10-13T17:19:22Z · status inbox→ready
- 2026-10-13T17:19:22Z · cli_override, model_override
- 2026-10-13T17:19:23Z · status ready→active, branch
- 2026-10-13T17:33:30Z · message_queued at 2026-10-13T17:33:30.802Z
- 2026-10-13T17:33:30Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T18:07:52Z · message_delivered: 1 message(s)
- 2026-10-13T18:11:09Z · status active→review
- 2026-10-13T18:11:18Z · note: 28 more images not shown (cap 12 per task) — declare a `## Shots` entry with a `glob` to capture a specific one
- 2026-10-13T18:11:50Z · note: review pass 1: needs some work
- 2026-10-13T18:11:50Z · status review→active
- 2026-10-13T18:20:31Z · message_queued at 2026-10-13T18:20:31.043Z
- 2026-10-13T18:36:01Z · message_delivered: 1 message(s)
- 2026-10-13T18:39:14Z · status active→review
- 2026-10-13T18:39:26Z · note: 28 more images not shown (cap 12 per task) — declare a `## Shots` entry with a `glob` to capture a specific one
- 2026-10-13T18:40:08Z · note: review pass 2: needs some work
- 2026-10-13T18:40:08Z · message_queued at 2026-10-13T18:40:08.933Z
- 2026-10-13T18:40:09Z · status review→active
- 2026-10-13T18:41:26Z · message_delivered: 1 message(s)
- 2026-10-13T18:44:32Z · status active→review
- 2026-10-13T18:44:32Z · note: shots: skipped — 12 handoff shots already captured for this exact plan (4c1b5492) during finalization (#0734)
- 2026-10-13T18:45:22Z · note: review pass 3: needs some work
- 2026-10-13T18:45:22Z · needs_input
- 2026-10-13T18:49:54Z · needs_input
- 2026-10-13T18:49:54Z · status review→active
- 2026-10-13T18:49:54Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
