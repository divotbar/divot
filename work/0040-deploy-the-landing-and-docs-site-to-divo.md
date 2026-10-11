---
id: "0040"
title: Deploy the landing and docs site to divotbar.app with GitHub Actions and Cloudflare Pages
type: feature
status: review
priority: p1
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/deploy-the-landing-and-docs-site-to-divo
created_at: "2026-10-11T12:47:04Z"
updated_at: "2026-10-11T13:21:35Z"
review_rounds: 1
review_passes: 1
incomplete_review_retries: 1
---
## Problem

The site builds locally but nothing deploys it. The domain divotbar.app is bought on Cloudflare. The maintainer wants pushes to main to publish the site.

## Desired UX

- A GitHub Actions workflow builds the site (`bun run build`) and deploys `site/.vitepress/dist` to a Cloudflare Pages project served on divotbar.app.
- Deploys run on pushes to main and can be started by hand.
- The canonical URLs and sitemap use https://divotbar.app.

## Acceptance criteria

- Add `.github/workflows/site.yml` using the Cloudflare Pages action, reading the account ID and API token from GitHub secrets. No secrets in the repo.
- Set the site base URL and canonical links to https://divotbar.app.
- Document the one-time setup steps (create the Pages project, add the custom domain, add the two secrets) in docs/infrastructure.md.
- A dry run on a pull request builds without deploying.
- `repoos check` passes.

## Notes for AI

The maintainer will create the Cloudflare token and account secrets; do not guess them. Until secrets exist the deploy job should skip with a clear message, not fail the build.

## Activity

- 2026-10-11T12:47:04Z · created · njachowski@gmail.com
- 2026-10-11T12:47:15Z · status inbox→ready
- 2026-10-11T12:47:15Z · status ready→active, branch
- 2026-10-11T12:49:40Z · status active→review
- 2026-10-11T12:54:06Z · note: review pass 1: incomplete — no verdict in report
- 2026-10-11T12:59:48Z · note: review pass 2: incomplete — no verdict in report
- 2026-10-11T13:18:11Z · status review→active
- 2026-10-11T13:18:11Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T13:18:46Z · status active→review
- 2026-10-11T13:18:46Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (29de07b) during finalization (#0734)
- 2026-10-11T13:19:34Z · note: review pass 3: needs some work
- 2026-10-11T13:19:34Z · status review→active
- 2026-10-11T13:21:35Z · status active→review
- 2026-10-11T13:21:35Z · note: shots: skipped — 1 handoff shot already captured for this exact plan (75663a2) during finalization (#0734)
