# Meet Divot

A quieter edge for your Mac. Divot is an open-source native macOS bar built around a simple idea: workspaces and the active app live left of the camera notch; everyday status lives right of it.

::: warning Pre-alpha
There is no downloadable native app yet. The website, requirements, configuration examples, and the Swift foundation — including a buildable AppKit shell, its display coordinator, the built-in status providers, the AeroSpace/yabai workspace adapters, the versioned configuration with settings, and the theme families — are available. The shell and providers are not physically validated and there is no signed bundle. The preview below is a browser concept, not the running macOS app.
:::

<BarPreview />

## What we're building

A Swift/AppKit application for macOS 26+ on Apple silicon. A polished default — workspaces and the active app left of the camera, battery, clock, network, and volume to the right — and both sides are configurable. A native theme plus four families pair with light and dark. AeroSpace and yabai are both supported, and the bar stays useful without a window manager. Local configuration and event-driven updates throughout.

## Explore

- [Build the foundation from source](./build).
- [Understand workspaces and displays](./workspaces).
- [Try customization](./customization).
- [Read the configuration proposal](../reference/configuration).
- [Help implement the native app](../contributing/).

## Availability

No Homebrew formula, installer, or signed release exists today. Installation instructions will appear here after the app passes device, accessibility, signing, and performance gates. Until then you can build the static website and run the native core tests.
