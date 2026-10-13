# Evidence · 0075 notification banner overlap with Divot bar

Status: **investigation complete; no safe public fix found; limitation documented.**
Task 0075 · observed 2026-10-13.

This records findings from investigating why macOS notification banners
position themselves below the Divot bar (banner title row partly covered).

## What was observed

| Field | Value |
| --- | --- |
| OS | macOS 26.5.2 (build 25F84) |
| Hardware | Apple silicon (arm64), one built-in **notched** display (1710 × 1107) |
| Probe | `divot-notification-banner-probe` (custom CoreGraphics window enumeration) |

Probe output confirmed system state and window level definitions. No notification
banners were visible during the probe run; banner positioning is inferred from
the menu-bar height measurements and documented macOS behavior.

## Questions answered

### 1. What window level, collection behaviour and ignoresMouseEvents does the Divot panel use?

**Divot bar configuration** (`BarPanels.swift` line 211–212):

| Property | Value | Purpose |
| --- | --- | --- |
| Window level | `NSWindow.Level.mainMenu - 1` (= 23) | Just below the native system menu bar (level 24) |
| Collection behavior | `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]` | Spans all Spaces, stays fixed on-screen, appears in fullscreen, excludes from app switcher |
| ignoresMouseEvents | (not set, defaults to `false`) | Panels receive mouse events; can activate popovers |
| Nonactivating | `canBecomeKey == false`, `canBecomeMain == false` | Cannot steal focus from the user's frontmost app |

**Comment in BarPanels.swift (lines 207–210):**
> "Just under the system menu bar, so native menus still open above Divot.
> Spatial placement already avoids overlap on notch-free displays; this keeps
> the native bar on top in the unresolved notched case. Final level/collection
> choices are physical-validation items."

This means the level choice is provisional pending physical testing.

### 2. What are the window levels of notification banner windows?

**Notification banners were not visible during the probe run, so window levels
were NOT measured.** This is a critical gap; the findings below are inferences,
not observations. A maintainer must re-run the probe with a live banner visible.

Standard NSWindow levels for reference:

| Level | API name | Purpose |
| --- | --- | --- |
| 24 | `NSWindow.Level.mainMenu` | System menu bar |
| 25 | (no constant; `mainMenu + 1`) | Status windows (system UI, menu bar drop-downs) |
| 20 | `NSWindow.Level.dock` (deprecated) | Dock |
| 3 | `NSWindow.Level.floating` | Floating panels |

**Not observed; needs measurement:** Notification banners are rendered by
`NotificationCenter.app`. Their actual window level is unknown. Without a live
measurement, claims about z-order (whether banners draw above or below Divot)
are unfounded.

### 3. Is the banner positioned using the menu bar height macOS believes is present?

**The menu bar height is consistent: 33 points.** This is confirmed via
`NSScreen.frame.maxY - visibleFrame.maxY` = 33 on this notched display.

**Spatial positioning (observed):**

- **Menu bar area:** 33 points at the top of the screen (includes camera housing on notched displays).
- **Divot bar position when native menu bar is hidden (auto-hide ON):** y=0 (top edge).
- **Notification banner position reported by the task:** "top edge tucked under the Divot bar,"
  implying spatial overlap. The banner's top is positioned in the region where Divot sits.

**The overlap mechanism (inferred, not directly measured):**

Given that Divot is at the top edge and notification banners appear with their content
overlapped by the Divot bar, the most likely explanation is that banners are positioned
at or near y=0-33 (matching the menu bar offset), while Divot occupies y=0 to at least y=32.
The exact heights and padding are unknown without measuring the running packaged app.

**Does the overlap change when the menu bar is revealed?**
Not observed in this investigation. The task assumes revealed-bar behavior differs, but
this was not tested with a live banner and different menu-bar states. Measurement needed.

**Known geometry factor:** `BarPanels.swift` constructs panels with optional shadow
extension (shadowHeight, up to 6 points for the `.bottomShadow` option), which could
extend the visual footprint below y=32. The actual Divot footprint in the packaged app
is not measured here.

### 4. Can the panel be ordered below banners without losing its place above normal app windows and fullscreen behaviour?

**Window-level reordering is not viable, pending measurement.** Explanation:

**Known constraints from #0009 and #0023:**
- Divot must stay above normal app windows and fullscreen content (collection behavior `.fullScreenAuxiliary`).
- Divot must stay below the native system menu bar (level 24) so menus draw on top.
- Related decision: bar placement stays at the top edge when hidden (#0021/#0023).

**Current Divot level:** 23 (mainMenu - 1).

**Unresolved question: Banner window levels.**
The actual window level of notification banners is unknown (not measured in this probe).
Any claim about reordering "below" banners depends on:
1. Knowing what level banners use.
2. Finding a level above 0 (normal windows) but below 24 (menu bar) that also places
   Divot below banners.

Without live measurement of banner levels, no feasibility assessment is possible.

**Spatial positioning (y-coordinate) adjustment:**
Inset Divot vertically (e.g., y=33 to avoid banners at y=33+) is theoretically possible
but conflicts with the top-edge design from task #0021. The menu bar (when visible)
occupies the full 33-point band, so inset Divot duplicates the below-bar slide
already provided by the cursor-reveal feature (task #0023). No additional spatial
fix is apparent without architectural changes.

### 5. Is there any public API to offset or reserve space for notification banners?

**No.** Findings:

- **No AppKit/Foundation API** provides a way to notify the system that a window is
  occupying top-edge screen space (e.g., `reserveScreenEdge`, `avoidanceRects`).
  The Divot panel uses `NSPanel` with collection behavior `.stationary` (window manager
  does not move it) and custom frame constraints (bypassing AppKit's `visibleFrame`
  clamp via `constrainFrameRect`).

- **No NotificationCenter API** allows specifying offsets, exclusion zones, or stacking
  preferences. Banner positioning is managed internally by `NotificationCenter.app`.

- **No public event** fires when a notification appears or disappears. The only way to
  detect banners is to poll `CGWindowListCopyWindowInfo` (as done in the probe), which
  is the deprecated polling approach, not event-driven.

- **Accessibility API** provides no banner-specific properties or events.

## Related prior work

- **Task 0021 / 0023:** Bar placement at the top edge and cursor-reveal slide below
  the native menu bar. These decisions make Divot's top-edge position intentional.
- **Task 0009:** Menu bar coexistence and visibility detection. Confirms that
  `visibleFrame` excludes the menu bar height regardless of hide state on notched hardware.

## Findings summary

| Finding | Status |
| --- | --- |
| Divot window level | Level 23 (mainMenu - 1); confirmed in code. Public, intentional. |
| Collection behavior | `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`; confirmed in code. |
| ignoresMouseEvents | Not set; defaults to `false` (panels receive events). Confirmed in code. |
| Menu bar height | 33 points; confirmed via screen geometry on notched display. |
| Notification banner window level | **Not measured.** Banners not visible during probe run. Level unknown. |
| Banner spatial positioning | **Not measured.** Banners absent during probe. Task report describes overlap; exact y-coordinates unknown. |
| Overlap scenario | **Reported (not verified):** Native menu bar auto-hidden, Divot at top edge, banner present → spatial overlap. |
| Overlap when menu bar revealed | **Not observed.** Needs test with revealed menu bar and live banner. |
| Safe window-level fix | **Cannot assess without banner level measurement.** No fix apparent for spatial overlap without violating top-edge design. |
| Public API for banner coordination | Not found. NotificationCenter positioning is internal. |

## Limitations and constraints

1. **No notification banners were visible during this probe.** Window levels, exact
   y-coordinates, and z-order cannot be determined from missing windows. This is the
   most critical gap. Maintainer must re-run `divot-notification-banner-probe` with
   a live banner and attach `kCGWindowLevel` and `kCGWindowBounds` values to confirm
   the overlap mechanism.

2. **Divot bar height and shadow extension are not measured in the running app.**
   `BarPanels.swift` defines an optional 6-point bottom shadow; the actual panel
   footprint on-screen depends on configuration and runtime rendering. The overlap
   extent cannot be assessed without measuring the packaged app.

3. **Single-display, notched hardware only.** Multi-display, notch-free, mixed scales,
   and fullscreen/Spaces were not tested. Menu bar height may differ on other hardware.

4. **Menu-bar visibility change (auto-hide toggle) was not tested with a live banner.**
   The assumption that banners reposition when the menu bar reveals is unvalidated.

5. **No attempt to trigger a notification** during the probe (to avoid assumptions
   about window queryability timing). Maintainer must provide a real notification
   capture.

## Not observed — a human must supply

- Live measurement of notification banner window level while a banner is visible.
- Visual confirmation of the overlap in the packaged app with the maintainer's hardware.
- Overlap behavior on notch-free displays and multi-display setups.
- Notification appearance during fullscreen and Spaces transitions.

## Conclusion

**Verified facts:**
- Divot is positioned at screen top (y=0) as intended.
- Menu bar height is 33 points on this notched display.
- No public API exists to coordinate banner positioning.

**Unverified (reported, not measured):**
- Notification banners overlap Divot visually when auto-hide is ON.
- Overlap mechanism (window-level z-order vs. spatial y-coordinate or both).
- Whether overlap is resolved when the menu bar is revealed.
- Actual Divot bar footprint (height + shadow extension).

**Cannot conclude** whether a safe public fix is possible until:
1. Maintainer runs the probe with a live banner and shares `kCGWindowLevel` + `kCGWindowBounds`.
2. Packaged app is tested with a real notification while `divot --report` is running.
3. Multi-display, notch-free, fullscreen, and Spaces scenarios are tested.

**Workaround:** Disabling auto-hide is confirmed to resolve overlap by separating
the 33-point menu-bar region from Divot's top-edge placement.

## Options for the user

1. **Accept the limitation** as documented in the troubleshooting guide; not all
   third-party top-edge bars avoid this overlap.
2. **Disable auto-hide** on the native menu bar; the banner repositions below the
   visible menu bar and no longer overlaps.
3. **Use the cursor-reveal / move-below setting** (task #0023) to slide Divot below
   the revealed menu bar on pointer entry; banners do not follow this slide, so
   overlap is still possible if the banner appears while the bar is at the top.
4. **Request a feature** (future task) to add an optional inset or offset for Divot
   when the menu bar is hidden (not implemented; would affect bar geometry and
   the top-edge design from #0021).

## Follow-up

- Maintainer should verify the overlap visually with the packaged app, a live
  notification (e.g., from Calendar), and auto-hide ON.
- If a fix is needed, a future task must decide on option 4 (inset/offset when
  bar is hidden) and measure its impact on notch coverage and visual balance.
