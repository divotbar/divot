# Contributing

Read `AGENTS.md`, `docs/README.md`, and the spec for your area. This is a new product, so identify whether a feature is implemented, proposed, or measured before changing public copy.

## Local checks

```sh
bun install --frozen-lockfile
bun run check
swift test --package-path macos
```

No default web telemetry or third-party fonts. Keep the native bar free of web views and SwiftUI; SwiftUI is allowed for settings. Never put subprocess work, file reads, or network requests on the main thread. Prefer small, explicit interfaces and system frameworks to dependencies.

For task work use the assigned branch/worktree, update affected docs, run `repoos check`, then request review. Human approval and RepoOS own landing. Do not manually edit `work/*.md` or move a task to done as a substitute for close-out.

A real-device QA matrix and signing proof are release requirements, not outcomes an AI may invent. Report test machine, OS, commit, widget set, measurement method, and limitations with every performance result.

## Just recipes

Run `just` for documented, grouped commands. Common entry points: `just install`, `just dev`, `just web-check`, `just macos-test`, `just check`, and `just list`. `just serve` is a foreground, human-operated RepoOS server. `just review <id>` and `just done <id>` use the supported control plane; done still requires human approval. There is no blanket staging/commit recipe.
