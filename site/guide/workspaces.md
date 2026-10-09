# Workspaces & displays

::: info Planned behavior
This page describes the native app requirements. The interactive website demonstrates the layout only.
:::

## Left of the camera

Workspace indicators and the frontmost program belong on the left. The focused workspace has both a clear visual shape and an accessible selected state. Occupied and empty workspaces should be distinguishable without relying on color alone. Optional per-workspace app icons show what is running and can be turned off.

AeroSpace is the initial adapter; yabai follows as a second adapter in its own milestone. Workspace activation is asynchronous; a slow command must never freeze the bar. Supported events/callbacks drive refreshes rather than continuous shell polling. The adapter reads real workspace names and focus/occupied/empty state from AeroSpace's documented CLI, subscribes to its documented events, and draws the row in the left panel. On-device appearance and interaction are still being validated.

## Right of the camera

The default status group is battery percentage, a minute clock with weekday and date, network status, and volume. Both sides are configurable, so you can reorder items or move them between groups. The website's Wi-Fi glyph is illustrative of the planned network item.

## A real gap

The camera housing stays outside interactive panels. Divot uses system-reported geometry rather than a guessed notch width. On displays without a notch, groups sit at opposite edges with breathing room in the middle.

## Multiple displays

Each display has its own geometry and workspace mapping. Disconnecting a screen must not erase settings. Mixed scaling and negative display origins are part of the core test plan. Per-display customization follows the initial global layout.

## The macOS menu bar

The planned behavior is persistent top/below placement, which replaces the earlier fullscreen-hide default. Divot stays visible: when the native menu bar is hidden it takes the top edge; when the bar appears it shifts below it, and it returns to the top when the bar hides. If the system bar is configured always visible, Divot stays below it.

This is a requirement, not a shipped capability. Detecting the native bar is still being validated; on notched displays the camera housing masks the same band, so actual menu-bar visibility remains unresolved without a validated Accessibility observation. A top band occupied by another bar (for example a-bar under AeroSpace) is likewise not treated as a revealed native bar, so Divot holds the top edge instead of stacking below it. No run yet proves always-visible behavior. Fullscreen and Spaces limits are not implemented yet and will be documented honestly. Divot does not recreate other applications' menus or force-hide the system menu bar.
