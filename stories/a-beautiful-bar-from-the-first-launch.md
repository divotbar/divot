---
name: A beautiful bar from the first launch
number: "0001"
created_at: "2026-10-09T16:41:10.545Z"
created_by: api
---
## User story

As a Mac user, I want to install and launch Divot and immediately see a good-looking, useful bar, so I can get on with my work without an onboarding questionnaire or writing a config file.

## Default experience

Left of the camera: actual workspace names/labels (1, 2, 3, 4 where applicable) and the currently selected/frontmost program. Right: battery percentage, time, day of week and date, Wi-Fi/network status, and volume. Use a polished default theme following macOS appearance. Prefer a compact default; per-workspace app icons and extra details are optional customization, not compulsory clutter.

## Acceptance criteria

- First launch loads built-in defaults without requiring a configuration file, account, or theme/setup questionnaire.
- Show real data; permission denial or an unavailable provider never blocks the whole bar.
- Detect a supported workspace manager where possible; first release supports AeroSpace. If unavailable, explain unavailable workspace controls without fake spaces or repeated prompts.
- Any essential permission request is contextual, minimal, and explained; unsupported Wi-Fi details degrade honestly instead of requesting unnecessary permissions on every launch.
- Battery displays a sensible no-battery state on desktop Macs; clock includes time + weekday + date by default, local to the user.
- A signed/notarized release launches without quarantine-stripping instructions.

## Scope and non-goals

This is the default journey, not a promise that the app exists today. Volume/network click actions can use native controls or safe settings links; design them explicitly during implementation. No mandatory wizard or hidden cloud dependency.

## Delivery

Native provider task #0004 and human release task #0008. Defaults/settings also depend on the configuration story. Performance and always-visible behavior are cross-cutting requirements.
