---
id: "0051"
title: Keep-awake indicator should only show when Divot itself is keeping the Mac awake
type: bug
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/keep-awake-indicator-should-only-show-wh
created_at: "2026-10-12T06:54:32Z"
updated_at: "2026-10-12T07:12:39Z"
handoff_signal_retry_count: 1
---
## Problem

The cup indicator next to the battery (keep-awake active, drawn in green) appears whenever any app is keeping the Mac awake, not only when Divot's own keep-awake toggle is on. During a video call the microphone and speaker hold sleep assertions, and `pmset -g assertions` also shows caffeinate processes, so the cup appears even though the user never turned on Divot's keep-awake.

The indicator is driven by `isKeepingAwake` on the battery snapshot (WidgetPresentation.swift, batteryPresentation), which reflects system-wide sleep prevention rather than Divot's own assertion.

## Desired UX

- The cup appears only while Divot's own keep-awake toggle is on.
- Other apps' sleep prevention does not show the cup.

## Acceptance criteria

- Track the keep-awake state from Divot's own power assertion (the one created when the toggle is on), not from system-wide assertions.
- Add a test: with the toggle off and another app holding a sleep assertion, no cup is shown; with the toggle on, the cup is shown.
- Verify on the packaged app: the cup is absent during a call while Divot's toggle is off. Record the `pmset` output and the bar state in the task.
- repoos check passes.

## Notes for AI

Relevant code: the keep-awake provider (SystemKeepAwake / KeepAwake observation), the battery snapshot's isKeepingAwake, and batteryPresentation in WidgetPresentation.swift. Keep the change to the source of the keep-awake state.

## Activity

- 2026-10-12T06:54:32Z · created · njachowski@gmail.com
- 2026-10-12T06:54:33Z · status inbox→ready
- 2026-10-12T06:54:33Z · status ready→active, branch
- 2026-10-12T07:11:45Z · status active→review
- 2026-10-12T07:11:45Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T07:12:39Z · note: review pass 1: needs some work
