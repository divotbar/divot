# Divot Tap

Homebrew cask for [Divot](https://divotbar.app), a native macOS bar for
workspaces and status.

## Install

```sh
brew install --cask divotbar/tap/divot
```

Or tap first, then install:

```sh
brew tap divotbar/tap
brew install --cask divot
```

Or in a `Brewfile`:

```ruby
tap "divotbar/tap"
cask "divot"
```

## How this tap stays current

The cask is generated from the GitHub Release for each Divot version. The
Divot repository's release workflow dispatches a `divot-release`
`repository_dispatch` event with the version and the source repository; the
workflow in `.github/workflows/divot-release.yml` reads the DMG download URL
and SHA-256 from the release assets and commits the updated
`Casks/divot.rb`. Nothing about a release is hard-coded here, and the cask in
this repository carries placeholders until the first release.

Divot releases are currently unsigned. On first launch, right-click the app in
Applications and choose **Open**, then confirm. See
[divotbar.app](https://divotbar.app/) for the current instructions.

## Maintenance

`brew style --cask`, `brew audit --cask`, and `brew bump --casks` run in CI
(`.github/workflows/tests.yml` and `.github/workflows/autobump.yml`). The
one-time setup for the maintainer is documented in the Divot repository's
`docs/infrastructure.md`.
