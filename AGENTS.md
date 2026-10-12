# AGENTS.md

This repo uses **RepoOS**: tasks are markdown files under `work/`, and the
repo itself is the source of truth. This file tells AI agents how to operate.

## For AI agents, day one

New to this repo? The board is `work/` — one markdown file per task.
Create work with `repoos new "<title>"`, move it with `repoos mv <id> <status>`,
and **never** edit `work/*.md` by hand (use the CLI or the HTTP API).
Project context lives under `docs/`; start there. Run `repoos serve` in a
terminal you keep open, or install `repoos service` for an unattended server —
a detached `repoos serve` started from an agent shell is reaped as a stray orphan
(see `docs/agent-process-safety.md`). RepoOS runs each managed agent turn in its
own process group and tears that group down when the turn ends; never use `pkill`
or `killall` to clean up helpers. When a task is done, run `repoos check` and
hand off with `repoos mv <id> review`; see the operating loop below.

## Operating loop

For a RepoOS-managed task runner:

1. Read this file, your assigned task under `work/`, and relevant
   project docs under `docs/` — start from the index at
   `docs/README.md`, which lists the reading order. Before reading a
   large file, run `repoos outline <path>` to get its symbols with line
   numbers, then read only the range you need instead of the whole file.
2. Work in the task branch and dedicated worktree RepoOS assigned. The server
   owns activation and worktree setup; do not claim another task or edit its
   frontmatter directly.
3. Implement the task, update the docs and public site it affects (see
   **Definition of done**), and run `repoos check --changed main`. It must pass
   before handoff.
4. Request handoff with `repoos mv <id> review` or finish your reply with
   `::repoos-handoff-ready::`, then end your turn. In your own runner session,
   both record a request without changing status. RepoOS commits the branch,
   runs checks, verifies the tested tree stayed unchanged, and then moves the
   task to `review`. Failure leaves it `active` with the reason shown.
5. Leave the worktree open and stop. Do not merge the branch or mark it done.
   Requested fixes continue on the same worktree with another checked handoff.

Interactive agents helping on a task use its same branch/worktree and the
same review/close-out workflow. Coordinate with any live engineer/reviewer
before editing. Do not edit a task's worktree while it is in `review` or
close-out — check `.repoos/locks/<id>.json` if unsure. Outside a managed
runner, `repoos mv <id> review` writes metadata that the server intercepts
asynchronously; wait for finalization, not just the CLI command's return.
Runner-only signals do not apply there.

## Definition of done

A change to user-visible behaviour, settings, defaults, install steps, or the
CLI is not done until it updates **both** `docs/` and the matching `site/`
pages (the guide, `site/reference/configuration.md`, and the landing page) in
the same branch. If no docs change applies, the task says so and why. Public
copy distinguishes implemented from planned behaviour and never invents
release links or availability. `scripts/docs-drift.ts`, run by `bun run check`,
fails a native-configuration change that does not update the configuration
reference and contract.

## Review and sign-off

RepoOS owns review and close-out whether or not this repo has a Git remote.
Do not open a PR, push a task branch, or substitute GitHub approval/merge
unless the human explicitly requests that separate workflow.

The reviewer agent, when enabled, writes an advisory report in the task drawer.
It does not edit code or replace human approval. After the human approves,
use **Move to done** in RepoOS or `POST /api/tasks/:id/done`. The server
merges the task into a separate candidate worktree, validates the combined
result, rechecks the primary branch under a publication lock, publishes,
cleans up, and records completion. `repoos mv <id> done` only changes metadata;
it does not run close-out or merge code.

A direct commit on the primary branch is an exception requiring explicit
human authorization. If that already-landed work has a branchless task record,
the `/done` endpoint can check the primary checkout and record release without
a candidate merge. Do not erase a task's branch metadata to force this path.

## Rules

- **`repoos.toml` owns the layout.** `workDir` (`work`) and `docsDir`
  (`docs`) are authoritative: tasks live under `work/` and project
  docs under `docs/` because the config says so. Never move, rename or
  relocate those directories, and never "fix" a layout you think is wrong by
  moving files. If project docs or a person's own notes disagree with the
  config, report the mismatch — the fix is to update `repoos.toml` with human
  approval (or correct the docs), never to move directories on your own. Do not
  invent ownership rules for RepoOS directories; the config is the only source
  of truth for layout.
- **Never** move task files between folders. Status lives in frontmatter.
- **Never write directly to `work/*.md` files.** All task creation and
  manipulation goes through `repoos` commands or HTTP API endpoints
  (`POST /api/tasks`, `PATCH /api/tasks/:id`, etc.). If the RepoOS server
  is unreachable, stop and report the issue — do not hand-write task files.
- **The Product Manager agent is authorized to create and update tasks.** It
  must use those same RepoOS CLI commands or HTTP API endpoints for task body,
  metadata, and status changes; it must never edit task Markdown directly.
- **Never** deploy to production without human sign-off.
- Keep frontmatter tidy; `repoos` will normalize key order on write.
- One task = one focused worktree.
- **Never invent evidence.** Do not fabricate device sessions, live API results,
  external account IDs, or registration details. Leave those fields blank and
  say a human must supply the proof. Split acceptance criteria that require a
  real device, account, or third-party registration into a separate human-only
  task.

## Conventions

Document stack-specific conventions here (framework, lint, test commands).

## UI previews are server-owned

Never run `repoos serve` yourself and never pick a port — RepoOS owns the
control-plane port and every preview port, and direct serve attempts from agent
processes are rejected. Preview requests are the human's to make — do NOT
automatically request a preview before handoff or as a routine part of finishing
a task. If the human explicitly asks you to verify a change the way a browser
would see it, request this task's managed preview by emitting the exact signal
line (idempotent, and no localhost or curl is required — your sandbox may have
no network access to the control plane):

    ::repoos-preview-request::

RepoOS validates the request against your live run, starts the preview from
your worktree, probes it server-side, and records the preview URL and probe
result in your task transcript. The preview is reaped when the task leaves
active/review.

## Declaring evidence shots (## Shots)

A task body may carry a `## Shots` section with a fenced JSON list of capture
entries (see `src/core/shot-plan.ts`). Each entry has `target`, `route`, an
optional `selector` (element crop — the exception), an optional `highlight`
CSS selector (outlines changed elements), a `label`, and optional ordered
`steps` (click/fill/wait, plain CSS selectors). Use `repoos update <id>
--shots '<JSON list>'` to declare it (the CLI validates the JSON and writes the
fenced section) without touching the rest of the body — a full `--body` replace that drops
Problem / Desired UX / Acceptance criteria / Notes for AI is refused unless
`--force` is passed.

For tabbed views (e.g. Agents), prefer `?tab=<id>` routes
(`/agents?tab=detected`) over click steps to reach the right tab, and always
set `highlight` to the changed elements. A declared `highlight` or `selector`
that matches nothing at capture time records a visible warning — capture still
succeeds. Declared shots default to the whole visible window (`fullPage:
false`) with changed elements outlined via `highlight`; `selector` (element
crop) is the exception and `fullPage` stays off.

## Section body edits

To replace a single `## Section` without touching the rest of the body (the
Activity log is always preserved), use:

    repoos update <id> --section "Section Name" --section-body "new content"

A full `--body` replace that would drop Problem / Desired UX / Acceptance
criteria / Notes for AI is refused unless `--force` is passed; the error
message points at this section form.

## Divot conventions

Start at `docs/README.md`. macOS 26+ / Apple silicon; Swift 6.2+, AppKit for the persistent bar, optional SwiftUI for settings. No native runtime dependencies, WebKit bar, private APIs, or permanent render loop. Main actor owns UI; providers collect off-main and update only changed widgets.

Website: Vue 3/VitePress, static output, Bun tooling. Run `bun run check` and `swift test --package-path macos`. Use the existing local Lake Tahoe photo with its credited CC BY-SA 3.0 license; code/docs are MIT. No invented release links, benchmarks, or app availability. Public copy must distinguish planned behavior from implemented code. Keep the Tahoe editorial direction: warm paper, alpine blue/pine, restrained typography; avoid generic card grids and decorative animation.
