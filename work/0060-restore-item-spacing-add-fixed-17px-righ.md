---
id: "0060"
title: Restore item spacing; add fixed 17px right inset at screen edge
type: bug
status: done
priority: p1
area: macos
merged_commit: 41929ef73d6c2651d89c9d6610662d3e38fb4c07
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/restore-item-spacing-add-fixed-17px-righ
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-12T09:37:42Z"
updated_at: "2026-10-12T11:02:10Z"
last_close_out_gate_ms: 48807
last_close_out_gate_at: "2026-10-12T11:02:08.663Z"
review_passes: 1
handoff_signal_retry_count: 2
---
## Problem
#0054 misread the spacing request. It set a large gap (17px) between the right-side items. Maintainer screenshot 2026-10-12 shows the items spread far apart.

## Desired UX
- Gap between items returns to what it was before #0054 (8pt between items per docs/configuration.md; check git history of BarMetrics before #0054 to confirm).
- Fixed 17px inset between the rightmost item and the right edge of the screen so the macOS green camera dot never overlaps content.
- The Divot-icon-to-workspaces gap and the front-app gap: restore to their pre-#0054 values too unless #0054 only changed the right side.

## Acceptance criteria
- Item gaps equal the pre-#0054 values; unit test on BarMetrics.
- Right inset is exactly 17px, tested.
- docs/configuration.md and site/reference/configuration.md updated.
- Maintainer confirms by eye on the packaged app.

## Notes for AI
See #0054 diff (git log --grep 0054) and revert only the between-item spacing; keep or add the 17px right-edge inset. Touches BarMetrics.swift and the bar layout code.

## Activity

- 2026-10-12T09:37:42Z · created · njachowski@gmail.com
- 2026-10-12T09:37:44Z · status inbox→ready
- 2026-10-12T09:37:45Z · status ready→active, branch
- 2026-10-12T10:52:54Z · cli_override, model_override
- 2026-10-12T10:56:10Z · status active→review
- 2026-10-12T10:56:10Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T10:57:12Z · note: review pass 1: good to go
- 2026-10-12T11:02:08Z · close-out gate completed in 49s
- 2026-10-12T11:02:10Z · status review→done, release:success
