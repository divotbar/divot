---
id: "0031"
title: Optional %/muted label on the volume item in Settings
type: feature
status: review
priority: p2
area: macos
depends_on: ["0028"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/optional-muted-label-on-the-volume-item-
created_at: "2026-10-11T00:39:23Z"
updated_at: "2026-10-11T00:50:16Z"
---
## Problem

The volume item always shows a percentage and a muted label. The maintainer wants each to be optional.

## Desired UX

- Settings has two toggles for the volume item: "Show percentage" and "Show muted state", both on by default to keep today's look.
- With both off, the item shows only the volume icon.

## Acceptance criteria

- Add `showVolumePercent` and `showVolumeMuted` configuration keys (default true), persisted through the configuration store, with toggles in the settings window.
- The volume item hides the matching text live, without a relaunch.
- Tests cover the defaults and the label output for each combination.
- `repoos check` passes.

## Notes for AI

Depends on #0028. Keep changes to the volume widget's label, not the volume reading.

## Activity

- 2026-10-11T00:39:23Z · created · njachowski@gmail.com
- 2026-10-11T00:43:52Z · status inbox→ready
- 2026-10-11T00:43:52Z · status ready→active, branch
- 2026-10-11T00:50:16Z · status active→review
