# Infrastructure and delivery

## Repository

| Path | Responsibility |
| --- | --- |
| `macos/` | Swift package: pure core, `DivotAppKit` platform adapter, `divot` app shell, and the menu-bar probe |
| `site/` | Landing page, public guides, reference, contributor docs |
| `docs/` | Product/engineering requirements and ADRs |
| `examples/` | Proposed versioned configuration examples |
| `scripts/` | Local configuration and docs-drift checks |
| `packaging/` | Homebrew tap contents under `packaging/homebrew-tap/`, pushed to `divotbar/homebrew-tap` |
| `work/` | RepoOS task records; CLI/API writes only |
| `.github/workflows/` | CI templates, active when hosted on GitHub |

MIT licensed. Public domain: https://divotbar.app. The hosting repository URL, bundle identifier, and Apple developer team are not provisioned. Do not invent them or silently use a contributor's identity.

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

The RepoOS plan declares web configuration validation/static build, native core tests, an app build gate (`native-app`), and a local preview package-and-launch gate (`native-app-bundle`). `bun run check` also runs `scripts/docs-drift.ts`, which fails a native configuration-source change that does not update `docs/configuration.md` and `site/reference/configuration.md` (`DOCS_DRIFT_ALLOW=1` overrides it when a task records why no docs change applies). Native tests and the app build require macOS with a compatible Swift toolchain. Release/device checks are a separate human gate; CI cannot prove VoiceOver, physical notch behavior, or fullscreen/Spaces behavior. The `divot --bench` harness runs in-process for the deterministic scenarios, but its Release numbers on a stable reference machine are the only performance evidence; see [Performance](performance.md) and the [local preview](local-preview.md).

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
- Per-page canonical URLs are generated to `https://divotbar.app` in the HTML head via `transformHead`
- Sitemap hostname is set to `https://divotbar.app` for absolute URLs in `sitemap.xml`

## Native distribution

### Release builds and artifacts

Pushing a version tag (e.g., `v0.1.0`) triggers `.github/workflows/release.yml`, which:

1. Checks out the tag
2. Builds Divot in Release configuration using Swift Package Manager
3. Packages it as `dist/Divot.app` using `scripts/package-app.sh`
4. Creates `dist/Divot.dmg` using `scripts/make-dmg.sh` with a drag-to-Applications layout
5. Generates `dist/Divot.dmg.sha256` for checksum verification
6. Creates a GitHub Release with both files and release notes explaining that the build is unsigned
7. Dispatches a `divot-release` event to the Homebrew tap so its cask updates from the release assets

The workflow runs on `macos-26` (Apple silicon) in GitHub Actions.

### Homebrew cask

Users install the released DMG with Homebrew:

```sh
brew install --cask divotbar/tap/divot
```

The tap lives in its own repository (`divotbar/homebrew-tap`). Its contents are
prepared here under `packaging/homebrew-tap/` so they are versioned with the
app, and the maintainer pushes them to the tap repository:

| Path | Responsibility |
| --- | --- |
| `packaging/homebrew-tap/Casks/divot.rb` | The cask; placeholders until the first release |
| `packaging/homebrew-tap/.github/workflows/divot-release.yml` | Updates the cask from a `divot-release` dispatch |
| `packaging/homebrew-tap/.github/workflows/tests.yml` | Style and audit the cask on every change |
| `packaging/homebrew-tap/.github/workflows/autobump.yml` | Daily fallback bump via `brew bump --casks` |
| `packaging/homebrew-tap/README.md` | Install and tap-maintenance notes |

After the release job creates the GitHub Release, `release.yml` dispatches a
`divot-release` event to the tap (with the version and the source repository)
when the `HOMEBREW_TAP_TOKEN` secret exists, and skips with a clear message
when it does not. The tap workflow reads the version, DMG download URL, and
SHA-256 from the release assets and commits the updated `Casks/divot.rb`;
nothing about a release is hard-coded in the cask. The cask matches the
unsigned build and its caveats tell users to right-click and Open on first
launch. It makes no notarization claim; signed distribution is a separate,
planned task.

#### One-time setup (maintainer only)

1. Create the GitHub repository `divotbar/homebrew-tap`.
2. Push the contents of `packaging/homebrew-tap/` as the repository root
   (`Casks/`, `README.md`, and `.github/`).
3. Create a token that can dispatch to the tap repository: a fine-grained
   personal access token scoped to `divotbar/homebrew-tap` with
   **Contents: Read and write**, or a classic personal access token with the
   `repo` scope.
4. Add the token as the `HOMEBREW_TAP_TOKEN` secret in the Divot repository
   (Settings → Secrets and variables → Actions). Without it, the release
   workflow skips the dispatch and the cask does not update.
5. After the first release, confirm the tap workflow committed the updated
   cask and that `brew install --cask divotbar/tap/divot` installs
   `Divot.app`. That first-release check is a human step: no release exists
   yet, so the cask carries clearly marked placeholders until then.

### Unsigned builds (current)

Current releases are **unsigned**: ad-hoc signed only, not Developer ID signed or notarized. Users must right-click the Divot app and select "Open" once to bypass Gatekeeper. The release notes include these instructions.

To test locally:
```sh
./scripts/package-app.sh --configuration release    # assemble Divot.app
./scripts/make-dmg.sh                               # create Divot.dmg
hdiutil attach dist/Divot.dmg                       # mount the DMG
open /Volumes/Divot/Divot.app                       # launch the app
```

The DMG includes a symlink to `/Applications` for drag-and-drop installation.

### Signed distribution (planned)

Developer ID signed and notarized universal or arm64 app (arm64 first) is planned as a separate task. Keep signing credentials in the CI secret store/keychain. Do not distribute instructions to remove quarantine. Start with direct downloadable releases; evaluate a signed update mechanism after the first stable release. Mac App Store/sandbox support is not promised: CLI integration and future scripts require a deliberate entitlement/distribution assessment.

### Local preview

A **local, ad-hoc-signed** preview bundle is produced by `scripts/package-app.sh` for the maintainer's Mac; it is explicitly not the public release. See the [local preview](local-preview.md).

## Security/privacy

No telemetry by default. Native built-ins collect locally. Weather/network integrations, if added, disclose outbound requests and need opt-in configuration. Request Accessibility permission only for capabilities requiring it. Script providers are trusted local code with access to the user's privileges; a timeout is resource protection, not sandbox isolation.

## Just recipes

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. The local preview recipes are `just app-package` (assemble + ad-hoc sign `dist/Divot.app` and the versioned archive), `just app-smoke` (package + verify + launch), and `just app-run` (build and open the app). `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
