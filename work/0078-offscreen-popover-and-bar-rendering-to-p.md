---
updated_at: "2026-10-13T06:43:44Z"
review_passes: 3
id: "0078"
title: Offscreen popover and bar rendering to PNG with pixel assertions (gitignored output)
type: chore
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p2
area: macos
depends_on: ["0076"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/offscreen-popover-and-bar-rendering-to-p
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T06:23:20Z"
review_rounds: 2
---
## Problem
Native UI changes here have no visual evidence: RepoOS shots only cover web targets, so every macOS task reports 'shots: skipped'. Look, alignment, translucency and contrast problems were found only by the maintainer's eye (Appearance, Volume and Wi-Fi popovers, #0072-#0076). A RepoOS feature for command-based native shots is filed separately in the RepoOS repo (#0761); this task gives Divot something to feed it.

## Desired UX
- A test helper renders Divot views offscreen to PNG without showing a window and without Screen Recording permission (AppKit bitmapImageRepForCachingDisplay / cacheDisplay or equivalent public API), inside the normal swift test run.
- It renders the bar and each popover (Wi-Fi, Volume, Appearance and, once it lands, Calendar) for every theme family in light and dark, at the default text size and one larger size.
- The images are written to a gitignored directory (for example macos/.build/snapshots/ or a path from an environment variable such as DIVOT_SNAPSHOT_DIR). They are NEVER committed to git: add the ignore rule, and make sure nothing under docs/ or site/ references a tracked PNG from this task.

## Acceptance criteria
- Pixel-level assertions that do not need stored baseline images: the popover background fill is fully opaque (alpha 1) and equals the theme popover palette; sampled text pixels meet the existing contrast threshold against the sampled background; content is left-aligned (first non-background pixel column of header and rows within a small tolerance of the leading inset); nothing is clipped (content bounds within the popover bounds). Do not commit golden images.
- A short script or just recipe (for example scripts/snapshots.sh) that runs the snapshot tests and prints the output directory, so the maintainer and a future RepoOS command target can collect the PNGs.
- If offscreen rendering cannot reproduce the system popover chrome (arrow or window material), say so in docs/ and render the content view only; do not claim the chrome was verified.
- Runs headless in CI-like conditions (no display required) or skips with a clear message when it cannot; swift test --package-path macos still passes.
- docs/ describes the helper and states that rendered images are local evidence only.

## Notes for AI
Look at how the popover views and BarTheme/popoverPalette are built (BarPopover.swift, AppearancePopover.swift, VolumePopover.swift, WifiPopover.swift) and at existing tests with fakes. Start after #0076 lands so the popover layout is stable. Never git add the generated PNGs.

## Activity

- 2026-10-13T06:23:20Z · created · njachowski@gmail.com
- 2026-10-13T06:25:24Z · status inbox→ready
- 2026-10-13T06:25:25Z · cli_override, model_override
- 2026-10-13T06:25:25Z · status ready→active, branch
- 2026-10-13T06:35:26Z · status active→review
- 2026-10-13T06:35:26Z · note: shots: skipped — the diff (4 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T06:36:23Z · note: review pass 1: needs some work
- 2026-10-13T06:36:23Z · status review→active
- 2026-10-13T06:37:35Z · message_queued at 2026-10-13T06:37:35.540Z
- 2026-10-13T06:40:00Z · status active→review
- 2026-10-13T06:40:00Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T06:40:49Z · note: review pass 2: needs some work
- 2026-10-13T06:40:49Z · message_delivered: 1 message(s)
- 2026-10-13T06:40:49Z · status review→active
- 2026-10-13T06:42:41Z · status active→review
- 2026-10-13T06:42:41Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-13T06:43:44Z · note: review pass 3: needs some work
- 2026-10-13T06:43:44Z · needs_input

