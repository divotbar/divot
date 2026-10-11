---
id: "0036"
title: Toggle the battery percentage on or off in Settings
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/toggle-the-battery-percentage-on-or-off-
created_at: "2026-10-11T00:41:47Z"
updated_at: "2026-10-11T00:50:22Z"
---
## Problem

The battery item always shows the percentage. The maintainer wants it optional.

## Desired UX

- Settings has a "Show battery percentage" toggle, on by default to keep today's look.
- With it off, the battery item shows the icon only.

## Acceptance criteria

- Add a `showBatteryPercent` configuration key (default true), persisted through the configuration store, with a toggle in the settings window.
- The battery item hides the percentage live, without a relaunch.
- Tests cover the default and the label with and without the percentage.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep changes to the battery widget's label, not the battery reading.

## Activity

- 2026-10-11T00:41:47Z · created · njachowski@gmail.com
- 2026-10-11T00:43:54Z · status inbox→ready
- 2026-10-11T00:43:55Z · status ready→active, branch
- 2026-10-11T00:50:22Z · status active→review
