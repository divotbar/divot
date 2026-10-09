# Troubleshooting

## I can't find an installer

There isn't one yet. Divot is pre-alpha. [Build the website and core tests](./build) or check the [roadmap](./roadmap).

## The configuration doesn't change my menu bar

The native app exists, but only the `widgets.workspaces` options are applied at launch today (task 0005). Other config sections and the settings surface are not implemented yet, so most examples and the browser preview remain design artifacts. They do not modify macOS.

## Website build fails on a link

VitePress treats dead internal links as errors. Check the target Markdown filename and path. Run `bun run check` after correcting the source; do not disable dead-link checks.

## Swift tests fail before compiling

Run `swift --version` and verify Xcode 26+ is selected. This foundation targets macOS 26 and tools version 6.2. An older system or toolchain is unsupported for now.

## AeroSpace isn't installed

It is not needed to run the website or geometry tests. The bar runs without it and shows an honest unavailable state for workspaces rather than inventing numbered spaces. When AeroSpace is installed, the adapter detects the documented CLI, reads real workspaces, and draws them in the left panel. Do not grant Accessibility permission for website previews.

## yabai isn't detected, or shows the wrong workspaces

yabai is the second adapter, chosen by the same policy as AeroSpace. Divot needs the `yabai` binary on a Homebrew path or your `PATH`, and the yabai service must be running so its message interface answers; without either, the bar reports the honest unavailable state instead of inventing spaces. If both AeroSpace and yabai are installed, AeroSpace is chosen first — set `widgets.workspaces.adapter` to `yabai` (or `DIVOT_WORKSPACES_ADAPTER=yabai`) to force yabai. Divot reads only documented `yabai -m query` output and focuses spaces with `yabai -m space --focus`, neither of which needs the yabai scripting addition or System Integrity Protection changes; yabai itself still needs its Accessibility permission. yabai has no persistent event stream, so the row refreshes at launch and after a click rather than on every keypress. Live yabai behavior has not been physically validated yet; report what you see.

## A theme or side doesn't change anything

Theme families, both configurable sides, and most items are proposed only. The native app reads only `widgets.workspaces` today; the theme and settings surface is not implemented, so current examples and the browser preview are design artifacts.

## Report a problem

When repository hosting is provisioned, include OS, hardware, commit, enabled widgets, display layout, expected behavior, actual behavior, and minimal reproduction. Remove secrets from configurations and captures. Performance reports also need the measurement method.
