---
id: "0043"
title: Add a Homebrew cask so users can install Divot with brew
type: feature
status: review
priority: p2
area: [macos, docs]
depends_on: ["0041"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/add-a-homebrew-cask-so-users-can-install
created_at: "2026-10-11T12:47:11Z"
updated_at: "2026-10-12T13:16:12Z"
---
## Problem

Users who prefer Homebrew have no install command. The maintainer wants a cask that installs the released DMG.

## Desired UX
- `brew install --cask divotbar/tap/divot` (or the final tap name) installs the latest released Divot.app.
- Same approach as RepoOS: a separate tap repo owns the cask and updates itself; the release workflow only dispatches an event to the tap after the GitHub Release exists.

## Acceptance criteria
- Prepare the tap contents in a new directory packaging/homebrew-tap/ in this repo (to be pushed by the maintainer as divotbar/homebrew-tap): Casks/divot.rb, README.md, and .github/workflows/ that updates the cask on a repository_dispatch from this repo (modelled on ~/code/nick/homebrew-tap: autobump/repoos-release/tests workflows). The updater reads the version, DMG URL and SHA-256 from the GitHub Release assets (the DMG and checksum from #0041); it never hard-codes values.
- Add a 'Request Homebrew tap update' step to .github/workflows/release.yml, modelled on ~/code/nick/repoos/.github/workflows/release.yml (repository_dispatch to the tap, skipped with a clear message when the secret is missing).
- No invented version or checksum: the cask in the repo uses placeholders clearly marked until the first release; no notarization claims (unsigned build, #0044 is separate).
- Verify with brew style / brew audit --cask where possible, and shellcheck or actionlint on the workflows if available.
- Document the install command and the one-time maintainer setup (create divotbar/homebrew-tap, add the dispatch token secret) in docs/infrastructure.md; the install page copy stays with #0042.
- repoos check passes.

## Notes for AI
Reference: ~/code/nick/homebrew-tap (repo-os/homebrew-tap) and repoos's release.yml lines ~86-125. Do not create GitHub repos, push, tag or set secrets: those are maintainer actions. No release exists yet, so everything must work from release data at dispatch time. Leave the first-release verification as a human step.

## Activity

- 2026-10-11T12:47:11Z · created · njachowski@gmail.com
- 2026-10-12T11:38:53Z · status inbox→ready
- 2026-10-12T13:01:45Z · body: section Desired UX
- 2026-10-12T13:01:45Z · body: section Acceptance criteria
- 2026-10-12T13:01:46Z · body: section Notes for AI
- 2026-10-12T13:01:46Z · status ready→active, branch
- 2026-10-12T13:16:11Z · status active→review
- 2026-10-12T13:16:12Z · note: shots: skipped — the diff (9 changed paths) touches no [[preview.paths]] globs — no UI change to capture
