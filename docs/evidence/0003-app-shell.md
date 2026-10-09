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

## Honest status by claim

**Implemented and covered by tests (`swift test --package-path macos`, 45 tests):**

- Top-edge vs below-bar geometry, notched split around the housing, notch gap
  dropped below the bar, screen clamping, and segment non-overlap.
- Per-display placement state: rapid toggles converge on the last observation,
  superseded transitions cancel, Reduced Motion repositions immediately, a
  hidden bar returns to the top edge, and no code path emits a hide.
- Multi-display coordination: displays resolve independently, a display add/remove
  or geometry change is applied immediately (never animated through an
  intermediate position), and hot-unplug drops the display cleanly.
- Undecidable input returns `.indeterminate` and holds position.
- The observation adapter never turns an untrusted probe into a visibility
  claim, never hands the single system-wide sample to more than one display, and
  never lets it override a display whose own `visibleFrame` decides.
- Missing or zero-area AX attributes stay `.unavailable` instead of being coerced
  into a visible/hidden claim.

**Implemented but only asserted by construction, not observed:**

- The AppKit panel flags that avoid focus theft (`NSApplication` is an accessory
  app; panels are borderless/nonactivating and refuse `canBecomeKey`/`canBecomeMain`).
- Window level just below the system menu bar (`mainMenu - 1`, so native menus
  stay above Divot) and collection behavior
  `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
- Animated reposition and the cancel path between transitions.

**Not verified at all — a human must supply (do not treat as working):**

- Whether the bar actually appears/is ordered correctly on-screen on a real
  display, and the fullscreen/Spaces/multi-display behaviors above.
- Whether native-bar reveal/hide is observable on notched hardware. The
  Accessibility probe is the candidate detector; it is gated and untested.
- Whether a single system-wide AX sample can be attributed to the right display
  in a multi-display setup. Until then it is only used for a single masked
  display.
- Animation smoothness, no flashing/overlap, and no focus theft under rapid
  toggles; sleep/wake and hot-plug with real displays.

## Permissions

Accessibility permission is required for the notched-display detector (product
decision (a) in the 0009 report). Without it the shell logs the missing
permission at launch and every notched display is reported as
`indeterminate(notchedHousingMasksMenuBar)` — it holds the top edge and never
converts pointer proximity into a visibility claim. On notch-free displays
`visibleFrame` remains the signal and no permission is needed.

The sample is applied conservatively: it is only used for a display whose own
geometry is masked by the camera housing, and only when there is a single
display, because the AX menu bar is one system-wide object that public APIs do
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
