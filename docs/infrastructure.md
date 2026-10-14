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
scripts/swift-test-lock.sh    # the same suite, serialized across worktrees (#0091)
swift build --package-path macos --product divot
swift build --package-path macos -c release --product divot
macos/.build/release/divot --bench
scripts/package-app.sh        # assemble + ad-hoc sign the local Divot.app preview
scripts/smoke-app-bundle.sh   # package + verify + launch the bundled executable
scripts/run-packaged.sh       # build + run the real Divot.app (Dev page packaged target)
scripts/run-dev.sh            # run the bare dev binary (Dev page Divot bar target)
repoos check
```

The RepoOS plan declares web configuration validation/static build, native core tests, an app build gate (`native-app`), a local preview package-and-launch gate (`native-app-bundle`), and a dry-run gate for the packaged Dev target (`run-packaged-dry-run`, which exercises `scripts/run-packaged.sh` without launching any UI). `bun run check` also runs `scripts/docs-drift.ts`, which fails a native configuration-source change that does not update `docs/configuration.md` and `site/reference/configuration.md` (`DOCS_DRIFT_ALLOW=1` overrides it when a task records why no docs change applies). Native tests and the app build require macOS with a compatible Swift toolchain. Release/device checks are a separate human gate; CI cannot prove VoiceOver, physical notch behavior, or fullscreen/Spaces behavior. The `divot --bench` harness runs in-process for the deterministic scenarios, but its Release numbers on a stable reference machine are the only performance evidence; see [Performance](performance.md) and the [local preview](local-preview.md).

## Dev targets

`repoos.toml` declares the runnable targets the Dev page starts and stops. Two of
them run a Divot bar and only one may run at a time — two bars stack on screen —
so each stops the other first (matched by exact executable path and stopped by
PID, never by name or pattern). **Divot bar** (`scripts/run-dev.sh`) is the bare
dev binary: no `Info.plist` and no bundle identity, so it cannot hold Location
permission and its Accessibility grant attaches to the host. **Divot bar
(packaged)** (`scripts/run-packaged.sh`) rebuilds `dist/Divot.app` from the
checkout and runs the real bundle with `open`, so it holds Location and
Accessibility like the product and shows the build commit and PID. See the
[local preview](local-preview.md) for the permission differences.

## Tests

Tests run windowless. A `swift test --package-path macos` run must never put a Divot bar, popover, or panel on screen, steal focus, or leave a stray process behind, so the suite is safe to run while the maintainer is at the machine. Every call that makes a Divot window visible goes through the injectable `WindowPresenting` seam (`macos/Sources/DivotAppKit/WindowPresenter.swift`): production uses `SystemWindowPresenter`, and tests inject `RecordingWindowPresenter`, a no-op that records the call so a test can assert "would present" without ordering anything front. Offscreen snapshot renders are unaffected — they render views, not visible windows.

Two guards enforce the rule. The AppKit tests that build windows carry the `.windowless` trait (`WindowlessTestSupport.swift`), which fails a test that leaves any `NSApp.windows` entry visible, and `WindowlessAppKitTests` lists the on-screen windows owned by the test process (`CGWindowListCopyWindowInfo`) before and after exercising the presentation paths. No test activates the app, changes its activation policy, posts a real system notification, or opens System Settings.

Run the suite through `scripts/swift-test-lock.sh` (also `just macos-test` and `bun run test:core`). It takes a lock under the shared repository's `macos/.build` so only one `swift test` runs at a time per machine, letting parallel agent runs queue instead of piling up test processes and spiking the load. The lock is released on exit, breaks a lock left by a dead process, and times out (`DIVOT_SWIFT_TEST_LOCK_WAIT`, default 1800s) rather than blocking forever.

## Continuous integration

Web CI runs on Linux with Bun and uploads the static output. Core CI runs on a macOS runner with Xcode 26 selected. The workflow checks toolchain availability instead of silently skipping. No signing secrets are required for pull-request checks. Update the runner label if GitHub changes image availability.

## Static hosting and deployment

The site builds to `site/.vitepress/dist/` and is deployed to **Cloudflare Workers** (static assets) as the `divot-site` Worker. `wrangler.jsonc` at the repository root declares the pure static-assets config — no Worker script — with `assets.directory` `./site/.vitepress/dist` and `not_found_handling` `404-page`. Cloudflare's git-connected build runs `bun install && bun run build` and deploys the output, so there is no GitHub Actions deploy job: `.github/workflows/site.yml` only builds the site (on pull requests and pushes to `main`) and uploads the static output as a debugging artifact.

Branch convention, matching the RepoOS sites:

| Branch | Environment | Domain |
| --- | --- | --- |
| `main` | dev/staging | `https://main-divot-site.njachowski.workers.dev` |
| `prod` | production | `https://divotbar.app` |

`main` is the working branch and publishes the dev site on every push. `prod` advances **only** by an infrequent, deliberate fast-forward merge of `main` — production never moves on its own. RepoOS's Deployments page renders both rows from the `[[deployments]]` block in `repoos.toml` and can run the push/fast-forward itself.

### One-time setup (maintainer only)

1. **Create a git-connected Worker:**
   - Log in to https://dash.cloudflare.com and go to Workers & Pages → Create → Connect to Git
   - Select this repository. Cloudflare's current flow creates git-connected static sites as Workers driven by `wrangler.jsonc`, not the older "Pages project" direct-upload flow — there is no root-directory/output-directory pair to fill in.
2. **Build settings (Advanced):**
   - **Build command:** `bun install && bun run build`
   - **Deploy command:** leave the default (`npx wrangler deploy`)
   - **Path:** the repository root — `package.json` and `wrangler.jsonc` both live there, so no subdirectory override is needed
   - **Production branch:** `prod`
   - **Builds for non-production branches:** on (so `main` publishes the dev URL)
   - Let Cloudflare auto-create the API token; no manual secret is needed
3. **Add the custom domain:** in the production environment, add `divotbar.app` and follow Cloudflare's DNS steps.
4. **Paste the dashboard URL:** each `[[deployments]]` row in `repoos.toml` has an empty `dashboard_url`; paste the account-specific Worker dashboard link (visible in the dash.cloudflare.com URL) once the Worker exists.

The **first deploy is a human step**: the maintainer verifies it after the Cloudflare setup above. This repository does not claim a working deployment until then. Verify the config locally with `bun run build && bunx wrangler deploy --dry-run` (this needs wrangler; skip it when offline).

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

### RepoOS Releases page

`repoos.toml` opts Divot into RepoOS's Releases surface (#0067): a `[release]`
block with `provider = "git-tag"` tracks annotated `v<version>` tags cut from
`main`, and two `[[distribution]]` rows render the page's "Published to"
summary — **GitHub Releases** (the `Divot.dmg` attached to the release) and
**Homebrew** (`divotbar/tap/divot`, read from the tap cask's `version` line).
RepoOS links to `.github/workflows/release.yml` as context but never runs it;
the workflow is triggered by the tag push, exactly as described above.

RepoOS reads the committed release version from `package.json` (`version`),
because its release provider requires a JSON manifest. The root `VERSION` file
is the separate local-preview version that `scripts/package-app.sh` packages
(see the [local preview](local-preview.md)); the two carry the same number until
the preview becomes a real release. `scripts/release-config.test.ts`, run by
`bun run check`, requires a semver `package.json` version and, while both files
hold a `-preview.N` version, that they agree; after a real release `package.json`
may move ahead of `VERSION`. Cut releases through RepoOS rather than pushing
a tag by hand: RepoOS writes the version into `package.json` and pushes the
matching `v<version>` tag, so the manifest and the tag agree — a hand-pushed tag
that disagrees would confuse the release view. The release and distribution keys
are set in `repoos.toml` — there is no RepoOS Settings-window control for them,
so the Settings page is not a place to edit them. The `[[deployments]]` rows
(#0068) instead cover hosting: **Site (dev)** on `main` and **Site (prod)** on
`prod`, both `cloudflare-workers`, with `subdir = "site"` scoping RepoOS's
freshness lookup to the site's source and `dashboard_url` left blank for the
maintainer to paste; see [Static hosting and
deployment](#static-hosting-and-deployment). Like the Releases surface, this is
maintainer-facing infrastructure, so no `site/` page changes: the public site
documents the product, not the pipeline. No tag or release exists yet, so the
Releases page shows its empty state. Whether a nav entry renders is verified by
RepoOS when the server loads `repoos.toml`; `bun run check` only validates the
config shape.

### Public install guide

The user-facing install instructions live in `site/guide/install.md`: the
download link, the checksum note, the first-launch steps for the unsigned
build, the Accessibility and Location permission setup, the Homebrew command,
and the pointer to `site/guide/ai-setup.md`. The page is gated by one constant,
`FIRST_RELEASE_PUBLISHED` in `site/.vitepress/release.ts`. While it is `false`,
the page states plainly that the first release is not published and renders no
download button, version, or checksum. When the first release is actually
published, flip that one line to `true`; the page then renders the button
pointed at the stable `https://github.com/divotbar/divot/releases/latest` URL,
so no version or asset name is ever hard-coded. The guide makes no notarization
claim and labels signed distribution as planned.

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

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. The local preview recipes are `just app-package` (assemble + ad-hoc sign `dist/Divot.app` and the versioned archive), `just app-smoke` (package + verify + launch), `just app-run` (build and open the app), `just app-run-packaged` (the Dev page's packaged target: rebuild, stop the other bar, and run the real bundle), and `just app-dev` (the bare dev binary). `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
