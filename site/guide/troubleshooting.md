# Troubleshooting

## I can't find an installer

There isn't one yet. Divot is pre-alpha. [Build the website and core tests](./build) or check the [roadmap](./roadmap).

## The configuration doesn't change my menu bar

The native app reads and validates the versioned config: both sides, per-widget options, layout height/padding/notch gap, the System/Light/Dark variant, and the theme family all apply, and the settings window writes the same file. Theme family colors and custom palettes are resolved to semantic tokens and repaint the bar. There is no packaged release yet, so there is nothing to install; the examples and the browser preview remain design artifacts and do not modify macOS.

## Website build fails on a link

VitePress treats dead internal links as errors. Check the target Markdown filename and path. Run `bun run check` after correcting the source; do not disable dead-link checks.

## Swift tests fail before compiling

Run `swift --version` and verify Xcode 26+ is selected. This foundation targets macOS 26 and tools version 6.2. An older system or toolchain is unsupported for now.

## AeroSpace isn't installed

It is not needed to run the website or geometry tests. The bar runs without it and shows an honest unavailable state for workspaces rather than inventing numbered spaces. When AeroSpace is installed, the adapter detects the documented CLI, reads real workspaces, and draws them in the left panel. yabai follows later. Do not grant Accessibility permission for website previews.

## A theme or side doesn't change anything

Both configurable sides, per-item options, layout, the System/Light/Dark variant, and the theme family are implemented and applied by the native app. Theme family colors and custom palettes are validated, saved, and resolved to the bar's semantic tokens. There is no packaged release, so current examples and the browser preview remain design artifacts.

## Report a problem

When repository hosting is provisioned, include OS, hardware, commit, enabled widgets, display layout, expected behavior, actual behavior, and minimal reproduction. Remove secrets from configurations and captures. Performance reports also need the measurement method.
