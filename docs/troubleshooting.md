# Troubleshooting and Known Limitations

This document lists known limitations and technical constraints that affect Divot's behavior. Limitations are organized by feature area, with evidence links and workarounds where applicable.

## Notification banner overlap when the menu bar is auto-hidden

**Root cause measured, fix implemented (#0080).** When the native macOS menu bar
is auto-hidden and a notification banner appears, the banner used to be tucked
under the Divot bar, hiding its title row. The [probe measurement](evidence/0075-notification-banner-overlap.md)
showed why: Divot's panel drew at window layer 23 and the banner at layer 21, so
Divot was ordered *above* the banner and its opaque full-width top strip covered
the banner's title. Divot now sets its panel one layer below the banner (level
20), so a banner draws **over** the bar instead of being hidden by it, while the
bar stays above ordinary app windows and below the native menu bar and its menus.

The fix uses the public `NSWindow.level` only. It does not change placement,
`collectionBehavior`, or fullscreen behavior, and it is unit-tested. The
maintainer's eye check on the packaged app with a real notification is still
pending — the visual result is not yet signed off.

**Measurement:** You can re-measure your system's window layers with the probe:

1. Build the measurement probe: `swift build --package-path macos`
2. Run the watch mode: `macos/.build/debug/divot-notification-banner-probe --watch 30`
3. While watching, use one of these triggers:
   - **Reliable (no notifications needed):** Open System Settings → Control Center and toggle a control (Wi-Fi, Bluetooth, etc.) — the Control Center panel appears as `[ControlCenter]` in the output
   - **Alternative:** Trigger a notification via `osascript -e 'display notification "Test message" with title "Divot"'` (only works if Do Not Disturb is OFF)
4. For the banner's own bounds, run the one-shot probe (`divot-notification-banner-probe`, no `--watch`) while a banner is visible; the `--watch` summary reports levels only.

The probe also measures and displays Divot's real panel layer in real time, making it easy to see how other windows rank against it.

**If a banner still overlaps (or you prefer the bar on top):**

1. **Disable menu bar auto-hide:** In System Settings → Dock & Menu Bar, turn off auto-hide.
   Banners then reposition below the visible menu bar, well clear of the bar.
2. **Use cursor-reveal (Settings → Move below the menu bar when it appears):**
   When you move your pointer to the top, Divot temporarily slides below a revealed menu bar.
   Notification banners do not follow this animation, so overlap can still occur if a banner
   arrives while the bar is at the top edge.
3. **Accept the limitation:** reduced but not eliminated — on a side Dock the revealed Dock
   can still draw over the bar's end, because level 20 equals the Dock's level.

**Note:** Notifications are suppressed when Do Not Disturb or Focus modes are active. If no notifications appear while measuring, check that Do Not Disturb is OFF in Control Center.

## Permissions work in the packaged app, not the dev binary

Running Divot two different ways changes what permissions it can hold:

- **`swift run --package-path macos divot`** (the Dev page's **Divot bar**
  target, or a raw build binary) is a bare executable with no `Info.plist` and no
  bundle identity. macOS cannot grant it Location, so the Wi-Fi name and the
  nearby-network list stay empty, and any Accessibility grant attaches to the
  host terminal or app rather than to Divot.
- **`dist/Divot.app`** (the Dev page's **Divot bar (packaged)** target, or
  `scripts/run-packaged.sh` / `just app-run-packaged`) is the real bundle. It is
  the one that gets the Location prompt and holds Accessibility as Divot itself.

Accessibility and Location grants persist per app, but the preview is ad-hoc
signed, so a rebuild changes its code signature and an earlier grant may no
longer match. If a rebuilt app loses the grant, remove the stale Divot row under
**System Settings → Privacy & Security** and add the current `dist/Divot.app`
again. Only one bar may run at a time; each Dev target stops the other first.
See the [local preview](local-preview.md) for the targets.

## Other constraints

(To be filled in as physical validation identifies additional limitations.)
