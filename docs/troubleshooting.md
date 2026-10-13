# Troubleshooting and Known Limitations

This document lists known limitations and technical constraints that affect Divot's behavior. Limitations are organized by feature area, with evidence links and workarounds where applicable.

## Notification banner overlap when the menu bar is auto-hidden

**Reported limitation:** When the native macOS menu bar is set to auto-hide and a
notification banner appears, the banner may be visually overlapped by the Divot bar.

**Root cause:** Not fully understood. See [evidence/0075-notification-banner-overlap.md](evidence/0075-notification-banner-overlap.md)
for the investigation. The likely mechanism:

- Divot is positioned at y=0 (screen top) when the native menu bar is hidden.
- Notification banners are positioned in the 33-point menu-bar region when the bar is hidden.
- Both Divot and the banner title row occupy overlapping y-coordinates.

Exact z-order (which draws on top) and notification window levels are unmeasured.

**Workarounds:**

1. **Disable menu bar auto-hide:** In System Settings → Dock & Menu Bar, turn off auto-hide.
   Banners are expected to reposition below the visible menu bar, avoiding overlap.
   (Not verified with a live notification; awaiting maintainer test.)

2. **Use cursor-reveal (Settings → Move below the menu bar when it appears):**
   When you move your pointer to the top, Divot temporarily slides below a revealed menu bar.
   Notification banners do not follow this animation, so overlap can still occur if a banner
   arrives while the bar is at the top edge.

3. **Accept the limitation:** This is how some third-party top-edge bars behave on macOS.
   Notification content remains readable despite partial visual overlap.

**Investigation needed:** For a fix to be possible, a maintainer must:
1. Trigger a real notification with auto-hide ON.
2. Run `divot-notification-banner-probe --watch` and share the banner's `kCGWindowLayer` and bounds.
3. Determine the overlap mechanism and whether a safe public fix exists.

## Other constraints

(To be filled in as physical validation identifies additional limitations.)
