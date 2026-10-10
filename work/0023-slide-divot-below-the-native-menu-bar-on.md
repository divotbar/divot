---
id: "0023"
title: "Slide Divot below the native menu bar on cursor reveal, with a Settings toggle"
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
depends_on: ["0021", "0022"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/slide-divot-below-the-native-menu-bar-on
cli_override: claude code
model_override: haiku
review_cli_override: claude code
review_model_override: haiku
created_at: "2026-10-10T08:46:31Z"
updated_at: "2026-10-10T12:17:26Z"
review_passes: 5
review_rounds: 2
incomplete_review_retries: 1
---
## Problem

Divot sits at the top edge while the native macOS menu bar is auto-hidden. When the maintainer moves the cursor to the top edge, macOS reveals the native bar, but Divot doesn't move down, so the two overlap. Public APIs don't reliably report whether the native bar is currently showing, so Divot can't react to the reveal from the system signal alone.

## Desired UX

- When the cursor enters the top strip of the display, Divot slides down to sit below where the native bar will appear. When the cursor leaves that strip, Divot slides back up to the top edge.
- Settings has a toggle, "Move below the menu bar when it appears", on by default for auto-hide users, with the cursor behaviour as its only mode. When it is off, Divot keeps its current placement.
- A small fallback setting, "Always below the menu bar", is available for Macs where the cursor reveal does not line up.

## Acceptance criteria

- Cursor movement into the top strip and out of it drives the slide, using event-driven monitoring (no unbounded polling). Add a test for the state transition: enter, dwell, leave.
- Use the screen's visible frame as a cross-check when it is available, so Divot corrects itself if the two disagree. Add a test for the disagreement case.
- The toggle and fallback option live in Settings, persisted through the configuration store (0006), with a clear label and default. Route them through the existing settings window pattern from 0017.
- Behaviour is off when the toggle is off, and the slide respects the reduce-motion setting.
- Verify on the packaged app with `scripts/package-app.sh` and record a screen capture as evidence. The maintainer confirms the feel; do not claim it works without that.
- `repoos check` passes.

## Notes for AI

Depends on #0021 (top-edge placement) and #0022 (settings additions) so the new setting lands in the same settings window and metrics code. Do not start until both are done. Keep the cursor monitoring in its own type in `DivotAppKit`, not in the widget views.

## Verification
test

## Activity

- 2026-10-10T08:46:31Z · created · njachowski@gmail.com
- 2026-10-10T10:26:10Z · status inbox→ready
- 2026-10-10T10:26:12Z · status ready→active, branch
- 2026-10-10T10:37:44Z · body: section Verification
- 2026-10-10T10:39:43Z · status active→review
- 2026-10-10T10:39:43Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T10:40:20Z · note: review pass 1: needs some work
- 2026-10-10T10:40:20Z · status review→active
- 2026-10-10T10:42:06Z · body: section Verification
- 2026-10-10T10:42:31Z · status active→review
- 2026-10-10T10:42:31Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T10:43:05Z · note: review pass 2: needs some work
- 2026-10-10T10:43:05Z · status review→active
- 2026-10-10T10:44:40Z · body: section Verification
- 2026-10-10T10:45:03Z · status active→review
- 2026-10-10T10:45:03Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T10:45:32Z · note: review pass 3: needs some work
- 2026-10-10T10:45:33Z · needs_input
- 2026-10-10T10:52:55Z · status review→active
- 2026-10-10T11:03:09Z · body: section Verification
- 2026-10-10T11:04:18Z · status active→review
- 2026-10-10T11:04:18Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:04:54Z · note: review pass 4: needs some work
- 2026-10-10T11:04:54Z · needs_input
- 2026-10-10T11:04:54Z · needs_input
- 2026-10-10T11:30:17Z · review_cli_override, review_model_override
- 2026-10-10T11:30:19Z · review_model_override
- 2026-10-10T11:30:25Z · cli_override, model_override
- 2026-10-10T11:30:27Z · model_override
- 2026-10-10T11:30:40Z · status review→active
- 2026-10-10T11:32:19Z · body: section Verification
- 2026-10-10T11:32:42Z · body: section Verification
- 2026-10-10T11:33:08Z · status active→review
- 2026-10-10T11:33:08Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-10T11:33:09Z · note: review pass 5: incomplete — no verdict in report
- 2026-10-10T11:33:14Z · note: review pass 6: incomplete — no verdict in report
- 2026-10-10T11:36:31Z · needs_input (review-rounds-exhausted) cleared for review again by human
- 2026-10-10T11:39:14Z · note: review pass 7: needs some work
- 2026-10-10T11:39:14Z · needs_input
- 2026-10-10T12:17:24Z · cli_override, model_override
- 2026-10-10T12:17:25Z · cli_override, model_override
- 2026-10-10T12:17:26Z · model_override
