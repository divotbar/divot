# Troubleshooting

## I can't find an installer

There isn't a published one yet. Divot is pre-alpha, and there is no signed public download. The [install guide](./install) says so plainly and lists the current options — [build and run a local preview from source](./build) (ad-hoc signed, not notarized) — plus the steps the first unsigned release will use. The [roadmap](./roadmap) tracks the release gates.

## The configuration doesn't change my menu bar

The native app reads and validates the versioned config: both sides, per-widget options, layout height/padding, the System/Light/Dark variant, and the theme family all apply, and the settings window writes the same file. Theme family colors and custom palettes are resolved to semantic tokens and repaint the bar. You can run the native app as a local preview (`just app-run`); there is still no signed public download to install. The browser examples and preview remain design artifacts and do not modify macOS.

## The Wi-Fi network name doesn't appear

The Wi-Fi name needs Location permission, which macOS requires for reading the current SSID. Turn the name on in Settings to ask for it once. If you denied it, the Settings row explains and links to the Location Services pane; the bar then shows the network icon without a name. Divot never reads the name while the permission is off.

## The Wi-Fi popover shows no networks

Clicking the network item opens a popover of nearby networks. That list also needs Location permission, because macOS gates network names on it. Without permission the popover shows a short message and a button to **System Settings → Privacy & Security → Location Services** instead of an empty list; grant access there and click the item again. Divot scans on every open and paints its recent cached list at once when it has one, so a network that appears later shows up on the next open. Clicking a network joins it; a secured network asks for its password in a Divot dialog first. Use **Open Wi-Fi Settings…** at its last row for anything beyond that.

## Permissions only work in the packaged app

macOS ties Location permission to an app's bundle identity, so only the packaged `Divot.app` can ask for it. If you run the bare development binary (`swift run --package-path macos divot`, or the Dev page's **Divot bar** target), there is no bundle to grant Location to and the Wi-Fi name and nearby-network list stay empty — that is expected, not a bug. Run the packaged build instead: the Dev page's **Divot bar (packaged)** target, or `just app-run-packaged` (equivalent to `scripts/run-packaged.sh`, which rebuilds `dist/Divot.app` and opens it).

Accessibility behaves the same way: a grant made while running the dev binary attaches to your terminal or the host app, not to Divot. Grant it to `dist/Divot.app`. Both Accessibility and Location grants persist per app, but the local preview is ad-hoc signed, so a rebuild changes its signature and an earlier grant may stop matching; if that happens, remove the stale Divot row and add the current app again. Only one bar runs at a time — starting either target stops the other first. See the [build guide](./build) for the local-preview commands.

## The volume slider doesn't move the volume

Clicking the volume item opens a popover with a slider for the default output, a **Mute** toggle, and **Open Sound Settings…** at its last row. Moving the slider changes the default output's volume and the bar item's icon and percentage follow; while the popover is open it also follows volume changes made elsewhere, such as the keyboard volume keys. If the slider is disabled with a short note, that output exposes no settable volume control — some HDMI and DisplayPort devices do not — so use the display's or device's own controls. For input devices, per-app volume, or a different output device, use the Sound pane. This is implemented from public Core Audio only and is not physically validated yet.

## Website build fails on a link

VitePress treats dead internal links as errors. Check the target Markdown filename and path. Run `bun run check` after correcting the source; do not disable dead-link checks.

## Swift tests fail before compiling

Run `swift --version` and verify Xcode 26+ is selected. This foundation targets macOS 26 and tools version 6.2. An older system or toolchain is unsupported for now.

## AeroSpace isn't installed

It is not needed to run the website or geometry tests. The bar runs without it and shows an honest unavailable state for workspaces rather than inventing numbered spaces. When AeroSpace is installed, the adapter detects the documented CLI, reads real workspaces, and draws them in the left panel. Do not grant Accessibility permission for website previews.

## yabai isn't detected, or shows the wrong workspaces

yabai is the second adapter, chosen by the same policy as AeroSpace. Divot needs the `yabai` binary on a Homebrew path or your `PATH`, and the yabai service must be running so its message interface answers; without either, the bar reports the honest unavailable state instead of inventing spaces. If both AeroSpace and yabai are installed, AeroSpace is chosen first — set `widgets.workspaces.adapter` to `yabai` (or `DIVOT_WORKSPACES_ADAPTER=yabai`) to force yabai. Divot reads only documented `yabai -m query` output and focuses spaces with `yabai -m space --focus`, neither of which needs the yabai scripting addition or System Integrity Protection changes; yabai itself still needs its Accessibility permission. yabai has no persistent event stream, so the row refreshes at launch and after a click rather than on every keypress. Live yabai behavior has not been physically validated yet; report what you see.

## A theme or side doesn't change anything

Both configurable sides, per-item options, layout, the System/Light/Dark variant, and the theme family are implemented and applied by the native app. Theme family colors and custom palettes are validated, saved, and resolved to the bar's semantic tokens. The browser examples and preview remain design artifacts; the local preview runs the real app from source but is not a public release.

## Check what the app sees

Run `divot status --json` for a read-only diagnostic snapshot: the app version, whether a Divot app instance is running, the Accessibility and Location permission readings, the detected workspace adapter (AeroSpace or yabai), and the config path with its validity. The plain `divot status` prints the same facts in words. It never asks for or grants a permission; when Accessibility or Location is missing, the report names the System Settings pane to open (`Privacy & Security › Accessibility` or `Privacy & Security › Location Services`). If the config file is invalid, the status lists the failing field and notes that the running app keeps the last valid configuration. Because the app watches the file, a valid `divot config set` applies without a restart.

## Notification banners overlap the Divot bar

When the native macOS menu bar is auto-hidden, notification banners from Calendar, Mail, or other apps used to appear with their top edge tucked under the Divot bar, covering the banner's title. That is now addressed.

### Why it happened

A measurement run showed the Divot bar at window layer 23 and a live notification banner at layer 21. Divot was therefore ordered *above* the banner, and because the bar is an opaque, full-width strip across the top of the screen, it drew over the banner's title.

### The fix

Divot now sits one window layer below notification banners (level 20) while staying above ordinary app windows and below the native menu bar and its menus. A banner draws **over** the bar instead of being hidden by it. This uses the public `NSWindow.level` API only; it does not change the top-edge placement, Spaces, or fullscreen behavior, and it is unit-tested. The visual result is not yet confirmed on hardware — treat the fix as implemented, not screenshot-verified.

### Measure the layers yourself

Build and run the measurement probe to see window layers and Divot's actual position:

```bash
swift build --package-path macos && macos/.build/debug/divot-notification-banner-probe --watch 20
```

This polls `CGWindowListCopyWindowInfo` twice per second (0.5-second intervals) and prints every newly appearing window or layer change:
- Timestamp, owner name, owner PID, window name, layer, bounds (CG and AppKit coordinates), alpha, on-screen status
- Window classification (`[NotificationCenter banner]`, `[ControlCenter]`, or `[Divot panel]`)
- Divot panel's measured layer and bounds for comparison
- Per-window comparison line: e.g. `ControlCenter panel layer 25 is above Divot panel layer 20 (Divot y=1068 h=39)`
- Final summary: highest-layer windows observed (levels only; run the one-shot probe for a banner's bounds)

**Prerequisites:**
- Do Not Disturb must be OFF (notifications are suppressed when enabled)
- Trigger a notification via `osascript -e 'display notification "Test message" with title "Divot test"'` (if DND is off)
- OR: Open System Settings → Control Center and toggle a control (Wi-Fi, Bluetooth, etc.) — the ControlCenter panel appears as `[ControlCenter]` in the output and provides a reliable overlay for comparison without waiting for notifications

### If a banner still overlaps

- **Disable auto-hide:** Turn off auto-hide in System Settings → Dock & Menu Bar. Banners then reposition below the visible menu bar, well clear of the bar.
- **Use Divot's cursor-reveal setting:** Turn on **Settings → Move below the menu bar when it appears**. When you move your pointer to the top of the screen, the native menu bar slides into view and Divot slides below it temporarily. Banners do not follow this animation, so overlap can still occur if a notification arrives while the bar is at the top.
- **Side Dock:** level 20 equals the Dock's level, so a revealed Dock on the left or right edge can draw over the bar's end. This is a minor, disclosed trade.

## Report a problem

When repository hosting is provisioned, include OS, hardware, commit, enabled widgets, display layout, expected behavior, actual behavior, and minimal reproduction. Remove secrets from configurations and captures. Performance reports also need the measurement method.
