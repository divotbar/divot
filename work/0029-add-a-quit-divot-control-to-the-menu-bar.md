---
id: "0029"
title: Add a Quit Divot control to the menu bar menu and the Settings window
type: feature
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-quit-divot-control-to-the-menu-bar
created_at: "2026-10-10T13:19:42Z"
updated_at: "2026-10-10T13:26:48Z"
---
## Problem

There is no in-app way to quit Divot. The only ways to stop a running bar are a terminal command or the Dev page, which makes it hard to end an instance that is running from the packaged app.

## Desired UX

- The Divot menu bar menu has a "Quit Divot" item.
- The Settings window has a "Quit Divot" button, placed away from other controls so it isn't hit by accident.
- Quitting releases any keep-awake assertion (#0018) and removes the bar cleanly.

## Acceptance criteria

- Add "Quit Divot" to the status item menu and a button to the Settings window, both calling a single quit path through the application delegate.
- Quit goes through `NSApplication.terminate`, so the existing shutdown paths run, including releasing keep-awake assertions.
- The Settings button asks for confirmation through the shared dialog component, not a native `alert()`.
- Tests cover the single quit path and that the keep-awake release runs on quit.
- `repoos check` passes.

## Notes for AI

Keep the menu item in the existing status item setup in `DivotAppDelegate`. Do not add a new window for confirmation; use the shared dialog component.

## Activity

- 2026-10-10T13:19:42Z · created · njachowski@gmail.com
- 2026-10-10T13:19:46Z · note: Scope correction: the status item menu already has a Quit Divot item (DivotAppDelegate, around lines 245 and 268). This task only needs the Settings window button, plus a test that the menu and Settings both reach the same quit path.
- 2026-10-10T13:20:50Z · status inbox→ready
- 2026-10-10T13:20:50Z · status ready→active, branch
- 2026-10-10T13:26:48Z · status active→review
