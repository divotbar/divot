# Build from source

The repository contains a working website and a Swift library foundation. It does not yet contain an executable native app target.

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
```

This builds `DivotCore` and tests its notch-aware geometry. It does not launch a bar. The AppKit app target, configuration loader, and providers are still planned.

## Repository hosting

The public hosting URL is not provisioned in this starter. Work from the local checkout or the maintainer-provided source URL. No guessed `git clone` URL or install command is supplied.
