# Evidence · 0003 native AppKit shell and display coordinator

Status: **implemented shell, not physically validated** · task 0003 · 2026-10-10.
This records what the app shell actually does, what is covered by tests, and
what still needs a person on real hardware. It is not a claim that always-visible
menu-bar behavior works.

Story: [Divot stays visible when the native menu bar appears](../../stories/divot-stays-visible-when-the-native-menu-bar-appears.md).
Feasibility gate: [0009 evidence](0009-native-menu-bar-coexistence.md).

## What was built

| Piece | Path | Role |
| --- | --- | --- |
| Pure placement math | `macos/Sources/DivotCore/BarGeometry.swift` | Top/below segment frames; `edgeMargin` is the explicit below-bar gap policy. |
| Pure detection + controller | `macos/Sources/DivotCore/NativeMenuBar.swift` | Geometry signals, coalescing settle, reduced-motion immediacy, no hide action. |
| Pure multi-display machine | `macos/Sources/DivotCore/DisplayLayout.swift` | Per-display state, batch display add/remove, `BarContentPolicy`. |
| Reusable observation adapter | `macos/Sources/DivotAppKit/*` | `NSScreen` → readings, Accessibility probe, event set, shared by app and probe. |
| AppKit panel coordinator | `macos/Sources/DivotAppKit/DisplayCoordinator.swift`, `BarPanels.swift` | Owns two nonactivating panels per display, applies placements. |
| Executable shell | `macos/Sources/DivotApp/*` | Accessory app; `divot --report` prints one observation pass and exits. |

Run it (read-only report; does not move panels or change settings):

```sh
swift build --package-path macos --product divot
macos/.build/debug/divot --report
```

## App build gate

`repoos check` declares a required `native-app` step that runs
`swift build --package-path macos --product divot`, and the config guard is
itself tested (`bun test scripts/native-app-gate.test.ts`). The guard's negative
test is not just a config-string check: it copies the real package to a temp
directory (excluding `.build`), proves that copy builds with the exact gate
command, injects a deliberate type error into its `Sources/DivotApp/main.swift`,
and asserts the same command exits non-zero and reports a `DivotApp` compile
error. It then re-reads the working `macos/Sources/DivotApp/main.swift` to prove
the project was not corrupted. The temp copy is removed in a `finally`.

Observed locally: `bun test scripts/native-app-gate.test.ts` → 4 pass, 0 fail
(~7s, including the two SwiftPM builds). The negative test requires the Swift
toolchain, which every declared check step already requires; it does not need
network access or any physical hardware.

## Honest status by claim

**Implemented and covered by tests (`swift test --package-path macos`, 196 tests):**

- Top-edge vs below-bar geometry, notched split around the housing, notch gap
  dropped below the bar, screen clamping, and segment non-overlap.
- Per-display placement state: rapid toggles converge on the last observation,
  superseded transitions cancel, Reduced Motion repositions immediately, a
  hidden bar returns to the top edge, and no code path emits a hide.
- A visibility change that arrives together with a geometry change (a notch-free
  display's `visibleFrame` shrinks on reveal) applies the *new* placement at once
  rather than re-applying the committed state, so a reveal never leaves the
  panels overlapping the bar while the settle timer runs.
- Reduced Motion changed while running is propagated to every existing
  per-display controller, so the next change repositions without the settle delay.
- Multi-display coordination: displays resolve independently, a display add/remove
  or geometry change is applied immediately (never animated through an
  intermediate position), and hot-unplug drops the display cleanly.
- A reset/restart re-emits a placement for every display, so panels rebuilt after
  a stop do not stay at their initial size.
- A reveal that arrived with a geometry change keeps its immediate below-bar
  placement through the follow-up settled `advance()`: the queued settle may
  reposition, but it never falls back to the stale top edge.
- Undecidable input returns `.indeterminate` and holds position.
- A camera housing is detected from either public signal (`safeAreaInsets.top` or
  the auxiliary top areas beside the notch). A notched display whose inset reads
  zero — for example with a third-party bar (a-bar/AeroSpace) occupying the band
  — is therefore never misread from *geometry* as a revealed native menu bar: its
  pure-geometry result stays `.indeterminate(notchedHousingMasksMenuBar)` and
  holds the top edge instead of stacking below the bar (task 0015). The default
  pointer-reveal path (task 0023) is a separate, deliberate input: when the
  pointer is in the top strip the bars simply move below the revealed native bar.
- The observation adapter never turns an untrusted probe into a visibility
  claim, never hands the single system-wide sample to more than one display, and
  never lets it override a display whose own `visibleFrame` decides.
- The AX menu-bar visibility is derived from the bar's own frame, not
  `kAXHiddenAttribute`: an auto-hidden bar still reports `hidden == false`
  because it is slid above the screen, so the on-screen position test
  (`position.y >= 0`) is the signal that distinguishes revealed from hidden
  (#0021). A complete sample stays `.provisional` unless explicitly marked
  `validated`; the app withholds the derived visibility unless the configuration
  opts in (`menuBar.trustAccessibilityProbe`, default off), so a shipping build
  never asserts the hardware-specific heuristic globally.
- Missing or zero-area AX attributes stay `.unavailable` instead of being coerced
  into a visible/hidden claim.

**Implemented but only asserted by construction, not observed:**

- The AppKit panel flags that avoid focus theft (`NSApplication` is an accessory
  app; panels are borderless/nonactivating and refuse `canBecomeKey`/`canBecomeMain`).
- Window level just below the system menu bar (`mainMenu - 1`, so native menus
  stay above Divot) and collection behavior
  `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
- The nonactivating panels override `constrainFrameRect(_:to:)` so a top-edge
  placement may occupy the camera-housing band. AppKit's default clamp parks the
  panel at the bottom of that band (`visibleFrame.maxY`, observed as y=33 from
  the top on the built-in display) even while the native bar is hidden; the
  override keeps the requested frame with the level unchanged. Verified locally
  with a window-list read (not a screenshot).
- Animated reposition and the cancel path between transitions.

**Not verified at all — a human must supply (do not treat as working):**

- Whether the bar actually appears/is ordered correctly on-screen on a real
  display, and the fullscreen/Spaces/multi-display behaviors above.
- Whether native-bar reveal/hide is observable on notched hardware. The default
  path is the pointer reaching a display's top strip
  (`menuBar.moveBelowOnCursorReveal`, on by default), observed by an
  event-driven mouse-moved monitor (`DivotAppKit.TopStripCursorMonitor`) with no
  polling; the permission-gated Accessibility probe is a further opt-in
  (`menuBar.trustAccessibilityProbe`, default off) that takes precedence when
  enabled. Whether the bar visually lands correctly on reveal is still a human
  check.
- Whether the macOS always-visible menu-bar setting is readable from public
  APIs. The detector accepts a `configuredAlwaysVisible` signal and treats it as
  authoritative (covered by pure tests), but the observation adapter does not
  populate it yet, so an always-visible native bar on notched hardware still
  resolves to indeterminate rather than below-bar on this build.
- Whether a single system-wide AX sample can be attributed to the right display
  in a multi-display setup. Until then it is only used for a single masked
  display.
- Animation smoothness, no flashing/overlap, and no focus theft under rapid
  toggles; sleep/wake and hot-plug with real displays.
- Whether the pointer reveal lands the bar correctly and returns it. A
  mouse-moved monitor now supplies the event trigger the earlier run lacked
  (instead of relying on whatever refresh happened to fire), the visibility
  cross-check and the enter/dwell/leave transition are covered by pure and
  AppKit tests, but the on-screen feel is still a human check.

## Permissions

Accessibility permission is required for the notched-display Accessibility
detector (product decision (a) in the 0009 report). Without it the shell logs the
missing permission at launch, and the notched-display detector still has the
default pointer-reveal path (`menuBar.moveBelowOnCursorReveal`) to fall back on;
the Accessibility probe only adds a decisive signal after a person opts in. On
notch-free displays `visibleFrame` remains the signal and no permission is
needed.

Permission alone is not enough by itself: a complete sample stays
`.provisional` unless explicitly marked `validated`, and the adapter withholds
the derived visibility unless the configuration opts in
(`menuBar.trustAccessibilityProbe`, default off). With that opt-in enabled, the
on-screen position test is the trusted signal for this build and a masked
notched display follows reveal/hide. Whether the bar visually lands right is
still a human check (see the "not verified" list above).

When a validated sample is used, it is applied conservatively: it is only used
for a display whose own geometry is masked by the camera housing, and only when
there is a single display, because the AX menu bar is one system-wide object that
public APIs do
not attribute to a screen. A system-wide sample therefore never overrides a
notch-free display's `visibleFrame`, and multiple masked displays stay
indeterminate rather than sharing one guess. Missing or zero-area AX attributes
stay `.unavailable`; they are never read as a zero-sized or `hidden == false`
menu bar. Attributing the sample correctly across multiple displays is an open
physical-validation item.

## Gap and layout policy

- **Below-bar row is edge-to-edge by default** (`BarContentPolicy.edgeMargin == 0`).
  It overlays app content. Reserving tiling space is a window-manager adapter
  decision, not an AppKit effect; that policy is still open (see below).
- **No notch hole below the bar**: the center seam is `2 × clearance`, never the
  housing gap.

## Open product decisions (unchanged by this task)

1. **Notched-display visibility** — ship the permission-gated AX probe, require
   an always-visible bar on notched displays, or accept an explicit proximity
   heuristic. Only the AX probe claims true detection, and it needs hardware proof.
2. **Fullscreen/Spaces** — the story supersedes the starter's fullscreen-hide
   default; behavior is unresolved and needs an explicit decision. The shell does
   not hide in fullscreen, but it is not verified visible there either.
3. **Window-manager gap policy** — whether Divot reserves space (and how) is an
   adapter concern. `BarContentPolicy.edgeMargin` is the knob; the value is TBD.
