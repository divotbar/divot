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

**Measurement:** If you encounter this limitation, you can help diagnose it by measuring your system's actual window layers:

1. Build the measurement probe: `swift build --package-path macos`
2. Run the watch mode: `macos/.build/debug/divot-notification-banner-probe --watch 30`
3. While watching, use one of these triggers:
   - **Reliable (no notifications needed):** Open System Settings → Control Center and toggle a control (Wi-Fi, Bluetooth, etc.) — the Control Center panel appears as `[ControlCenter]` in the output
   - **Alternative:** Trigger a notification via `osascript -e 'display notification "Test message" with title "Divot"'` (only works if Do Not Disturb is OFF)
4. Share the output showing the window layer and bounds (AppKit coordinates) for comparison

The probe also measures and displays Divot's real panel layer in real time, making it easy to see how other windows rank against it.

**Workarounds:**

1. **Disable menu bar auto-hide:** In System Settings → Dock & Menu Bar, turn off auto-hide.
   Banners are expected to reposition below the visible menu bar, avoiding overlap.
   (Not yet verified with a live notification and measured layers.)

2. **Use cursor-reveal (Settings → Move below the menu bar when it appears):**
   When you move your pointer to the top, Divot temporarily slides below a revealed menu bar.
   Notification banners do not follow this animation, so overlap can still occur if a banner
   arrives while the bar is at the top edge.

3. **Accept the limitation:** This is how some third-party top-edge bars behave on macOS.
   Notification content remains readable despite partial visual overlap.

**Note:** Notifications are suppressed when Do Not Disturb or Focus modes are active. If no notifications appear while measuring, check that Do Not Disturb is OFF in Control Center.

## Other constraints

(To be filled in as physical validation identifies additional limitations.)
