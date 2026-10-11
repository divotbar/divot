---
id: "0040"
title: Deploy the landing and docs site to divotbar.app with GitHub Actions and Cloudflare Pages
type: feature
status: ready
priority: p1
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T12:47:04Z"
updated_at: "2026-10-11T12:47:15Z"
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
