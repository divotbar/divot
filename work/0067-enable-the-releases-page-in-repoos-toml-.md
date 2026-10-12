---
id: "0067"
title: Enable the Releases page in repoos.toml (release block and distribution rows)
type: chore
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: infra
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/enable-the-releases-page-in-repoos-toml-
created_at: "2026-10-12T14:36:53Z"
updated_at: "2026-10-12T16:07:20Z"
check_retry_count: 1
last_check_failure: "repoos check at 2026-10-12T16:06:47.982Z: repoos check failed: ◆ Check plan"
review_rounds: 2
review_passes: 2
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
- 2026-10-12T15:38:16Z · message_queued at 2026-10-12T15:38:16.983Z
- 2026-10-12T15:45:01Z · status active→review
- 2026-10-12T15:45:01Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T15:46:20Z · note: review pass 3: needs some work
- 2026-10-12T15:46:20Z · message_delivered: 1 message(s)
- 2026-10-12T15:46:20Z · status review→active
- 2026-10-12T15:46:30Z · message_queued at 2026-10-12T15:46:30.770Z
- 2026-10-12T15:50:07Z · note: Round 3: the required check is green — repoos check --changed main passed all 5 declared steps (site, native-core, native-app, native-app-bundle, justfile); .repoos/check-results/latest.json records passed=true. Nothing in the automated verification list is actually failing. Added representative prohibited-input cases to scripts/release-config.test.ts for the release/distribution guards: disabled release, non-git-tag provider, non-JSON versionFile, non-http url, unknown kind, malformed github-release repository, and a missing/non-compiling homebrew versionRegex. These mirror the rules RepoOS applies at load. Remaining guard flags were heuristic string-change notices and are now answered.
- 2026-10-12T15:54:33Z · status active→review
- 2026-10-12T15:54:33Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T15:57:22Z · note: review pass 4: failed — no usable report
- 2026-10-12T15:57:22Z · needs_input
- 2026-10-12T15:59:48Z · needs_input
- 2026-10-12T15:59:48Z · status review→active
- 2026-10-12T15:59:48Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-12T15:59:48Z · message_delivered: 1 message(s)
- 2026-10-12T16:01:07Z · note: Shots/UI evidence: no preview target can render the RepoOS Releases page for this task. The only [[preview.targets]] is 'website' (VitePress site; paths=["site/**"], areas=["web","docs"]); the Releases nav is a RepoOS control-plane surface served by 'repoos serve', which the agent must not start. This task's area is 'infra' and the diff touches no site/** path, so shot-target resolution (changed paths -> area -> default command) resolves to none — a declared shot would record 'could not resolve a preview target', not an image. No shot declared; the human eye on the Releases nav at sign-off is the UI evidence. repoos check --changed main is green (all 5 steps passed, .repoos/check-results/latest.json passed=true).
- 2026-10-12T16:01:53Z · status active→review
- 2026-10-12T16:01:53Z · note: shots: skipped — the diff (5 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-12T16:07:20Z · note: review pass 5: needs some work
- 2026-10-12T16:07:20Z · needs_input
