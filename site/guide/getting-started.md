# Meet Divot

A quieter edge for your Mac. Divot is an open-source native macOS bar built around a simple idea: workspaces and the active app live left of the camera notch; everyday status lives right of it.

::: warning Pre-alpha
There is no published download and no signed/notarized release yet. The [install guide](./install) states that plainly and explains what the first unsigned release will require; today you can [build and run a local, ad-hoc-signed preview](./build) from the source. The website, requirements, configuration examples, and the Swift foundation — including a buildable AppKit shell, its display coordinator, the built-in status providers, the AeroSpace/yabai workspace adapters, the versioned configuration with settings, and the theme families — are available. The shell and providers are not physically validated. The preview below is a browser concept, not the running macOS app.
:::

<BarPreview />

## What we're building

A Swift/AppKit application for macOS 26+ on Apple silicon. A polished default — workspaces and the active app left of the camera, battery, time, network, and volume to the right — and both sides are configurable. A native default, its own Alpine family, and four curated families pair with light and dark. AeroSpace and yabai are both supported, and the bar stays useful without a window manager. Local configuration and event-driven updates throughout.

## Explore

- [Build the foundation from source](./build).
- [Understand workspaces and displays](./workspaces).
- [Try customization](./customization).
- [Read the configuration proposal](../reference/configuration).
- [Help implement the native app](../contributing/).

## Running it locally

There is no published download yet, so today the app runs from source as a local, ad-hoc-signed preview. Two ways to run it behave differently: the bare development binary (`swift run --package-path macos divot`) has no bundle identity, so macOS will not grant it Location and its Accessibility grant attaches to your terminal; the packaged `Divot.app` is the real bundle and is the one that gets the Location prompt and holds Accessibility as Divot. Use the packaged build for anything permission-related — `just app-run-packaged`, or the Dev page's **Divot bar (packaged)** target. Only one bar runs at a time, and the [build guide](./build) has the commands. See [Troubleshooting](./troubleshooting) for the permission details.

## Availability

The first public release is not published yet, so there is no DMG or signed app to install today. The [install guide](./install) shows the current state, the local-preview path that works now, and the exact first-launch, permission, checksum, and Homebrew steps the first unsigned release will use. The Homebrew cask is prepared but only installs once a release exists. Signed and notarized distribution remains planned.
