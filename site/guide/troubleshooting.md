# Troubleshooting

## I can't find an installer

There isn't a published one yet. Divot is pre-alpha, and there is no signed public download. The [install guide](./install) says so plainly and lists the current options — [build and run a local preview from source](./build) (ad-hoc signed, not notarized) — plus the steps the first unsigned release will use. The [roadmap](./roadmap) tracks the release gates.

## The configuration doesn't change my menu bar

The native app reads and validates the versioned config: both sides, per-widget options, layout height/padding, the System/Light/Dark variant, and the theme family all apply, and the settings window writes the same file. Theme family colors and custom palettes are resolved to semantic tokens and repaint the bar. You can run the native app as a local preview (`just app-run`); there is still no signed public download to install. The browser examples and preview remain design artifacts and do not modify macOS.

## The Wi-Fi network name doesn't appear

The Wi-Fi name needs Location permission, which macOS requires for reading the current SSID. Turn the name on in Settings to ask for it once. If you denied it, the Settings row explains and links to the Location Services pane; the bar then shows the network icon without a name. Divot never reads the name while the permission is off.

## The Wi-Fi popover shows no networks

Clicking the network item opens a read-only popover of nearby networks. That list also needs Location permission, because macOS gates network names on it. Without permission the popover shows a short message and a button to **System Settings → Privacy & Security → Location Services** instead of an empty list; grant access there and click the item again. Divot scans only when the popover opens, so a network that appears later shows up on the next open. The popover never joins a network and never asks for a password; use **Open Wi-Fi Settings…** at its last row for anything beyond looking.

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

When the native macOS menu bar is auto-hidden (set to auto-hide in System Settings), notification banners from Calendar, Mail, or other apps may appear with their top edge tucked under the Divot bar, partly covering the banner's title. This is a reported limitation.

### Why it happens

Divot is positioned at the very top of the screen (y=0) to stay out of the way while the menu bar is hidden. Notification banners appear in the 33-point menu-bar region when the bar is hidden. Both Divot and the banner title row end up in overlapping screen space, causing visual overlap.

Whether banners draw on top or behind Divot (z-order) and the exact positioning mechanism are not fully understood — a maintainer needs to measure the actual window levels and bounds with a live notification.

### What to do

- **Disable auto-hide:** Turn off auto-hide in System Settings → Dock & Menu Bar. The menu bar stays visible, and banners reposition below it, avoiding overlap.
- **Use Divot's cursor-reveal setting:** Turn on **Settings → Move below the menu bar when it appears**. When you move your pointer to the top of the screen, the native menu bar slides into view and Divot slides below it temporarily. Banners do not follow this animation, so overlap can still occur if a notification arrives while the bar is at the top.
- **Accept the limitation:** This is how some third-party top-edge bars behave on macOS. Notification content is still readable, just with partial overlap at the very top.

## Report a problem

When repository hosting is provisioned, include OS, hardware, commit, enabled widgets, display layout, expected behavior, actual behavior, and minimal reproduction. Remove secrets from configurations and captures. Performance reports also need the measurement method.
