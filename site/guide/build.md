# Build from source

The repository contains a working website and a Swift foundation: the pure `DivotCore` library and a buildable AppKit app shell (`divot`). You can package a local, ad-hoc-signed preview `.app` from this checkout; there is still no signed or notarized public release.

## Website

Install Bun, then run from the repository root:

```sh
bun install --frozen-lockfile
bun run dev
```

Open the local URL printed by VitePress. To check configuration examples and generate the static site:

```sh
bun run check
bun run preview
```

The static output is `site/.vitepress/dist/`. It can be served by a static host without a backend. All photography and icons are local; search runs in the browser.

## Native foundation

Use a Mac with macOS 26+ and Xcode 26+ / Swift 6.2+. Select the compatible Xcode developer directory if multiple versions are installed.

```sh
swift --version
swift test --package-path macos
swift build --package-path macos --product divot
```

This builds `DivotCore` and `DivotAppKit`, tests the notch-aware geometry, the placement state machine, and the provider pipeline, and builds the executable app shell. The built-in status providers (clock, battery/power, network, volume, and frontmost app) are wired and unit-tested, but they are not physically validated. `macos/.build/debug/divot --report` prints one honest display/menu-bar observation pass without moving any panel, and `macos/.build/debug/divot --widgets` prints live built-in provider values for a short window. The AeroSpace and yabai workspace adapters are implemented and fixture-tested but not physically validated; the versioned configuration and settings window are implemented, and the four theme families are implemented.

## Package a local preview

Build an actual `Divot.app` bundle for this Mac with [just](https://github.com/casey/just) (or run the scripts directly):

```sh
just app-package   # build (Release), assemble and ad-hoc sign dist/Divot.app, write the archive
just app-smoke     # package + verify structure, signature, checksum, and launch
just app-run       # build and open the bundle
```

The result is a **local preview**, not a downloadable release: it is signed ad-hoc (`codesign --sign -`), not Developer ID signed, and not notarized. `dist/` receives `Divot.app` plus a versioned archive, a SHA-256 checksum, and a manifest recording the build commit. The bundle does not install anything system-wide or change any security setting. The notched-display menu-bar detector may ask for Accessibility permission and degrades honestly without it. A person still has to check on-screen appearance, VoiceOver, fullscreen/Spaces, and performance on real hardware.

## Repository hosting

The public hosting URL is not provisioned in this starter. Work from the local checkout or the maintainer-provided source URL. No guessed `git clone` URL or install command is supplied.
