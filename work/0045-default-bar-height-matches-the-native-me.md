---
id: "0045"
title: Default bar height matches the native menu bar height on each display
type: bug
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/default-bar-height-matches-the-native-me
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-11T13:13:19Z"
updated_at: "2026-10-11T14:38:53Z"
review_rounds: 2
review_passes: 2
last_check_failure: "repoos check at 2026-10-11T13:37:56.607Z: repoos check failed: native-core — 􀟈 Test workspaceBarViewDrawsEveryDeduplicatedAppIcon() started."
---
## Problem

Divot's default row height is 32pt. On the maintainer's notched MacBook Air the native menu bar is 33pt tall (the screen's top safe-area inset, `safeAreaInsets.top` = 33, with the menu band equal to frame.maxY minus visibleFrame.maxY = 33). The Divot row sits 1pt (2px at 2x) shorter, which the maintainer can see.

## Desired UX

- With no user override, Divot's row height equals the native menu bar height on the display it sits on.
- On notched displays that is the safe-area top (33pt here). On notch-free displays it is the native menu bar height reported by AppKit (24pt).
- A `layout.height` value in configuration still overrides it.

## Acceptance criteria

- Compute the default row height per display from the native menu bar band, not a constant. Keep `BarMetrics.default.height` only as a fallback when the band is unknown.
- A configured `layout.height` still wins when set.
- Tests cover: notched display returns the safe-area top, notch-free display returns the fallback, and an explicit configured height overrides both.
- Verify on the packaged app that the Divot row matches the native bar height on the notched display; record the measured values in the task. The maintainer confirms the look.
- `repoos check` passes.

## Notes for AI

Measured on 2026-10-11: NSScreen.main safeAreaInsets.top = 33, frame.maxY - visibleFrame.maxY = 33, NSStatusBar.system.thickness = 22 (status item height, not the menu bar height; do not use it). Change only the height default and its resolution, not the padding or item layout.

## Activity

- 2026-10-11T13:13:19Z · created · njachowski@gmail.com
- 2026-10-11T13:13:20Z · status inbox→ready
- 2026-10-11T13:13:21Z · status ready→active, branch
- 2026-10-11T13:23:30Z · status active→review
- 2026-10-11T13:23:30Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T13:24:17Z · note: review pass 1: needs some work
- 2026-10-11T13:24:18Z · status review→active
- 2026-10-11T13:39:09Z · handoff failed · check failed after 2 automatic retries · repoos check failed: native-core — 􀟈  Test everyDefaultItemIsLabelledAndRoatedAcrossEveryTheme() started.
- 2026-10-11T13:44:40Z · watchdog: escalated to needs_input · check-failed-after-retries · check failed after 2 automatic retries · repoos check failed: native-core — 􀟈  Test everyDefaultItemIsLabelledAndRoatedAcrossEveryTheme() started. · next step: resume the session manually from the task's worktree and check for uncommitted work
- 2026-10-11T14:17:48Z · needs_input
- 2026-10-11T14:19:52Z · status active→review
- 2026-10-11T14:19:52Z · note: shots: skipped — the diff (7 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T14:20:07Z · handoff failed · check failed after 2 automatic retries · repoos check failed: native-core — 􀟈  Test optionsToggleFiltersEmptyWorkspacesWithoutAReload() started.
- 2026-10-11T14:21:03Z · note: review pass 2: needs some work
- 2026-10-11T14:21:03Z · status review→active
- 2026-10-11T14:26:41Z · watchdog: escalated to needs_input · check-failed-after-retries · check failed after 2 automatic retries · repoos check failed: native-core — 􀟈  Test everyDefaultItemIsLabelledAndRoatedAcrossEveryTheme() started. · next step: resume the session manually from the task's worktree and check for uncommitted work
- 2026-10-11T14:27:17Z · cli_override, model_override
- 2026-10-11T14:27:17Z · needs_input
- 2026-10-11T14:37:17Z · note: Clock/date/time items now always carry a non-empty, role-prefixed accessibility label (e.g. "Date: Sun 11 Oct"), so an all-off format cannot leave a silent item; core tests added. Merged main, which cleared the native-core SIGSEGV in ConfigurationParser.parse; repoos check passes (533 tests).
- 2026-10-11T14:37:52Z · status active→review
- 2026-10-11T14:37:52Z · note: shots: skipped — the diff (7 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T14:38:53Z · note: review pass 3: needs some work
- 2026-10-11T14:38:53Z · needs_input
