---
updated_at: "2026-10-10T00:55:14Z"
review_passes: 1
id: "0018"
title: "Add a keep-awake (Caffeine-style) toggle to the right side, on the battery item"
type: feature
status: review
priority: p1
area: macos
depends_on: ["0016"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-keep-awake-caffeine-style-toggle-t
created_at: "2026-10-09T20:50:06Z"
---
## Problem

The maintainer uses Caffeine / Amphetamine every day to stop the laptop from sleeping. Divot should offer that as an option on the right side of the bar, so one click toggles keep-awake.

## Desired UX

- Clicking the battery item (percentage and icon) toggles keep-awake on and off.
- When it is on, a clear indicator sits next to the battery (an icon or a subtle animation, such as a filled cup or a pulse) so the state is obvious at a glance. Off shows no indicator or a dimmed one.
- The state survives relaunch only if the user opts in; the default is off at launch.
- Tooltips use styled popovers, not native `title` attributes (AGENTS.md).

## Acceptance criteria

- Keep-awake uses a public API only (IOKit power assertions, `PreventUserIdleDisplaySleep` / `PreventUserIdleSystemSleep`). No private APIs and no shelling out to `caffeinate` if the assertion API is available.
- Turning it on creates the assertion and turning it off releases it. Quitting Divot releases any held assertion. A test checks the assertion lifecycle through an injectable seam.
- The toggle is a provider/widget action using the existing widget pipeline, not a new ad-hoc timer.
- The indicator changes with the state and is readable in every shipped theme (contrast audit passes for the new text/icon colours).
- A Settings entry controls whether the state is remembered across launches (default off). Route it through the configuration store (0006).
- `repoos check` passes. A screenshot is evidence only; do not claim a human checked the look.

## Notes for AI

Depends on #0016 (bar sizing), which touches the same widget view files. Start only after #0016 is done. Keep the first version to a single toggle with an on/off indicator; durations and timers can come later.

## Activity

- 2026-10-09T20:50:06Z · created · njachowski@gmail.com
- 2026-10-10T00:42:28Z · status inbox→ready
- 2026-10-10T00:42:29Z · status ready→active, branch
- 2026-10-10T00:54:34Z · status active→review
- 2026-10-10T00:54:35Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T00:55:14Z · note: review pass 1: good to go

