---
id: "0057"
title: "Battery, volume and Wi-Fi icons match the native menu bar icon size"
type: feature
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/battery-volume-and-wi-fi-icons-match-the
created_at: "2026-10-12T08:36:24Z"
updated_at: "2026-10-12T08:36:31Z"
---
## Problem

The battery, volume and Wi-Fi icons on the Divot bar are small and hard to read beside the native menu bar icons. The maintainer wants them about the same size as the native icons.

## Desired UX

- The battery, volume and Wi-Fi icons match the size of the native menu bar icons on the same display.
- The size follows the bar's icon size setting, so it scales with it.

## Acceptance criteria

- Set the default symbol size for these three icons to match the native menu bar icon size, measured on the packaged app and recorded in the task.
- Icons scale with the app icon size setting, with a test at the smallest and largest sizes.
- Verify the three icons read at the same visual weight as the native bar's; the maintainer confirms the look.
- repoos check passes.

## Notes for AI

Keep the change to these three icons' symbol sizing. Do not change spacing or alignment, which are in #0054 and #0055.

## Activity

- 2026-10-12T08:36:24Z · created · njachowski@gmail.com
- 2026-10-12T08:36:31Z · status inbox→ready
- 2026-10-12T08:36:31Z · status ready→active, branch
