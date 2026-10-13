# List the documented project commands.
default:
    @just --list

# Install the locked website dependencies.
[group('setup')]
install:
    bun install --frozen-lockfile

# Show toolchain versions; native builds need macOS and Xcode 26+.
[group('setup')]
doctor:
    bun --version
    just --version
    xcodebuild -version
    swift --version

# Run the landing page and docs with hot reload (one Vue/VitePress site).
[group('dev')]
dev:
    bun run dev

# Serve the generated static site locally.
[group('dev')]
preview:
    bun run preview

# Build the static landing page and documentation.
[group('build')]
build:
    bun run build

# Build the Swift library foundation.
[group('build')]
macos-build:
    swift build --package-path macos

# Build the executable app shell (debug executable, not a packaged bundle).
[group('build')]
macos-app:
    swift build --package-path macos --product divot

# Assemble the ad-hoc-signed local Divot.app preview (Release by default).
[group('app')]
app-package:
    scripts/package-app.sh

# Package and verify the local preview: structure, signature, and a real launch.
[group('app')]
app-smoke:
    scripts/smoke-app-bundle.sh

# Build the preview bundle and open it as a real app on this Mac.
[group('app')]
app-run:
    scripts/package-app.sh
    open dist/Divot.app

# Run the declared RepoOS gate.
[group('quality')]
check:
    repoos check

# Validate proposed configurations and build all static pages.
[group('quality')]
web-check:
    bun run check

# Run the Swift core tests (one run at a time per machine; see #0091).
[group('quality')]
macos-test:
    scripts/swift-test-lock.sh

# Build the optimized Release app and run the performance harness.
[group('quality')]
bench:
    swift build --package-path macos -c release --product divot
    macos/.build/release/divot --bench

# Validate the justfile without executing recipes.
[group('quality')]
just-check:
    just --fmt --check

# Print the RepoOS task board.
[group('repoos')]
list:
    repoos list

# Start the RepoOS control plane in the foreground (human-operated).
[group('repoos')]
serve:
    repoos serve

# Show live engineers/reviewers before editing a task worktree.
[group('repoos')]
agents:
    repoos agents

# Request synchronous handoff through the server; never just change status.
[group('repoos')]
review id:
    repoos review {{ quote(id) }}

# Run close-out only after human approval.
[group('repoos')]
done id:
    repoos done {{ quote(id) }}

# Inspect the checkout without staging or committing unrelated files.
[group('repoos')]
git-status:
    git status --short
