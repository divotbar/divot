---
id: "0010"
title: Align product docs and public guides with the agreed stories
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: [docs, web]
story: Make either side of the bar my own
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/align-product-docs-and-public-guides-wit
created_at: "2026-10-09T16:41:12Z"
updated_at: "2026-10-09T17:04:17Z"
review_rounds: 2
review_passes: 3
---
## Problem

The starter contains stale first-release defaults, front-app placement, fullscreen hiding and deferred themes.

## Desired UX

Engineering docs, public guides, roadmap and schema proposal all tell the same user-approved product story.

## Acceptance criteria

Update product-requirements, architecture, performance default workload, configuration proposal, roadmap and directly affected guides. Left default workspaces + active app; right battery %, clock + weekday/date, network, volume. Both sides configurable, optional workspace app icons. Four theme families/variants first-class. AeroSpace then yabai; native Spaces remains researched. Persistent top/below behavior replaces hide defaults. Keep implemented vs proposed clear; schema/examples/checker migrate together if changed. Run repoos check.

## Notes for AI

This is planning/docs alignment, not a native implementation claim or landing redesign. Use the six registered stories as authoritative user scope. Stage only this task diff; keep examples and validator consistent.

## Integration follow-up
Close-out after approved task 0009 landed failed with conflicts in docs/product-requirements.md and site/guide/workspaces.md. In this task existing worktree, merge current main into the branch and resolve the two overlapping product-doc edits semantically. Preserve both the approved story alignment and task 0009 honest feasibility limits: notched-display actual menu-bar visibility remains unresolved without validated Accessibility observation; no claim of proven always-visible behavior. Run repoos check --changed main and request a fresh independent review through the normal handoff. Do not hand-land or edit main. The human has revoked the USD 2/hour cap provided configured roles/agents/models remain unchanged; preserve that configuration. Their Mac runs AeroSpace and a-bar; the local preview comparison must temporarily stop only a-bar and preserve a restore path.

## Activity

- 2026-10-09T16:41:12Z · created · njachowski@gmail.com
- 2026-10-09T16:41:16Z · status inbox→ready
- 2026-10-09T16:41:16Z · note: Align stale bootstrap docs with the approved product stories before implementation.
- 2026-10-09T16:43:24Z · status ready→active, branch
- 2026-10-09T16:50:13Z · status active→review
- 2026-10-09T16:50:13Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T16:51:17Z · note: review pass 1: needs some work
- 2026-10-09T16:51:17Z · status review→active
- 2026-10-09T16:52:02Z · status active→review
- 2026-10-09T16:52:02Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T16:52:50Z · note: review pass 2: good to go
- 2026-10-09T16:54:55Z · body: section Integration follow-up
- 2026-10-09T16:54:58Z · status review→active
- 2026-10-09T16:58:24Z · status active→review
- 2026-10-09T16:58:24Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T16:59:48Z · note: review pass 3: needs some work
- 2026-10-09T16:59:49Z · status review→active
- 2026-10-09T17:02:12Z · status active→review
- 2026-10-09T17:02:12Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T17:04:16Z · note: review pass 4: needs some work
- 2026-10-09T17:04:17Z · needs_input
