# Git: `main`, `prod`, and the `v0.1.0` release

Three things: push `main` to GitHub, create `prod` from it, and cut the first
release tag. The rules come from
[docs/infrastructure.md](../infrastructure.md) and RepoOS's own practice.

## Rules to keep in mind

- `main` is the working branch. It publishes the **dev** site on every push.
- `prod` moves only by a deliberate fast-forward of `main`. It publishes the
  live site. Never commit to `prod` directly.
- Releases are cut from `main`. The version lives in `package.json`, and a tag
  `v<version>` triggers `.github/workflows/release.yml`.

## Part 1: push `main` and create `prod`

Run from `~/code/nick/divot`. Check the state first:

```bash
cd ~/code/nick/divot
git status
```

The working tree must be clean. Commit or stash anything listed first. Do not
commit to `main` just to clear the tree unless that change is meant for `main`.

Push `main` (about 3,665 commits):

```bash
git push origin main
```

Create `prod` on GitHub from the pushed `main`:

```bash
git push origin main:prod
```

Confirm both branches exist and match:

```bash
git ls-remote --heads origin main prod
```

The two SHAs should match. If they do not, `prod` is behind `main`, which is
fine: it only advances by a deliberate fast-forward later (below).

### Later: advancing `prod` to a new `main`

```bash
git fetch origin
git push origin origin/main:refs/heads/prod
```

Do this only when you want the live site updated. Pushing a non-fast-forward
fails loudly, which is what you want.

## Part 2: the `v0.1.0` release

`package.json` is currently `0.1.0-preview.1`. The release has to write
`0.1.0` into `package.json` and push the matching tag, or the release view and
the tag disagree.

### Recommended: cut it through RepoOS

Divot's `repoos.toml` has a `[release]` block (`provider = "git-tag"`,
`branch = "main"`, `tagPrefix = "v"`). Cut the release on the RepoOS Releases
page:

1. Open the Releases page for the Divot repo in RepoOS.
2. Enter `0.1.0` as the new version (or use **Cut Next** if it suggests `0.1.0`).
3. Confirm the tag `v0.1.0`. RepoOS bumps `package.json`, commits, runs the
   checks, pushes `main`, creates the annotated tag, and pushes it.
4. Pushing the tag starts `.github/workflows/release.yml`, which builds
   `Divot.dmg` and creates the GitHub Release.

RepoOS needs a clean `main` and a passing `repoos check` to cut the release.

### Alternative: by hand

Only if RepoOS is unavailable. Bump the version, commit, and tag by hand:

```bash
cd ~/code/nick/divot
git checkout main
# edit package.json: "version": "0.1.0"
git add package.json
git commit -m "chore: release 0.1.0"
git push origin main
git tag -a v0.1.0 -m "Divot v0.1.0"
git push origin v0.1.0
```

The docs say to prefer RepoOS for this, because a hand-pushed tag that
disagrees with `package.json` confuses the release view.

## Check it worked

- `git ls-remote --tags origin v0.1.0` shows the tag.
- The **Actions** tab on `divotbar/divot` shows the release workflow running and
  then succeeding.
- The **Releases** page on GitHub shows `v0.1.0` with `Divot.dmg` and
  `Divot.dmg.sha256` attached.

## If it fails

- **`git push origin main` rejected:** someone else pushed to `origin/main`. Run
  `git fetch origin`, check the difference, and merge only if it is yours. Do
  not force-push.
- **Release workflow skips the tap step:** `HOMEBREW_TAP_TOKEN` is not set. See
  [homebrew-tap.md](homebrew-tap.md) part 3. The release still succeeds.
- **Tag exists already:** delete it on both sides only if you're sure nothing
  references it, then cut again. Ask before deleting a published tag.
