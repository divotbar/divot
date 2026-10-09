# Build from source

The repository contains a working website and a Swift foundation: the pure `DivotCore` library and a buildable AppKit app shell (`divot`). There is no signed `.app` bundle or downloadable release yet.

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

This builds `DivotCore` and `DivotAppKit`, tests the notch-aware geometry, the placement state machine, and the provider pipeline, and builds the executable app shell. The built-in status providers (clock, battery/power, network, volume, and frontmost app) are wired and unit-tested, but they are not physically validated. `macos/.build/debug/divot --report` prints one honest display/menu-bar observation pass without moving any panel, and `macos/.build/debug/divot --widgets` prints live built-in provider values for a short window. The AeroSpace and yabai workspace adapters are implemented and fixture-tested but not physically validated; the configuration loader and themes are still planned, and there is no signed app bundle.

## Repository hosting

The public hosting URL is not provisioned in this starter. Work from the local checkout or the maintainer-provided source URL. No guessed `git clone` URL or install command is supplied.
