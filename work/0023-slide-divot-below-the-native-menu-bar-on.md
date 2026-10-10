---
id: "0023"
title: "Slide Divot below the native menu bar on cursor reveal, with a Settings toggle"
type: feature
status: active
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
updated_at: "2026-10-10T11:03:09Z"
review_passes: 3
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

- `swift test --package-path macos`: **419 tests pass** (417 before this review; +2 new), including the cursor enter → dwell → leave transition on a masked display, the notch-free `visibleFrame` cross-check disagreement case, per-display cursor attribution, the toggle-off and Reduced Motion behaviour, the config parse/round-trip, the settings-model persistence, and two `TopStripCursorMonitor` integration tests that drive the tracking loop through a stub geometry provider and an injected pointer location.
- New for the review's optional monitor no-op: `MenuBarConfiguration.usesCursorRevealMonitoring` is tested for all four on/off combinations, and `TopStripCursorMonitor.setEnabled` is tested to stop the loop and re-report the current engagement. `DivotAppDelegate` now starts/stops the monitor from that derived setting, so an install with the cursor reveal and the always-below fallback both inactive keeps no global mouse tap installed.
- `bun run check`: config schema, examples, and the website build pass.
- `REPOOS_CHECK_CHANGED=main repoos check`: all steps pass (native-core, native-app, native-app-bundle, justfile). The bundled step runs `scripts/package-app.sh` and the packaged app's headless smoke checks (`--help`, `--report`, `--widgets`).
- Packaged `dist/Divot.app/Contents/MacOS/divot --report` (this run, maintainer's notched display, `_HIHideMenuBar=1`): `moveBelowOnCursorReveal=true`, `alwaysBelow=false`, `cursorEngaged=` (pointer away from the strip), `cursorGlobalMonitor=installed`, `reduceMotion=false`, `display-1 notched=true visibility=hidden`, `mode=topEdge left=(0.0, 1075.0, 753.0, 32.0) right=(958.0, 1075.0, 752.0, 32.0)`. `divot --report` also prints the cursor settings and `cursorGlobalMonitor=installed|unavailable`, so a "setting broken" report is diagnosable without moving anything.

Implementation notes:

- `TopStripCursorMonitor` (DivotAppKit) is the only new input type: an event-driven global + local mouse-moved monitor that reports the engaged display IDs only when the pointer crosses a top-strip boundary. No polling; it holds no window or view.
- `CursorMenuBarReveal` (DivotCore) is the pure geometry; `NativeMenuBarDetector` only consults the cursor reading for a masked (notched) display, and a notch-free display's own `visibleFrame` overrides it.
- Settings carries "Move below the menu bar when it appears" (default on) and the "Always below the menu bar" fallback (default off), persisted through the store with `menuBar.moveBelowOnCursorReveal` / `menuBar.alwaysBelow`.
- On a detection-policy change the coordinator resets its retained core state so an indeterminate state cannot leave the bar stuck below after the toggle is turned off.

Review rounds 2–4:

- Global monitor availability is surfaced three ways: a stderr warning at launch, `TopStripCursorMonitor.globalMonitorInstalled`, and a `divot --report` line. On this machine the probe reports `cursorGlobalMonitor=installed` even with Accessibility not granted, so the mouse monitor does not depend on the Accessibility grant. The local monitor still runs regardless.
- The monitor is now started/stopped from `menuBar.usesCursorRevealMonitoring` (`moveBelowOnCursorReveal && !alwaysBelow`), so it does not hold a global mouse tap while its reading cannot affect placement; a re-enable re-reads and reports the current engagement at once.
- Notch-free + auto-hide relies on `visibleFrame` by design (the required cross-check); the flat-display case is in the `docs/local-preview.md` hardware checklist and covered by the detector disagreement tests, with `menuBar.alwaysBelow` as the fallback where that frame lies.
- Multiple masked displays stay per-display; the settle-delay feel is a hardware item below.

Human-only (NOT supplied here; do not treat as verified):

- The acceptance screen capture of the slide (and the flat-external case) and the maintainer's confirmation of the feel were not produced from this agent process. `screencapture` is reachable here, but driving the reveal needs the pointer at the top edge and `CGWarpMouseCursorPosition` is a no-op for this process (verified this run: warping to a location leaves `CGEvent(source: nil)?.location` unchanged), so an agent cannot move the pointer to trigger the native reveal. A person must run `just app-run` (or `open dist/Divot.app`), move the pointer to the top edge, confirm Divot slides below the revealed native menu bar and returns to the top edge when the pointer leaves, and record a screen capture. On the notched built-in this is the default path; on a flat external the `visibleFrame` cross-check applies. No run here claims it works visually or that the feel is right.
- The browser UI handoff gate does not apply: the diff touches the native app and docs, not a `[[preview.paths]]` web route, so there is no shot to capture and no `ui-verification/0023.json` is produced by design.
- The Reduce Motion slide was exercised by unit tests only, not on glass.

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
