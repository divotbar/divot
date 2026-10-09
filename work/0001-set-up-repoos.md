---
id: "0001"
title: Set up RepoOS
type: chore
status: done
hold: true
priority: p2
area: infra
assigned_to: unassigned
created_by: human
branch: ""
updated_at: "2026-10-09T16:18:38Z"
---
## Overview

Divot: an open-source, performance-first native macOS status bar. Swift and AppKit with event-driven widgets. Workspaces sit left of the camera notch; status widgets sit right. Includes a static Vue landing page and customization documentation.

## Problem

The repo needed a lightweight, repo-native way to track work that AI agents
and humans share. Tasks live as markdown files, versioned in git.

## Desired UX

Run `repoos list` to see the board. Run `repoos show 0001` to read a task
(this one). Agents read these files directly for full context.

## Acceptance criteria

- [x] `repoos init` scaffolded work/, repoos.toml, AGENTS.md
- [x] `repoos list` shows this task
- [x] Editing the `status:` field moves it across the board

This task exists to show you the shape of a task file — it's done because
running `repoos init` already satisfies everything above. There's nothing to
"work" here; move on to your next task.

## Notes for AI

Status is a frontmatter field — never move files between folders. Keep diffs
small. Read AGENTS.md before starting any task.

## Activity

- 2026-10-09T16:18:38Z · held
