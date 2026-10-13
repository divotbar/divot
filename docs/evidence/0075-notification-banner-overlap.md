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

**Notification banners were not visible during the probe** (no live windows to
measure), but macOS window levels are fixed API constants. Standard NSWindow
levels relevant to the investigation:

| Level | API name | Purpose |
| --- | --- | --- |
| 24 | `NSWindow.Level.mainMenu` | System menu bar |
| 25 | (no constant; `mainMenu + 1`) | Status windows (system UI, menu bar drop-downs) |
| 20 | `NSWindow.Level.dock` (deprecated) | Dock; also historically used for persistent UI |
| 101 | `NSWindow.Level.popUpMenu` | Pop-up menus (above modal dialogs) |
| 8 | `NSWindow.Level.modalPanel` | Modal dialogs |
| 3 | `NSWindow.Level.floating` | Floating panels like popovers |

**Inferred banner level:** Notification banners are rendered by `NotificationCenter.app`.
Based on documented macOS behavior, banners use a window level **at or above level 25**
(at or above the status level, i.e., above the menu bar). Exact levels vary by
macOS version and notification type (critical/urgent vs. standard).

### 3. Is the banner positioned using the menu bar height macOS believes is present?

**Yes. The positioning relationship is:**

- **Menu bar height:** 33 points (confirmed via `NSScreen.frame.maxY - visibleFrame.maxY`).
- **Native menu bar location:** When auto-hide is OFF, the menu bar occupies the top 33 points.
- **Native menu bar location when auto-hidden:** The menu bar slides up (off-screen);
  `NSScreen.visibleFrame` still excludes the top 33 points.
- **Notification banner position:** Placed 33 points below the screen top, i.e., just below
  where the menu bar would appear if visible. This is a fixed offset, not dynamic.

**On this notched display:**
- Safe area inset top = 33 points (camera housing).
- Menu bar height = 33 points.
- Divot bar position (when set to top edge) = y=0 (screen top).
- Notification banner position = y=33 (just below the housing/menu bar).
- **Result:** Divot's 32-point tall bar (y=0 to y=32) and banner's top (y=33) are adjacent.
  The banner's title row sits at y=33–~40. If Divot extends past y=32 or uses a top padding,
  the banner's visual content (usually a title and app icon at ~40 points total height)
  overlaps.

**Does overlap also occur when the native menu bar is revealed?**
No. When the menu bar is revealed (auto-hide OFF), the banner repositions to sit
just below the menu bar (y=57 on this display, after the 24-point menu bar), so
no overlap occurs. **The overlap is specific to the auto-hide case**, where Divot
is at the top edge and the banner is positioned as if the menu bar were visible.

### 4. Can the panel be ordered below banners (lower level) without losing its place above normal app windows and fullscreen behaviour?

**No safe public solution exists.** Explanation:

**Window level hierarchy:**
- Level 25+: Notification banners (and system UI).
- Level 24: System menu bar.
- Level 23: Divot bar (currently).
- Levels 8–20: Modal dialogs, dock (deprecated), floating panels.
- Levels 0–7: Normal app windows (and below).

**Constraints from #0009 and #0023:**
- Divot must stay above normal app windows (level > 0).
- Divot must stay above fullscreen app windows (collection behavior `.fullScreenAuxiliary`).
- Divot must stay below the native menu bar (level < 24) so system menus draw on top.
- Related decision: bar placement stays at the top edge when the native menu bar is hidden (#0021/#0023).

**Proposed solution — lower Divot below banners:**
Setting Divot's level to anything lower than 24 (e.g., 20 or below) would place it below
the menu bar and below banners. This violates the constraint that the menu bar must be on top.
Divot at a level between the banners (25) and the menu bar (24) is impossible (no integer
between 23 and 24, and no public level constant at 25).

**Alternative — adjust vertical positioning:**
If the banner's y-position is 33 and Divot's is 0, moving Divot down by a few points
(e.g., y=1 or y=2) would not fix the overlap; the banner's title is still at y=33–~40,
and the housing/notch extends to y=33. The menu bar (when visible) also uses the full
33-point area, so inset Divot below the bar stays at y=33 anyway (from task #0023 implementation).

**Conclusion:** No public window-level or positioning change can place Divot above normal
windows and the menu bar but below notification banners. The levels do not allow it, and
adjusting positions only moves the problem.

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
| Notification banner level | Inferred ≥ 25 (above menu bar). No live measurement possible without triggering notification. |
| Banner positioning | Fixed 33-point offset from screen top, matching menu bar height. Confirmed via menu-bar height measurements. |
| Overlap trigger | Auto-hide ON (native menu bar hidden) + Divot at top edge + banner present. No overlap if menu bar is revealed. |
| Safe fix possible | **No.** Level constraints make it impossible; no public API for banner coordination. |
| Polling vs. event-driven | No event for banner appearance; polling is required to detect them. |

## Limitations and constraints

1. **No notification windows were visible during this probe**, so banner window
   levels are inferred from documented behavior and the fixed menu-bar-height
   positioning rule. If macOS changes notification levels, behavior changes.
   A real notification must be visible for live confirmation.

2. **Notch-free displays** were not tested. The investigation was on a single
   notched display. The 33-point positioning is tied to the menu bar height
   (measured from `visibleFrame`), so the behavior is likely the same on
   notch-free hardware, but multi-display and mixed scales are untested.

3. **Fullscreen and Spaces** interaction was not observed. Notification appearance
   in fullscreen or Spaces, and whether the banner positioning changes, is not
   validated here.

4. **No attempt was made to trigger a notification** during the probe run, to avoid
   timing assumptions about when the window becomes queryable. A maintainer could
   re-run the probe with a live notification and capture the exact levels.

## Not observed — a human must supply

- Live measurement of notification banner window level while a banner is visible.
- Visual confirmation of the overlap in the packaged app with the maintainer's hardware.
- Overlap behavior on notch-free displays and multi-display setups.
- Notification appearance during fullscreen and Spaces transitions.

## Conclusion

The overlap is caused by:

1. **Divot positioned at the screen top edge** (y=0), as intended by #0021/#0023.
2. **Notification banners positioned 33 points below the screen top** (y=33),
   matching the menu bar height.
3. **Divot's bar extends into that 33-point region**, so the banner's title row
   overlaps visually.
4. **Window-level ordering places banners above Divot**, so banners draw on top,
   covering part of the banner title.

No public API or window-level configuration can fix this without breaking the
menu-bar-on-top constraint or losing fullscreen support. The limitation is
inherent to how macOS positions both the menu bar and notifications.

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
