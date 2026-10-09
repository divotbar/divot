---
name: Make either side of the bar my own
number: "0004"
created_at: "2026-10-09T16:41:11.330Z"
created_by: api
---
## User story

As a power user, I want to choose what appears on both sides of Divot and how much detail each item shows, so the bar matches my workflow instead of enforcing a fixed layout.

## Scope

Both left and right are configurable groups. Add/remove/reorder supported widgets and move them between groups when appropriate. Workspace app icons, workspace empty-state visibility, front-app text/icon and status detail are configurable. File customization is a core supported path; settings edit the same model.

## Acceptance criteria

- A versioned schema expresses left/right item order and namespaced per-widget options rather than hard-coding workspaces left and a status-only right array as the only possible arrangement.
- Defaults still match the first-launch story; customization never requires starting from a blank bar.
- Toggles for per-workspace app icons and detail work independently of theme selection.
- Validate before applying; invalid reload preserves the last good snapshot and explains the field error.
- Persist changes atomically, reject unsupported versions, and migrate existing starter examples intentionally.
- Disabled providers stop collecting; moving/reordering an item does not duplicate provider activity.
- Keyboard-accessible settings and documented file examples cover every supported option.

## Non-goals

A marketplace and arbitrary in-process binary plugins are not prerequisites. Extensible/script widgets follow after the native registry and resource limits are stable; do not claim existing xbar/SketchyBar compatibility.
