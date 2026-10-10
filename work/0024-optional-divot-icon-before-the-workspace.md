---
id: "0024"
title: Optional Divot icon before the workspace numbers that opens Settings when clicked
type: feature
status: active
priority: p1
area: macos
depends_on: ["0022"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-divot-icon-before-the-workspace
created_at: "2026-10-10T09:48:56Z"
updated_at: "2026-10-10T09:49:00Z"
---
## Problem

The maintainer wants a Divot icon at the far left of the bar, before the workspace numbers, that opens the Divot settings window when clicked. It should be optional, controlled by a Settings toggle.

## Desired UX

- Settings has a toggle, "Show the Divot icon before the workspaces", off by default.
- When on, the Divot mark (the landing-page mark, `site/public/mark.svg`) sits at the start of the left group, before the workspace numbers.
- Clicking the icon opens the Divot settings window.
- The icon follows the bar's theme colours and scales with the text and icon size set in #0022.

## Acceptance criteria

- Add a `showAppIcon` configuration key, default false, persisted through the configuration store (0006), with a Settings toggle in the existing settings window (0017).
- The icon renders from the same mark used for the menu bar icon (#0019). It is a template image, so it adapts to light and dark themes.
- Clicking the icon opens the settings window; keyboard focus and an accessible label are set; no native `title` tooltip is used.
- Toggling the setting shows or hides the icon live, without relaunch, and survives relaunch.
- Tests cover the config round-trip, the default being off, and the click action routing to the settings window.
- `repoos check` passes. A screenshot is evidence only; the maintainer confirms how it looks.

## Notes for AI

Depends on #0022, which changes the text and icon size metrics this icon must follow. Do not start until #0022 is done. Keep the click action routed through the existing settings-window opener, not a new window path.

## Activity

- 2026-10-10T09:48:56Z · created · njachowski@gmail.com
- 2026-10-10T09:48:59Z · status inbox→ready
- 2026-10-10T09:49:00Z · status ready→active, branch
