---
id: "0079"
title: Offscreen bar rendering to PNG with pixel assertions (follow-up to popover snapshots)
type: chore
status: ready
priority: p3
area: macos
depends_on: ["0078"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T07:01:36Z"
updated_at: "2026-10-13T07:22:37Z"
---
## Problem
#0078 renders the popovers offscreen. The bar itself (workspaces, front app and right-side chips) has no offscreen render, so bar layout, spacing, chip style and the charging colour have no visual evidence.

## Desired UX
- Reuse the #0078 helper to render the bar view offscreen to PNG for every theme family in light and dark at the default and one larger text size, with chips on and off, into the same gitignored directory. Never commit PNGs.

## Acceptance criteria
- Pixel assertions without stored goldens: item order and gaps match BarMetrics, the 17px right inset, chip opacity applied, charging indicator is the fixed green while charging, text contrast meets the audit.
- If part of the bar cannot be rendered offscreen, state exactly what and why.
- docs updated; swift test --package-path macos passes.

## Notes for AI
Build on the helper and docs/popover-snapshot-testing.md from #0078.

## Activity

- 2026-10-13T07:01:36Z · created · njachowski@gmail.com
- 2026-10-13T07:22:36Z · status inbox→ready
- 2026-10-13T07:22:37Z · cli_override, model_override
