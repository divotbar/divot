# Troubleshooting

## I can't find an installer

There isn't one yet. Divot is pre-alpha. [Build the website and core tests](./build) or check the [roadmap](./roadmap).

## The configuration doesn't change my menu bar

The native app/parser has not been implemented. Current examples and the browser preview are design artifacts. They do not modify macOS.

## Website build fails on a link

VitePress treats dead internal links as errors. Check the target Markdown filename and path. Run `bun run check` after correcting the source; do not disable dead-link checks.

## Swift tests fail before compiling

Run `swift --version` and verify Xcode 26+ is selected. This foundation targets macOS 26 and tools version 6.2. An older system or toolchain is unsupported for now.

## AeroSpace isn't installed

It is not needed to run the website or geometry tests. The bar runs without it and shows an honest unavailable state for workspaces rather than inventing numbered spaces. When AeroSpace is installed, the adapter detects the documented CLI and reads real workspaces; the visible indicator row is not implemented yet. yabai follows later. Do not grant Accessibility permission for website previews.

## A theme or side doesn't change anything

Theme families, both configurable sides, and every item are proposed only. The native parser and settings are not implemented, so current examples and the browser preview are design artifacts.

## Report a problem

When repository hosting is provisioned, include OS, hardware, commit, enabled widgets, display layout, expected behavior, actual behavior, and minimal reproduction. Remove secrets from configurations and captures. Performance reports also need the measurement method.
