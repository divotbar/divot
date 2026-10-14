# Human setup: what only you can do

These steps need your accounts, your secrets, or a decision that only you can
make. The agents cannot do them. Each doc below is self-contained.

| Doc | Covers | Needs |
| --- | --- | --- |
| [cloudflare.md](cloudflare.md) | The `divot-site` Worker, build settings, the `divotbar.app` domain | Cloudflare login |
| [git-main-and-prod.md](git-main-and-prod.md) | Pushing `main`, creating `prod`, cutting the `v0.1.0` release | GitHub push access |
| [homebrew-tap.md](homebrew-tap.md) | Creating `divotbar/homebrew-tap`, its contents, the `HOMEBREW_TAP_TOKEN` secret | GitHub org admin |
| [github-sponsors.md](github-sponsors.md) | The Sponsors profile and the URL to paste | GitHub account |

## Order

1. **Push `main`** (`git-main-and-prod.md`, part 1). Cloudflare and the tap both
   need the code on GitHub first.
2. **Cloudflare** (`cloudflare.md`). Creates the Worker from `prod`. The Worker
   needs `prod` to exist, so do step 1 first.
3. **Homebrew tap** (`homebrew-tap.md`). Independent of the site, but it must
   exist before the first release, or the release skips the cask update.
4. **Cut `v0.1.0`** (`git-main-and-prod.md`, part 3). Do this last, after the
   tap and secret exist, so the first release updates the cask.
5. **Sponsors** (`github-sponsors.md`). Independent. Do it whenever.

## Things to know before you start

- Nothing here commits to `main`. The files in this folder are untracked until
  you commit them. An untracked change in the repo root blocks task close-outs,
  so commit this folder (or move it out) before the next close-out.
- `git push origin main` sends about 3,665 commits. Check you're on the network
  you expect, and that `git status` is clean first.
- Do not run `git push --force` on any of these steps. None of them need it.
