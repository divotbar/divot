---
id: "0067"
title: Enable the Releases page in repoos.toml (release block and distribution rows)
type: chore
status: review
priority: p1
area: infra
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/enable-the-releases-page-in-repoos-toml-
created_at: "2026-10-12T14:36:53Z"
updated_at: "2026-10-12T16:10:31Z"
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
- 2026-10-12T14:42:59Z · status active→review
- 2026-10-12T16:08:51Z · status review→active
- 2026-10-12T16:10:31Z · status active→review
