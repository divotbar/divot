---
updated_at: "2026-10-10T10:45:33Z"
review_passes: 3
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
created_at: "2026-10-10T08:46:31Z"
review_rounds: 2
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
Automated (task branch, this run):

- `swift test --package-path macos`: **417 tests pass**, including the cursor enter → dwell → leave transition on a masked display, the notch-free `visibleFrame` cross-check disagreement case, per-display cursor attribution, the toggle-off and Reduced Motion behaviour, the config parse/round-trip, the settings-model persistence, and two `TopStripCursorMonitor` integration tests that drive the tracking loop through a stub geometry provider and an injected pointer location.
- `bun run check`: config schema, examples, and the website build pass.
- `REPOOS_CHECK_CHANGED=main repoos check`: all steps pass (native-core, native-app, native-app-bundle, justfile). The bundled step runs `scripts/package-app.sh` and the packaged app's headless smoke checks (`--help`, `--report`, `--widgets`).
- `divot --report` now prints the cursor settings, the engaged displays, and `cursorGlobalMonitor=installed|unavailable`, so a "setting broken" report is diagnosable without moving anything.

Implementation notes:

- `TopStripCursorMonitor` (DivotAppKit) is the only new input type: an event-driven global + local mouse-moved monitor that reports the engaged display IDs only when the pointer crosses a top-strip boundary. No polling; it holds no window or view.
- `CursorMenuBarReveal` (DivotCore) is the pure geometry; `NativeMenuBarDetector` only consults the cursor reading for a masked (notched) display, and a notch-free display's own `visibleFrame` overrides it.
- Settings carries "Move below the menu bar when it appears" (default on) and the "Always below the menu bar" fallback (default off), persisted through the store with `menuBar.moveBelowOnCursorReveal` / `menuBar.alwaysBelow`.
- On a detection-policy change the coordinator resets its retained core state so an indeterminate state cannot leave the bar stuck below after the toggle is turned off.

Review rounds 2–3:

- Global monitor availability is surfaced three ways: a stderr warning at launch, `TopStripCursorMonitor.globalMonitorInstalled`, and a `divot --report` line. On this machine the probe reports `cursorGlobalMonitor=installed` even with Accessibility not granted, so the mouse monitor does not depend on the Accessibility grant. The local monitor still runs regardless.
- Notch-free + auto-hide relies on `visibleFrame` by design (the required cross-check); the flat-display case is in the `docs/local-preview.md` hardware checklist and covered by the detector disagreement tests, with `menuBar.alwaysBelow` as the fallback where that frame lies.
- Default on is kept per spec; the Settings caption states it targets an auto-hidden menu bar, and on a notch-free display the cursor reading is ignored in favour of `visibleFrame`, so an always-visible setup is unaffected there.
- Multiple masked displays stay per-display; the settle-delay feel is a hardware item below.

Human-only (NOT supplied here; do not treat as verified):

- Visual confirmation that the bar slides below the native menu bar when the pointer reaches the top edge and returns when it leaves, on the maintainer's display (notched built-in and a flat external display). The screen capture the acceptance asks for was not produced from this agent process; a `ui-verification/0023.json`/shot attachment must be added and the maintainer must confirm the feel before close-out. No run here claims it works visually.


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

