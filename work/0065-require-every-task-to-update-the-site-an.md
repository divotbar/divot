---
id: "0065"
title: Require every task to update the site and docs it affects (AGENTS.md rule)
type: chore
status: review
priority: p1
area: docs
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/require-every-task-to-update-the-site-an
created_at: "2026-10-12T11:40:14Z"
updated_at: "2026-10-12T11:44:05Z"
---
## Problem
AGENTS.md step 3 says 'update directly affected docs' but does not name the public site (site/) or the landing page, and nothing checks it. Features have landed with docs updates only when the engineer remembered.

## Desired UX
- AGENTS.md operating loop and a Definition-of-done line state: any task that changes user-visible behaviour, settings, defaults, install steps or CLI must update docs/ AND the matching site/ pages (guide, reference/configuration.md, landing) in the same branch, or state in the task why no docs change applies.
- Public copy distinguishes implemented from planned behaviour; no invented release links.
- Reviewer prompt/checklist, if the repo configures one in repoos.toml, asks 'were docs and site updated?' and flags a missing update as blocking.

## Acceptance criteria
- AGENTS.md updated with the rule; repoos.toml reviewer/check config updated if applicable.
- A docs-drift guard script under scripts/ is added only if it is simple (e.g. fails when macos/Sources/DivotCore config keys change without site/reference/configuration.md changing); otherwise note why not.

## Notes for AI
Edit AGENTS.md on the task branch only; never commit to main. Keep the rule short.

## Activity

- 2026-10-12T11:40:14Z · created · njachowski@gmail.com
- 2026-10-12T11:40:15Z · status inbox→ready
- 2026-10-12T11:40:18Z · status ready→active, branch
- 2026-10-12T11:44:05Z · status active→review
