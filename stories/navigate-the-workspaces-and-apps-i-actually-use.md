---
name: Navigate the workspaces and apps I actually use
number: "0003"
created_at: "2026-10-09T16:41:11.067Z"
created_by: api
---
## User story

As a workspace user, I want Divot to reflect my current window manager and show where my applications are, so I can navigate confidently without configuring a second workspace system.

## Experience

Workspace indicators and the frontmost program belong on the left by default. Use real manager workspace labels instead of inventing fixed numbered spaces. Focused, occupied and empty states are distinguishable; optional app icons show applications on each workspace. Clicking an indicator activates that workspace asynchronously without stealing focus for the bar itself.

## Acceptance criteria

- AeroSpace first; yabai second through a separate adapter and delivery milestone.
- A shared adapter model carries workspace IDs/names, focused/occupied state, monitor association and optional deduplicated app identities/icons.
- Detect supported capabilities and avoid undocumented sockets or frame-rate CLI queries.
- Icons and extra detail can be toggled off; overflow never crosses the camera housing.
- Multiple installed managers have a deterministic choice with a user override; reconfiguration/disconnect cancels stale adapter work.
- No manager available is an honest unavailable state, not fake native Spaces support.

## Native macOS Spaces

Native Spaces is a research question, not a confirmed implementation commitment. Investigate public APIs and their limits for listing/switching Spaces and mapping apps. Keep this separate from AeroSpace delivery; do not imply that NSWorkspace notifications provide a full native workspace adapter.
