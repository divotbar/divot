---
id: "0054"
title: "Default spacing: 17px on the right, half that between the Divot icon and workspaces, and 12px for the front app"
type: feature
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/default-spacing-17px-on-the-right-half-t
created_at: "2026-10-12T08:30:32Z"
updated_at: "2026-10-12T08:30:33Z"
---
## Problem

The bar spacing is wrong in three places, from the maintainer's screenshots:

1. The right side needs more space between its items. 17px is the right gap.
2. Applying 17px on the right makes the gap between the Divot icon and the workspaces too wide. That gap should be half of the right-side gap by default.
3. The front app next to the Divot icon should keep a 12px gap, and that gap must not change with the side spacing.

## Desired UX

- Right-side items are separated by 17px by default.
- The gap between the Divot icon and the workspace group defaults to half of the right-side gap, so 8.5px.
- The gap between the front app and the Divot icon stays 12px, regardless of the side spacing setting.

## Acceptance criteria

- Add `rightItemSpacing` (default 17), and a left default that is half of it, persisted through the configuration store, with sliders in Settings.
- The Divot-icon-to-workspaces gap follows the half-spacing default unless the user sets it explicitly.
- The front-app-to-Divot-icon gap is fixed at 12px and is not affected by any side-spacing setting.
- Tests cover the 17px default on the right, the half-value default on the left, and the fixed 12px front-app gap when the side spacing changes.
- Verify on the packaged app; record the measured gaps in the task. The maintainer confirms the look.
- repoos check passes.

## Notes for AI

Keep the change to item spacing in the layout code. Do not change the chips, the icon sizes or the opacity, which are in #0052.

## Activity

- 2026-10-12T08:30:32Z · created · njachowski@gmail.com
- 2026-10-12T08:30:33Z · status inbox→ready
- 2026-10-12T08:30:33Z · status ready→active, branch
