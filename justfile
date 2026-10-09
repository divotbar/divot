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

# Build the executable app shell (no signed .app bundle yet).
[group('build')]
macos-app:
    swift build --package-path macos --product divot

# Run the declared RepoOS gate.
[group('quality')]
check:
    repoos check

# Validate proposed configurations and build all static pages.
[group('quality')]
web-check:
    bun run check

# Run the Swift core tests.
[group('quality')]
macos-test:
    swift test --package-path macos

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
