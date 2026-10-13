---
id: "0091"
title: Tests must never put real Divot bars or popovers on the maintainer's screen
type: bug
status: ready
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T16:33:40Z"
updated_at: "2026-10-13T16:50:44Z"
---
## Problem
Maintainer report 2026-10-13: 'a lot of test instances of Divot running, bars all over my screen'. Process check at 23:35: only ONE real Divot app (dist/Divot.app, the maintainer's own, running for 6 hours); the rest are short-lived swiftpm-testing-helper processes started by the engineer agents' swift test runs (three engineers were running builds and tests at once). Those tests create REAL AppKit windows: BarPopoverTests.swift calls host.present(content, relativeTo: anchor) (lines ~85 and ~219), which goes through BarPopoverHost.present -> panel.makeKeyAndOrderFront(nil) (BarPopover.swift ~472); DisplayCoordinatorWidgetTests drive DisplayCoordinator / BarPanels, which order real panels to the front (BarPanels.swift orderFrontRegardless ~130). So every swift test run flashes bars and popovers over the maintainer's desktop, steals focus, and with several runs in parallel the screen fills with them.

## Desired UX
- Running swift test (by an agent or by hand) never shows a window, bar, popover or panel on screen, never steals focus, and never leaves a stray process behind.

## Acceptance criteria
- Find every test that makes a window visible: search macos/Tests for present(, orderFront, makeKeyAndOrderFront, show(relativeTo:), DisplayCoordinator.start, BarPanels creation and any NSApplication activation; list them in the task.
- Add a seam so production code orders panels front through an injectable 'WindowPresenter' (or a flag on BarPopoverHost/BarPanels) and tests inject a no-op presenter that records the call (assert 'would present' without ordering anything front). Offscreen snapshot renders keep working (they render views, not visible windows).
- A guard test or test-suite setup that fails if any test leaves a visible Divot window: after each test assert NSApp.windows.filter(\.isVisible) is empty, for the AppKit test target.
- Tests must not activate the app (NSApp.activate) or change the activation policy; they must not post real system notifications or open System Settings.
- swift test --package-path macos passes and, run while watching the screen or checking CGWindowListCopyWindowInfo during the run, shows no Divot window; record how you verified this (for example a test that lists on-screen windows owned by the test process before and after).
- Document the rule in docs/ (testing section) and add one line to AGENTS.md: tests must be windowless; use the injected presenter.
- Also make the repo's test and snapshot scripts run only one swift test at a time per machine (a simple lock file under macos/.build) so parallel agent runs queue instead of piling up and spiking the load; the lock must time out and never block forever.

## Notes for AI
Do not kill processes by name or pattern. Related: #0078/#0079 offscreen snapshot helpers (keep them offscreen), #0083 BarPopoverHost/BarPopoverPanel.

## Activity

- 2026-10-13T16:33:40Z · created · njachowski@gmail.com
- 2026-10-13T16:50:44Z · status inbox→ready
