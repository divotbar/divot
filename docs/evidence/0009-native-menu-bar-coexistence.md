# Evidence · 0009 native menu-bar coexistence (feasibility gate)

Status: **open** · task 0009 · 2026-10-10. This is a feasibility report, not a
claim that the feature works. It records what public APIs were observed to do in
one run, what still needs physical proof, and the product decision that follows.

Story: [Divot stays visible when the native menu bar appears](../../stories/divot-stays-visible-when-the-native-menu-bar-appears.md).

## Question

Can Divot, using only public/supported APIs and event-driven observation, detect
when the native macOS menu bar is *actually* visible and move between the top
edge and an inset row below the bar — without polling, overlap, flashing, focus
theft, or a silent hide fallback?

## What was run

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 (build 25F84) |
| Hardware | Apple silicon (arm64), one built-in **notched** display |
| Toolchain | Swift 6.3.3, Xcode 26.6 |
| Display | 1710 × 1107 @ 2.0×, `safeAreaInsets.top = 33` |
| Probe | `swift build --package-path macos`, then `macos/.build/debug/divot-menu-bar-probe` |

This is a single-machine, single-display run. Everything below is limited to that
environment; the multi-display, notch-free, fullscreen, sleep/wake, and hot-plug
cases were **not** observed and remain human-only (see the last section).

## Observed in this run

The probe's raw output:

```text
# divot menu-bar probe
os=26.5.2
screens=1
display[0] frame=(0.0, 0.0, 1710.0, 1107.0) visible=(60.0, 0.0, 1650.0, 1074.0)
  topBand=33.0 housingTop=33.0 menuBarInset=0.0 notched=true scale=2.0
  auxL=Optional((0.0, 1074.0, 763.0, 33.0)) auxR=Optional((948.0, 1074.0, 762.0, 33.0))
  -> indeterminate(notchedHousingMasksMenuBar)
defaults._HIHideMenuBar=1 (undocumented; diagnostic only)
systemPresentationOptions=0
appPresentationOptions=4
accessibilityTrusted=false
axMenuBar=unavailable (Accessibility permission not granted)
```

Readings that matter:

1. **`NSScreen.visibleFrame` excludes the entire top band, even though auto-hide
   is on.** `_HIHideMenuBar` (the global auto-hide preference) read as `1`, yet
   `frame.maxY − visibleFrame.maxY = 33 = safeAreaInsets.top`. The camera-housing
   band is excluded from `visibleFrame` regardless of whether the native bar is
   currently showing. Apple's own note on `visibleFrame` confirms this: on Macs
   with a camera housing, "this rectangle does not include the bezel or the
   visible areas on either side of the bezel."
2. **The auxiliary top areas begin exactly where `visibleFrame` ends** (`y=1074`,
   height 33), i.e. they are the two side regions of the housing band. That band
   is where the native bar renders, so on notched hardware the geometry signal is
   **masked**.
3. **A brief pointer warp to the top edge produced no observable change** —
   `visibleFrame`, `safeAreaInsets`, and the notification observers were all
   silent. This result is **inconclusive**: without Accessibility or
   screen-recording permission the probe could not confirm that the native bar
   actually revealed. It is reported as an inconclusive experiment, not as proof
   that the reveal is invisible to these APIs.
4. **No notification fired** for `NSApplication.didChangeScreenParametersNotification`,
   workspace activation, space change, or occlusion during the warp. (Same
   inconclusive caveat as above.)
5. **Accessibility is not trusted** for the probe process (`AXIsProcessTrusted() == false`),
   so the AX menu-bar path could not be exercised. No Accessibility or Screen
   Recording permission was granted during this run.

## Public API inventory

| API | Shape | What it can do | Limitation found |
| --- | --- | --- | --- |
| `NSScreen.frame` / `visibleFrame` | geometry | On **notch-free** displays the top delta is a plausible menu-bar visibility signal ("currently occupied … dock and menu bar"). | **Masked on notched displays**: the housing already excludes the band, so hidden and visible are indistinguishable. |
| `NSScreen.safeAreaInsets` | geometry | Physical camera-housing inset; invariant. | Not a visibility signal; it is a hardware property. |
| `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` | geometry | The two drawable side regions beside the housing; the basis for notch-aware bar layout. | Does not report bar visibility. |
| `NSApplication.didChangeScreenParametersNotification` | event | Fires on display-configuration changes. | Not observed on menu-bar reveal (inconclusive); documented for *display* changes, not menu-bar hover. |
| `NSWorkspace.activeSpaceDidChangeNotification`, `didActivateApplicationNotification`, `NSMenu.didBegin/EndTrackingNotification`, `NSApplication.didChangeOcclusionStateNotification` | events | Useful triggers for re-evaluating and coalescing. | None of these is a first-class "bar is visible" signal. |
| `NSApplication.currentSystemPresentationOptions` | config read | Reports system presentation options. | Read `0` here while the global auto-hide default read `1` — the two disagree, so config-based inference is unreliable on this build. |
| Accessibility (`AXUIElementCreateSystemWide` → `kAXMenuBarAttribute`, `kAXPositionAttribute`) | public AX | Plausible precise probe of the system menu bar's on-screen state. | Requires Accessibility permission (not trusted here → untested). Any off-screen heuristic must be validated, not assumed. |
| `NSUserDefaults` key `_HIHideMenuBar` | undocumented key | Read/observe the *configured* auto-hide choice. | Underscore-prefixed and not in Apple's supported API surface; used for diagnostics only, never as a trusted signal. |

## Findings

**Reliable (implemented and covered by tests in this branch):**

- Pure, platform-free detection and placement math: top-band/housing separation,
  notch masking, inset resolution, and full-width below-bar geometry.
- Housing detection accepts either public notch signal (`safeAreaInsets.top` or
  the auxiliary top areas beside the notch). A notched display whose inset reads
  zero — for example while a third-party bar (a-bar/AeroSpace) occupies the band
  — is not read as a revealed native bar; it stays indeterminate and holds the
  top edge (task 0015 code fix; still wants physical confirmation).
- An event-driven coalescing controller that converges on the latest observation,
  cancels in-flight transitions, repositions immediately under Reduced Motion,
  and **never emits a hide**. Undecidable input returns `.indeterminate` and
  holds position (no silent hide fallback).
- The AppKit adapter surface: build the probe and run it read-only.

**Needs physical human proof (cannot be proven in this environment):**

- Whether the native bar's reveal/hide is observable through any of the candidate
  signals on **notch-free** displays (`visibleFrame` delta) and on notched
  displays (Accessibility probe) — needs the user to toggle auto-hide while the
  probe runs, ideally with Accessibility granted.
- Ordering without focus theft, menu interaction (system menus still open above
  Divot), overlap/flash behavior during rapid toggles.
- Multiple displays and mixed scales, fullscreen/Spaces, sleep/wake, hot-plug.

**Likely unsupported with public APIs alone (needs a product decision):**

- On **notched hardware**, no public geometry API distinguishes a hidden from a
  revealed native bar. Absent the Accessibility probe (permission-gated), a
  precise "actual visibility" signal appears to be unavailable.

## Prototype

- `macos/Sources/DivotCore/NativeMenuBar.swift` — `ScreenGeometry`,
  `NativeMenuBarDetector`, `MenuBarInsetController`, `NativeMenuBarSignal`.
- `macos/Sources/DivotCore/BarGeometry.swift` — `nativeMenuBarInset` parameter
  adds the below-bar placement and drops the notch gap in that row.
- `macos/Sources/DivotMenuBarProbe/main.swift` — read-only AppKit probe:
  one-shot report and `--watch` event log. Public APIs only. It does not move any
  panel or change any system setting.

Run it:

```sh
swift build --package-path macos
macos/.build/debug/divot-menu-bar-probe          # one-shot report
macos/.build/debug/divot-menu-bar-probe --watch  # event-driven log, Ctrl-C to stop
```

## Tests

`swift test --package-path macos` — pure state/geometry only, no window server:

- notched vs notch-free top-band derivation, dock-on-left false positives;
- notched masking → `.indeterminate`, and Accessibility signal overriding it;
- below-bar geometry spanning the full width without the notch gap, screen clamping;
- rapid toggle convergence to the latest observation, animation cancellation,
  Reduced Motion immediacy, and "hidden bar returns to top edge, never hides".

## Product decision requested

1. **Notched-display visibility.** Either (a) request Accessibility permission and
   ship the AX system-menu-bar probe as the notched-display detector, gated and
   documented; (b) require an always-visible menu-bar configuration on notched
   displays and permanently inset below the housing; or (c) accept a
   proximity-driven inset (pointer enters the top edge → inset) as a heuristic.
   Option (a) is the only one that claims true visibility detection; it must be
   validated on real hardware before shipping.
2. **Fullscreen.** The always-visible story supersedes the starter's
   fullscreen-hide default. Fullscreen/Spaces behavior is unresolved and needs an
   explicit decision rather than the old default.
3. **Tiling gap policy.** The below-bar row overlays app content; whether Divot
   reserves window-manager space (and how) is a window-manager adapter policy,
   not something AppKit changes.

## Not observed — a human must supply

Fabricated proof is not included. The following were **not** performed in this
run and must be filled in by a person on real hardware:

- Toggling menu-bar auto-hide / always-visible modes while the probe runs.
- Granting Accessibility permission and exercising the AX menu-bar probe.
- Menu-bar reveal timing, overlap, flashing, focus, and system-menu interaction.
- Multiple displays, mixed scales, notch-free hardware, fullscreen/Spaces,
  sleep/wake, and hot-plug.

## Follow-up

Task 0003 built the app shell and display coordinator on top of these findings.
The Accessibility probe moved into the reusable `DivotAppKit`
`AXSystemMenuBarProbe`; the app reports an untrusted probe honestly instead of
guessing. Physical validation of the items above still has not been performed;
see [0003 app shell evidence](0003-app-shell.md).
