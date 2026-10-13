---
id: "0090"
title: "Per-task shot selection: DIVOT_SNAPSHOT_ONLY filter and a ## Shots recipe (using RepoOS #0769)"
type: chore
status: ready
priority: p2
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T16:31:06Z"
updated_at: "2026-10-13T16:49:23Z"
---
## Problem
RepoOS #0769 landed: a ## Shots entry for a command target can pass an env map and a per-entry glob, so a task can capture only the images it changed, for example:
[ {"target": "Divot bar", "label": "World clock popover", "env": {"DIVOT_SNAPSHOT_ONLY": "worldclock"}, "glob": "*worldclock*.png"} ]
Divot's 'Divot bar' shot target (#0081) still renders the whole fixed reduced set (about 27 PNGs) for every task, and nothing honours a DIVOT_SNAPSHOT_ONLY variable, so the new filtering has nothing to act on.

## Desired UX
- The snapshot tests accept DIVOT_SNAPSHOT_ONLY=<token>[,<token>...]: only views whose snapshot name contains one of the tokens are rendered and written (tokens used by the file naming: bar, wifi, volume, appearance, calendar, worldclock, battery, charging, keepawake, ...). Unset keeps today's behaviour (the reduced set under DIVOT_SNAPSHOT_SET=shots, the full matrix for scripts/snapshots.sh). Unknown tokens produce a visible note and an empty set, not a silent full run.
- File names are stable and start with the token, so a per-entry glob like *worldclock*.png reliably selects them; document the naming convention.
- Assertions still run for the selected views; selecting nothing never reports success silently.
- scripts/snapshots.sh accepts a --only token list that sets the variable.

## Acceptance criteria
- Implement the filter in SnapshotTestHelpers (shared by the popover and bar snapshot tests); unit tests for token matching, multiple tokens, unknown token note, and unset behaviour.
- Add the missing tokens to existing snapshot names where needed (for example worldclock, keepawake, charging) without changing the full-matrix output set.
- Update docs/popover-snapshot-testing.md and docs/README.md with the ## Shots recipe: how a task declares per-entry env and glob (copy the example above), the token list, and the 'repoos shot --target "Divot bar" --env DIVOT_SNAPSHOT_ONLY=worldclock --glob "*worldclock*.png"' ad hoc form. Add one line to AGENTS.md (Divot conventions): UI tasks declare ## Shots entries that name only the images they change.
- VERIFY: run repoos shot with the filter for two different tokens and confirm each captures only its own images, not tracked (gitignored); describe what you saw in the task. If the installed repoos CLI does not yet support --env/--glob, say so in the task.
- swift test --package-path macos and repoos check --changed main pass.

## Notes for AI
Reference: RepoOS user-docs/configuration.md section on [[shot.targets]] (per-entry env/glob) in ~/code/nick/repoos. Do not commit images.

## Activity

- 2026-10-13T16:31:06Z · created · njachowski@gmail.com
- 2026-10-13T16:49:23Z · status inbox→ready
