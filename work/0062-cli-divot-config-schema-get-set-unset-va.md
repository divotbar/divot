---
id: "0062"
title: "CLI: divot config schema/get/set/unset/validate with --json"
type: feature
status: inbox
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T11:38:56Z"
updated_at: "2026-10-12T11:38:56Z"
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
