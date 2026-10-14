# Cloudflare: the `divot-site` Worker

This is the one-time setup for the website. It follows the same pattern RepoOS
uses for its own sites: a git-connected Worker driven by `wrangler.jsonc`, with
`main` as the dev branch and `prod` as production. The source of truth is
[docs/infrastructure.md](../infrastructure.md#static-hosting-and-deployment).

## Before you start

- Push `main` and create `prod` first (see [git-main-and-prod.md](git-main-and-prod.md)
  part 1). Cloudflare needs the `prod` branch to exist to pick it as production.
- Have access to the Cloudflare account that owns `divotbar.app`.

## Steps

1. Sign in at https://dash.cloudflare.com.
2. Go to **Workers & Pages** → **Create** → **Connect to Git**.
3. Choose the **divotbar/divot** repository and authorise Cloudflare's GitHub
   app for it if asked.
4. Set the build settings:
   - **Worker name:** `divot-site`
   - **Production branch:** `prod`
   - **Build command:** `bun install && bun run build`
   - **Deploy command:** leave the default (`npx wrangler deploy`)
   - **Root directory / path:** the repository root (`wrangler.jsonc` and
     `package.json` are both there)
   - **Builds for non-production branches:** on. This publishes `main` to the
     dev URL, `https://main-divot-site.njachowski.workers.dev`.
5. Save and deploy. Cloudflare creates an API token automatically. You do not
   add a secret yourself.
6. **Custom domain:** open the `divot-site` Worker → **Settings** → **Domains &
   Routes** → **Add** → **Custom domain** → `divotbar.app`. Follow the DNS
   prompts if the zone is on Cloudflare. It should be.
7. **Dashboard URL:** copy the Worker's dashboard URL from the address bar (it
   looks like `https://dash.cloudflare.com/<account-id>/workers/services/view/divot-site`).
   Paste it into `repoos.toml` as the `dashboard_url` of the `[[deployments]]`
   rows (the empty string is there now). Commit that change on a task branch,
   not `main` directly.

## Check it worked

- `https://main-divot-site.njachowski.workers.dev` loads the site after the first
  build of `main`.
- `https://divotbar.app` loads the site after the first build of `prod`.
- The build log shows `bun run build` succeeding. A failing build is not a
  deploy, so check the log, not just the URL.

## If it fails

- **Build fails:** read the build log. The build command must be exactly
  `bun install && bun run build`, as in the steps above. If the log says `bun`
  is not found, that is a Cloudflare build-image question. Ask in the chat with
  the log, rather than changing the command.
- **`prod` not listed as a production branch:** push `prod` first (see
  git-main-and-prod.md), then reconnect the Worker's production branch.
- **Domain shows an error:** the zone's DNS must be on Cloudflare. If the
  domain is registered elsewhere, move its nameservers first.
