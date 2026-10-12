---
id: "0067"
title: Enable the Releases page in repoos.toml (release block and distribution rows)
type: chore
status: active
priority: p1
area: infra
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/enable-the-releases-page-in-repoos-toml-
created_at: "2026-10-12T14:36:53Z"
updated_at: "2026-10-12T15:33:25Z"
review_rounds: 1
review_passes: 1
---
## Problem
Divot's repoos.toml has no [release] block and no [[distribution]] rows, so RepoOS shows no Releases page for this project.

## Desired UX
- The Releases page appears and tracks git-tag releases for divotbar/divot, with a 'Published to' section listing GitHub Releases and Homebrew.

## Acceptance criteria
- Add [release] (enabled, provider git-tag, branch main, tagPrefix v, remote origin, repository divotbar/divot, workflow .github/workflows/release.yml, versionFile = the file that holds Divot's version: check package.json and macos/ and use the real one, and say which in the task).
- Add [[distribution]] rows modelled on ~/code/nick/repoos/repoos.toml: 'GitHub Releases' (kind github-release, repository divotbar/divot, url with {tag}) with the install note to download Divot.dmg, and 'Homebrew' (kind homebrew, package divotbar/tap/divot, url https://github.com/divotbar/homebrew-tap/blob/main/Casks/divot.rb, versionUrl the raw URL of that file, and a versionRegex that reads the cask's version line; install brew install --cask divotbar/tap/divot).
- Do NOT add any [[deployments]] rows: those need Cloudflare values the maintainer has not supplied yet (a separate task).
- If a Settings UI control exists for these keys, confirm they show; add docs/infrastructure.md notes.
- Verify the Releases page renders (nav entry appears) via the existing check or server probe; repoos check passes.

## Notes for AI
Reference ~/code/nick/repoos/repoos.toml lines ~398-450 and docs/releases.md. No release or tag exists yet, so the page may show an empty state; that is expected. Edit on the task branch only.

## Activity

- 2026-10-12T14:36:53Z · created · njachowski@gmail.com
- 2026-10-12T14:36:55Z · status inbox→ready
- 2026-10-12T14:36:56Z · status ready→active, branch
- 2026-10-12T14:42:10Z · note: versionFile decision: Divot's committed version is the root VERSION file (plain text, currently 0.1.0-preview.1); package.json had no version and neither does macos/. RepoOS's release provider reads versionFile as JSON and requires a .version property (installed repoos v0.5.70). To make the Releases page functional, added "version": "0.1.0-preview.1" to package.json and set versionFile = "package.json"; VERSION remains the separate local-preview version scripts/package-app.sh packages. Relationship documented in docs/infrastructure.md. No RepoOS Settings control exists for the release/distribution keys, and no [[deployments]] rows were added.
- 2026-10-12T14:42:59Z · status active→review
- 2026-10-12T14:43:00Z · note: shots: skipped — the diff (4 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T15:05:39Z · note: review pass 1: failed — no usable report
- 2026-10-12T15:05:39Z · needs_input
- 2026-10-12T15:26:55Z · needs_input
- 2026-10-12T15:26:55Z · status review→active
- 2026-10-12T15:26:55Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-12T15:29:58Z · status active→review
- 2026-10-12T15:29:58Z · note: shots: skipped — the diff (4 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T15:33:25Z · note: review pass 2: needs some work
- 2026-10-12T15:33:25Z · status review→active
