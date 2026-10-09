# Infrastructure and delivery

## Repository

| Path | Responsibility |
| --- | --- |
| `macos/` | Swift package: pure core, `DivotAppKit` platform adapter, `divot` app shell, and the menu-bar probe |
| `site/` | Landing page, public guides, reference, contributor docs |
| `docs/` | Product/engineering requirements and ADRs |
| `examples/` | Proposed versioned configuration examples |
| `scripts/` | Local configuration checks |
| `work/` | RepoOS task records; CLI/API writes only |
| `.github/workflows/` | CI templates, active when hosted on GitHub |

MIT licensed. The hosting repository URL, bundle identifier, Apple developer team, signing credentials, and public domain are not provisioned. Do not invent them or silently use a contributor's identity.

## Toolchain

Bun for web dependencies/scripts; pin dependencies in `bun.lock`. VitePress generates a static site and fails on dead internal links. Swift Package Manager provides a dependency-free core plus an executable app shell (`divot`) and the `divot-menu-bar-probe` diagnostic; Xcode 26+ will own the later signed `.app` bundle. macOS 26+ / Apple silicon is the initial product target. Swift package tools minimum: 6.2.

## Local commands

```sh
bun install --frozen-lockfile
bun run check
swift test --package-path macos
swift build --package-path macos --product divot
repoos check
```

The RepoOS plan declares web configuration validation/static build, native core tests, and an app build gate (`native-app`). Native tests and the app build require macOS with a compatible Swift toolchain. Release/device checks are a separate human gate; CI cannot prove VoiceOver, physical notch behavior, or fullscreen/Spaces behavior.

## Continuous integration

Web CI runs on Linux with Bun and uploads the static output. Core CI runs on a macOS runner with Xcode 26 selected. The workflow checks toolchain availability instead of silently skipping. No signing secrets are required for pull-request checks. Update the runner label if GitHub changes image availability.

## Static hosting

Deploy only `site/.vitepress/dist/` after a successful build. A root domain needs no base override; a subpath deployment must set VitePress `base` and test all asset/deep-link URLs. Choose the public URL before adding canonical tags, sitemap, repository links, or social share images. No deployment has been created by this starter. Repository source and deployment remain separate; publishing needs maintainer approval.

## Native distribution (planned)

Developer ID signed and notarized universal or arm64 app (arm64 first); hardened runtime; staple notarization proof; versioned archive and checksums. Keep signing credentials in the CI secret store/keychain. Do not distribute instructions to remove quarantine. Start with direct downloadable releases; evaluate a signed update mechanism after the first stable release. Mac App Store/sandbox support is not promised: CLI integration and future scripts require a deliberate entitlement/distribution assessment.

## Security/privacy

No telemetry by default. Native built-ins collect locally. Weather/network integrations, if added, disclose outbound requests and need opt-in configuration. Request Accessibility permission only for capabilities requiring it. Script providers are trusted local code with access to the user's privileges; a timeout is resource protection, not sandbox isolation.

## Just recipes

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
