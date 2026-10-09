# Workspaces & displays

::: info Planned behavior
This page describes the native app requirements. The interactive website demonstrates the layout only.
:::

## Left of the camera

Workspace indicators belong on the left. The focused workspace has both a clear visual shape and an accessible selected state. Occupied and empty workspaces should be distinguishable without relying on color alone.

AeroSpace is the initial adapter. Workspace activation is asynchronous; a slow command must never freeze the bar. Supported events/callbacks drive refreshes rather than continuous shell polling. The exact integration setup will be documented with the first working adapter.

## Right of the camera

The initial status group is frontmost app, battery, and clock. You choose their order. The website's Wi-Fi glyph is illustrative and does not promise a Wi-Fi provider in the first release.

## A real gap

The camera housing stays outside interactive panels. Divot uses system-reported geometry rather than a guessed notch width. On displays without a notch, groups sit at opposite edges with breathing room in the middle.

## Multiple displays

Each display has its own geometry and workspace mapping. Disconnecting a screen must not erase settings. Mixed scaling and negative display origins are part of the core test plan. Per-display customization follows the initial global layout.

## The macOS menu bar

The planned top-edge mode works with macOS menu-bar auto-hide. An inset mode leaves the system bar in place. Divot does not recreate other applications' menus or force-hide the system menu bar. Persistent visibility is the goal: Divot should move below the native bar and return to the top edge instead of disappearing. Native-bar visibility detection and fullscreen behavior are still being validated and are not implemented yet.
