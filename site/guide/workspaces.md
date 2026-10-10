# Workspaces & displays

::: info Planned behavior
This page describes the native app requirements. The interactive website demonstrates the layout only.
:::

## Left of the camera

Workspace indicators and the frontmost program belong on the left. The focused workspace has both a clear visual shape and an accessible selected state. Occupied and empty workspaces should be distinguishable without relying on color alone. Optional per-workspace app icons show what is running and can be turned off.

AeroSpace is the initial adapter and yabai is the second, both behind the same model (task 0012). Workspace activation is asynchronous; a slow command must never freeze the bar. Supported events/callbacks drive refreshes rather than continuous shell polling. For AeroSpace the adapter reads real workspace names and focus/occupied/empty state from its documented CLI, and subscribes to its documented events. The yabai adapter reads its documented `-m query` output the same way: workspace identity is yabai's own space label when set and its mission-control index otherwise, and app icons come from the window listing keyed by the running process's bundle id. yabai has no persistent event stream — its documented signals run callbacks — so Divot reads on launch and after an action instead. Reading yabai's spaces/windows/displays and focusing a space need no scripting addition and no private API; yabai itself still needs its Accessibility permission and a running service. Neither adapter is physically validated on-device yet.

Native macOS Spaces is researched, not planned. Public APIs expose displays and the active Space's on-screen windows, and a notification that a Space changed, but no Space identity — so Spaces cannot be listed, switched, or mapped to apps without private APIs. Divot therefore treats "no window manager" as an honest unavailable state rather than presenting Spaces as a workspace source.

## Right of the camera

The default status group is battery percentage, a minute clock with weekday and date, network status, and volume. Both sides are configurable, so you can reorder items or move them between groups. The website's Wi-Fi glyph is illustrative of the planned network item.

## A real gap

The camera housing stays outside interactive panels. Divot uses system-reported geometry rather than a guessed notch width. On displays without a notch, groups sit at opposite edges with breathing room in the middle.

## Multiple displays

Each display has its own geometry and workspace mapping. Disconnecting a screen must not erase settings. Mixed scaling and negative display origins are part of the core test plan. Per-display customization follows the initial global layout.

## The macOS menu bar

The planned behavior is persistent top/below placement, which replaces the earlier fullscreen-hide default. Divot stays visible: when the native menu bar is hidden it takes the top edge; when the bar appears it shifts below it, and it returns to the top when the bar hides. If the system bar is configured always visible, Divot stays below it.

This is a requirement, not a shipped capability. Detection is implemented through the permission-gated Accessibility probe, behind a documented per-install opt-in (`menuBar.trustAccessibilityProbe`, off by default): the bar's own on-screen frame distinguishes a revealed bar from one that still reports `hidden == false` while auto-hidden. The visual result is not yet physically confirmed, and on notched displays the camera housing masks the same band, so actual menu-bar visibility depends on that observation. A top band occupied by another bar (for example a-bar under AeroSpace) is likewise not treated as a revealed native bar, so Divot holds the top edge instead of stacking below it. No run yet proves always-visible behavior. Fullscreen and Spaces limits are not implemented yet and will be documented honestly. Divot does not recreate other applications' menus or force-hide the system menu bar.
