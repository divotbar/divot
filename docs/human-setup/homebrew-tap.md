# Homebrew tap: `divotbar/homebrew-tap`

This sets up the tap that serves `brew install --cask divotbar/tap/divot`. The
rules come from
[docs/infrastructure.md](../infrastructure.md#homebrew-cask). The contents
are already prepared in `packaging/homebrew-tap/`.

## Part 1: create the repository

1. On GitHub, open the `divotbar` organisation (or your account, if the tap is
   under it). The repository `divotbar/homebrew-tap` should already exist and be
   empty. If it does not, create it: **New repository** → name
   `homebrew-tap` → **Public** → no README (the folder has one).

## Part 2: push the tap contents

The tap repository's root must contain `Casks/`, `README.md`, and `.github/`.
Copy the contents of `packaging/homebrew-tap/` into a fresh clone of the tap, so
the tap gets its own history:

```bash
git clone https://github.com/divotbar/homebrew-tap.git ~/code/nick/homebrew-tap
cp -R ~/code/nick/divot/packaging/homebrew-tap/. ~/code/nick/homebrew-tap/
cd ~/code/nick/homebrew-tap
git add -A
git commit -m "Initial tap: Divot cask and release workflows"
git push origin HEAD:main
```

The clone may warn that it is empty. That is expected. If the tap's default
branch is not `main`, push to whatever it is, and tell the agents, since they
read `main`.

Check the layout:

```bash
ls ~/code/nick/homebrew-tap
```

It should list `Casks`, `README.md` and `.github`.

## Part 3: the `HOMEBREW_TAP_TOKEN` secret

The Divot release workflow sends a `divot-release` event to the tap. It needs a
token that can do that. The workflow skips the dispatch with a clear message
when the secret is missing, so the release still succeeds without it.

1. Create a **fine-grained personal access token** on GitHub: **Settings** →
   **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
   → **Generate new token**.
2. Set:
   - **Resource owner:** `divotbar`
   - **Repository access:** **Only select repositories** → `divotbar/homebrew-tap`
   - **Repository permissions:** **Contents: Read and write**
   - **Expiration:** pick a date you will remember to renew
3. Copy the token. GitHub shows it once.
4. Add it to the **Divot** repository (not the tap):
   **divotbar/divot** → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret** → name `HOMEBREW_TAP_TOKEN`, value the token.

A classic token with the `repo` scope also works, but the fine-grained token is
narrower, so prefer it.

## Part 4: check it

The first real check happens with the first release (see
[git-main-and-prod.md](git-main-and-prod.md) part 2). After `v0.1.0` is out:

1. The **Actions** tab on `divotbar/divot` shows **Request Homebrew tap update**
   succeeding in the release run.
2. The tap's **Actions** tab shows its `divot-release` workflow running, then
   committing an updated `Casks/divot.rb`.
3. On a Mac:

   ```bash
   brew install --cask divotbar/tap/divot
   ```

   It should install `Divot.app`. Because the build is unsigned, the first
   launch needs right-click → **Open**. The cask caveats say this.

Until the first release, `Casks/divot.rb` carries clearly marked placeholders.
That is intended.

## If it fails

- **Dispatch skipped:** the release log says `HOMEBREW_TAP_TOKEN` is not set.
  Add the secret (part 3), then re-run the release job. The tap workflow only
  runs on a `divot-release` dispatch, so there is no "Run workflow" button to
  use instead.
- **Dispatch returns 401 or 403:** the token is wrong, expired, or not scoped to
  `divotbar/homebrew-tap`. Regenerate it with the scope in part 3.
- **Cask not updated after dispatch:** check the tap's `divot-release` run log.
  It reads the version, DMG URL and SHA-256 from the release assets, so the
  release must have finished uploading them.
