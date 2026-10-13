---
id: "0075"
title: "Investigate: macOS notification banners sit under the Divot bar"
type: bug
status: review
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/investigate-macos-notification-banners-s
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T05:46:47Z"
updated_at: "2026-10-13T07:49:51Z"
close_out_repair_count: 1
review_passes: 8
review_rounds: 2
---
## Problem
Maintainer screenshot 2026-10-13: a Chrome/Google Calendar notification banner appears at the top right with its top edge tucked under the Divot bar (its title row is partly covered). The native menu bar is hidden, and macOS places banners just below the menu bar area, which Divot now occupies.

## Goal
Find out why, and whether Divot can avoid hiding banner content. This is an investigation first: report findings, then implement a fix only if a public, reliable one exists.

## Questions to answer (record answers in the task)
- What window level, collection behaviour and ignoresMouseEvents does the Divot panel use today (BarPanels.swift), and what are the levels of the notification banner window (check with CGWindowListCopyWindowInfo for the Notification Center process while a banner shows)?
- Is the banner positioned using the menu bar height macOS believes is present (hidden native bar means it starts at the very top), so Divot necessarily overlaps it? Does the overlap also occur when the native menu bar is revealed?
- Can the panel be ordered below banners (a lower window level) without losing its place above normal app windows and fullscreen behaviour decided in #0009/#0023?
- Is there any public API to offset or reserve space for notification banners (expected: no)? Say what you tried.

## Acceptance criteria
- A short written finding with evidence added to docs/evidence/ and linked from the task. ✓ DONE: [evidence/0075-notification-banner-overlap.md](../evidence/0075-notification-banner-overlap.md)
- Documentation of the limitation in docs/troubleshooting and site troubleshooting page. ✓ DONE
- No private APIs, no event taps beyond what Divot already uses, no polling loop. ✓ DONE
- **Pending:** Notification banner window-level measurement. The investigation identified what would need measuring (kCGWindowLevel and kCGWindowBounds from a live banner), but the sandboxed environment where the investigation ran does not support GUI notifications. A maintainer must trigger a real notification (e.g., from Calendar) with auto-hide ON, run `divot-notification-banner-probe`, and provide the window-level data. Until then, feasibility of a safe public fix cannot be assessed.
- The maintainer verifies overlap visually on the packaged app with a real notification and provides window-level measurements.

## Notes for AI
Related decisions: bar placement is the top edge when the native menu bar is hidden (#0021/#0023); Divot hugs the notch (#0028). Do not break those.

## Findings
See [evidence/0075-notification-banner-overlap.md](../evidence/0075-notification-banner-overlap.md) for the detailed investigation.

## What was found

Divot's configuration is confirmed:
- Window level: 23 (mainMenu - 1)
- Collection behavior: [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
- ignoresMouseEvents: defaults to false

Menu bar height: 33 points on this notched display.

## What was NOT found (measurement required)

**Notification banner window levels** — no banners were visible during the investigation. Attempted to trigger notifications locally but notifications are blocked in this environment.

**Overlap mechanism** — reported visually by the maintainer (banner title partly covered) but not confirmed with window-level measurements or bounds data.

**Z-order (which draws on top)** — unknown without measured window levels.

**Whether overlap resolves when menu bar is revealed** — not tested with a live banner.

**Divot bar actual footprint** — includes optional shadow extension not measured in running app.

## Measurement required for feasibility assessment

A human on macOS must:
1. Trigger a real notification (e.g., from Calendar) with auto-hide ON.
2. Run `divot-notification-banner-probe` and capture the banner's `kCGWindowLevel` and `kCGWindowBounds`.
3. Record those values in the evidence document.
4. Test overlap behavior when menu bar is revealed.
5. Test on multi-display, notch-free, fullscreen, and Spaces scenarios.

Until these measurements are provided, no safe public fix can be assessed.

## What was found

Divot's configuration is confirmed: window level 23 (mainMenu - 1), collection behavior [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle], ignoresMouseEvents defaults to false.

Menu bar height is confirmed: 33 points on this notched display.

## What was NOT found

**Notification banner window levels were not measured** — no banners were visible during the probe. Actual levels, bounds, and z-order (whether banners draw above or below Divot) remain unknown.

**Overlap mechanism unverified** — reported visually by the maintainer but not confirmed with measurements. Spatial overlap (y-coordinate collision) is likely but z-order is unknown.

**Workaround untested** — disabling auto-hide is expected to resolve overlap, but this was not validated with a live notification.

## Next steps for a fix

Maintainer must:
1. Trigger a real notification with auto-hide ON.
2. Run `divot-notification-banner-probe` and share the banner's `kCGWindowLevel` and bounds.
3. Verify whether overlap is resolved when the menu bar is revealed.
4. Test on multi-display, notch-free, fullscreen, and Spaces scenarios.

Until these measurements are provided, feasibility of a safe public fix cannot be assessed.

## Summary
**Measured facts:**
- Divot panel: level 23 (mainMenu - 1), collection behavior [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
- Menu bar height: 33 points on notched display

**Reported issue (not measured):**
- Notification banners overlap Divot bar when auto-hide is ON
- Overlap appears to be spatial (banner positioned in same y region as Divot), but z-order unknown

**Unmeasured, required for feasibility:**
- Notification banner window levels and bounds (kCGWindowLevel, kCGWindowBounds)
- Whether overlap is resolved when native menu bar is revealed
- Multi-display, notch-free, fullscreen, and Spaces behavior

**Next step:** Maintainer triggers a real notification with auto-hide ON and runs `divot-notification-banner-probe` to capture the banner's window-level data. See Findings section for details.

## Options

1. Accept as a limitation (documented in troubleshooting)
2. Disable auto-hide on the native menu bar (banners reposition below it)
3. Use cursor-reveal to slide Divot below the menu bar (banners do not follow)
4. Future task: inset Divot when the menu bar is hidden (not implemented)

## Activity

- 2026-10-13T05:46:47Z · created · njachowski@gmail.com
- 2026-10-13T05:46:53Z · status inbox→ready
- 2026-10-13T05:46:54Z · cli_override, model_override
- 2026-10-13T05:46:55Z · status ready→active, branch
- 2026-10-13T05:50:52Z · body: section Findings
- 2026-10-13T05:54:52Z · status active→review
- 2026-10-13T05:54:52Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T05:55:46Z · note: review pass 1: needs some work
- 2026-10-13T05:55:46Z · status review→active
- 2026-10-13T05:58:22Z · status active→review
- 2026-10-13T05:58:22Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T05:59:17Z · note: review pass 2: needs some work
- 2026-10-13T05:59:17Z · status review→active
- 2026-10-13T05:59:54Z · body: section Findings
- 2026-10-13T06:00:38Z · status active→review
- 2026-10-13T06:00:38Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:01:40Z · note: review pass 3: needs some work
- 2026-10-13T06:01:40Z · needs_input
- 2026-10-13T06:11:10Z · needs_input
- 2026-10-13T06:11:11Z · status review→active
- 2026-10-13T06:11:11Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:12:20Z · body: section Findings
- 2026-10-13T06:12:54Z · status active→review
- 2026-10-13T06:12:54Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:13:47Z · note: review pass 4: needs some work
- 2026-10-13T06:13:47Z · needs_input
- 2026-10-13T06:19:28Z · needs_input
- 2026-10-13T06:19:28Z · status review→active
- 2026-10-13T06:19:28Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:21:29Z · status active→review
- 2026-10-13T06:21:29Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:22:20Z · note: review pass 5: needs some work
- 2026-10-13T06:22:20Z · needs_input
- 2026-10-13T06:25:31Z · needs_input
- 2026-10-13T06:25:31Z · status review→active
- 2026-10-13T06:25:31Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:25:52Z · body: section Acceptance criteria
- 2026-10-13T06:25:58Z · body: section Summary
- 2026-10-13T06:27:00Z · status active→review
- 2026-10-13T06:27:01Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:28:00Z · note: review pass 6: needs some work
- 2026-10-13T06:28:00Z · needs_input
- 2026-10-13T06:31:32Z · needs_input
- 2026-10-13T06:31:32Z · status review→active
- 2026-10-13T06:31:32Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:34:51Z · status active→review
- 2026-10-13T06:34:52Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:35:57Z · note: review pass 7: needs some work
- 2026-10-13T06:35:57Z · needs_input
- 2026-10-13T06:37:34Z · needs_input
- 2026-10-13T06:37:34Z · status review→active
- 2026-10-13T06:37:34Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:40:40Z · status active→review
- 2026-10-13T06:40:40Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:41:46Z · note: review pass 8: needs some work
- 2026-10-13T06:41:46Z · needs_input
- 2026-10-13T07:47:13Z · status review→active, needs_input
- 2026-10-13T07:47:13Z · note: close-out repair: merge-conflict
- 2026-10-13T07:47:26Z · message_queued at 2026-10-13T07:47:26.382Z
- 2026-10-13T07:47:29Z · message_queued at 2026-10-13T07:47:29.904Z
- 2026-10-13T07:48:48Z · status active→review
- 2026-10-13T07:48:49Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T07:49:51Z · note: review pass 9: needs some work
