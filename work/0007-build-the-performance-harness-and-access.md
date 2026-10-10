---
id: "0007"
title: Build the performance harness and accessibility regression checks
type: feature
status: review
priority: p1
area: [macos, docs]
story: A native companion that stays out of my way
depends_on: ["0006", "0011"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/build-the-performance-harness-and-access
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-10T02:29:28Z"
---
## Problem

Continuous visibility, extra default widgets and themes need real performance/accessibility coverage.

## Desired UX

Repeatable measurement and accessible interactions throughout all default widgets, themes and panel movements.

## Acceptance criteria

Optimized-build protocol includes helper/compositor costs, both appearance modes, all four theme families, workspace bursts, native-menu-bar reveal/hide, provider cancellation and keyboard actions. Native default workload includes network/volume/current app/time+weekday/date. Publish only measured evidence. Document physical VoiceOver/display/fullscreen checks separately.

## Notes for AI

Performance targets remain provisional. Review current product stories and theme semantic tokens.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:14Z · story, depends_on, body
- 2026-10-09T17:20:40Z · status inbox→ready
- 2026-10-10T02:18:10Z · status ready→active, branch
- 2026-10-10T02:28:32Z · status active→review
- 2026-10-10T02:28:33Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T02:29:28Z · note: review pass 1: good to go
