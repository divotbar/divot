# Meet Divot

A quieter edge for your Mac. Divot is an open-source native macOS bar built around a simple idea: workspaces live left of the camera notch; everyday status lives right of it.

::: warning Pre-alpha
There is no downloadable native app yet. The website, requirements, configuration examples, and Swift geometry library are available. App panels and providers are the next milestone. The preview below is a browser concept, not the running macOS app.
:::

<BarPreview />

## What we're building

A Swift/AppKit application for macOS 26+ on Apple silicon. A purposeful default layout, native interaction, local configuration, and event-driven updates. AeroSpace integration is planned first; the bar will remain useful without a window manager.

## Explore

- [Build the foundation from source](./build).
- [Understand workspaces and displays](./workspaces).
- [Try customization](./customization).
- [Read the configuration proposal](../reference/configuration).
- [Help implement the native app](../contributing/).

## Availability

No Homebrew formula, installer, or signed release exists today. Installation instructions will appear here after the app passes device, accessibility, signing, and performance gates. Until then you can build the static website and run the native core tests.
