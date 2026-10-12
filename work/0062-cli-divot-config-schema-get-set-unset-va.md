---
last_close_out_gate_ms: 66913
last_close_out_gate_at: "2026-10-12T11:51:32.176Z"
id: "0062"
title: "CLI: divot config schema/get/set/unset/validate with --json"
type: feature
status: review
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/cli-divot-config-schema-get-set-unset-va
created_at: "2026-10-12T11:38:56Z"
updated_at: "2026-10-12T11:51:32Z"
review_passes: 1
---
## Problem
Users should be able to have an AI agent configure Divot via chat. The JSON config at ~/.config/divot/config.json is documented but there is no safe, discoverable interface.

## Desired UX
- divot config schema --json: every setting with key, type, range, default, one-line description.
- divot config show --json, get <key>, set <key> <value>, unset <key> using dotted keys (e.g. widgets.clock.seconds).
- divot config validate [--file], and --dry-run/--diff on set.
- Validates with the same schema the app and Settings UI use; atomic write; errors name valid values; clear exit codes.

## Acceptance criteria
- Schema output is generated from the single source the Settings UI and loader use (no hand-copied list); a test fails if a setting lacks a schema entry.
- set/unset round-trip tests, invalid-value rejection tests, atomic write test.
- Subcommand of the existing divot binary; zero runtime dependencies, no private APIs.
- docs/configuration.md and site docs updated.

## Notes for AI
Reuse the #0006 config model and validation. Do not add a daemon or network API.

## Activity

- 2026-10-12T11:38:56Z · created · njachowski@gmail.com
- 2026-10-12T11:39:03Z · status inbox→ready
- 2026-10-12T11:39:04Z · status ready→active, branch
- 2026-10-12T11:47:41Z · status active→review
- 2026-10-12T11:47:41Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-12T11:48:25Z · note: review pass 1: good to go
- 2026-10-12T11:51:32Z · close-out gate completed in 67s

