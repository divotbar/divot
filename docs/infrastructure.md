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
swift build --package-path macos -c release --product divot
macos/.build/release/divot --bench
scripts/package-app.sh        # assemble + ad-hoc sign the local Divot.app preview
scripts/smoke-app-bundle.sh   # package + verify + launch the bundled executable
repoos check
```

The RepoOS plan declares web configuration validation/static build, native core tests, an app build gate (`native-app`), and a local preview package-and-launch gate (`native-app-bundle`). Native tests and the app build require macOS with a compatible Swift toolchain. Release/device checks are a separate human gate; CI cannot prove VoiceOver, physical notch behavior, or fullscreen/Spaces behavior. The `divot --bench` harness runs in-process for the deterministic scenarios, but its Release numbers on a stable reference machine are the only performance evidence; see [Performance](performance.md) and the [local preview](local-preview.md).

## Continuous integration

Web CI runs on Linux with Bun and uploads the static output. Core CI runs on a macOS runner with Xcode 26 selected. The workflow checks toolchain availability instead of silently skipping. No signing secrets are required for pull-request checks. Update the runner label if GitHub changes image availability.

## Static hosting and deployment

The site builds to `site/.vitepress/dist/` and deploys to Cloudflare Pages at https://divotbar.app via GitHub Actions. The workflow (`.github/workflows/site.yml`) runs on pushes to main and can be triggered manually. Pull requests trigger a dry-run build without deployment.

### One-time setup (maintainer only)

1. **Create a Cloudflare Pages project:**
   - Log in to https://dash.cloudflare.com
   - Go to Workers & Pages
   - Create a new Pages project named `divotbar`
   - Select "Direct upload" and upload the built `site/.vitepress/dist/` directory once to initialize the project

2. **Add the custom domain:**
   - In the Pages project settings, add the custom domain `divotbar.app`
   - Follow Cloudflare's DNS configuration steps (or update the nameservers if the domain's registrar is Cloudflare)

3. **Create GitHub secrets:**
   - Go to the repository Settings → Secrets and variables → Actions
   - Add `CLOUDFLARE_ACCOUNT_ID`: your Cloudflare account ID (visible in the dash.cloudflare.com URL or account settings)
   - Add `CLOUDFLARE_API_TOKEN`: a scoped API token with Cloudflare Pages access
     - Create at https://dash.cloudflare.com/profile/api-tokens
     - Use the "Edit Cloudflare Workers" template or create a custom token with `Pages:Edit` permission
   - The workflow will skip deploy with a clear message if these secrets are missing

4. **Verify the deployment:**
   - After the first push to main, the workflow will deploy to https://divotbar.app
   - Check the Actions tab to monitor the build and deploy job

### Configuration

- VitePress `base` is set to `/` (root domain, no subpath)
- Canonical URLs are set to `https://divotbar.app` in the HTML head
- Sitemap generation and social share images use the canonical domain

## Native distribution (planned)

Developer ID signed and notarized universal or arm64 app (arm64 first); hardened runtime; staple notarization proof; versioned archive and checksums. Keep signing credentials in the CI secret store/keychain. Do not distribute instructions to remove quarantine. Start with direct downloadable releases; evaluate a signed update mechanism after the first stable release. Mac App Store/sandbox support is not promised: CLI integration and future scripts require a deliberate entitlement/distribution assessment. A **local, ad-hoc-signed** preview bundle is now produced by `scripts/package-app.sh` for the maintainer's Mac; it is explicitly not the public release. See the [local preview](local-preview.md).

## Security/privacy

No telemetry by default. Native built-ins collect locally. Weather/network integrations, if added, disclose outbound requests and need opt-in configuration. Request Accessibility permission only for capabilities requiring it. Script providers are trusted local code with access to the user's privileges; a timeout is resource protection, not sandbox isolation.

## Just recipes

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. The local preview recipes are `just app-package` (assemble + ad-hoc sign `dist/Divot.app` and the versioned archive), `just app-smoke` (package + verify + launch), and `just app-run` (build and open the app). `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
