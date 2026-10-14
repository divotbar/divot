# Evidence · 0075 notification banner overlap with Divot bar

Status: **banner level measured (21) and root cause confirmed; Divot's panel
level lowered to 20 (#0080). The z-order fix awaits the maintainer's eye check
on the packaged app; the banner's own bounds and the revealed-menu-bar /
fullscreen cases are still unmeasured.**
Task 0075 (investigation) · task 0080 (measurement + fix) · 2026-10-14.

This records what a live measurement observed on the maintainer's Mac about why
macOS notification banners sit under the Divot bar, and the fix decided from it.
It does not claim the fixed behaviour looks right on screen; a person must still
verify it by eye (see [What a person still has to do](#what-a-person-still-has-to-do)).

## Measurement run (2026-10-14)

Maintainer run on the packaged `dist/Divot.app` with the native menu bar set to
auto-hide, while a real **App Background Activity** notification banner was on
screen:

```text
$ swift run --package-path macos divot-notification-banner-probe --watch 20
os=26.5.2
Watching all windows for 20 seconds, polling twice per second...

[13:13:17] window-77191 [Divot panel] owner=divot pid=89801 layer=23 CG-bounds=(0, 0, 769, 39) AppKit-bounds=(0, 1068, 769, 39) alpha=1.00 on-screen=true
[13:13:17] window-77192 [Divot panel] owner=divot pid=89801 layer=23 CG-bounds=(942, 0, 768, 39) AppKit-bounds=(942, 1068, 768, 39) alpha=1.00 on-screen=true

[13:13:33] ControlCenter panels (layer 25, above Divot panel layer 23): window-53 (Amphetamine), window-14505, window-54133, window-61067, window-61090, window-61353, window-77190 (all Item-0), CG-bounds y=-34, on-screen=false
[13:13:33] window-77197 owner=Window Server name="System Status Item Clone" layer=25 CG-bounds=(1425, -26, 20, 18) alpha=0.29 on-screen=false

## Summary
Divot panel layer (measured): 23
  CG-bounds: (942, 0, 768, 39)
  AppKit-bounds: (942, 1068, 768, 39)

Highest-layer windows visible at end of watch period:
1. IsThereNet (layer 2147483628)
2. divot [Divot panel] (layer 23)
3. Notification Centre [NotificationCenter banner] (layer 21)
4. Dock (layer 20)
```

### What the numbers say

| Window | Layer | Bounds (CG, top-left origin) | Notes |
| --- | --- | --- | --- |
| Divot panel (left) | 23 | (0, 0, 769, 39) | top edge; 39 pt tall |
| Divot panel (right) | 23 | (942, 0, 768, 39) | camera-housing gap between x=769 and x=942 |
| NotificationCenter banner | 21 | **not captured in this run** | level read from the end-of-watch list |
| Dock | 20 | not captured | reference point for the level band |
| ControlCenter panel | 25 | y=-34 (off-screen here) | ordered above Divot already |

Coordinates keep their frame of reference. CG bounds use macOS's **top-left**
origin; AppKit bounds are the same rectangles flipped against the primary
display height (1107): `AppKit y = 1107 − CG maxY`. Divot's top-edge panel is
therefore CG `y=0` / AppKit `y=1068`, and it is 39 points tall.

**Root cause (measured, not inferred):** Divot's panel is at `kCGWindowLayer`
23 and the notification banner at 21, so Divot is ordered **above** the banner.
The banner's title row is hidden because the bar's opaque full-width region
occupies the top 39 points and draws over it. The overlap is a z-order
relationship, not only the spatial coincidence of both sitting near y=0.

**What this run did not capture.** The banner's own bounds are not in the paste
above: the `--watch` summary prints only the *layer* of the highest windows,
and per-window CG/AppKit bounds are printed only for windows that newly appear
or change during the watch. The banner was already on screen when the watch
seeded, so only its level reached the summary. Running the one-shot probe
(`divot-notification-banner-probe`, no `--watch`) while a banner is visible
prints its `frame (AppKit coords)`.

## Questions answered

### 1. What window level, collection behaviour and ignoresMouseEvents does the Divot panel use?

**Bar configuration (`BarPanels.swift`):**

| Property | Value | Purpose |
| --- | --- | --- |
| Window level | 20 (before #0080: `mainMenu - 1` = 23) | Below notification banners, above app content, below the native menu bar |
| Collection behavior | `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]` | Spans all Spaces, stays fixed on-screen, appears in fullscreen, excluded from the app switcher |
| ignoresMouseEvents | (not set, defaults to `false`) | Panels receive mouse events so they can activate popovers |
| Nonactivating | `canBecomeKey == false`, `canBecomeMain == false` | Cannot steal focus from the user's frontmost app |

Window *level* and `collectionBehavior` are orthogonal: lowering the level does
not change Spaces/fullscreen membership. The collection behavior is unchanged
by #0080.

### 2. What are the window levels of notification banner windows?

**Measured: layer 21.** The end-of-watch list above reports
`Notification Centre [NotificationCenter banner] (layer 21)`. For reference, the
same run measured the Dock at 20 and ControlCenter panels at 25.

Standard `NSWindow.Level` values for the surrounding band (public constants):

| Level | API name | Purpose |
| --- | --- | --- |
| 20 | `NSWindow.Level.dock` (deprecated) | Dock |
| 21 | *(no constant)* | Notification banner (measured) |
| 24 | `NSWindow.Level.mainMenu` | System menu bar |
| 25 | `NSWindow.Level.statusBar` | Status windows (ControlCenter, status items) |
| 101 | `NSWindow.Level.popUpMenu` | Open menus |

The banner level is not a public constant; it was read at runtime via
`CGWindowListCopyWindowInfo`. It is one point above the Dock and three points
below the native menu bar.

### 3. Is the banner positioned using the menu bar height macOS believes is present?

The menu-bar height on this machine is **33 points**, confirmed via
`NSScreen.frame.maxY − visibleFrame.maxY = 33` on the notched display. The
measured Divot panel is 39 points tall (`y=0`, height 39), consistent with the
configured bar height plus the optional 6-point bottom shadow strip.

The banner's exact y-position is **not measured** (bounds were not captured; see
above). What is measured is the ordering: Divot (23) draws over the banner (21),
which is why the banner's title row is covered.

**Does the overlap change when the menu bar is revealed?** Not measured — there
is no revealed-menu-bar run with a live banner. The level relationship is
expected to be the same, but that remains unverified.

### 4. Can the panel be ordered below banners without losing its place above normal app windows and fullscreen behaviour?

**Yes, with public API — and #0080 implements it.** The measured banner level
(21) leaves a public level that is above ordinary windows and below banners.
Divot now sets the panel to **`NSWindow.Level(rawValue: 20)`** instead of
`mainMenu - 1` (23):

- Above ordinary app content (level 0) and fullscreen app windows.
- Below the notification banner (21), so a banner draws over the bar.
- Below the native menu bar (24) and its pop-up menus (101), so system menus
  still open above Divot.
- Below ControlCenter / status windows (25), which were already above Divot.

Level is independent of `collectionBehavior`, so the all-Spaces and fullscreen
placement decided in #0021/#0023 is unchanged. The one trade-off is that level
20 equals the Dock's level; on a left- or right-side Dock the revealed Dock can
therefore draw over the bar's end. The Dock is not part of the menu-bar band and
the bar is ordered front, so this is a minor, disclosed trade.

The alternative — inset the bar vertically below the banner — was rejected: it
duplicates the cursor-reveal slide from #0023 and breaks the intentional
top-edge placement from #0021.

### 5. Is there any public API to offset or reserve space for notification banners?

**No.** Findings:

- **No AppKit/Foundation API** lets a window declare that it occupies top-edge
  screen space or reserve an avoidance rect. The Divot panel uses `NSPanel` with
  `.stationary` collection behavior and a custom `constrainFrameRect(_:to:)`.
- **No NotificationCenter API** allows offsets, exclusion zones, or stacking
  preferences. Banner positioning is internal to `NotificationCenter.app`; the
  banner's layer is only readable after the fact via `CGWindowListCopyWindowInfo`.
- **No public event** fires when a notification appears or disappears.
- **Accessibility** exposes no banner-specific properties or events.

So the only public lever is Divot's own window level, which is what #0080 uses.

## Decision (task #0080)

**Lower the bar panel's window level to 20 — one point below the measured
notification-banner layer — and keep the collection behavior unchanged.**

Reasoning:

1. The measurement shows the banner is *below* Divot (21 < 23), so the bar is
   what hides the banner. The minimal public fix is to reorder, not to move.
2. A level below 21 but above 0 keeps the bar above app content while letting
   banners draw over it, so banner content is never hidden.
3. Window level is orthogonal to `collectionBehavior`, so it cannot regress the
   Spaces/fullscreen placement from #0009/#0021/#0023.
4. Insetting the bar was rejected (duplicates the #0023 slide, breaks the #0021
   top-edge design).

Implemented in `NSPanelBarSurface.panelLevel` (`macos/Sources/DivotAppKit/BarPanels.swift`)
with a test in `macos/Tests/DivotAppKitTests/BarPanelContainerTests.swift`. The
level is a documented literal because macOS does not expose a
notification-banner level constant; the evidence above is its source.

## Public API inventory

| API | Shape | What it can do | Limitation found |
| --- | --- | --- | --- |
| `NSWindow.level` | config | Set where a window orders | No banner-aware constant; the banner level is read at runtime, not declared |
| `CGWindowListCopyWindowInfo` | read | Read every window's `kCGWindowLayer` and `kCGWindowBounds` | Deprecated polling; the only way to observe banners |
| `NSScreen.frame` / `visibleFrame` | geometry | Menu-bar height on notch-free displays | Masked by the camera housing on notched displays |
| `NSScreen.safeAreaInsets` | geometry | Camera-housing inset | A hardware property; does not report bar visibility |
| `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` | geometry | Notch-aware layout basis (side regions of the housing band) | Do not report bar visibility |
| Accessibility (`AXUIElementCreateSystemWide`) | public AX | Permission-gated menu-bar probe | Not trusted by default; no banner signal |
| `NSApplication.didChangeScreenParametersNotification` | event | Display-config changes | Not observed on menu-bar reveal |

## Related prior work

- **Task 0021 / 0023:** Bar placement at the top edge and cursor-reveal slide
  below the native menu bar. Those decisions make Divot's top-edge position
  intentional and are unchanged by the level fix.
- **Task 0009:** Menu bar coexistence and visibility detection. Confirms that
  `visibleFrame` excludes the menu-bar height regardless of hide state on
  notched hardware.

## Findings summary

| Finding | Status |
| --- | --- |
| Divot window level | Level 23 (`mainMenu - 1`) measured; changed to 20 in #0080. |
| Collection behavior | `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`; confirmed in code, unchanged. |
| ignoresMouseEvents | Not set; defaults to `false` (panels receive events). Confirmed in code. |
| Menu bar height | 33 points; confirmed via screen geometry on the notched display. |
| Notification banner window level | **Measured: 21** on macOS 26.5. |
| Banner spatial positioning | **Not measured:** bounds were not in the `--watch` summary. The one-shot probe prints them. |
| Overlap scenario | **Confirmed by measurement:** Divot at 23 draws over the banner at 21 → banner title row hidden. |
| Overlap when menu bar revealed | **Not observed.** Still needs a run with a revealed native bar and a live banner. |
| Fix | **Implemented (public API):** panel level lowered to 20; test added. Awaits the maintainer's eye check. |

## Limitations and constraints

1. **Banner bounds were not captured.** The `--watch` summary reports the layer
   of the highest windows but not their bounds, and the banner predated the
   watch seed. Use the one-shot probe while a banner is visible for bounds.
2. **Single run, single display, auto-hide on.** The revealed-menu-bar,
   fullscreen, Spaces, multi-display, and notch-free cases were not run with a
   live banner.
3. **The banner layer is not a public constant.** 21 was read at runtime on
   macOS 26.5. If a future OS moves banners to 20 or below, Divot's level 20
   would no longer sit beneath them; the level is one point of margin by design.
4. **Level 20 equals the Dock's level.** On a side Dock the revealed Dock can
   draw over the bar's end.

## What a person still has to do

Fabricated proof is not included. To finish #0080 a maintainer must:

1. Build the packaged app (`scripts/package-app.sh`, open `dist/Divot.app`) with
   the native menu bar on auto-hide and confirm by eye that a real notification
   banner now draws **over** the Divot bar rather than being tucked under it.
2. If desired, capture the banner's bounds with the one-shot probe while a
   banner is visible (not `--watch`), to fill the `bounds` gap above.
3. Note anything the level change regressed (system menus, ControlCenter,
   fullscreen, a side Dock).

Do not claim visual sign-off without that eye check.

## Conclusion

**Verified by measurement (2026-10-14):**
- Divot's panel draws at layer 23, full-width across the top 39 points.
- A live notification banner draws at layer 21 — *below* Divot. The overlap is
  z-order, and Divot is the window hiding the banner.
- The Dock is at 20 and ControlCenter at 25.

**Decided and implemented (#0080):** lower the panel level to 20 so banners draw
over the bar, using public `NSWindow.level` only; collection behavior and
placement are unchanged.

**Still open:** the banner's bounds, the revealed-menu-bar case, and the
maintainer's visual confirmation on the packaged app.
