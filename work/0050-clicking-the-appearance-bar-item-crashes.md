---
id: "0050"
title: Clicking the Appearance bar item crashes Divot (SIGTRAP)
type: bug
status: active
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/clicking-the-appearance-bar-item-crashes
created_at: "2026-10-12T05:09:55Z"
updated_at: "2026-10-12T05:19:41Z"
---
## Problem

Clicking the Appearance bar item (#0037) makes the bar disappear: the process exits with SIGTRAP, a Swift runtime trap. The item is meant to switch Divot's own bar between light and dark, and must not change the macOS setting.

The click path is `SystemAppearanceReading.toggleAppearance()` (macos/Sources/DivotAppKit/SystemAppearanceReading.swift), which is marked nonisolated, dispatches to the main queue, reads `NSApplication.shared.effectiveAppearance`, sets `NSApp.appearance`, and then calls the change handler inside `Task { @MainActor in ... }`. A Swift concurrency or actor-isolation check is the likely trap; the force unwraps of `NSAppearance(named:)` are unlikely to be the cause.

## Desired UX

- Clicking the Appearance item toggles Divot's bar between light and dark and the bar stays up.
- The item updates to show the new mode.
- No macOS system setting is changed.

## Acceptance criteria

- Reproduce the crash from the packaged app (dist/Divot.app), capture the crashing thread, and record it in the task.
- Fix the isolation or threading so the toggle runs on the main actor without a trap.
- Add a test that calling the toggle twice flips the mode and does not crash.
- Verify the bar stays up after several clicks; record the result in the task.
- repoos check passes.

## Notes for AI

Scope is Divot's own bar theme only (rescoped in #0037). Do not use AppleScript, System Events or any private API.

## Evidence
### Crash reproduced (pre-fix packaged app)

Built the pre-fix source into a packaged bundle and launched it with the
Appearance item placed (`right: ["battery","appearance"]`) on this Mac:

  scripts/package-app.sh --configuration debug --output /tmp/divot-prefix-dist --no-archive
  XDG_CONFIG_HOME=/tmp/dvcfg /tmp/divot-prefix-dist/Divot.app/Contents/MacOS/divot
  # -> Trace/BPT trap: 5, exit 133

macOS crash report `~/Library/Logs/DiagnosticReports/divot-2026-10-12-121822.ips`
(`bug_type 309`, `exception EXC_BREAKPOINT / SIGTRAP`, `faultingThread 0`,
queue `com.apple.main-thread`), crashing stack:

  0  libdispatch.dylib        __DISPATCH_WAIT_FOR_QUEUE__ +612
  1  libdispatch.dylib        _dispatch_sync_f_slow +140
  2  libswiftDispatch.dylib   OS_dispatch_queue.sync<A>(execute:) +64
  3  divot                    SystemAppearanceReading.snapshot() +108
  4  divot                    protocol witness for AppearanceReading.snapshot()
  5  divot                    closure #1 in closure #1 in AppearanceProvider.start(emit:)
  ...

Root cause: `SystemAppearanceReading.snapshot()` was `nonisolated` and reached
AppKit through `DispatchQueue.main.sync`. The provider's initial push and the
toggle's change handler both already run on the main actor, so libdispatch
detected `sync` onto the occupied main queue and trapped. The click path
(`toggleAppearance` -> change handler -> `push` -> `snapshot`) hits the same
call.

### Fix

- `AppearanceReading` is now `@MainActor` (matching `FrontAppReading`).
- `SystemAppearanceReading` is `@MainActor` and reads
`NSApplication.shared.effectiveAppearance` directly; the `DispatchQueue.main.sync`
dispatch is gone. `observeChanges` uses `MainActor.assumeIsolated` on the
main-queue notification callback; `toggleAppearance` sets
`NSApplication.shared.appearance` and calls the handler on the main actor.

### Verification

- `macos/Tests/DivotAppKitTests/SystemAppearanceReadingTests.swift` (4 tests,
all pass): toggle twice flips light -> dark -> light; six toggles keep
alternating; the observer is notified per toggle; `AppearanceProvider.start`
emits on start and after a toggle (the exact path that trapped).
- Fixed packaged app stayed up for 5 s with the Appearance item placed:
`/tmp/divot-fixed-dist/Divot.app/Contents/MacOS/divot` -> alive, no trap.
- `REPOOS_CHECK_CHANGED=main repoos check` -> all checks passed (548 tests).

Honest scope: this agent environment has no display session, so a literal mouse
click on the packaged bar was not performed here. The click handler chain is
covered by the automated provider/toggle tests; a physical click on the packaged
app still needs a human to confirm on hardware.


## Activity

- 2026-10-12T05:09:55Z · created · njachowski@gmail.com
- 2026-10-12T05:09:55Z · status inbox→ready
- 2026-10-12T05:09:56Z · status ready→active, branch
- 2026-10-12T05:19:41Z · body: section Evidence
