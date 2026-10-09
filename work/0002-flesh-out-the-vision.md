---
id: "0002"
title: Flesh out the product vision and initial architecture
type: spec
status: inbox
needs_input: true
needs_input_reason: underspecified
needs_input_detail: "missing sections: Problem, Acceptance criteria"
hold: true
priority: p2
area: product
assigned_to: unassigned
created_by: repoos-init
branch: ""
updated_at: "2026-10-09T16:29:46Z"
---
## Overview

This project started from a short description. This task turns it into
something a team can actually build from — a shared vision, an initial
architecture, and a first batch of concrete work.

## Project description

> Divot: an open-source, performance-first native macOS status bar. Swift and AppKit with event-driven widgets. Workspaces sit left of the camera notch; status widgets sit right. Includes a static Vue landing page and customization documentation.

## What to do

1. Read the description above and the rest of this repo.
2. If docs already exist in `docs/`, read them first instead of asking the
owner for the vision — they may already answer most of the questions below.
3. Work through the questions that block design — on your own, or with the
project's owner:
- Who is this for, and what is the smallest useful first release?
- What stack and hosting, and why those over the alternatives?
- What is explicitly **out of scope** for now?
4. Write the answers into `docs/` — at minimum a short vision note and an
architecture note. Keep them specific to this project.
5. Break the result into a handful of concrete tasks with
`repoos new "<title>"`, and move the ones that are ready into `ready`.
6. Record the docs you wrote here, then hand this task off with
`repoos mv <id> review` and stop — RepoOS runs the checks and moves the
status (or `done` if there is genuinely nothing left to capture).

## Notes for AI

This task is self-contained: the description above and the questions in step 2
are the prompt. Ask the human before inventing answers about stack, scope or
priorities — a short back-and-forth here saves a lot of rework later.

## Activity

- 2026-10-09T16:18:38Z · held
- 2026-10-09T16:29:46Z · needs_input
