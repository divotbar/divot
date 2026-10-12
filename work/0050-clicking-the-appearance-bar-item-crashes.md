---
id: "0050"
title: Clicking the Appearance bar item crashes Divot (SIGTRAP)
type: bug
status: review
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/clicking-the-appearance-bar-item-crashes
created_at: "2026-10-12T05:09:55Z"
updated_at: "2026-10-12T05:21:27Z"
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

## Activity

- 2026-10-12T05:09:55Z · created · njachowski@gmail.com
- 2026-10-12T05:09:55Z · status inbox→ready
- 2026-10-12T05:09:56Z · status ready→active, branch
- 2026-10-12T05:21:27Z · status active→review
