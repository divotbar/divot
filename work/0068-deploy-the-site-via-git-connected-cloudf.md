---
id: "0068"
title: "Deploy the site via git-connected Cloudflare Workers (main dev, prod production) and enable the Deployments page"
type: chore
status: review
priority: p1
area: [infra, web]
depends_on: ["0067"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/deploy-the-site-via-git-connected-cloudf
cli_override: claude
model_override: sonnet
created_at: "2026-10-12T14:43:34Z"
updated_at: "2026-10-12T18:53:15Z"
---
## Problem
The site deploys through .github/workflows/site.yml (GitHub Actions to Cloudflare Pages, main only, skipped without secrets). The maintainer wants the same setup as the RepoOS repo: git-connected Cloudflare Workers, main = dev, prod = production at divotbar.app, plus the Deployments page in RepoOS.

## Desired UX
- Pushing to main deploys the dev site at the stable main-branch workers.dev URL; fast-forwarding main to prod deploys https://divotbar.app.
- The Deployments page shows both rows.

## Acceptance criteria
- Add wrangler.jsonc at the repo root (pure static assets, no Worker script), modelled on ~/code/nick/repoos/landing/wrangler.jsonc: name divot-site, assets.directory ./site/.vitepress/dist, not_found_handling 404-page. Verify with bunx wrangler deploy --dry-run after bun run build (skip with a note if wrangler cannot run offline).
- Remove the Cloudflare Pages deploy job and secrets check from .github/workflows/site.yml; keep the build/check job so PRs still build. Update docs/infrastructure.md with the Workers setup and the convention (prod only advances by deliberate fast-forward of main).
- Add [[deployments]] rows to repoos.toml (after #0067 lands, merge main first): 'Site (prod)' branch prod, provider cloudflare-workers, url https://divotbar.app, subdir . ; 'Site (dev)' branch main, provider cloudflare-workers, url https://main-divot-site.njachowski.workers.dev, no dashboard_url (the maintainer pastes it later). Use the same field names as ~/code/nick/repoos/repoos.toml. Scope subdir sensibly for a site that lives under site/ with root-level package.json.
- Do not claim the deployment works: first deploy is verified by the maintainer after the Cloudflare setup.
- repoos check passes.

## Notes for AI
Reference ~/code/nick/repoos/landing/README.md 'Deploy (Cloudflare)' and docs/deployments.md. Do not create branches on the remote, push, or touch Cloudflare; those are maintainer steps.

## Activity

- 2026-10-12T14:43:34Z · created · njachowski@gmail.com
- 2026-10-12T17:20:27Z · cli_override, model_override
- 2026-10-12T17:25:20Z · status inbox→ready
- 2026-10-12T17:25:20Z · status ready→active, branch
- 2026-10-12T18:53:15Z · status active→review
