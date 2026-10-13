---
id: "0081"
title: "Turn on RepoOS shots for the Divot bar and popovers, and prove the capture works end to end"
type: chore
status: active
priority: p1
area: [macos, infra]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/turn-on-repoos-shots-for-the-divot-bar-a
cli_override: claude code
model_override: sonnet
created_at: "2026-10-13T08:21:30Z"
updated_at: "2026-10-13T08:28:57Z"
review_rounds: 2
review_passes: 2
---
## Problem
RepoOS #0761 landed command-based shot targets ([[shot.targets]]: a command renders image files into REPOOS_SHOT_DIR, RepoOS collects them as the task's shots, gitignored under work/.attachments). Divot only has a web preview target, so every native task still reports 'shots: skipped'. Divot already renders popovers and the bar offscreen to PNG (#0078, #0079, scripts/snapshots.sh, DIVOT_SNAPSHOT_DIR).

## Desired UX
- A task that changes macos/Sources/** gets automatic shots at handoff, and a task can declare shots in its ## Shots section, showing the Divot bar and the popovers (Wi-Fi, Volume, Appearance, Calendar) in the Changes tab and drawer.
- The maintainer can run repoos shot --target <name> by hand and see the images.

## Acceptance criteria
- Add [[shot.targets]] rows to repoos.toml (read RepoOS user-docs/configuration.md '[[shot.targets]]' and docs/previews.md 'Evidence shots for non-web targets' for the exact fields: name, areas, paths, command, outputGlob, requires, timeoutMs, cwd). Suggested: one target named 'Divot bar' (areas macos, paths macos/Sources/** and macos/Tests/**, command that runs the snapshot tests with DIVOT_SNAPSHOT_DIR set to "$REPOOS_SHOT_DIR", outputGlob ["**/*.png"], requires swift, a generous timeoutMs because swift test is slow). Do not touch the existing website preview target.
- The snapshot helpers currently refuse a DIVOT_SNAPSHOT_DIR that does not contain 'snapshots' or '.build' (BarSnapshotTests.swift preconditionFailure) and write ~40 PNGs. Make them accept the RepoOS-provided directory (REPOOS_SHOT_DIR is gitignored by RepoOS) without weakening the never-commit guarantee, and add a smaller shot set for RepoOS (for example a few representative themes/modes, bar plus each popover) selected by an environment variable, so a handoff capture is fast and does not flood the Changes tab; keep the full matrix for scripts/snapshots.sh.
- Prove it end to end and record the evidence in the task: run repoos shot --target for the new target and confirm PNGs of the bar AND at least one popover (for example the Appearance or Volume popover) appear; confirm they are NOT tracked (git status clean, git check-ignore passes) and the task-asset guard still passes. If a step cannot work in the agent environment (for example no display), say exactly what and why; do not invent evidence.
- Declare a ## Shots entry for this task (repoos update --shots) naming the target so the handoff capture is exercised, and note what the handoff recorded (shots captured or the visible skipped reason).
- Document in docs/ how shots work for Divot (one short section), and add the target to docs/README.md if appropriate.
- swift test --package-path macos still passes; repoos check --changed main passes.

## Notes for AI
Repo rule: do not commit images; repoos.toml edits happen on this task's branch only. Opening a popup 'for real' is not required: popovers are rendered offscreen by the existing snapshot tests, and that is the supported path. Do not use screencapture or Screen Recording. If the RepoOS server in this repo does not yet have #0761 (check repoos shot --help), stop and say so in a task note.

## Evidence
Run in this worktree (agent shell, offscreen AppKit rendering worked):
- repoos shot --target "Divot bar" reported 8 shots saved: bar (chips off) plus Wi-Fi, Volume and Appearance popovers, native light and dark, default text size. A manual run of the same command with DIVOT_SNAPSHOT_SET=shots wrote exactly those 8 PNGs. Repeated runs add a numeric suffix to the collected file names, so the Changes tab can show -1/-2 duplicates from earlier runs.
- git status shows only source, docs and config changes; git check-ignore matches work/.attachments/ (.gitignore:17) for the shots directory. repoos check passes, including the task-asset guard.
- Not done: the ## Shots entry. repoos update --shots reads the MAIN checkout's repoos.toml, which has no 'Divot bar' target until this branch merges (error: unknown target, valid names: website), and the main checkout is off-limits. Declare it after merge: repoos update 0081 --shots '[{"target":"Divot bar","route":"/","label":"Divot bar and popovers"}]'. The handoff capture therefore relies on path matching (macos/Tests/**); a human must confirm what it records.
- Calendar has no snapshot test, so no shot. Popover pixel assertions are disabled (they never ran before); reconciling them is follow-up.

## Activity

- 2026-10-13T08:21:30Z · created · njachowski@gmail.com
- 2026-10-13T08:21:33Z · status inbox→ready
- 2026-10-13T08:21:34Z · cli_override, model_override
- 2026-10-13T08:21:34Z · status ready→active, branch
- 2026-10-13T08:25:07Z · status active→review
- 2026-10-13T08:25:07Z · note: shots: skipped — 10 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T08:26:38Z · note: review pass 1: needs some work
- 2026-10-13T08:26:39Z · status review→active
- 2026-10-13T08:26:58Z · body: section Evidence
- 2026-10-13T08:27:50Z · status active→review
- 2026-10-13T08:27:50Z · note: shots: skipped — 10 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T08:28:57Z · note: review pass 2: needs some work
- 2026-10-13T08:28:57Z · status review→active
