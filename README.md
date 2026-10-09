# Divot

A quieter edge for your Mac. An open-source, performance-first status bar designed around the camera notch: workspaces and the active app on the left, everyday status on the right.

**Status: foundation / pre-alpha.** This repository contains the product and engineering specifications, a working static landing/docs site, a validated versioned configuration contract, and a tested Swift layout core. The native application is not yet implemented; there is no installable release or measured performance claim.

## Run the website

```sh
bun install
bun run dev
# Production static output:
bun run check
```

VitePress prints the local URL. Built HTML lives in `site/.vitepress/dist/`; deploy that directory to any static host. No web server, account, analytics, or cloud service is required at runtime.

## Run the native foundation

Requires macOS 26+ and a Swift 6.2+ toolchain (Xcode 26+).

```sh
swift test --package-path macos
```

`macos/` is a library foundation, not an app bundle. AppKit panels, system providers, and AeroSpace integration are scheduled next. See [roadmap](docs/roadmap.md).

## Start here

- [Product requirements](docs/product-requirements.md)
- [Architecture](docs/architecture.md) and [infrastructure](docs/infrastructure.md)
- [Performance acceptance](docs/performance.md)
- [Contributor guide](CONTRIBUTING.md)
- [Public documentation](site/guide/getting-started.md)

## RepoOS

Initialized with `repoos init --new`; `work/` is the board, `docs/` is engineering context. Use RepoOS commands for task writes. Starter tasks remain in inbox; this bootstrap does not start agents, approve tasks, or publish releases.

## License

MIT. No code has been copied from SketchyBar or a-bar. Repository hosting URL and signing identity are intentionally unset until the maintainer provisions them.

## Just recipes

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
